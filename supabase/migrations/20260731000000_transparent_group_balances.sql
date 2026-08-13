begin;

create function app_private.group_balance_rows(p_group_id uuid)
returns table (
  group_member_id uuid,
  display_name text,
  role public.group_member_role,
  is_removed boolean,
  is_guest boolean,
  is_current_user boolean,
  net_balance_minor bigint
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  with valid_posted_expenses as (
    select expense.id, expense.group_id
    from public.expenses as expense
    join lateral (
      select coalesce(sum(payer.amount_minor), 0)::bigint as total_amount_minor
      from public.expense_payers as payer
      where payer.expense_id = expense.id
        and payer.group_id = expense.group_id
    ) as payer_totals on true
    join lateral (
      select coalesce(sum(split.amount_minor), 0)::bigint as total_amount_minor
      from public.expense_splits as split
      where split.expense_id = expense.id
        and split.group_id = expense.group_id
    ) as split_totals on true
    where expense.group_id = p_group_id
      and expense.status = 'posted'::public.expense_status
      and expense.voided_at is null
      and payer_totals.total_amount_minor = expense.total_amount_minor
      and split_totals.total_amount_minor = expense.total_amount_minor
  ),
  valid_settlements as (
    select
      settlement.paying_member_id,
      settlement.receiving_member_id,
      settlement.amount_minor
    from public.settlements as settlement
    join public.group_members as paying_member
      on paying_member.id = settlement.paying_member_id
      and paying_member.group_id = settlement.group_id
    join public.group_members as receiving_member
      on receiving_member.id = settlement.receiving_member_id
      and receiving_member.group_id = settlement.group_id
    where settlement.group_id = p_group_id
      and settlement.voided_at is null
      and settlement.amount_minor > 0
  ),
  financial_members as (
    select payer.group_member_id
    from public.expense_payers as payer
    join valid_posted_expenses as expense
      on expense.id = payer.expense_id
      and expense.group_id = payer.group_id
    union
    select split.group_member_id
    from public.expense_splits as split
    join valid_posted_expenses as expense
      on expense.id = split.expense_id
      and expense.group_id = split.group_id
    union
    select settlement.paying_member_id
    from valid_settlements as settlement
    union
    select settlement.receiving_member_id
    from valid_settlements as settlement
  ),
  member_deltas as (
    select payer.group_member_id, payer.amount_minor as delta_minor
    from public.expense_payers as payer
    join valid_posted_expenses as expense
      on expense.id = payer.expense_id
      and expense.group_id = payer.group_id
    union all
    select split.group_member_id, -split.amount_minor as delta_minor
    from public.expense_splits as split
    join valid_posted_expenses as expense
      on expense.id = split.expense_id
      and expense.group_id = split.group_id
    union all
    select settlement.paying_member_id, settlement.amount_minor as delta_minor
    from valid_settlements as settlement
    union all
    select settlement.receiving_member_id, -settlement.amount_minor as delta_minor
    from valid_settlements as settlement
  )
  select
    member.id,
    member.display_name,
    member.role,
    member.removed_at is not null,
    member.user_id is null,
    member.user_id is not null and member.user_id = auth.uid(),
    coalesce(sum(delta.delta_minor), 0)::bigint
  from public.group_members as member
  left join member_deltas as delta on delta.group_member_id = member.id
  where member.group_id = p_group_id
    and (
      member.removed_at is null
      or exists (
        select 1
        from financial_members as financial_member
        where financial_member.group_member_id = member.id
      )
    )
  group by
    member.id,
    member.display_name,
    member.role,
    member.user_id,
    member.removed_at;
$$;

create function public.get_group_balances(p_group_id uuid)
returns table (
  group_member_id uuid,
  display_name text,
  role public.group_member_role,
  is_removed boolean,
  is_guest boolean,
  is_current_user boolean,
  net_balance_minor bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_net_total bigint;
  v_has_inconsistent_expense boolean;
  v_has_inconsistent_settlement boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to load group balances';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = v_user_id
      and profile.onboarding_completed_at is not null
  ) then
    raise exception 'Complete your profile before loading group balances';
  end if;

  if not app_private.is_active_group_member(p_group_id, v_user_id) then
    raise exception 'Group is unavailable';
  end if;

  select exists (
    select 1
    from public.expenses as expense
    join lateral (
      select coalesce(sum(payer.amount_minor), 0)::bigint as total_amount_minor
      from public.expense_payers as payer
      where payer.expense_id = expense.id
        and payer.group_id = expense.group_id
    ) as payer_totals on true
    join lateral (
      select coalesce(sum(split.amount_minor), 0)::bigint as total_amount_minor
      from public.expense_splits as split
      where split.expense_id = expense.id
        and split.group_id = expense.group_id
    ) as split_totals on true
    where expense.group_id = p_group_id
      and expense.status = 'posted'::public.expense_status
      and expense.voided_at is null
      and (
        payer_totals.total_amount_minor <> expense.total_amount_minor
        or split_totals.total_amount_minor <> expense.total_amount_minor
      )
  ) into v_has_inconsistent_expense;

  if v_has_inconsistent_expense then
    raise exception 'Financial records are inconsistent';
  end if;

  select exists (
    select 1
    from public.settlements as settlement
    where settlement.group_id = p_group_id
      and settlement.voided_at is null
      and (
        settlement.amount_minor <= 0
        or not exists (
          select 1
          from public.group_members as paying_member
          where paying_member.id = settlement.paying_member_id
            and paying_member.group_id = settlement.group_id
        )
        or not exists (
          select 1
          from public.group_members as receiving_member
          where receiving_member.id = settlement.receiving_member_id
            and receiving_member.group_id = settlement.group_id
        )
      )
  ) into v_has_inconsistent_settlement;

  if v_has_inconsistent_settlement then
    raise exception 'Financial records are inconsistent';
  end if;

  select coalesce(sum(balance.net_balance_minor), 0)::bigint
  into v_net_total
  from app_private.group_balance_rows(p_group_id) as balance;

  if v_net_total <> 0 then
    raise exception 'Financial records are inconsistent';
  end if;

  return query
  select
    balance.group_member_id,
    balance.display_name,
    balance.role,
    balance.is_removed,
    balance.is_guest,
    balance.is_current_user,
    balance.net_balance_minor
  from app_private.group_balance_rows(p_group_id) as balance
  order by
    case when balance.is_current_user then 0 else 1 end,
    case when balance.is_removed then 1 else 0 end,
    balance.display_name,
    balance.group_member_id;
end;
$$;

revoke all on function app_private.group_balance_rows(uuid) from public;
revoke all on function public.get_group_balances(uuid) from public;
grant execute on function public.get_group_balances(uuid) to authenticated;

commit;
