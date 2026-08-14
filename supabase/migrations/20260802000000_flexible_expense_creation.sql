begin;

alter table public.expense_splits
  drop constraint expense_splits_amount_minor_check,
  add constraint expense_splits_amount_minor_check check (amount_minor >= 0);

create function public.create_expense(
  p_group_id uuid,
  p_description text,
  p_total_amount_minor bigint,
  p_occurred_at timestamptz,
  p_payers jsonb,
  p_splits jsonb
)
returns public.expenses
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_description text := btrim(p_description);
  v_group public.groups;
  v_expense public.expenses;
  v_entry jsonb;
  v_member_id uuid;
  v_amount_minor bigint;
  v_payer_member_ids uuid[] := '{}'::uuid[];
  v_split_member_ids uuid[] := '{}'::uuid[];
  v_payer_total bigint := 0;
  v_split_total bigint := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to create an expense';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) then
    raise exception 'Complete your profile before creating an expense';
  end if;

  if not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Only an active group member can create an expense';
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
    raise exception 'Expenses cannot be added to an archived group';
  end if;

  if v_description is null or char_length(v_description) = 0 then
    raise exception 'Expense description cannot be blank';
  end if;

  if char_length(v_description) > 500 then
    raise exception 'Expense description must be 500 characters or fewer';
  end if;

  if p_total_amount_minor is null or p_total_amount_minor <= 0 then
    raise exception 'Expense total must be greater than zero';
  end if;

  if p_occurred_at is null then
    raise exception 'Expense date is required';
  end if;

  if jsonb_typeof(p_payers) <> 'array' or jsonb_array_length(p_payers) = 0 then
    raise exception 'Provide at least one payer allocation';
  end if;

  if jsonb_typeof(p_splits) <> 'array' or jsonb_array_length(p_splits) = 0 then
    raise exception 'Provide at least one split allocation';
  end if;

  insert into public.expenses (
    group_id,
    description,
    total_amount_minor,
    occurred_at,
    created_by
  ) values (
    p_group_id,
    v_description,
    p_total_amount_minor,
    p_occurred_at,
    v_user_id
  )
  returning * into v_expense;

  for v_entry in select value from jsonb_array_elements(p_payers)
  loop
    if jsonb_typeof(v_entry) <> 'object'
      or jsonb_typeof(v_entry -> 'member_id') <> 'string'
      or jsonb_typeof(v_entry -> 'amount_minor') <> 'number' then
      raise exception 'Payer allocations must contain a member ID and integer amount';
    end if;

    v_member_id := (v_entry ->> 'member_id')::uuid;
    v_amount_minor := (v_entry ->> 'amount_minor')::bigint;
    if v_amount_minor <= 0 then
      raise exception 'Payer amounts must be greater than zero';
    end if;
    if v_member_id = any(v_payer_member_ids) then
      raise exception 'Payer members cannot be selected more than once';
    end if;
    if not exists (
      select 1
      from public.group_members as member
      where member.id = v_member_id
        and member.group_id = p_group_id
        and member.removed_at is null
    ) then
      raise exception 'Payer members must be active in this group';
    end if;

    insert into public.expense_payers (
      expense_id,
      group_id,
      group_member_id,
      amount_minor
    ) values (
      v_expense.id,
      p_group_id,
      v_member_id,
      v_amount_minor
    );
    v_payer_member_ids := array_append(v_payer_member_ids, v_member_id);
    v_payer_total := v_payer_total + v_amount_minor;
  end loop;

  if v_payer_total <> p_total_amount_minor then
    raise exception 'Expense payer amounts must equal the expense total';
  end if;

  for v_entry in select value from jsonb_array_elements(p_splits)
  loop
    if jsonb_typeof(v_entry) <> 'object'
      or jsonb_typeof(v_entry -> 'member_id') <> 'string'
      or jsonb_typeof(v_entry -> 'amount_minor') <> 'number' then
      raise exception 'Split allocations must contain a member ID and integer amount';
    end if;

    v_member_id := (v_entry ->> 'member_id')::uuid;
    v_amount_minor := (v_entry ->> 'amount_minor')::bigint;
    if v_amount_minor < 0 then
      raise exception 'Split amounts cannot be negative';
    end if;
    if v_member_id = any(v_split_member_ids) then
      raise exception 'Split members cannot be selected more than once';
    end if;
    if not exists (
      select 1
      from public.group_members as member
      where member.id = v_member_id
        and member.group_id = p_group_id
        and member.removed_at is null
    ) then
      raise exception 'Split members must be active in this group';
    end if;

    insert into public.expense_splits (
      expense_id,
      group_id,
      group_member_id,
      amount_minor
    ) values (
      v_expense.id,
      p_group_id,
      v_member_id,
      v_amount_minor
    );
    v_split_member_ids := array_append(v_split_member_ids, v_member_id);
    v_split_total := v_split_total + v_amount_minor;
  end loop;

  if v_split_total <> p_total_amount_minor then
    raise exception 'Expense split amounts must equal the expense total';
  end if;

  select *
  into v_expense
  from public.finalize_expense(v_expense.id);

  return v_expense;
end;
$$;

revoke all on function public.create_expense(uuid, text, bigint, timestamptz, jsonb, jsonb) from public;
grant execute on function public.create_expense(uuid, text, bigint, timestamptz, jsonb, jsonb) to authenticated;

commit;
