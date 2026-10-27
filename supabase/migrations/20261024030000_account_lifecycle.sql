begin;
create table app_private.account_deletion_guards(user_id uuid primary key);
alter table app_private.account_deletion_guards enable row level security;
revoke all on app_private.account_deletion_guards from public,anon,authenticated,service_role;
create or replace function app_private.enforce_group_member_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  -- Only the trusted Auth deletion trigger can install this transactional guard.
  if old.user_id is not null and new.user_id is null
     and new.display_name='Deleted member' and new.role='member' and new.removed_at is not null
     and new.id=old.id and new.group_id=old.group_id and new.created_at=old.created_at
     and exists(select 1 from app_private.account_deletion_guards where user_id=old.user_id) then
    return new;
  end if;
  if new.id is distinct from old.id
    or new.group_id is distinct from old.group_id
    or new.created_at is distinct from old.created_at then
    raise exception 'Group membership identity fields cannot be changed';
  end if;

  if exists (
    select 1
    from public.groups as group_record
    where group_record.id = old.group_id
      and group_record.archived_at is not null
  ) then
    raise exception 'Archived group memberships cannot be changed';
  end if;

  if old.user_id is not null
    and new.user_id is not null
    and new.user_id is distinct from old.user_id then
    raise exception 'A registered membership cannot be reassigned to another user';
  end if;

  if old.removed_at is not null and new.removed_at is distinct from old.removed_at then
    raise exception 'A removed membership cannot be reactivated';
  end if;

  if old.role = 'owner'::public.group_member_role
    and old.removed_at is null
    and (
      new.role <> 'owner'::public.group_member_role
      or new.removed_at is not null
    )
    and not exists (
      select 1
      from public.group_members as member
      where member.group_id = old.group_id
        and member.id <> old.id
        and member.role = 'owner'::public.group_member_role
        and member.removed_at is null
    ) then
    raise exception 'A group must retain an active owner';
  end if;

  return new;
end;
$$;

create or replace function app_private.protect_group_fields()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if old.created_by is not null and new.created_by is null
     and (to_jsonb(new)-'created_by'-'updated_at')=(to_jsonb(old)-'created_by'-'updated_at')
     and exists(select 1 from app_private.account_deletion_guards where user_id=old.created_by) then
    return new;
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at then
    raise exception 'Group identity fields cannot be changed';
  end if;

  if old.archived_at is not null
    and (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    raise exception 'Archived groups cannot be changed';
  end if;

  if old.created_by is not null
    and new.created_by is not null
    and new.created_by is distinct from old.created_by then
    raise exception 'A group creator cannot be reassigned';
  end if;

  if new.currency_code is distinct from old.currency_code and exists (
    select 1
    from public.expenses as expense
    where expense.group_id = old.id
  ) then
    raise exception 'Group currency cannot change after expenses exist';
  end if;

  return new;
end;
$$;


create function public.get_account_deletion_blockers()
returns table(group_name text,reason text)
language plpgsql stable security definer set search_path=pg_catalog
as $$
declare v_member public.group_members; v_group public.groups;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  for v_member in select * from public.group_members where user_id=auth.uid() loop
    select * into v_group from public.groups where id=v_member.group_id;
    if v_member.role='owner' and v_member.removed_at is null and v_group.archived_at is null then
      group_name:=v_group.name;reason:='Transfer ownership or archive this group before deleting your account';return next;
    end if;
    if exists(select 1 from app_private.group_balance_rows(v_member.group_id) b
              where b.group_member_id=v_member.id and b.net_balance_minor<>0) then
      group_name:=v_group.name;reason:='Settle this membership balance before deleting your account';return next;
    end if;
  end loop;
end;
$$;

create function app_private.prepare_auth_account_deletion()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_member public.group_members;
begin
  -- Financial/membership writes use the same group lock, in deterministic order.
  perform g.id from public.groups g where exists(
    select 1 from public.group_members m where m.group_id=g.id and m.user_id=old.id)
  order by g.id for update;
  if exists(select 1 from public.group_members m join public.groups g on g.id=m.group_id
            where m.user_id=old.id and m.role='owner' and m.removed_at is null and g.archived_at is null) then
    raise exception 'Transfer ownership or archive owned groups before account deletion';
  end if;
  for v_member in select * from public.group_members where user_id=old.id loop
    if exists(select 1 from app_private.group_balance_rows(v_member.group_id) b
              where b.group_member_id=v_member.id and b.net_balance_minor<>0) then
      raise exception 'Settle all membership balances before account deletion';
    end if;
  end loop;
  insert into app_private.account_deletion_guards values(old.id);
  update public.group_members set user_id=null,display_name='Deleted member',
    role='member',removed_at=coalesce(removed_at,now()) where user_id=old.id;
  return old;
end;
$$;
create function app_private.finish_auth_account_deletion()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
begin delete from app_private.account_deletion_guards where user_id=old.id; return old; end;
$$;
create trigger oweloop_prepare_account_deletion before delete on auth.users
for each row execute function app_private.prepare_auth_account_deletion();
-- Name sorts after immediate FK action triggers, retaining the guard for
-- archived groups' creator de-identification during ON DELETE SET NULL.
create trigger zz_oweloop_finish_account_deletion after delete on auth.users
for each row execute function app_private.finish_auth_account_deletion();

create function public.export_personal_data()
returns jsonb language plpgsql stable security definer set search_path=pg_catalog
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication is required'; end if;
  return jsonb_build_object('format','oweloop-personal-v1','exported_at',now(),
    'profile',(select to_jsonb(p) from public.profiles p where p.id=v_user),
    'memberships',coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from public.group_members m where m.user_id=v_user),'[]'::jsonb),
    'created_expenses',coalesce((select jsonb_agg(to_jsonb(e) order by e.id) from public.expenses e where e.created_by=v_user),'[]'::jsonb),
    'created_settlements',coalesce((select jsonb_agg(to_jsonb(s) order by s.id) from public.settlements s where s.created_by=v_user),'[]'::jsonb),
    'pending_invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'group_id',i.group_id,'expires_at',i.expires_at)) from public.group_invitations i where i.recipient_user_id=v_user),'[]'::jsonb),
    'pending_guest_claims',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'group_id',c.group_id,'guest_member_id',c.guest_member_id,'expires_at',c.expires_at)) from public.guest_claim_requests c where c.recipient_user_id=v_user),'[]'::jsonb));
end;
$$;
revoke all on function public.get_account_deletion_blockers() from public;
revoke all on function public.export_personal_data() from public;
revoke all on function app_private.prepare_auth_account_deletion() from public;
revoke all on function app_private.finish_auth_account_deletion() from public;
grant execute on function public.get_account_deletion_blockers() to authenticated;
grant execute on function public.export_personal_data() to authenticated;
commit;
