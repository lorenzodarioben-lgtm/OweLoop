begin;

create index expenses_history_cursor on public.expenses
  (group_id, occurred_at desc, created_at desc, id desc)
  where status in ('posted','voided');
create index settlements_history_cursor on public.settlements
  (group_id, settled_at desc, created_at desc, id desc);

create function public.get_expense_page(
  p_group_id uuid, p_limit integer default 50,
  p_before_occurred_at timestamptz default null,
  p_before_created_at timestamptz default null, p_before_id uuid default null,
  p_query text default '', p_from timestamptz default null,
  p_until timestamptz default null, p_member_id uuid default null,
  p_include_voided boolean default true
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

create function public.get_settlement_page(
  p_group_id uuid, p_limit integer default 50,
  p_before_settled_at timestamptz default null,
  p_before_created_at timestamptz default null, p_before_id uuid default null,
  p_include_voided boolean default true
) returns setof jsonb language plpgsql stable security definer set search_path = pg_catalog
as $$
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid())
     or not exists (select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then
    raise exception 'Group is unavailable';
  end if;
  if p_limit is null or p_limit<1 or p_limit>100
     or num_nonnulls(p_before_settled_at,p_before_created_at,p_before_id) not in (0,3) then
    raise exception 'Invalid history request';
  end if;
  return query
  select jsonb_build_object('settlement_id',s.id,'paying_member_id',s.paying_member_id,
    'paying_member_name',payer.display_name,'receiving_member_id',s.receiving_member_id,
    'receiving_member_name',receiver.display_name,'amount_minor',s.amount_minor,
    'settled_at',s.settled_at,'is_voided',s.voided_at is not null,'voided_at',s.voided_at,
    'created_at',s.created_at)
  from public.settlements s
  join public.group_members payer on payer.id=s.paying_member_id
  join public.group_members receiver on receiver.id=s.receiving_member_id
  where s.group_id=p_group_id and (p_include_voided or s.voided_at is null)
    and (p_before_id is null or (s.settled_at,s.created_at,s.id)
         < (p_before_settled_at,p_before_created_at,p_before_id))
  order by s.settled_at desc,s.created_at desc,s.id desc limit p_limit+1;
end;
$$;

revoke all on function public.get_expense_page(uuid,integer,timestamptz,timestamptz,uuid,text,timestamptz,timestamptz,uuid,boolean) from public;
revoke all on function public.get_settlement_page(uuid,integer,timestamptz,timestamptz,uuid,boolean) from public;
grant execute on function public.get_expense_page(uuid,integer,timestamptz,timestamptz,uuid,text,timestamptz,timestamptz,uuid,boolean) to authenticated;
grant execute on function public.get_settlement_page(uuid,integer,timestamptz,timestamptz,uuid,boolean) to authenticated;
commit;
