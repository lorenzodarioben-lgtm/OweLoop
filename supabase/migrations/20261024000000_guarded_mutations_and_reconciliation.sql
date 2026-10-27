begin;

-- All membership/group changes now use guarded RPCs. Revoke both table and
-- column grants; table-level checks alone do not describe column privileges.
revoke update on public.groups from authenticated;
revoke update (name, currency_code, archived_at) on public.groups from authenticated;
revoke update on public.group_members from authenticated;
revoke update (display_name, removed_at) on public.group_members from authenticated;
revoke update (description, total_amount_minor, occurred_at) on public.expenses from authenticated;
revoke update (amount_minor) on public.expense_payers from authenticated;
revoke update (amount_minor) on public.expense_splits from authenticated;
revoke update (voided_at) on public.settlements from authenticated;
create or replace function public.create_expense(
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
  -- Serialize against archive, removal, invitation and claim transitions.
  perform 1 from public.groups where id = p_group_id for update;

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

create or replace function public.record_settlement(
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
  -- Serialize against archive, removal, invitation and claim transitions.
  perform 1 from public.groups where id = p_group_id for update;

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


-- An authenticated caller can reconcile only an operation they created.
-- This read remains usable after removal so a lost response is never mistaken
-- for failure. It reveals no payload, recipient identity or other user's work.
create function public.get_financial_operation(p_operation_id uuid)
returns table (operation_type text, group_id uuid, expense_id uuid, settlement_id uuid)
language plpgsql security definer set search_path = pg_catalog
as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  return query select o.operation_type, o.group_id, o.expense_id, o.settlement_id
  from public.financial_operations o
  where o.created_by = auth.uid() and o.operation_id = p_operation_id;
end;
$$;
revoke all on function public.get_financial_operation(uuid) from public;
grant execute on function public.get_financial_operation(uuid) to authenticated;

create function public.leave_group(p_group_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog
as $$
declare v_member public.group_members; v_archived timestamptz;
begin
  select archived_at into v_archived from public.groups where id = p_group_id for update;
  if not found or v_archived is not null then raise exception 'Group is unavailable'; end if;
  select * into v_member from public.group_members
  where group_id = p_group_id and user_id = auth.uid() and removed_at is null for update;
  if not found then raise exception 'Group is unavailable'; end if;
  if v_member.role = 'owner' then raise exception 'Transfer ownership before leaving this group'; end if;
  if exists (select 1 from public.get_group_balances(p_group_id) b
             where b.group_member_id = v_member.id and b.net_balance_minor <> 0) then
    raise exception 'Settle your balance before leaving this group';
  end if;
  update public.group_members set removed_at = now() where id = v_member.id;
end;
$$;
revoke all on function public.leave_group(uuid) from public;
grant execute on function public.leave_group(uuid) to authenticated;

-- Serialize removal before reading the actor or canonical balance.
create or replace function public.remove_group_member(p_group_id uuid, p_member_id uuid)
returns public.group_members language plpgsql security definer set search_path = pg_catalog
as $$
declare v_role public.group_member_role; v_member public.group_members; v_archived timestamptz;
begin
  select archived_at into v_archived from public.groups where id = p_group_id for update;
  if not found or v_archived is not null then raise exception 'Group is unavailable'; end if;
  select role into v_role from public.group_members
  where group_id = p_group_id and user_id = auth.uid() and removed_at is null;
  if not found or v_role not in ('owner','admin') then
    raise exception 'Only an active group owner or administrator can remove members';
  end if;
  select * into v_member from public.group_members
  where id = p_member_id and group_id = p_group_id and removed_at is null for update;
  if not found then raise exception 'Active group member not found'; end if;
  if v_member.role = 'owner' then raise exception 'Transfer ownership before removing an owner'; end if;
  if v_role = 'admin' and v_member.role <> 'member' then
    raise exception 'Only a group owner can remove an administrator';
  end if;
  if exists (select 1 from public.get_group_balances(p_group_id) b
             where b.group_member_id = p_member_id and b.net_balance_minor <> 0) then
    raise exception 'A member must settle their balance before removal';
  end if;
  update public.group_members set removed_at = now() where id = p_member_id returning * into v_member;
  return v_member;
end;
$$;

commit;
