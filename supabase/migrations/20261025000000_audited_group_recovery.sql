begin;

create table public.group_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  event_type text not null check (event_type in ('archived','reopened','operator_recovered')),
  actor_id uuid references auth.users(id) on delete set null,
  successor_member_id uuid references public.group_members(id),
  reason text,
  created_at timestamptz not null default now()
);
create index group_lifecycle_events_history on public.group_lifecycle_events(group_id,created_at,id);
alter table public.group_lifecycle_events enable row level security;
revoke all on public.group_lifecycle_events from public,anon,authenticated;
grant select on public.group_lifecycle_events to authenticated;
create policy group_lifecycle_member_read on public.group_lifecycle_events for select to authenticated
using (app_private.is_active_group_member(group_id,auth.uid()));

create table app_private.group_reopen_guards(group_id uuid primary key);
alter table app_private.group_reopen_guards enable row level security;
revoke all on app_private.group_reopen_guards from public,anon,authenticated,service_role;

create or replace function app_private.protect_group_fields()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
  if old.archived_at is not null and new.archived_at is null
     and (to_jsonb(new)-'archived_at'-'updated_at')=(to_jsonb(old)-'archived_at'-'updated_at')
     and exists(select 1 from app_private.group_reopen_guards where group_id=old.id) then
    return new;
  end if;
  if old.created_by is not null and new.created_by is null
     and (to_jsonb(new)-'created_by'-'updated_at')=(to_jsonb(old)-'created_by'-'updated_at')
     and exists(select 1 from app_private.account_deletion_guards where user_id=old.created_by) then
    return new;
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at then
    raise exception 'Group identity fields cannot be changed';
  end if;
  if old.archived_at is not null and (to_jsonb(new)-'updated_at') is distinct from (to_jsonb(old)-'updated_at') then
    raise exception 'Archived groups cannot be changed';
  end if;
  if old.created_by is not null and new.created_by is not null and new.created_by is distinct from old.created_by then
    raise exception 'A group creator cannot be reassigned';
  end if;
  if new.currency_code is distinct from old.currency_code and exists(select 1 from public.expenses where group_id=old.id) then
    raise exception 'Group currency cannot change after expenses exist';
  end if;
  return new;
end;
$$;

create or replace function public.archive_group(p_group_id uuid)
returns public.groups language plpgsql security definer set search_path=pg_catalog as $$
declare v_group public.groups;
begin
  select * into v_group from public.groups where id=p_group_id for update;
  if not app_private.is_group_admin(p_group_id,auth.uid()) then
    raise exception 'Only an active group owner or administrator can archive a group';
  end if;
  if not found or v_group.id is null then raise exception 'Group is unavailable'; end if;
  if v_group.archived_at is not null then raise exception 'Group is already archived'; end if;
  update public.groups set archived_at=now() where id=p_group_id returning * into v_group;
  insert into public.group_lifecycle_events(group_id,event_type,actor_id) values(p_group_id,'archived',auth.uid());
  return v_group;
end;
$$;

create function public.reopen_group(p_group_id uuid)
returns public.groups language plpgsql security definer set search_path=pg_catalog as $$
declare v_group public.groups;
begin
  select * into v_group from public.groups where id=p_group_id for update;
  if not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()
                and role='owner' and removed_at is null) then
    raise exception 'Only the active group owner can reopen this group';
  end if;
  if v_group.archived_at is null then return v_group; end if;
  insert into app_private.group_reopen_guards values(p_group_id);
  update public.groups set archived_at=null where id=p_group_id returning * into v_group;
  delete from app_private.group_reopen_guards where group_id=p_group_id;
  insert into public.group_lifecycle_events(group_id,event_type,actor_id) values(p_group_id,'reopened',auth.uid());
  return v_group;
end;
$$;

-- Trusted support only: never exposed as a mobile administrator override.
-- Requires an ownerless archive and an existing active registered successor.
create function public.recover_ownerless_archived_group(p_group_id uuid,p_successor_member_id uuid,p_reason text)
returns public.groups language plpgsql security definer set search_path=pg_catalog as $$
declare v_group public.groups;
begin
  select * into v_group from public.groups where id=p_group_id for update;
  if v_group.id is null or v_group.archived_at is null then raise exception 'An archived group is required'; end if;
  if exists(select 1 from public.group_members where group_id=p_group_id and role='owner' and removed_at is null and user_id is not null) then
    raise exception 'The group already has an active owner';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 10 and 500 then raise exception 'A recovery reason of 10 to 500 characters is required'; end if;
  if not exists(select 1 from public.group_members m join public.profiles p on p.id=m.user_id
                where m.id=p_successor_member_id and m.group_id=p_group_id and m.removed_at is null
                and p.onboarding_completed_at is not null) then
    raise exception 'Choose an existing active registered member';
  end if;
  insert into app_private.group_reopen_guards values(p_group_id);
  update public.groups set archived_at=null where id=p_group_id returning * into v_group;
  delete from app_private.group_reopen_guards where group_id=p_group_id;
  update public.group_members set role='owner' where id=p_successor_member_id;
  insert into public.group_lifecycle_events(group_id,event_type,successor_member_id,reason)
  values(p_group_id,'operator_recovered',p_successor_member_id,btrim(p_reason));
  return v_group;
end;
$$;

create or replace function public.get_account_deletion_blockers()
returns table(group_name text,reason text) language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_member public.group_members; v_group public.groups;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  for v_member in select * from public.group_members where user_id=auth.uid() loop
    select * into v_group from public.groups where id=v_member.group_id;
    if v_member.role='owner' and v_member.removed_at is null and v_group.archived_at is null then
      group_name:=v_group.name;reason:='Transfer ownership or archive this group before deleting your account';return next;
    end if;
    if exists(select 1 from app_private.group_balance_rows(v_member.group_id) b where b.group_member_id=v_member.id and b.net_balance_minor<>0) then
      group_name:=v_group.name;
      reason:=case when v_group.archived_at is null then 'Settle this membership balance before deleting your account'
        when exists(select 1 from public.group_members where group_id=v_member.group_id and role='owner' and removed_at is null and user_id is not null)
        then 'Ask the group owner to reopen this archive in Group settings, then record the external settlement'
        else 'Ask support for audited ownerless-group recovery, then record the external settlement' end;
      return next;
    end if;
  end loop;
end;
$$;

revoke all on function public.reopen_group(uuid) from public,anon;
grant execute on function public.reopen_group(uuid) to authenticated;
revoke all on function public.recover_ownerless_archived_group(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.recover_ownerless_archived_group(uuid,uuid,text) to service_role;
commit;
