begin;

create function app_private.prepare_group_creation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication is required to create a group';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) then
    raise exception 'Complete your profile before creating a group';
  end if;

  new.created_by := v_user_id;
  new.name := btrim(new.name);

  if new.name is null or char_length(new.name) = 0 then
    raise exception 'Group name cannot be blank';
  end if;

  if char_length(new.name) > 120 then
    raise exception 'Group name must be 120 characters or fewer';
  end if;

  if new.currency_code is null or new.currency_code !~ '^[A-Z]{3}$' then
    raise exception 'Currency code must be a three-letter uppercase ISO code';
  end if;

  if new.archived_at is not null then
    raise exception 'New groups cannot be archived';
  end if;

  return new;
end;
$$;

create trigger groups_prepare_creation
before insert on public.groups
for each row execute function app_private.prepare_group_creation();

create or replace function app_private.protect_group_fields()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
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

create or replace function app_private.enforce_group_member_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
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

drop policy if exists group_members_insert_administrator on public.group_members;
revoke insert on table public.group_members from authenticated;

create function public.add_guest_member(
  p_group_id uuid,
  p_display_name text
)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := btrim(p_display_name);
  v_archived_at timestamptz;
  v_member public.group_members;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to add a guest';
  end if;

  if not app_private.is_group_admin(p_group_id, v_user_id) then
    raise exception 'Only an active group owner or administrator can add guests';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = p_group_id
  for update;

  if not found then
    raise exception 'Group is unavailable';
  end if;

  if v_archived_at is not null then
    raise exception 'Guests cannot be added to an archived group';
  end if;

  if v_display_name is null or char_length(v_display_name) = 0 then
    raise exception 'Guest display name cannot be blank';
  end if;

  if char_length(v_display_name) > 80 then
    raise exception 'Guest display name must be 80 characters or fewer';
  end if;

  insert into public.group_members (group_id, user_id, display_name, role)
  values (
    p_group_id,
    null,
    v_display_name,
    'member'::public.group_member_role
  )
  returning * into v_member;

  return v_member;
end;
$$;

revoke all on function app_private.prepare_group_creation() from public;
revoke all on function app_private.protect_group_fields() from public;
revoke all on function app_private.enforce_group_member_transition() from public;
revoke all on function public.add_guest_member(uuid, text) from public;
grant execute on function public.add_guest_member(uuid, text) to authenticated;

commit;
