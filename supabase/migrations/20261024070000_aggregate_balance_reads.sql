begin;
-- Aggregate once per expense/member before joining the membership set. Explicit
-- materialization prevents parameterized nested rescans on newly populated
-- groups whose table statistics have not yet been refreshed by autovacuum.
create or replace function app_private.group_balance_rows(p_group_id uuid)
returns table(group_member_id uuid,display_name text,role public.group_member_role,
  is_removed boolean,is_guest boolean,is_current_user boolean,net_balance_minor bigint)
language sql stable security definer set search_path=pg_catalog
as $$
with posted as materialized (
  select e.id,e.total_amount_minor from public.expenses e
  where e.group_id=p_group_id and e.status='posted' and e.voided_at is null
), payer_totals as materialized (
  select p.expense_id,sum(p.amount_minor) as amount
  from public.expense_payers p join posted e on e.id=p.expense_id
  where p.group_id=p_group_id group by p.expense_id
), split_totals as materialized (
  select s.expense_id,sum(s.amount_minor) as amount
  from public.expense_splits s join posted e on e.id=s.expense_id
  where s.group_id=p_group_id group by s.expense_id
), valid_expenses as materialized (
  select e.id from posted e join payer_totals p on p.expense_id=e.id
  join split_totals s on s.expense_id=e.id
  where p.amount=e.total_amount_minor and s.amount=e.total_amount_minor
), valid_settlements as materialized (
  select s.paying_member_id,s.receiving_member_id,s.amount_minor
  from public.settlements s
  join public.group_members payer on payer.id=s.paying_member_id and payer.group_id=s.group_id
  join public.group_members receiver on receiver.id=s.receiving_member_id and receiver.group_id=s.group_id
  where s.group_id=p_group_id and s.voided_at is null and s.amount_minor>0
), deltas as materialized (
  select p.group_member_id,p.amount_minor::numeric as amount
  from public.expense_payers p join valid_expenses e on e.id=p.expense_id where p.group_id=p_group_id
  union all
  select s.group_member_id,-s.amount_minor::numeric
  from public.expense_splits s join valid_expenses e on e.id=s.expense_id where s.group_id=p_group_id
  union all select s.paying_member_id,s.amount_minor::numeric from valid_settlements s
  union all select s.receiving_member_id,-s.amount_minor::numeric from valid_settlements s
), netted as materialized (
  select d.group_member_id,sum(d.amount) as net from deltas d group by d.group_member_id
)
select m.id,m.display_name,m.role,m.removed_at is not null,m.user_id is null,
  m.user_id is not null and m.user_id=auth.uid(),coalesce(n.net,0)::bigint
from public.group_members m left join netted n on n.group_member_id=m.id
where m.group_id=p_group_id and (m.removed_at is null or n.group_member_id is not null)
$$;
commit;
