begin;

create function public.rename_group(p_group_id uuid, p_name text)
returns public.groups
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_name text := btrim(p_name);
  v_group public.groups;
begin
  if not app_private.is_group_admin(p_group_id, auth.uid()) then
    raise exception 'Only an active group owner or administrator can rename a group';
  end if;
  if v_name is null or char_length(v_name) = 0 then
    raise exception 'Group name cannot be blank';
  end if;
  if char_length(v_name) > 120 then
    raise exception 'Group name must be 120 characters or fewer';
  end if;

  select group_record.*
  into v_group
  from public.groups as group_record
  where group_record.id = p_group_id
  for update;
  if not found or v_group.archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  update public.groups
  set name = v_name
  where id = p_group_id
  returning * into v_group;
  return v_group;
end;
$$;

create function public.archive_group(p_group_id uuid)
returns public.groups
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_group public.groups;
begin
  if not app_private.is_group_admin(p_group_id, auth.uid()) then
    raise exception 'Only an active group owner or administrator can archive a group';
  end if;
  select group_record.*
  into v_group
  from public.groups as group_record
  where group_record.id = p_group_id
  for update;
  if not found then
    raise exception 'Group is unavailable';
  end if;
  if v_group.archived_at is not null then
    raise exception 'Group is already archived';
  end if;

  update public.groups
  set archived_at = now()
  where id = p_group_id
  returning * into v_group;
  return v_group;
end;
$$;

create function public.remove_group_member(p_group_id uuid, p_member_id uuid)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor_role public.group_member_role;
  v_member public.group_members;
  v_group_archived_at timestamptz;
begin
  select member.role
  into v_actor_role
  from public.group_members as member
  where member.group_id = p_group_id
    and member.user_id = auth.uid()
    and member.removed_at is null
  for update;

  if not found or v_actor_role not in ('owner'::public.group_member_role, 'admin'::public.group_member_role) then
    raise exception 'Only an active group owner or administrator can remove members';
  end if;

  select group_record.archived_at
  into v_group_archived_at
  from public.groups as group_record
  where group_record.id = p_group_id
  for update;
  if not found or v_group_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  select member.*
  into v_member
  from public.group_members as member
  where member.id = p_member_id
    and member.group_id = p_group_id
    and member.removed_at is null
  for update;
  if not found then
    raise exception 'Active group member not found';
  end if;
  if v_member.role = 'owner'::public.group_member_role then
    raise exception 'Transfer ownership before removing an owner';
  end if;
  if v_actor_role = 'admin'::public.group_member_role
    and v_member.role <> 'member'::public.group_member_role then
    raise exception 'Only a group owner can remove an administrator';
  end if;

  update public.group_members
  set removed_at = now()
  where id = v_member.id
  returning * into v_member;
  return v_member;
end;
$$;

revoke all on function public.rename_group(uuid, text) from public;
revoke all on function public.archive_group(uuid) from public;
revoke all on function public.remove_group_member(uuid, uuid) from public;
grant execute on function public.rename_group(uuid, text) to authenticated;
grant execute on function public.archive_group(uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

commit;
