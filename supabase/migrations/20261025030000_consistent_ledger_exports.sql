begin;
-- Scalar JSON avoids PostgREST's row cap. STABLE uses the calling statement's
-- MVCC snapshot, including all nested allocation/name reads, instead of a
-- multi-request cursor walk observing different ledger revisions.
create function public.get_group_expense_export_snapshot(p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare result jsonb;
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid())
     or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then
    raise exception 'Group is unavailable';
  end if;
  select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('currency_code',g.currency_code,
    'expense_payers',(select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('group_members',jsonb_build_object('display_name',m.display_name)) order by p.group_member_id),'[]')
       from public.expense_payers p join public.group_members m on m.id=p.group_member_id where p.expense_id=e.id),
    'expense_splits',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('group_members',jsonb_build_object('display_name',m.display_name)) order by s.group_member_id),'[]')
       from public.expense_splits s join public.group_members m on m.id=s.group_member_id where s.expense_id=e.id))
    order by e.occurred_at desc,e.created_at desc,e.id desc),'[]') into result
  from public.expenses e join public.groups g on g.id=e.group_id
  where e.group_id=p_group_id and e.status in ('posted','voided');
  return result;
end;
$$;
create function public.get_group_settlement_export_snapshot(p_group_id uuid)
returns jsonb language sql stable security definer set search_path=pg_catalog as $$
select coalesce(jsonb_agg(to_jsonb(s) order by s.settled_at desc,s.settlement_id desc),'[]')
from public.get_group_settlements(p_group_id) s;
$$;
revoke all on function public.get_group_expense_export_snapshot(uuid) from public,anon;
revoke all on function public.get_group_settlement_export_snapshot(uuid) from public,anon;
grant execute on function public.get_group_expense_export_snapshot(uuid) to authenticated;
grant execute on function public.get_group_settlement_export_snapshot(uuid) to authenticated;
commit;
