begin;

drop policy if exists settlements_insert_active_member on public.settlements;
drop policy if exists settlements_update_manager on public.settlements;

create policy settlements_insert_active_member
on public.settlements
for insert to authenticated
with check (
  created_by = auth.uid()
  and voided_at is null
  and app_private.is_active_group_member(group_id, auth.uid())
  and exists (
    select 1
    from public.groups as group_record
    where group_record.id = group_id
      and group_record.archived_at is null
  )
);

create policy settlements_update_manager
on public.settlements
for update to authenticated
using (
  app_private.can_manage_settlement(id, auth.uid())
  and exists (
    select 1
    from public.groups as group_record
    where group_record.id = group_id
      and group_record.archived_at is null
  )
)
with check (
  app_private.can_manage_settlement(id, auth.uid())
  and exists (
    select 1
    from public.groups as group_record
    where group_record.id = group_id
      and group_record.archived_at is null
  )
);

grant insert, update (voided_at) on table public.settlements to authenticated;

create function public.record_settlement(
  p_group_id uuid,
  p_paying_member_id uuid,
  p_receiving_member_id uuid,
  p_amount_minor bigint,
  p_settled_at timestamptz
)
returns public.settlements
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_settlement public.settlements;
  v_archived_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to record a settlement';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) then
    raise exception 'Complete your profile before recording a settlement';
  end if;

  if not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Group is unavailable';
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
    raise exception 'Settlements cannot be recorded in an archived group';
  end if;

  if p_paying_member_id is null
    or p_receiving_member_id is null
    or p_paying_member_id = p_receiving_member_id then
    raise exception 'Choose two different active group members';
  end if;

  if p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'Settlement amount must be greater than zero';
  end if;

  if p_settled_at is null then
    raise exception 'Settlement date is required';
  end if;

  if (
    select count(*)
    from public.group_members as member
    where member.group_id = p_group_id
      and member.id in (p_paying_member_id, p_receiving_member_id)
      and member.removed_at is null
  ) <> 2 then
    raise exception 'Settlement members must be active in this group';
  end if;

  insert into public.settlements (
    group_id,
    paying_member_id,
    receiving_member_id,
    amount_minor,
    settled_at,
    created_by
  ) values (
    p_group_id,
    p_paying_member_id,
    p_receiving_member_id,
    p_amount_minor,
    p_settled_at,
    v_user_id
  )
  returning * into v_settlement;

  return v_settlement;
end;
$$;

create function public.void_settlement(p_settlement_id uuid)
returns public.settlements
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_settlement public.settlements;
  v_archived_at timestamptz;
begin
  select settlement.*
  into v_settlement
  from public.settlements as settlement
  where settlement.id = p_settlement_id
  for update;

  if not found then
    raise exception 'Settlement is unavailable';
  end if;

  if not app_private.can_manage_settlement(v_settlement.id, auth.uid()) then
    raise exception 'Only an active settlement manager can void this settlement';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = v_settlement.group_id
  for update;

  if v_archived_at is not null then
    raise exception 'Settlements cannot be changed in an archived group';
  end if;

  if v_settlement.voided_at is not null then
    raise exception 'Settlement is already voided';
  end if;

  update public.settlements
  set voided_at = now()
  where id = v_settlement.id
  returning * into v_settlement;

  return v_settlement;
end;
$$;

create function public.get_group_settlements(p_group_id uuid)
returns table (
  settlement_id uuid,
  paying_member_id uuid,
  paying_member_name text,
  receiving_member_id uuid,
  receiving_member_name text,
  amount_minor bigint,
  settled_at timestamptz,
  is_voided boolean,
  voided_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication is required to load settlements';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) or not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Group is unavailable';
  end if;

  return query
  select
    settlement.id,
    settlement.paying_member_id,
    paying_member.display_name,
    settlement.receiving_member_id,
    receiving_member.display_name,
    settlement.amount_minor,
    settlement.settled_at,
    settlement.voided_at is not null,
    settlement.voided_at,
    settlement.created_at
  from public.settlements as settlement
  join public.group_members as paying_member
    on paying_member.id = settlement.paying_member_id
    and paying_member.group_id = settlement.group_id
  join public.group_members as receiving_member
    on receiving_member.id = settlement.receiving_member_id
    and receiving_member.group_id = settlement.group_id
  where settlement.group_id = p_group_id
  order by settlement.settled_at desc, settlement.created_at desc, settlement.id desc;
end;
$$;

revoke all on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz) from public;
revoke all on function public.void_settlement(uuid) from public;
revoke all on function public.get_group_settlements(uuid) from public;
grant execute on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz) to authenticated;
grant execute on function public.void_settlement(uuid) to authenticated;
grant execute on function public.get_group_settlements(uuid) to authenticated;

commit;
