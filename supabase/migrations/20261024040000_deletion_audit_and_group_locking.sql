begin;
-- Account deletion may run while request.jwt still names the deleted identity.
-- Retain the event but never create a dangling actor reference.
create or replace function app_private.record_expense_event()
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
    (select id from auth.users where id = auth.uid()),
    v_previous_state,
    v_new_state
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function public.set_group_member_role(
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
  perform 1 from public.groups where id=p_group_id for update;
  if not app_private.is_group_owner(p_group_id, auth.uid()) then
    raise exception 'Only an active group owner can change member roles';
  end if;

  if p_role not in ('admin'::public.group_member_role, 'member'::public.group_member_role) then
    raise exception 'Use ownership transfer to assign the owner role';
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

  if p_role = 'admin'::public.group_member_role and v_member.user_id is null then
    raise exception 'Only registered active group members can be promoted to administrator';
  end if;

  update public.group_members
  set role = p_role
  where id = v_member.id
  returning * into v_member;

  return v_member;
end;
$$;

create or replace function public.transfer_group_ownership(
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
  v_successor_is_registered boolean;
begin
  perform 1 from public.groups where id=p_group_id for update;
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

  select member.user_id is not null
  into v_successor_is_registered
  from public.group_members as member
  where member.id = p_successor_member_id
    and member.group_id = p_group_id
    and member.removed_at is null
  for update;

  if not found or not coalesce(v_successor_is_registered, false) then
    raise exception 'Ownership successor must be an active registered group member';
  end if;

  update public.group_members
  set role = 'owner'::public.group_member_role
  where id = p_successor_member_id;

  update public.group_members
  set role = 'admin'::public.group_member_role
  where id = v_current_owner_id;
end;
$$;


commit;
