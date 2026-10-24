begin;
select no_plan();
insert into auth.users(id,email) values('c1111111-1111-4111-8111-111111111101','filter-owner@example.test');
select set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111101',true);
select public.complete_profile('Filter owner');
insert into public.groups(id,name,currency_code) values('c1111111-1111-4111-8111-111111111100','Settlement filters','AUD');
insert into public.group_members(id,group_id,display_name) values('c1111111-1111-4111-8111-111111111102','c1111111-1111-4111-8111-111111111100','Guest');
insert into public.settlements(group_id,paying_member_id,receiving_member_id,amount_minor,settled_at,created_by)
select 'c1111111-1111-4111-8111-111111111100','c1111111-1111-4111-8111-111111111102',
(select id from public.group_members where user_id=auth.uid() and group_id='c1111111-1111-4111-8111-111111111100'),i,'2026-01-01'::timestamptz+(i%30)*interval '1 day',auth.uid() from generate_series(1,150) i;
set local role authenticated;
select public.void_settlement(id) from public.settlements where group_id='c1111111-1111-4111-8111-111111111100' and amount_minor%10=0;
select is((select count(*) from public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_limit=>100,p_state=>'voided')),15::bigint,'void-only filter is applied before limit');
select is((select count(*) from public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_min_minor=>50,p_max_minor=>60)),11::bigint,'amount range uses exact integer bounds');
select is((select count(*) from public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_receiving_member_id=>'c1111111-1111-4111-8111-111111111102')),0::bigint,'payer and recipient filters are directional');
select is((select count(*) from public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_from=>'2026-01-01',p_until=>'2026-01-02',p_limit=>100)),5::bigint,'half-open dates match across the whole history');
select throws_ok($$select public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_min_minor=>20,p_max_minor=>10)$$,'P0001','Invalid history request','reversed ranges are rejected');
select throws_ok($$select public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_state=>'invented')$$,'P0001','Invalid history request','invalid state is rejected');
reset role;
create function pg_temp.walk_settlements(oldest boolean) returns uuid[] language plpgsql as $$
declare seen uuid[]:='{}'; cursor_row jsonb; item jsonb; page jsonb[];
begin
  loop
    select array_agg(row) into page from public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100',p_limit=>7,
      p_before_settled_at=>(cursor_row->>'settled_at')::timestamptz,p_before_created_at=>(cursor_row->>'created_at')::timestamptz,
      p_before_id=>(cursor_row->>'settlement_id')::uuid,p_min_minor=>20,p_max_minor=>80,p_oldest_first=>oldest) row;
    if page is null then exit; end if;
    for i in 1..least(7,array_length(page,1)) loop
      item:=page[i];seen:=array_append(seen,(item->>'settlement_id')::uuid);cursor_row:=item;
    end loop;
    if array_length(page,1)<=7 then exit; end if;
    if array_length(seen,1)>200 then raise exception 'Cursor did not progress'; end if;
  end loop;
  return seen;
end;
$$;
set local role authenticated;
select is(cardinality(pg_temp.walk_settlements(false)),61,'newest-first filtered traversal reaches every qualifying record');
select is(cardinality(pg_temp.walk_settlements(true)),61,'oldest-first filtered traversal reaches every qualifying record');
select is((select count(distinct id) from unnest(pg_temp.walk_settlements(true)) id),61::bigint,'tied dates do not duplicate records');
select is((select (pg_temp.walk_settlements(true))[1]),(select id from public.settlements where amount_minor between 20 and 80 order by settled_at,created_at,id limit 1),'ascending traversal starts with the canonical earliest tuple');
select set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111199',true);
select throws_ok($$select public.get_filtered_settlement_page('c1111111-1111-4111-8111-111111111100')$$,'P0001','Group is unavailable','filter API cannot expose another group');
reset role;
select * from finish();
rollback;
