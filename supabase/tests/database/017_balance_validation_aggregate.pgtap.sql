begin;
select no_plan();
insert into auth.users(id,email) values('b7777777-1111-4111-8111-111111111101','balance-validation@example.test');
select set_config('request.jwt.claim.sub','b7777777-1111-4111-8111-111111111101',true);
select public.complete_profile('Balance validation');
insert into public.groups(id,name,currency_code) values('b7777777-1111-4111-8111-111111111100','Validation','AUD');
insert into public.group_members(id,group_id,display_name) values('b7777777-1111-4111-8111-111111111102','b7777777-1111-4111-8111-111111111100','Validation guest');
select set_config('test.validated_expense',(public.create_expense('b7777777-1111-4111-8111-111111111100','Validated amount',101,now(),
 jsonb_build_array(jsonb_build_object('member_id',m.id,'amount_minor',101)),
 jsonb_build_array(jsonb_build_object('member_id','b7777777-1111-4111-8111-111111111102','amount_minor',101)),gen_random_uuid())).id::text,true)
 from public.group_members m where m.user_id=auth.uid();
select is((select sum(net_balance_minor) from public.get_group_balances('b7777777-1111-4111-8111-111111111100')),0::numeric,'canonical exact group sum');
set local session_replication_role=replica;
update public.expense_payers set amount_minor=102 where expense_id=current_setting('test.validated_expense')::uuid;
set local session_replication_role=origin;
select throws_ok($$select * from public.get_group_balances('b7777777-1111-4111-8111-111111111100')$$,'P0001','Financial records are inconsistent','aggregated payer validation cannot hide corrupt posted expense');
set local session_replication_role=replica;
update public.expense_payers set amount_minor=101 where expense_id=current_setting('test.validated_expense')::uuid;
update public.expense_splits set amount_minor=100 where expense_id=current_setting('test.validated_expense')::uuid;
set local session_replication_role=origin;
select throws_ok($$select * from public.get_group_balances('b7777777-1111-4111-8111-111111111100')$$,'P0001','Financial records are inconsistent','aggregated split validation cannot hide corrupt posted expense');
set local session_replication_role=replica;
update public.expense_splits set amount_minor=101 where expense_id=current_setting('test.validated_expense')::uuid;
update public.group_members set removed_at=now() where id='b7777777-1111-4111-8111-111111111102';
set local session_replication_role=origin;
select is((select net_balance_minor from public.get_group_balances('b7777777-1111-4111-8111-111111111100') where group_member_id='b7777777-1111-4111-8111-111111111102'),-101::bigint,'removed financial identities remain in canonical ledger');
select is((select is_removed from public.get_group_balances('b7777777-1111-4111-8111-111111111100') where group_member_id='b7777777-1111-4111-8111-111111111102'),true,'removed status preserved');
set local session_replication_role=replica;
delete from public.expense_payers where expense_id=current_setting('test.validated_expense')::uuid;
set local session_replication_role=origin;
select throws_ok($$select * from public.get_group_balances('b7777777-1111-4111-8111-111111111100')$$,'P0001','Financial records are inconsistent','missing allocation total fails closed');
select set_config('request.jwt.claim.sub','b7777777-1111-4111-8111-111111111199',true);
select throws_ok($$select * from public.get_group_balances('b7777777-1111-4111-8111-111111111100')$$,'P0001','Complete your profile before loading group balances','caller validation still precedes ledger reads');
select * from finish();
rollback;
