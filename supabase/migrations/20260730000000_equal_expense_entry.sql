begin;

create function public.create_equal_expense(
  p_group_id uuid,
  p_description text,
  p_total_amount_minor bigint,
  p_occurred_at timestamptz,
  p_payer_member_id uuid,
  p_participant_member_ids uuid[]
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
  v_participant_count integer;
  v_active_participant_count integer;
  v_base_amount bigint;
  v_remainder bigint;
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

  if p_payer_member_id is null or not exists (
    select 1
    from public.group_members as member
    where member.id = p_payer_member_id
      and member.group_id = p_group_id
      and member.removed_at is null
  ) then
    raise exception 'Payer must be an active member of this group';
  end if;

  v_participant_count := cardinality(p_participant_member_ids);

  if v_participant_count is null or v_participant_count = 0 then
    raise exception 'Select at least one active participant';
  end if;

  if array_position(p_participant_member_ids, null) is not null then
    raise exception 'Participants must be active members of this group';
  end if;

  if v_participant_count <> (
    select count(distinct participant_id)
    from unnest(p_participant_member_ids) as participant_id
  ) then
    raise exception 'Participants cannot be selected more than once';
  end if;

  select count(*)
  into v_active_participant_count
  from public.group_members as member
  where member.id = any(p_participant_member_ids)
    and member.group_id = p_group_id
    and member.removed_at is null;

  if v_active_participant_count <> v_participant_count then
    raise exception 'Participants must be active members of this group';
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

  insert into public.expense_payers (
    expense_id,
    group_id,
    group_member_id,
    amount_minor
  ) values (
    v_expense.id,
    p_group_id,
    p_payer_member_id,
    p_total_amount_minor
  );

  v_base_amount := p_total_amount_minor / v_participant_count;
  v_remainder := p_total_amount_minor % v_participant_count;

  with ordered_participants as (
    select
      member.id,
      row_number() over (order by member.id) as participant_position
    from public.group_members as member
    where member.id = any(p_participant_member_ids)
      and member.group_id = p_group_id
      and member.removed_at is null
  )
  insert into public.expense_splits (
    expense_id,
    group_id,
    group_member_id,
    amount_minor
  )
  select
    v_expense.id,
    p_group_id,
    participant.id,
    v_base_amount + case
      when participant.participant_position <= v_remainder then 1
      else 0
    end
  from ordered_participants as participant
  order by participant.id;

  select *
  into v_expense
  from public.finalize_expense(v_expense.id);

  return v_expense;
end;
$$;

revoke all on function public.create_equal_expense(
  uuid,
  text,
  bigint,
  timestamptz,
  uuid,
  uuid[]
) from public;

grant execute on function public.create_equal_expense(
  uuid,
  text,
  bigint,
  timestamptz,
  uuid,
  uuid[]
) to authenticated;

commit;
