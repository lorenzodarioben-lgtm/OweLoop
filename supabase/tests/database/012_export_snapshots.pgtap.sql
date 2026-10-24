begin;
select no_plan();
insert into auth.users(id,email) values('d1111111-1111-4111-8111-111111111101','export-owner@example.test');
select set_config('request.jwt.claim.sub','d1111111-1111-4111-8111-111111111101',true);
select public.complete_profile('Export owner');
insert into public.groups(id,name,currency_code) values('d1111111-1111-4111-8111-111111111100','Export snapshot','AUD');
select public.create_categorized_expense('d1111111-1111-4111-8111-111111111100','Snapshot dinner',9223372036854775807,now(),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='d1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',9223372036854775807)),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='d1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',9223372036854775807)),gen_random_uuid(),'food');
set local role authenticated;
select is(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')->0->>'total_amount_minor','9223372036854775807','snapshot preserves bigint exactly');
select is(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')->0->>'category_key','food','snapshot retains categories');
select is(jsonb_array_length(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')->0->'expense_payers'),1,'snapshot includes complete allocations');
select is(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')->0->'expense_splits'->0->'group_members'->>'display_name','Export owner','snapshot includes participant names');
select public.void_expense(id) from public.expenses where group_id='d1111111-1111-4111-8111-111111111100';
select is(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')->0->>'status','voided','snapshot sees authoritative void state');
select public.archive_group('d1111111-1111-4111-8111-111111111100');
select is(jsonb_array_length(public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')),1,'archived complete history is exportable');
select is(public.get_group_settlement_export_snapshot('d1111111-1111-4111-8111-111111111100'),'[]'::jsonb,'empty settlement export is explicit');
select set_config('request.jwt.claim.sub','d1111111-1111-4111-8111-111111111199',true);
select throws_ok($$select public.get_group_expense_export_snapshot('d1111111-1111-4111-8111-111111111100')$$,'P0001','Group is unavailable','outsider cannot export');
select throws_ok($$select public.get_group_settlement_export_snapshot('d1111111-1111-4111-8111-111111111100')$$,'P0001',null,'settlement snapshot preserves authorization');
reset role;
select is((select provolatile::text from pg_proc where oid='public.get_group_expense_export_snapshot(uuid)'::regprocedure),'s','nested export reads share a stable statement snapshot');
select * from finish();
rollback;
