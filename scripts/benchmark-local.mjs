// Bounded fictional fixtures in one rollback-only transaction. Local Docker only.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
const context=spawnSync('docker',['context','inspect'],{encoding:'utf8'});
assert.equal(context.status,0,'Local Docker is required.');
const endpoint=process.env.DOCKER_HOST||JSON.parse(context.stdout)[0].Endpoints.docker.Host;
assert.match(endpoint,/^(npipe:|unix:|tcp:\/\/(127\.0\.0\.1|localhost)(:|\/|$))/,'Remote Docker is refused.');
const container=process.env.OWELOOP_DB_CONTAINER||'supabase_db_oweloop-local';
assert.match(container,/^supabase_db_[a-zA-Z0-9_-]+$/,'Use a disposable local Supabase DB.');
const owner=randomUUID();
const source=`begin;
insert into auth.users(id,email) values('${owner}','benchmark-${owner}@example.test');
select set_config('request.jwt.claim.sub','${owner}',true);
select public.complete_profile('Disposable benchmark');
create function pg_temp.measure_reads(member_count integer,expense_count integer,settlement_count integer) returns jsonb
language plpgsql as $$
declare g public.groups; own uuid; other uuid; started timestamptz; metrics jsonb:='{}'; data jsonb; last_expense uuid; plan jsonb; cursor_row public.expenses;
begin
  select * into g from public.create_group('Benchmark '||member_count,'AUD');
  select id into own from public.group_members where group_id=g.id and user_id=auth.uid();
  insert into public.group_members(group_id,display_name) select g.id,'Fixture member '||i from generate_series(2,member_count) i;
  select id into other from public.group_members where group_id=g.id and user_id is null order by id limit 1;
  for i in 1..expense_count loop
    select id into last_expense from public.create_expense(g.id,'Benchmark expense '||i,1,now()-interval '1 day',
      jsonb_build_array(jsonb_build_object('member_id',own,'amount_minor',1)),jsonb_build_array(jsonb_build_object('member_id',other,'amount_minor',1)),gen_random_uuid());
  end loop;
  for i in 1..settlement_count loop perform public.record_settlement(g.id,other,own,1,now()-interval '1 hour',gen_random_uuid());end loop;
  started:=clock_timestamp();data:=public.get_group_balance_snapshot(g.id);
  if jsonb_array_length(data)<>member_count or (select sum((value->>'net_balance_minor')::numeric) from jsonb_array_elements(data))<>0 then raise exception 'Benchmark reconciliation failed';end if;
  metrics:=metrics||jsonb_build_object('balances_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();perform public.get_categorized_expense_page(g.id,p_limit=>50);
  metrics:=metrics||jsonb_build_object('history_first_ms',extract(epoch from clock_timestamp()-started)*1000);
  if expense_count>50 then
    select * into cursor_row from public.expenses where group_id=g.id order by occurred_at desc,created_at desc,id desc offset 49 limit 1;
    started:=clock_timestamp();perform public.get_categorized_expense_page(g.id,p_limit=>50,p_before_occurred_at=>cursor_row.occurred_at,p_before_created_at=>cursor_row.created_at,p_before_id=>cursor_row.id);
    metrics:=metrics||jsonb_build_object('history_next_ms',extract(epoch from clock_timestamp()-started)*1000);
  end if;
  started:=clock_timestamp();perform public.get_categorized_expense_page(g.id,p_limit=>50,p_query=>'expense 1');
  metrics:=metrics||jsonb_build_object('filtered_history_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();data:=public.get_group_expense_export_snapshot(g.id);
  if jsonb_array_length(data)<>expense_count then raise exception 'Expense export truncated';end if;
  metrics:=metrics||jsonb_build_object('expense_export_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();data:=public.get_group_settlement_export_snapshot(g.id);
  if jsonb_array_length(data)<>settlement_count then raise exception 'Settlement export truncated';end if;
  metrics:=metrics||jsonb_build_object('settlement_export_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();data:=public.get_group_member_snapshot(g.id);
  if jsonb_array_length(data)<>member_count then raise exception 'Membership snapshot truncated';end if;
  metrics:=metrics||jsonb_build_object('members_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();perform public.get_expense_activity_snapshot(last_expense);
  metrics:=metrics||jsonb_build_object('activity_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();perform public.get_notification_page();
  metrics:=metrics||jsonb_build_object('notification_page_ms',extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();perform public.export_personal_data();
  metrics:=metrics||jsonb_build_object('account_export_cumulative_ms',extract(epoch from clock_timestamp()-started)*1000);
  execute 'explain (analyze,buffers,format json) select id from public.expenses where group_id=$1 and status in (''posted'',''voided'') order by occurred_at desc,created_at desc,id desc limit 51' into plan using g.id;
  return jsonb_build_object('members',member_count,'expenses',expense_count,'settlements',settlement_count,'timings',metrics,'history_plan',plan->0->'Plan','history_plan_execution_ms',plan->0->'Execution Time');
end;
$$;
select jsonb_build_object('postgres',version(),'scope','local SQL only; account export includes cumulative fixtures; all fixtures rolled back');
select pg_temp.measure_reads(2,20,10);
select pg_temp.measure_reads(20,300,100);
select pg_temp.measure_reads(100,1000,500);
select pg_temp.measure_reads(1000,2000,1000);
rollback;`;
const result=spawnSync('docker',['exec','-i',container,'psql','-U','postgres','-d','postgres','-q','-A','-t','-v','ON_ERROR_STOP=1'],{input:source,encoding:'utf8',timeout:300000,maxBuffer:4*1024*1024});
if(result.status!==0)throw Error(result.stderr||'Bounded local benchmark failed.');
for(const line of result.stdout.split(/\r?\n/)){if(line.trim().startsWith('{'))console.log(JSON.stringify(JSON.parse(line)));}
console.log('PASS: four bounded local scale fixtures reconciled and rolled back; no production performance guarantee.');
