begin;

create function public.get_expense_activity(p_expense_id uuid)
returns table (
  event_id uuid,
  event_type text,
  occurred_at timestamptz,
  member_display_name text,
  amount_minor bigint,
  expense_description text
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
    raise exception 'Authentication is required to load expense activity';
  end if;

  if not app_private.can_read_expense(p_expense_id, v_user_id) then
    raise exception 'Expense is unavailable';
  end if;

  return query
  select
    event.id,
    event.event_type::text,
    event.created_at,
    member.display_name,
    case
      when coalesce(event.new_state, event.previous_state) ? 'amount_minor'
        then (coalesce(event.new_state, event.previous_state) ->> 'amount_minor')::bigint
      when coalesce(event.new_state, event.previous_state) ? 'total_amount_minor'
        then (coalesce(event.new_state, event.previous_state) ->> 'total_amount_minor')::bigint
      else null
    end,
    coalesce(
      event.new_state ->> 'description',
      event.previous_state ->> 'description'
    )
  from public.expense_events as event
  left join public.group_members as member
    on member.id = nullif(
      coalesce(
        event.new_state ->> 'group_member_id',
        event.previous_state ->> 'group_member_id'
      ),
      ''
    )::uuid
    and member.group_id = event.group_id
  where event.expense_id = p_expense_id
  order by
    event.created_at asc,
    case event.event_type
      when 'expense_created'::public.expense_event_type then 0
      when 'payer_added'::public.expense_event_type then 1
      when 'payer_updated'::public.expense_event_type then 2
      when 'payer_removed'::public.expense_event_type then 3
      when 'split_added'::public.expense_event_type then 4
      when 'split_updated'::public.expense_event_type then 5
      when 'split_removed'::public.expense_event_type then 6
      when 'expense_updated'::public.expense_event_type then 7
      when 'expense_finalized'::public.expense_event_type then 8
      when 'expense_voided'::public.expense_event_type then 9
      else 10
    end,
    event.id asc;
end;
$$;

revoke all on function public.get_expense_activity(uuid) from public;
grant execute on function public.get_expense_activity(uuid) to authenticated;

commit;
