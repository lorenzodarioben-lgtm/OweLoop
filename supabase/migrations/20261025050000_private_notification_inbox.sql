begin;
create table public.notification_reads(
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_key text not null check(char_length(notification_key) between 1 and 100),
  read_at timestamptz not null default now(),
  primary key(user_id,notification_key)
);
alter table public.notification_reads enable row level security;
revoke all on public.notification_reads from public,anon,authenticated;

-- Notifications are projections of authoritative records, not financial writes.
-- Current membership is rechecked every time; removal hides historical details.
create function app_private.notification_rows(p_user_id uuid)
returns table(notification_key text,group_id uuid,group_name text,kind text,occurred_at timestamptz,expense_id uuid)
language sql stable security definer set search_path=pg_catalog as $$
with membership as materialized(select m.group_id from public.group_members m where m.user_id=p_user_id and m.removed_at is null)
select 'expense:'||e.id,g.id,g.name,case when e.event_type::text='expense_finalized' then 'expense_posted' else 'expense_voided' end,e.created_at,e.expense_id
from public.expense_events e join membership m on m.group_id=e.group_id join public.groups g on g.id=e.group_id
where e.event_type::text in ('expense_finalized','expense_voided')
union all
select 'group:'||e.id,g.id,g.name,'group_'||e.event_type,e.created_at,null::uuid
from public.group_lifecycle_events e join membership m on m.group_id=e.group_id join public.groups g on g.id=e.group_id
union all
select 'settlement:'||s.id,g.id,g.name,'settlement_recorded',s.created_at,null::uuid
from public.settlements s join membership m on m.group_id=s.group_id join public.groups g on g.id=s.group_id
union all
select 'settlement-void:'||s.id,g.id,g.name,'settlement_voided',s.voided_at,null::uuid
from public.settlements s join membership m on m.group_id=s.group_id join public.groups g on g.id=s.group_id where s.voided_at is not null
union all
select 'invitation:'||i.id,g.id,g.name,'invitation',i.created_at,null::uuid
from public.group_invitations i join public.groups g on g.id=i.group_id
where i.recipient_user_id=p_user_id and i.expires_at>now() and i.accepted_at is null
and i.declined_at is null and i.revoked_at is null and i.expired_at is null and g.archived_at is null
union all
select 'claim:'||c.id,g.id,g.name,'guest_claim',c.created_at,null::uuid
from public.guest_claim_requests c join public.groups g on g.id=c.group_id
join public.group_members guest on guest.id=c.guest_member_id and guest.group_id=c.group_id
where c.recipient_user_id=p_user_id and c.expires_at>now() and c.accepted_at is null
and c.declined_at is null and c.revoked_at is null and c.expired_at is null and g.archived_at is null
and guest.user_id is null and guest.removed_at is null;
$$;
revoke all on function app_private.notification_rows(uuid) from public,anon,authenticated;

create function public.get_notification_page(p_limit integer default 50,
  p_before_at timestamptz default null,p_before_key text default null,p_unread_only boolean default false)
returns setof jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then raise exception 'Complete your profile before viewing notifications'; end if;
  if p_limit is null or p_limit not between 1 and 100 or num_nonnulls(p_before_at,p_before_key) not in (0,2)
    or char_length(p_before_key)>100 or p_unread_only is null then raise exception 'Invalid notification request'; end if;
  return query select to_jsonb(n)||jsonb_build_object('is_read',r.notification_key is not null)
  from app_private.notification_rows(auth.uid()) n left join public.notification_reads r on r.user_id=auth.uid() and r.notification_key=n.notification_key
  where (not p_unread_only or r.notification_key is null)
    and (p_before_key is null or (n.occurred_at,n.notification_key)<(p_before_at,p_before_key))
  order by n.occurred_at desc,n.notification_key desc limit p_limit+1;
end;
$$;

create function public.mark_notification_read(p_notification_key text)
returns void language plpgsql security definer set search_path=pg_catalog as $$
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null)
    or p_notification_key is null or char_length(p_notification_key)>100
    or not exists(select 1 from app_private.notification_rows(auth.uid()) where notification_key=p_notification_key) then raise exception 'Notification is unavailable'; end if;
  insert into public.notification_reads(user_id,notification_key) values(auth.uid(),p_notification_key) on conflict do nothing;
end;
$$;
revoke all on function public.get_notification_page(integer,timestamptz,text,boolean) from public,anon;
revoke all on function public.mark_notification_read(text) from public,anon;
grant execute on function public.get_notification_page(integer,timestamptz,text,boolean) to authenticated;
grant execute on function public.mark_notification_read(text) to authenticated;

-- Preserve caller-only export while extending it with newly introduced data.
alter function public.export_personal_data() rename to export_personal_data_base_internal;
revoke all on function public.export_personal_data_base_internal() from public,anon,authenticated;
create function public.export_personal_data()
returns jsonb language sql stable security definer set search_path=pg_catalog as $$
select public.export_personal_data_base_internal()||jsonb_build_object(
 'readable_group_templates',(select coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]') from public.expense_templates t where app_private.is_active_group_member(t.group_id,auth.uid())),
 'notification_read_state',(select coalesce(jsonb_agg(to_jsonb(r) order by r.notification_key),'[]') from public.notification_reads r where r.user_id=auth.uid()));
$$;
revoke all on function public.export_personal_data() from public,anon;
grant execute on function public.export_personal_data() to authenticated;
commit;
