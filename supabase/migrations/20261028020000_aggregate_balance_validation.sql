begin;
-- Preserve the complete canonical validation, but aggregate allocation totals
-- once per expense and calculate canonical member rows once per statement.
create or replace function public.get_group_balances(p_group_id uuid)
returns table(group_member_id uuid,display_name text,role public.group_member_role,
 is_removed boolean,is_guest boolean,is_current_user boolean,net_balance_minor bigint)
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_user_id uuid:=auth.uid(); v_balance record;
begin
 if v_user_id is null then raise exception 'Authentication is required to load group balances'; end if;
 if not exists(select 1 from public.profiles where id=v_user_id and onboarding_completed_at is not null) then
   raise exception 'Complete your profile before loading group balances'; end if;
 if not app_private.is_active_group_member(p_group_id,v_user_id) then raise exception 'Group is unavailable'; end if;

 if exists(
   with posted as materialized(select e.id,e.total_amount_minor from public.expenses e
     where e.group_id=p_group_id and e.status='posted' and e.voided_at is null),
   payers as materialized(select p.expense_id,sum(p.amount_minor) as total from public.expense_payers p
     join posted e on e.id=p.expense_id where p.group_id=p_group_id group by p.expense_id),
   splits as materialized(select s.expense_id,sum(s.amount_minor) as total from public.expense_splits s
     join posted e on e.id=s.expense_id where s.group_id=p_group_id group by s.expense_id)
   select 1 from posted e left join payers p on p.expense_id=e.id left join splits s on s.expense_id=e.id
   where coalesce(p.total,0)::bigint<>e.total_amount_minor or coalesce(s.total,0)::bigint<>e.total_amount_minor
 ) then raise exception 'Financial records are inconsistent'; end if;
 if exists(select 1 from public.settlements s where s.group_id=p_group_id and s.voided_at is null and (
   s.amount_minor<=0 or not exists(select 1 from public.group_members m where m.id=s.paying_member_id and m.group_id=s.group_id)
   or not exists(select 1 from public.group_members m where m.id=s.receiving_member_id and m.group_id=s.group_id))) then
   raise exception 'Financial records are inconsistent'; end if;

 for v_balance in
   with rows as materialized(select * from app_private.group_balance_rows(p_group_id))
   select b.*,sum(b.net_balance_minor::numeric) over() as net_total from rows b
   order by case when b.is_current_user then 0 else 1 end,case when b.is_removed then 1 else 0 end,b.display_name,b.group_member_id
 loop
   if v_balance.net_total<>0 then raise exception 'Financial records are inconsistent'; end if;
   group_member_id:=v_balance.group_member_id;display_name:=v_balance.display_name;role:=v_balance.role;
   is_removed:=v_balance.is_removed;is_guest:=v_balance.is_guest;is_current_user:=v_balance.is_current_user;
   net_balance_minor:=v_balance.net_balance_minor;
   return next;
 end loop;
end;
$$;
revoke all on function public.get_group_balances(uuid) from public,anon;
grant execute on function public.get_group_balances(uuid) to authenticated;
commit;
