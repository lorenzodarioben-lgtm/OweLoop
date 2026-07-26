begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;
revoke all on schema app_private from public;

create type public.group_member_role as enum ('owner', 'admin', 'member');
create type public.expense_status as enum ('draft', 'posted', 'voided');
create type public.expense_event_type as enum (
  'expense_created',
  'expense_updated',
  'expense_finalized',
  'expense_voided',
  'payer_added',
  'payer_updated',
  'payer_removed',
  'split_added',
  'split_updated',
  'split_removed'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete restrict,
  user_id uuid references auth.users (id) on delete set null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  role public.group_member_role not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  removed_at timestamptz,
  unique (id, group_id)
);

create unique index group_members_one_active_user_per_group
  on public.group_members (group_id, user_id)
  where user_id is not null and removed_at is null;

create index group_members_active_group_lookup
  on public.group_members (group_id, id)
  where removed_at is null;

create index group_members_active_user_lookup
  on public.group_members (user_id, group_id)
  where user_id is not null and removed_at is null;

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete restrict,
  description text not null check (char_length(description) between 1 and 500),
  total_amount_minor bigint not null check (total_amount_minor > 0),
  occurred_at timestamptz not null default now(),
  status public.expense_status not null default 'draft',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  voided_at timestamptz,
  unique (id, group_id),
  check (
    (status = 'voided' and voided_at is not null)
    or (status <> 'voided' and voided_at is null)
  )
);

create index expenses_group_occurred_at
  on public.expenses (group_id, occurred_at desc);

create index expenses_created_by
  on public.expenses (created_by)
  where created_by is not null;

create table public.expense_payers (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null,
  group_id uuid not null,
  group_member_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  created_at timestamptz not null default now(),
  unique (expense_id, group_member_id),
  foreign key (expense_id, group_id)
    references public.expenses (id, group_id) on delete restrict,
  foreign key (group_member_id, group_id)
    references public.group_members (id, group_id) on delete restrict
);

create index expense_payers_group_member_lookup
  on public.expense_payers (group_id, group_member_id);

create table public.expense_splits (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null,
  group_id uuid not null,
  group_member_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  created_at timestamptz not null default now(),
  unique (expense_id, group_member_id),
  foreign key (expense_id, group_id)
    references public.expenses (id, group_id) on delete restrict,
  foreign key (group_member_id, group_id)
    references public.group_members (id, group_id) on delete restrict
);

create index expense_splits_group_member_lookup
  on public.expense_splits (group_id, group_member_id);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete restrict,
  paying_member_id uuid not null,
  receiving_member_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  settled_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  voided_at timestamptz,
  check (paying_member_id <> receiving_member_id),
  foreign key (paying_member_id, group_id)
    references public.group_members (id, group_id) on delete restrict,
  foreign key (receiving_member_id, group_id)
    references public.group_members (id, group_id) on delete restrict
);

create index settlements_group_settled_at
  on public.settlements (group_id, settled_at desc);

create table public.expense_events (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null,
  group_id uuid not null,
  event_type public.expense_event_type not null,
  subject_type text not null check (subject_type in ('expense', 'payer', 'split')),
  subject_id uuid not null,
  acting_user_id uuid references auth.users (id) on delete set null,
  previous_state jsonb,
  new_state jsonb,
  created_at timestamptz not null default now(),
  check (previous_state is null or jsonb_typeof(previous_state) = 'object'),
  check (new_state is null or jsonb_typeof(new_state) = 'object'),
  foreign key (expense_id, group_id)
    references public.expenses (id, group_id) on delete restrict
);

create index expense_events_expense_created_at
  on public.expense_events (expense_id, created_at desc);

create index expense_events_group_created_at
  on public.expense_events (group_id, created_at desc);

create function app_private.set_created_and_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.created_at := now();
  new.updated_at := new.created_at;
  return new;
end;
$$;

create function app_private.set_created_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.created_at := now();
  return new;
end;
$$;

create function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if (to_jsonb(new) - 'updated_at') is not distinct from (to_jsonb(old) - 'updated_at') then
    new.updated_at := old.updated_at;
  else
    new.updated_at := now();
  end if;

  return new;
end;
$$;

create function app_private.is_active_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1
    from public.group_members as member
    where member.group_id = p_group_id
      and member.user_id = p_user_id
      and member.removed_at is null
  );
$$;

create function app_private.is_group_admin(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1
    from public.group_members as member
    where member.group_id = p_group_id
      and member.user_id = p_user_id
      and member.removed_at is null
      and member.role in ('owner'::public.group_member_role, 'admin'::public.group_member_role)
  );
$$;

create function app_private.is_group_owner(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1
    from public.group_members as member
    where member.group_id = p_group_id
      and member.user_id = p_user_id
      and member.removed_at is null
      and member.role = 'owner'::public.group_member_role
  );
$$;

create function app_private.can_read_expense(p_expense_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.expenses as expense
    where expense.id = p_expense_id
      and app_private.is_active_group_member(expense.group_id, p_user_id)
  );
$$;

create function app_private.can_manage_expense(p_expense_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1
    from public.expenses as expense
    where expense.id = p_expense_id
      and (
        app_private.is_group_admin(expense.group_id, p_user_id)
        or (
          expense.created_by = p_user_id
          and app_private.is_active_group_member(expense.group_id, p_user_id)
        )
      )
  );
$$;

create function app_private.can_manage_draft_expense(p_expense_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.expenses as expense
    where expense.id = p_expense_id
      and expense.status = 'draft'::public.expense_status
      and app_private.can_manage_expense(expense.id, p_user_id)
  );
$$;

create function app_private.can_manage_settlement(p_settlement_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1
    from public.settlements as settlement
    where settlement.id = p_settlement_id
      and (
        app_private.is_group_admin(settlement.group_id, p_user_id)
        or (
          settlement.created_by = p_user_id
          and app_private.is_active_group_member(settlement.group_id, p_user_id)
        )
      )
  );
$$;

create function app_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, 'Member')
  on conflict (id) do nothing;

  return new;
end;
$$;

create function app_private.create_group_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_display_name text;
begin
  select profile.display_name
  into v_display_name
  from public.profiles as profile
  where profile.id = new.created_by;

  insert into public.group_members (group_id, user_id, display_name, role)
  values (
    new.id,
    new.created_by,
    coalesce(v_display_name, 'Member'),
    'owner'::public.group_member_role
  );

  return new;
end;
$$;

create function app_private.protect_profile_fields()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at then
    raise exception 'Profile identity fields cannot be changed';
  end if;

  return new;
end;
$$;

create function app_private.protect_group_fields()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at then
    raise exception 'Group identity fields cannot be changed';
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

create function app_private.enforce_group_member_transition()
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

create function app_private.prevent_group_member_delete()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception 'Group membership records are historical and cannot be deleted';
end;
$$;

create function app_private.protect_expense_fields()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.id is distinct from old.id
    or new.group_id is distinct from old.group_id
    or new.created_at is distinct from old.created_at then
    raise exception 'Expense identity fields cannot be changed';
  end if;

  if old.created_by is not null
    and new.created_by is not null
    and new.created_by is distinct from old.created_by then
    raise exception 'An expense creator cannot be reassigned';
  end if;

  if old.status = 'voided'::public.expense_status and new.status <> old.status then
    raise exception 'A voided expense cannot be reactivated';
  end if;

  if old.status = 'draft'::public.expense_status
    and new.status not in ('draft'::public.expense_status, 'posted'::public.expense_status, 'voided'::public.expense_status) then
    raise exception 'Invalid expense status transition';
  end if;

  if old.status = 'posted'::public.expense_status
    and new.status not in ('posted'::public.expense_status, 'voided'::public.expense_status) then
    raise exception 'Invalid expense status transition';
  end if;

  if new.status = 'voided'::public.expense_status and new.voided_at is null then
    raise exception 'A voided expense requires a voided timestamp';
  end if;

  if new.status <> 'voided'::public.expense_status and new.voided_at is not null then
    raise exception 'Only voided expenses can have a voided timestamp';
  end if;

  return new;
end;
$$;

create function app_private.assert_posted_expense_totals()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_payer_total bigint;
  v_split_total bigint;
begin
  if new.status = 'posted'::public.expense_status
    and old.status <> 'posted'::public.expense_status then
    select coalesce(sum(payer.amount_minor), 0)
    into v_payer_total
    from public.expense_payers as payer
    where payer.expense_id = new.id;

    select coalesce(sum(split.amount_minor), 0)
    into v_split_total
    from public.expense_splits as split
    where split.expense_id = new.id;

    if v_payer_total <> new.total_amount_minor then
      raise exception 'Expense payer amounts must equal the expense total';
    end if;

    if v_split_total <> new.total_amount_minor then
      raise exception 'Expense split amounts must equal the expense total';
    end if;
  end if;

  return new;
end;
$$;

create function app_private.assert_draft_expense_participant()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_expense_id uuid;
  v_group_id uuid;
  v_member_id uuid;
  v_status public.expense_status;
begin
  if tg_op = 'DELETE' then
    v_expense_id := old.expense_id;
    v_group_id := old.group_id;
    v_member_id := old.group_member_id;
  else
    v_expense_id := new.expense_id;
    v_group_id := new.group_id;
    v_member_id := new.group_member_id;
  end if;

  select expense.status
  into v_status
  from public.expenses as expense
  where expense.id = v_expense_id
    and expense.group_id = v_group_id
  for update;

  if v_status is distinct from 'draft'::public.expense_status then
    raise exception 'Payers and splits can only change while an expense is a draft';
  end if;

  if tg_op <> 'DELETE' and not exists (
    select 1
    from public.group_members as member
    where member.id = v_member_id
      and member.group_id = v_group_id
      and member.removed_at is null
  ) then
    raise exception 'Expense participants must be active members of the expense group';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create function app_private.assert_active_settlement_members()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
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

create function app_private.protect_settlement_history()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if old.created_by is not null
    and new.created_by is not null
    and new.created_by is distinct from old.created_by then
    raise exception 'A settlement creator cannot be reassigned';
  end if;

  if old.voided_at is not null and new.voided_at is distinct from old.voided_at then
    raise exception 'A voided settlement cannot be reactivated or changed';
  end if;

  if (to_jsonb(new) - 'updated_at' - 'voided_at' - 'created_by')
    is distinct from (to_jsonb(old) - 'updated_at' - 'voided_at' - 'created_by') then
    raise exception 'Settlement financial history cannot be changed';
  end if;

  return new;
end;
$$;

create function app_private.record_expense_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_expense_id uuid;
  v_group_id uuid;
  v_subject_id uuid;
  v_subject_type text;
  v_event_type public.expense_event_type;
  v_previous_state jsonb;
  v_new_state jsonb;
begin
  if tg_table_name = 'expenses' then
    v_expense_id := coalesce(new.id, old.id);
    v_group_id := coalesce(new.group_id, old.group_id);
    v_subject_id := v_expense_id;
    v_subject_type := 'expense';
    v_previous_state := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
    v_new_state := case when tg_op = 'DELETE' then null else to_jsonb(new) end;

    if tg_op = 'INSERT' then
      v_event_type := 'expense_created'::public.expense_event_type;
    elsif new.status = 'posted'::public.expense_status
      and old.status <> 'posted'::public.expense_status then
      v_event_type := 'expense_finalized'::public.expense_event_type;
    elsif new.status = 'voided'::public.expense_status
      and old.status <> 'voided'::public.expense_status then
      v_event_type := 'expense_voided'::public.expense_event_type;
    else
      v_event_type := 'expense_updated'::public.expense_event_type;
    end if;
  elsif tg_table_name = 'expense_payers' then
    v_expense_id := coalesce(new.expense_id, old.expense_id);
    v_group_id := coalesce(new.group_id, old.group_id);
    v_subject_id := coalesce(new.id, old.id);
    v_subject_type := 'payer';
    v_previous_state := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
    v_new_state := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
    v_event_type := case tg_op
      when 'INSERT' then 'payer_added'::public.expense_event_type
      when 'UPDATE' then 'payer_updated'::public.expense_event_type
      else 'payer_removed'::public.expense_event_type
    end;
  else
    v_expense_id := coalesce(new.expense_id, old.expense_id);
    v_group_id := coalesce(new.group_id, old.group_id);
    v_subject_id := coalesce(new.id, old.id);
    v_subject_type := 'split';
    v_previous_state := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
    v_new_state := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
    v_event_type := case tg_op
      when 'INSERT' then 'split_added'::public.expense_event_type
      when 'UPDATE' then 'split_updated'::public.expense_event_type
      else 'split_removed'::public.expense_event_type
    end;
  end if;

  insert into public.expense_events (
    expense_id,
    group_id,
    event_type,
    subject_type,
    subject_id,
    acting_user_id,
    previous_state,
    new_state
  ) values (
    v_expense_id,
    v_group_id,
    v_event_type,
    v_subject_type,
    v_subject_id,
    auth.uid(),
    v_previous_state,
    v_new_state
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create function public.finalize_expense(p_expense_id uuid)
returns public.expenses
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_expense public.expenses;
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
    raise exception 'Only an active expense manager can finalize this expense';
  end if;

  if v_expense.status <> 'draft'::public.expense_status then
    raise exception 'Only draft expenses can be finalized';
  end if;

  perform 1
  from public.expense_payers as payer
  where payer.expense_id = p_expense_id
  for update;

  perform 1
  from public.expense_splits as split
  where split.expense_id = p_expense_id
  for update;

  update public.expenses
  set status = 'posted'::public.expense_status
  where id = p_expense_id
  returning * into v_expense;

  return v_expense;
end;
$$;

create function public.void_expense(p_expense_id uuid)
returns public.expenses
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_expense public.expenses;
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

create function public.set_group_member_role(
  p_group_id uuid,
  p_member_id uuid,
  p_role public.group_member_role
)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_member public.group_members;
begin
  if not app_private.is_group_owner(p_group_id, auth.uid()) then
    raise exception 'Only an active group owner can change member roles';
  end if;

  if p_role not in ('admin'::public.group_member_role, 'member'::public.group_member_role) then
    raise exception 'Use ownership transfer to assign the owner role';
  end if;

  update public.group_members
  set role = p_role
  where id = p_member_id
    and group_id = p_group_id
    and removed_at is null
  returning * into v_member;

  if not found then
    raise exception 'Active group member not found';
  end if;

  return v_member;
end;
$$;

create function public.transfer_group_ownership(
  p_group_id uuid,
  p_successor_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_current_owner_id uuid;
begin
  select member.id
  into v_current_owner_id
  from public.group_members as member
  where member.group_id = p_group_id
    and member.user_id = auth.uid()
    and member.role = 'owner'::public.group_member_role
    and member.removed_at is null
  for update;

  if not found then
    raise exception 'Only an active group owner can transfer ownership';
  end if;

  if p_successor_member_id = v_current_owner_id then
    raise exception 'Transfer ownership to a different active member';
  end if;

  perform 1
  from public.group_members as member
  where member.id = p_successor_member_id
    and member.group_id = p_group_id
    and member.removed_at is null
  for update;

  if not found then
    raise exception 'Ownership successor must be an active group member';
  end if;

  update public.group_members
  set role = 'owner'::public.group_member_role
  where id = p_successor_member_id;

  update public.group_members
  set role = 'admin'::public.group_member_role
  where id = v_current_owner_id;
end;
$$;

create trigger profiles_set_created_and_updated_at
before insert on public.profiles
for each row execute function app_private.set_created_and_updated_at();

create trigger profiles_protect_fields
before update on public.profiles
for each row execute function app_private.protect_profile_fields();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function app_private.set_updated_at();

create trigger groups_set_created_and_updated_at
before insert on public.groups
for each row execute function app_private.set_created_and_updated_at();

create trigger groups_protect_fields
before update on public.groups
for each row execute function app_private.protect_group_fields();

create trigger groups_set_updated_at
before update on public.groups
for each row execute function app_private.set_updated_at();

create trigger groups_create_owner_membership
after insert on public.groups
for each row execute function app_private.create_group_owner_membership();

create trigger group_members_set_created_and_updated_at
before insert on public.group_members
for each row execute function app_private.set_created_and_updated_at();

create trigger group_members_enforce_transition
before update on public.group_members
for each row execute function app_private.enforce_group_member_transition();

create trigger group_members_set_updated_at
before update on public.group_members
for each row execute function app_private.set_updated_at();

create trigger group_members_prevent_delete
before delete on public.group_members
for each row execute function app_private.prevent_group_member_delete();

create trigger expenses_set_created_and_updated_at
before insert on public.expenses
for each row execute function app_private.set_created_and_updated_at();

create trigger expenses_protect_fields
before update on public.expenses
for each row execute function app_private.protect_expense_fields();

create trigger expenses_assert_posted_totals
before update on public.expenses
for each row execute function app_private.assert_posted_expense_totals();

create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function app_private.set_updated_at();

create trigger expenses_record_events
after insert or update on public.expenses
for each row execute function app_private.record_expense_event();

create trigger expense_payers_assert_draft_participant
before insert or update or delete on public.expense_payers
for each row execute function app_private.assert_draft_expense_participant();

create trigger expense_payers_set_created_at
before insert on public.expense_payers
for each row execute function app_private.set_created_at();

create trigger expense_payers_record_events
after insert or update or delete on public.expense_payers
for each row execute function app_private.record_expense_event();

create trigger expense_splits_assert_draft_participant
before insert or update or delete on public.expense_splits
for each row execute function app_private.assert_draft_expense_participant();

create trigger expense_splits_set_created_at
before insert on public.expense_splits
for each row execute function app_private.set_created_at();

create trigger expense_splits_record_events
after insert or update or delete on public.expense_splits
for each row execute function app_private.record_expense_event();

create trigger settlements_set_created_and_updated_at
before insert on public.settlements
for each row execute function app_private.set_created_and_updated_at();

create trigger settlements_assert_active_members
before insert or update on public.settlements
for each row execute function app_private.assert_active_settlement_members();

create trigger settlements_protect_history
before update on public.settlements
for each row execute function app_private.protect_settlement_history();

create trigger settlements_set_updated_at
before update on public.settlements
for each row execute function app_private.set_updated_at();

create trigger expense_events_set_created_at
before insert on public.expense_events
for each row execute function app_private.set_created_at();

create trigger auth_users_create_profile
after insert on auth.users
for each row execute function app_private.handle_new_user();

insert into public.profiles (id, display_name)
select users.id, 'Member'
from auth.users as users
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_payers enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.expense_events enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.groups from anon, authenticated;
revoke all on table public.group_members from anon, authenticated;
revoke all on table public.expenses from anon, authenticated;
revoke all on table public.expense_payers from anon, authenticated;
revoke all on table public.expense_splits from anon, authenticated;
revoke all on table public.settlements from anon, authenticated;
revoke all on table public.expense_events from anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name) on table public.profiles to authenticated;

grant select, insert on table public.groups to authenticated;
grant update (name, currency_code, archived_at) on table public.groups to authenticated;

grant select, insert on table public.group_members to authenticated;
grant update (display_name, removed_at) on table public.group_members to authenticated;

grant select, insert on table public.expenses to authenticated;
grant update (description, total_amount_minor, occurred_at) on table public.expenses to authenticated;

grant select, insert, delete on table public.expense_payers to authenticated;
grant update (amount_minor) on table public.expense_payers to authenticated;

grant select, insert, delete on table public.expense_splits to authenticated;
grant update (amount_minor) on table public.expense_splits to authenticated;

grant select, insert on table public.settlements to authenticated;
grant update (voided_at) on table public.settlements to authenticated;

grant select on table public.expense_events to authenticated;

create policy profiles_select_own
on public.profiles
for select to authenticated
using (id = auth.uid());

create policy profiles_update_own
on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy groups_select_active_member
on public.groups
for select to authenticated
using (app_private.is_active_group_member(id, auth.uid()));

create policy groups_insert_creator
on public.groups
for insert to authenticated
with check (
  created_by = auth.uid()
  and archived_at is null
);

create policy groups_update_administrator
on public.groups
for update to authenticated
using (app_private.is_group_admin(id, auth.uid()))
with check (app_private.is_group_admin(id, auth.uid()));

create policy group_members_select_active_member
on public.group_members
for select to authenticated
using (app_private.is_active_group_member(group_id, auth.uid()));

create policy group_members_insert_administrator
on public.group_members
for insert to authenticated
with check (
  app_private.is_group_admin(group_id, auth.uid())
  and role = 'member'::public.group_member_role
  and removed_at is null
);

create policy group_members_update_administrator
on public.group_members
for update to authenticated
using (app_private.is_group_admin(group_id, auth.uid()))
with check (
  app_private.is_group_admin(group_id, auth.uid())
  and role = 'member'::public.group_member_role
);

create policy expenses_select_active_member
on public.expenses
for select to authenticated
using (app_private.is_active_group_member(group_id, auth.uid()));

create policy expenses_insert_active_member
on public.expenses
for insert to authenticated
with check (
  created_by = auth.uid()
  and status = 'draft'::public.expense_status
  and voided_at is null
  and app_private.is_active_group_member(group_id, auth.uid())
);

create policy expenses_update_draft_manager
on public.expenses
for update to authenticated
using (
  status = 'draft'::public.expense_status
  and app_private.can_manage_expense(id, auth.uid())
)
with check (
  status = 'draft'::public.expense_status
  and app_private.can_manage_expense(id, auth.uid())
);

create policy expense_payers_select_parent_expense
on public.expense_payers
for select to authenticated
using (app_private.can_read_expense(expense_id, auth.uid()));

create policy expense_payers_insert_draft_manager
on public.expense_payers
for insert to authenticated
with check (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy expense_payers_update_draft_manager
on public.expense_payers
for update to authenticated
using (app_private.can_manage_draft_expense(expense_id, auth.uid()))
with check (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy expense_payers_delete_draft_manager
on public.expense_payers
for delete to authenticated
using (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy expense_splits_select_parent_expense
on public.expense_splits
for select to authenticated
using (app_private.can_read_expense(expense_id, auth.uid()));

create policy expense_splits_insert_draft_manager
on public.expense_splits
for insert to authenticated
with check (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy expense_splits_update_draft_manager
on public.expense_splits
for update to authenticated
using (app_private.can_manage_draft_expense(expense_id, auth.uid()))
with check (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy expense_splits_delete_draft_manager
on public.expense_splits
for delete to authenticated
using (app_private.can_manage_draft_expense(expense_id, auth.uid()));

create policy settlements_select_active_member
on public.settlements
for select to authenticated
using (app_private.is_active_group_member(group_id, auth.uid()));

create policy settlements_insert_active_member
on public.settlements
for insert to authenticated
with check (
  created_by = auth.uid()
  and voided_at is null
  and app_private.is_active_group_member(group_id, auth.uid())
);

create policy settlements_update_manager
on public.settlements
for update to authenticated
using (app_private.can_manage_settlement(id, auth.uid()))
with check (app_private.can_manage_settlement(id, auth.uid()));

create policy expense_events_select_parent_expense
on public.expense_events
for select to authenticated
using (app_private.can_read_expense(expense_id, auth.uid()));

revoke all on function app_private.set_created_and_updated_at() from public;
revoke all on function app_private.set_created_at() from public;
revoke all on function app_private.set_updated_at() from public;
revoke all on function app_private.is_active_group_member(uuid, uuid) from public;
revoke all on function app_private.is_group_admin(uuid, uuid) from public;
revoke all on function app_private.is_group_owner(uuid, uuid) from public;
revoke all on function app_private.can_read_expense(uuid, uuid) from public;
revoke all on function app_private.can_manage_expense(uuid, uuid) from public;
revoke all on function app_private.can_manage_draft_expense(uuid, uuid) from public;
revoke all on function app_private.can_manage_settlement(uuid, uuid) from public;
revoke all on function app_private.handle_new_user() from public;
revoke all on function app_private.create_group_owner_membership() from public;
revoke all on function app_private.protect_profile_fields() from public;
revoke all on function app_private.protect_group_fields() from public;
revoke all on function app_private.enforce_group_member_transition() from public;
revoke all on function app_private.prevent_group_member_delete() from public;
revoke all on function app_private.protect_expense_fields() from public;
revoke all on function app_private.assert_posted_expense_totals() from public;
revoke all on function app_private.assert_draft_expense_participant() from public;
revoke all on function app_private.assert_active_settlement_members() from public;
revoke all on function app_private.protect_settlement_history() from public;
revoke all on function app_private.record_expense_event() from public;

grant execute on function app_private.is_active_group_member(uuid, uuid) to authenticated;
grant execute on function app_private.is_group_admin(uuid, uuid) to authenticated;
grant execute on function app_private.can_read_expense(uuid, uuid) to authenticated;
grant execute on function app_private.can_manage_expense(uuid, uuid) to authenticated;
grant execute on function app_private.can_manage_draft_expense(uuid, uuid) to authenticated;
grant execute on function app_private.can_manage_settlement(uuid, uuid) to authenticated;

revoke all on function public.finalize_expense(uuid) from public;
revoke all on function public.void_expense(uuid) from public;
revoke all on function public.set_group_member_role(uuid, uuid, public.group_member_role) from public;
revoke all on function public.transfer_group_ownership(uuid, uuid) from public;

grant execute on function public.finalize_expense(uuid) to authenticated;
grant execute on function public.void_expense(uuid) to authenticated;
grant execute on function public.set_group_member_role(uuid, uuid, public.group_member_role) to authenticated;
grant execute on function public.transfer_group_ownership(uuid, uuid) to authenticated;

commit;
