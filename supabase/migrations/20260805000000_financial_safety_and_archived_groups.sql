begin;

create table public.financial_operations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users (id) on delete set null,
  operation_id uuid not null,
  operation_type text not null check (operation_type in ('expense', 'settlement')),
  group_id uuid not null references public.groups (id) on delete restrict,
  request_fingerprint text not null check (char_length(request_fingerprint) = 64),
  expense_id uuid references public.expenses (id) on delete restrict,
  settlement_id uuid references public.settlements (id) on delete restrict,
  created_at timestamptz not null default now(),
  check (
    (operation_type = 'expense' and expense_id is not null and settlement_id is null)
    or (operation_type = 'settlement' and settlement_id is not null and expense_id is null)
  )
);

create unique index financial_operations_creator_operation
  on public.financial_operations (created_by, operation_id)
  where created_by is not null;

alter table public.financial_operations enable row level security;
revoke all on table public.financial_operations from anon, authenticated;

alter function public.create_expense(
  uuid,
  text,
  bigint,
  timestamptz,
  jsonb,
  jsonb
) rename to create_expense_unchecked_internal;

alter function public.record_settlement(
  uuid,
  uuid,
  uuid,
  bigint,
  timestamptz
) rename to record_settlement_unchecked_internal;

revoke all on function public.create_expense_unchecked_internal(
  uuid,
  text,
  bigint,
  timestamptz,
  jsonb,
  jsonb
) from public, authenticated;

revoke all on function public.record_settlement_unchecked_internal(
  uuid,
  uuid,
  uuid,
  bigint,
  timestamptz
) from public, authenticated;

create function public.create_expense(
  p_group_id uuid,
  p_description text,
  p_total_amount_minor bigint,
  p_occurred_at timestamptz,
  p_payers jsonb,
  p_splits jsonb,
  p_operation_id uuid
)
returns public.expenses
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_description text := btrim(p_description);
  v_fingerprint text;
  v_operation public.financial_operations;
  v_expense public.expenses;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to create an expense';
  end if;
  if p_operation_id is null then
    raise exception 'An expense operation ID is required';
  end if;
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) or not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Only an active group member can create an expense';
  end if;

  v_fingerprint := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'description', v_description,
          'group_id', p_group_id,
          'occurred_at', p_occurred_at,
          'payers', p_payers,
          'splits', p_splits,
          'total_amount_minor', p_total_amount_minor,
          'type', 'expense'
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':' || p_operation_id::text, 0)
  );

  select operation.*
  into v_operation
  from public.financial_operations as operation
  where operation.created_by = v_user_id
    and operation.operation_id = p_operation_id;
  if found then
    if v_operation.operation_type <> 'expense'
      or v_operation.group_id <> p_group_id
      or v_operation.request_fingerprint <> v_fingerprint then
      raise exception 'This operation ID was already used for a different financial request';
    end if;
    select expense.*
    into v_expense
    from public.expenses as expense
    where expense.id = v_operation.expense_id;
    if not found then
      raise exception 'The existing expense operation is unavailable';
    end if;
    return v_expense;
  end if;

  select *
  into v_expense
  from public.create_expense_unchecked_internal(
    p_group_id,
    p_description,
    p_total_amount_minor,
    p_occurred_at,
    p_payers,
    p_splits
  );

  insert into public.financial_operations (
    created_by,
    operation_id,
    operation_type,
    group_id,
    request_fingerprint,
    expense_id
  ) values (
    v_user_id,
    p_operation_id,
    'expense',
    p_group_id,
    v_fingerprint,
    v_expense.id
  );
  return v_expense;
end;
$$;

create function public.record_settlement(
  p_group_id uuid,
  p_paying_member_id uuid,
  p_receiving_member_id uuid,
  p_amount_minor bigint,
  p_settled_at timestamptz,
  p_operation_id uuid
)
returns public.settlements
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_fingerprint text;
  v_operation public.financial_operations;
  v_settlement public.settlements;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to record a settlement';
  end if;
  if p_operation_id is null then
    raise exception 'A settlement operation ID is required';
  end if;
  if p_settled_at is null then
    raise exception 'Settlement date is required';
  end if;
  if p_settled_at > now() + interval '5 minutes' then
    raise exception 'Settlement date cannot be in the future';
  end if;
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) or not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Group is unavailable';
  end if;

  v_fingerprint := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'amount_minor', p_amount_minor,
          'group_id', p_group_id,
          'paying_member_id', p_paying_member_id,
          'receiving_member_id', p_receiving_member_id,
          'settled_at', p_settled_at,
          'type', 'settlement'
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':' || p_operation_id::text, 0)
  );

  select operation.*
  into v_operation
  from public.financial_operations as operation
  where operation.created_by = v_user_id
    and operation.operation_id = p_operation_id;
  if found then
    if v_operation.operation_type <> 'settlement'
      or v_operation.group_id <> p_group_id
      or v_operation.request_fingerprint <> v_fingerprint then
      raise exception 'This operation ID was already used for a different financial request';
    end if;
    select settlement.*
    into v_settlement
    from public.settlements as settlement
    where settlement.id = v_operation.settlement_id;
    if not found then
      raise exception 'The existing settlement operation is unavailable';
    end if;
    return v_settlement;
  end if;

  select *
  into v_settlement
  from public.record_settlement_unchecked_internal(
    p_group_id,
    p_paying_member_id,
    p_receiving_member_id,
    p_amount_minor,
    p_settled_at
  );

  insert into public.financial_operations (
    created_by,
    operation_id,
    operation_type,
    group_id,
    request_fingerprint,
    settlement_id
  ) values (
    v_user_id,
    p_operation_id,
    'settlement',
    p_group_id,
    v_fingerprint,
    v_settlement.id
  );
  return v_settlement;
end;
$$;

create or replace function app_private.assert_active_settlement_members()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.settled_at > now() + interval '5 minutes' then
    raise exception 'Settlement date cannot be in the future';
  end if;

  if tg_op = 'UPDATE'
    and new.group_id = old.group_id
    and new.paying_member_id = old.paying_member_id
    and new.receiving_member_id = old.receiving_member_id then
    return new;
  end if;

  if not exists (
    select 1
    from public.group_members as member
    where member.id = new.paying_member_id
      and member.group_id = new.group_id
      and member.removed_at is null
  ) then
    raise exception 'The paying settlement member must be active in the settlement group';
  end if;
  if not exists (
    select 1
    from public.group_members as member
    where member.id = new.receiving_member_id
      and member.group_id = new.group_id
      and member.removed_at is null
  ) then
    raise exception 'The receiving settlement member must be active in the settlement group';
  end if;
  return new;
end;
$$;

create or replace function public.void_expense(p_expense_id uuid)
returns public.expenses
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_expense public.expenses;
  v_group_archived_at timestamptz;
begin
  select expense.*
  into v_expense
  from public.expenses as expense
  where expense.id = p_expense_id
  for update;
  if not found then
    raise exception 'Expense not found';
  end if;
  if not app_private.can_manage_expense(v_expense.id, auth.uid()) then
    raise exception 'Only an active expense manager can void this expense';
  end if;
  select group_record.archived_at
  into v_group_archived_at
  from public.groups as group_record
  where group_record.id = v_expense.group_id
  for update;
  if v_group_archived_at is not null then
    raise exception 'Expenses cannot be changed in an archived group';
  end if;
  if v_expense.status = 'voided'::public.expense_status then
    raise exception 'Expense is already voided';
  end if;
  update public.expenses
  set status = 'voided'::public.expense_status,
      voided_at = now()
  where id = p_expense_id
  returning * into v_expense;
  return v_expense;
end;
$$;

create or replace function public.void_settlement(p_settlement_id uuid)
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

create or replace function public.remove_group_member(p_group_id uuid, p_member_id uuid)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor_role public.group_member_role;
  v_member public.group_members;
  v_group_archived_at timestamptz;
  v_net_balance_minor bigint;
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

  select balance.net_balance_minor
  into v_net_balance_minor
  from public.get_group_balances(p_group_id) as balance
  where balance.group_member_id = p_member_id;
  if coalesce(v_net_balance_minor, 0) <> 0 then
    raise exception 'A member must settle their balance before removal';
  end if;

  update public.group_members
  set removed_at = now()
  where id = v_member.id
  returning * into v_member;
  return v_member;
end;
$$;

revoke insert, update, delete on table public.expenses from authenticated;
revoke insert, update, delete on table public.expense_payers from authenticated;
revoke insert, update, delete on table public.expense_splits from authenticated;
revoke insert, update, delete on table public.settlements from authenticated;
revoke execute on function public.create_equal_expense(uuid, text, bigint, timestamptz, uuid, uuid[]) from authenticated;
revoke execute on function public.finalize_expense(uuid) from authenticated;

revoke all on function public.create_expense(uuid, text, bigint, timestamptz, jsonb, jsonb, uuid) from public;
revoke all on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz, uuid) from public;
grant execute on function public.create_expense(uuid, text, bigint, timestamptz, jsonb, jsonb, uuid) to authenticated;
grant execute on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz, uuid) to authenticated;

commit;
