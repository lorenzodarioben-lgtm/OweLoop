begin;
alter table public.expenses add column category_key text
  check (category_key in ('food','groceries','transport','accommodation','utilities','shopping','entertainment','travel','household','healthcare','other'));
create function app_private.protect_expense_category()
returns trigger language plpgsql set search_path=pg_catalog as $$
begin
  if new.category_key is distinct from old.category_key then raise exception 'Expense category is immutable; void and duplicate to correct it'; end if;
  return new;
end;
$$;
create trigger protect_expense_category before update on public.expenses
for each row execute function app_private.protect_expense_category();
create function app_private.create_categorized_allocations(
  p_group_id uuid,
  p_description text,
  p_total_amount_minor bigint,
  p_occurred_at timestamptz,
  p_payers jsonb,
  p_splits jsonb,
  p_category_key text
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
    created_by, category_key
  ) values (
    p_group_id,
    v_description,
    p_total_amount_minor,
    p_occurred_at,
    v_user_id, p_category_key
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


create function public.create_categorized_expense(
  p_group_id uuid,
  p_description text,
  p_total_amount_minor bigint,
  p_occurred_at timestamptz,
  p_payers jsonb,
  p_splits jsonb,
  p_operation_id uuid, p_category_key text
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
          'category_key',p_category_key,'type', 'expense'
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
  from app_private.create_categorized_allocations(
    p_group_id,
    p_description,
    p_total_amount_minor,
    p_occurred_at,
    p_payers,
    p_splits, p_category_key
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


create function public.get_categorized_expense_page(
  p_group_id uuid, p_limit integer default 50,
  p_before_occurred_at timestamptz default null,
  p_before_created_at timestamptz default null, p_before_id uuid default null,
  p_query text default '', p_from timestamptz default null,
  p_until timestamptz default null, p_member_id uuid default null,
  p_include_voided boolean default true, p_category_key text default null
) returns setof jsonb language plpgsql stable security definer set search_path = pg_catalog
as $$
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid())
     or not exists (select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then
    raise exception 'Group is unavailable';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100
     or char_length(coalesce(p_query,'')) > 200
     or num_nonnulls(p_before_occurred_at,p_before_created_at,p_before_id) not in (0,3)
     or (p_from is not null and p_until is not null and p_until <= p_from) then
    raise exception 'Invalid history request';
  end if;
  return query
  select to_jsonb(e) || jsonb_build_object('currency_code',g.currency_code)
  from public.expenses e join public.groups g on g.id=e.group_id
  where e.group_id=p_group_id and e.status in ('posted','voided')
    and (p_include_voided or e.status='posted')
    and (p_category_key is null or e.category_key=p_category_key or (p_category_key='' and e.category_key is null))
    and (coalesce(p_query,'')='' or position(lower(p_query) in lower(e.description))>0)
    and (p_from is null or e.occurred_at>=p_from)
    and (p_until is null or e.occurred_at<p_until)
    and (p_member_id is null or exists(select 1 from public.expense_payers ep
         where ep.expense_id=e.id and ep.group_member_id=p_member_id)
         or exists(select 1 from public.expense_splits es
         where es.expense_id=e.id and es.group_member_id=p_member_id))
    and (p_before_id is null or (e.occurred_at,e.created_at,e.id)
         < (p_before_occurred_at,p_before_created_at,p_before_id))
  order by e.occurred_at desc,e.created_at desc,e.id desc limit p_limit+1;
end;
$$;


revoke all on function app_private.create_categorized_allocations(uuid,text,bigint,timestamptz,jsonb,jsonb,text) from public,anon,authenticated;
revoke all on function public.create_categorized_expense(uuid,text,bigint,timestamptz,jsonb,jsonb,uuid,text) from public,anon;
grant execute on function public.create_categorized_expense(uuid,text,bigint,timestamptz,jsonb,jsonb,uuid,text) to authenticated;
revoke all on function public.get_categorized_expense_page(uuid,integer,timestamptz,timestamptz,uuid,text,timestamptz,timestamptz,uuid,boolean,text) from public,anon;
grant execute on function public.get_categorized_expense_page(uuid,integer,timestamptz,timestamptz,uuid,text,timestamptz,timestamptz,uuid,boolean,text) to authenticated;
commit;
