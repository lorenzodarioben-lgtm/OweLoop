begin;
create table public.expense_receipts(
 id uuid primary key,
 expense_id uuid not null,
 group_id uuid not null references public.groups(id),
 foreign key(expense_id,group_id) references public.expenses(id,group_id),
 object_key text not null unique,
 sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
 mime_type text not null check(mime_type in ('image/png','image/jpeg')),
 size_bytes integer not null check(size_bytes between 1 and 4194304),
 state text not null default 'pending' check(state in ('pending','ready','deleting','deleted')),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index expense_receipts_expense on public.expense_receipts(expense_id,created_at,id);
create table public.receipt_events(
 id uuid primary key default gen_random_uuid(),
 receipt_id uuid not null references public.expense_receipts(id),
 group_id uuid not null references public.groups(id),
 event_type text not null check(event_type in ('reserved','ready','deleting','deleted')),
 actor_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
alter table public.expense_receipts enable row level security;
alter table public.receipt_events enable row level security;
revoke all on public.expense_receipts,public.receipt_events from public,anon,authenticated;
grant select on public.expense_receipts,public.receipt_events to authenticated;
create policy receipt_read on public.expense_receipts for select to authenticated using(
 app_private.is_active_group_member(group_id,auth.uid()) and
 (state='ready' or created_by=auth.uid() or app_private.is_group_admin(group_id,auth.uid())));
create policy receipt_event_read on public.receipt_events for select to authenticated
 using(app_private.is_active_group_member(group_id,auth.uid()));

create function public.get_expense_receipts(p_expense_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare e public.expenses; g public.groups;
begin
 select * into e from public.expenses where id=p_expense_id;
 select * into g from public.groups where id=e.group_id;
 if e.id is null or not app_private.is_active_group_member(e.group_id,auth.uid()) then raise exception 'Expense is unavailable'; end if;
 return jsonb_build_object('can_upload',g.archived_at is null and e.status='posted',
  'receipts',(select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('can_delete',g.archived_at is null
   and r.state<>'deleted' and (coalesce(r.created_by=auth.uid(),false) or app_private.is_group_admin(r.group_id,auth.uid()))) order by r.created_at,r.id),'[]')
   from public.expense_receipts r where r.expense_id=e.id and (r.state='ready' or r.created_by=auth.uid() or app_private.is_group_admin(r.group_id,auth.uid()))));
end;
$$;
create function public.reserve_expense_receipt(p_receipt_id uuid,p_expense_id uuid,p_sha256 text,p_mime_type text,p_size_bytes integer)
returns public.expense_receipts language plpgsql security definer set search_path=pg_catalog as $$
declare e public.expenses; g public.groups; r public.expense_receipts;
begin
 select * into e from public.expenses where id=p_expense_id;
 select * into g from public.groups where id=e.group_id for update;
 if e.id is null or not app_private.is_active_group_member(e.group_id,auth.uid())
   or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null)
   or g.archived_at is not null or e.status<>'posted' then raise exception 'Receipt upload is unavailable'; end if;
 if p_receipt_id is null or p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$'
   or p_mime_type is null or p_mime_type not in ('image/png','image/jpeg')
   or p_size_bytes is null or p_size_bytes not between 1 and 4194304 then raise exception 'Invalid receipt'; end if;
 -- Global ID lock prevents concurrent cross-group reuse of one upload identity.
 perform pg_advisory_xact_lock(hashtextextended('receipt:'||p_receipt_id::text,0));
 select * into r from public.expense_receipts where id=p_receipt_id;
 if found then
   if r.created_by is distinct from auth.uid() or r.expense_id<>p_expense_id or r.sha256<>p_sha256
     or r.mime_type<>p_mime_type or r.size_bytes<>p_size_bytes or r.state not in ('pending','ready') then raise exception 'Receipt identity is unavailable'; end if;
   return r;
 end if;
 if (select count(*) from public.expense_receipts where expense_id=e.id and state<>'deleted')>=20 then raise exception 'Expense receipt limit reached'; end if;
 insert into public.expense_receipts(id,expense_id,group_id,object_key,sha256,mime_type,size_bytes,created_by)
 values(p_receipt_id,e.id,e.group_id,e.id::text||'/'||p_receipt_id::text||case when p_mime_type='image/png' then '.png' else '.jpg' end,p_sha256,p_mime_type,p_size_bytes,auth.uid()) returning * into r;
 insert into public.receipt_events(receipt_id,group_id,event_type,actor_id) values(r.id,r.group_id,'reserved',auth.uid());
 return r;
end;
$$;
create function public.delete_expense_receipt(p_receipt_id uuid)
returns public.expense_receipts language plpgsql security definer set search_path=pg_catalog as $$
declare r public.expense_receipts; g public.groups;
begin
 select * into r from public.expense_receipts where id=p_receipt_id;
 select * into g from public.groups where id=r.group_id for update;
 select * into r from public.expense_receipts where id=p_receipt_id for update;
 if r.id is null or not app_private.is_active_group_member(r.group_id,auth.uid()) or g.archived_at is not null
   or not(coalesce(r.created_by=auth.uid(),false) or app_private.is_group_admin(r.group_id,auth.uid())) then raise exception 'Receipt deletion is unavailable'; end if;
 if r.state in ('deleting','deleted') then return r; end if;
 update public.expense_receipts set state='deleting',updated_at=now() where id=r.id returning * into r;
 insert into public.receipt_events(receipt_id,group_id,event_type,actor_id) values(r.id,r.group_id,'deleting',auth.uid());
 return r;
end;
$$;
-- Only the trusted gateway can confirm that object bytes were validated/stored,
-- or that deletion completed. No client can turn an upload intent into a receipt.
create function public.finish_expense_receipt(p_receipt_id uuid,p_actor_id uuid,p_deleted boolean default false)
returns public.expense_receipts language plpgsql security definer set search_path=pg_catalog as $$
declare r public.expense_receipts; g public.groups;
begin
 select * into r from public.expense_receipts where id=p_receipt_id;
 select * into g from public.groups where id=r.group_id for update;
 select * into r from public.expense_receipts where id=p_receipt_id for update;
 if r.id is null or p_deleted is null then raise exception 'Receipt is unavailable'; end if;
 if p_deleted then
   if r.state='deleted' then return r; end if;
   if r.state<>'deleting' then raise exception 'Receipt deletion was not authorized'; end if;
   update public.expense_receipts set state='deleted',updated_at=now() where id=r.id returning * into r;
 else
   if r.state='ready' then return r; end if;
   if r.state<>'pending' or r.created_by is distinct from p_actor_id or g.archived_at is not null
     or not app_private.is_active_group_member(r.group_id,p_actor_id)
     or not exists(select 1 from public.expenses where id=r.expense_id and status='posted') then raise exception 'Receipt completion is unavailable'; end if;
   update public.expense_receipts set state='ready',updated_at=now() where id=r.id returning * into r;
 end if;
 insert into public.receipt_events(receipt_id,group_id,event_type,actor_id) values(r.id,r.group_id,r.state,p_actor_id);
 return r;
end;
$$;
create function public.claim_stale_receipt(p_receipt_id uuid,p_expected_updated_at timestamptz)
returns public.expense_receipts language plpgsql security definer set search_path=pg_catalog as $$
declare r public.expense_receipts;
begin
 select * into r from public.expense_receipts where id=p_receipt_id for update;
 if r.id is null or r.state not in ('pending','deleting','deleted') or r.updated_at is distinct from p_expected_updated_at
   or r.updated_at>now()-interval '24 hours' then raise exception 'Receipt is not stale'; end if;
 -- A tombstone sweep removes any late object from an interrupted stale upload.
 -- Deleted identities cannot be reused; ready attachments are never candidates.
 if r.state='deleted' then return r; end if;
 update public.expense_receipts set state='deleting',updated_at=now() where id=r.id returning * into r;
 insert into public.receipt_events(receipt_id,group_id,event_type) values(r.id,r.group_id,'deleting');
 return r;
end;
$$;
revoke all on function public.get_expense_receipts(uuid),public.reserve_expense_receipt(uuid,uuid,text,text,integer),public.delete_expense_receipt(uuid) from public,anon;
grant execute on function public.get_expense_receipts(uuid),public.reserve_expense_receipt(uuid,uuid,text,text,integer),public.delete_expense_receipt(uuid) to authenticated;
revoke all on function public.finish_expense_receipt(uuid,uuid,boolean),public.claim_stale_receipt(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.finish_expense_receipt(uuid,uuid,boolean),public.claim_stale_receipt(uuid,timestamptz) to service_role;
create function public.get_stale_receipt_candidates(p_after_id uuid default null)
returns setof public.expense_receipts language sql stable security definer set search_path=pg_catalog as $$
 select * from public.expense_receipts where state in ('pending','deleting','deleted')
   and updated_at<now()-interval '24 hours' and (p_after_id is null or id>p_after_id)
 order by id limit 50;
$$;
revoke all on function public.get_stale_receipt_candidates(uuid) from public,anon,authenticated;
grant execute on function public.get_stale_receipt_candidates(uuid) to service_role;

-- Storage is optional in minimal SQL-only upgrade databases. Actual receipt
-- delivery requires the real Storage service and gateway, verified separately.
do $$ begin
 if to_regclass('storage.buckets') is not null then
   insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
   values('oweloop-receipts','oweloop-receipts',false,4194304,array['image/png','image/jpeg']) on conflict(id) do nothing;
   if exists(select 1 from storage.buckets where id='oweloop-receipts' and (public or file_size_limit is null or file_size_limit>4194304
      or allowed_mime_types is distinct from array['image/png','image/jpeg'])) then raise exception 'Existing receipt bucket configuration is unsafe'; end if;
   execute $policy$create policy receipt_object_read on storage.objects for select to authenticated using(bucket_id='oweloop-receipts' and exists(
     select 1 from public.expense_receipts r where r.object_key=name and r.state='ready' and app_private.is_active_group_member(r.group_id,auth.uid())))$policy$;
   execute $policy$create policy receipt_read_guard on storage.objects as restrictive for select to anon,authenticated using(bucket_id<>'oweloop-receipts' or exists(
     select 1 from public.expense_receipts r where r.object_key=name and r.state='ready' and app_private.is_active_group_member(r.group_id,auth.uid())))$policy$;
   execute $policy$create policy receipt_insert_guard on storage.objects as restrictive for insert to anon,authenticated with check(bucket_id<>'oweloop-receipts')$policy$;
   execute $policy$create policy receipt_update_guard on storage.objects as restrictive for update to anon,authenticated using(bucket_id<>'oweloop-receipts') with check(bucket_id<>'oweloop-receipts')$policy$;
   execute $policy$create policy receipt_delete_guard on storage.objects as restrictive for delete to anon,authenticated using(bucket_id<>'oweloop-receipts')$policy$;
 end if;
end $$;

alter function public.export_personal_data() rename to export_personal_data_pre_receipt_internal;
revoke all on function public.export_personal_data_pre_receipt_internal() from public,anon,authenticated;
create function public.export_personal_data() returns jsonb language sql stable security definer set search_path=pg_catalog as $$
select public.export_personal_data_pre_receipt_internal()||jsonb_build_object(
 'readable_receipt_metadata',(select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]') from public.expense_receipts r where app_private.is_active_group_member(r.group_id,auth.uid())
   and (r.state='ready' or r.created_by=auth.uid() or app_private.is_group_admin(r.group_id,auth.uid()))),
 'readable_receipt_events',(select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]') from public.receipt_events e where app_private.is_active_group_member(e.group_id,auth.uid())));
$$;
revoke all on function public.export_personal_data() from public,anon;
grant execute on function public.export_personal_data() to authenticated;
commit;
