begin;
select no_plan();
insert into auth.users(id,email) values
('a1111111-1111-4111-8111-111111111101','recovery-owner@example.test'),
('a1111111-1111-4111-8111-111111111102','recovery-member@example.test'),
('a1111111-1111-4111-8111-111111111103','recovery-admin@example.test'),
('a1111111-1111-4111-8111-111111111104','recovery-outsider@example.test');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111101',true);
select public.complete_profile('Recovery owner');
insert into public.groups(id,name,currency_code) values('a1111111-1111-4111-8111-111111111100','Recovery ledger','AUD');
insert into public.group_members(id,group_id,user_id,display_name,role) values
('a1111111-1111-4111-8111-111111111112','a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111102','Member','member'),
('a1111111-1111-4111-8111-111111111113','a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111103','Admin','admin');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111102',true);
select public.complete_profile('Recovery member');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111103',true);
select public.complete_profile('Recovery admin');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111101',true);
set local role authenticated;
select public.create_expense('a1111111-1111-4111-8111-111111111100','Debt survives archive',100,now(),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='a1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',100)),
'[{"member_id":"a1111111-1111-4111-8111-111111111112","amount_minor":100}]',gen_random_uuid());
select public.archive_group('a1111111-1111-4111-8111-111111111100');
select ok((select reason from public.get_account_deletion_blockers()) like '%reopen%','archived debt blocker gives a recovery action');
select throws_ok($$update public.groups set archived_at=null where id='a1111111-1111-4111-8111-111111111100'$$,'42501',null,'direct reopen remains forbidden');
select throws_ok($$select public.recover_ownerless_archived_group('a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111112','Unauthorized recovery')$$,'42501',null,'mobile cannot invoke operator recovery');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111102',true);
select throws_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'P0001','Only the active group owner can reopen this group','ordinary member cannot reopen');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111103',true);
select throws_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'P0001','Only the active group owner can reopen this group','admin cannot promote own reopening authority');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111104',true);
select is((select count(*) from public.group_lifecycle_events),0::bigint,'outsider cannot read lifecycle events');
select throws_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'P0001','Only the active group owner can reopen this group','outsider cannot reopen');
reset role;
set local role anon;
select throws_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'42501',null,'anonymous cannot reopen');
reset role;
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111101',true);
set local role authenticated;
select lives_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'owner reopens outstanding ledger');
select lives_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'repeated reopen is idempotent');
select is((select count(*) from public.group_lifecycle_events where event_type='reopened'),1::bigint,'retries do not duplicate reopen events');
select is((select net_balance_minor from public.get_group_balances('a1111111-1111-4111-8111-111111111100') where group_member_id='a1111111-1111-4111-8111-111111111112'),(-100)::bigint,'reopening does not forgive debt');
select public.record_settlement('a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111112',(select id from public.group_members where group_id='a1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),100,now(),gen_random_uuid());
select ok(not exists(select 1 from public.get_group_balances('a1111111-1111-4111-8111-111111111100') where net_balance_minor<>0),'normal settlement resolves reopened balances');
select public.archive_group('a1111111-1111-4111-8111-111111111100');
select is((select count(*) from public.get_account_deletion_blockers()),0::bigint,'settled rearchived owner can delete');
reset role;
select lives_ok($$delete from auth.users where id='a1111111-1111-4111-8111-111111111101'$$,'owner deletion preserves archived ledger');
select is((select count(*) from public.expenses where group_id='a1111111-1111-4111-8111-111111111100'),1::bigint,'shared expense survives owner deletion');
set local role authenticated;
select throws_ok($$select public.reopen_group('a1111111-1111-4111-8111-111111111100')$$,'P0001','Only the active group owner can reopen this group','deleted owner token cannot reopen');
reset role;
set local role service_role;
select throws_ok($$select public.recover_ownerless_archived_group('a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111104','Reviewed support recovery')$$,'P0001','Choose an existing active registered member','operator cannot inject outsider ownership');
select lives_ok($$select public.recover_ownerless_archived_group('a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111112','Reviewed support recovery')$$,'trusted operator recovers only to existing registered member');
select throws_ok($$select public.recover_ownerless_archived_group('a1111111-1111-4111-8111-111111111100','a1111111-1111-4111-8111-111111111113','Reviewed support recovery')$$,'P0001','An archived group is required','operator cannot reuse recovery on active ledger');
reset role;
select is((select count(*) from app_private.group_reopen_guards),0::bigint,'private guards are removed');
select ok(not has_table_privilege('authenticated','app_private.group_reopen_guards','INSERT'),'mobile cannot forge a reopen guard');
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111102',true);
set local role authenticated;
select is((select role::text from public.group_members where id='a1111111-1111-4111-8111-111111111112'),'owner','successor receives explicit ownership');
select is((select count(*) from public.group_lifecycle_events where event_type='operator_recovered' and reason='Reviewed support recovery'),1::bigint,'recovery reason is durably audited');
select throws_ok($$delete from public.group_lifecycle_events$$,'42501',null,'mobile cannot erase audit');
select * from finish();
rollback;
