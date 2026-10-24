begin;

select no_plan();

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '88888888-8888-8888-8888-888888888881',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'financial-owner@example.test',
  '$2a$10$testhash',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

select set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888881', true);
set local role authenticated;

select lives_ok(
  $$select public.complete_profile('Financial owner')$$,
  'a financial test owner can complete onboarding'
);

select lives_ok(
  $$insert into public.groups (id, name, currency_code)
    values ('88888888-8888-8888-8888-888888888800', 'Financial safety', 'AUD')$$,
  'the financial test owner can create a group'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  '88888888-8888-8888-8888-888888888802',
  '88888888-8888-8888-8888-888888888800',
  null,
  'Financial guest'
);

select set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888881', true);
set local role authenticated;

select throws_ok($$update public.group_members set removed_at=now() where id='88888888-8888-8888-8888-888888888802'$$,'42501',null,'owner cannot bypass guarded removal');
select throws_ok($$update public.group_members set display_name='Impersonation' where id='88888888-8888-8888-8888-888888888802'$$,'42501',null,'owner cannot directly rewrite participant identity');
select throws_ok($$update public.groups set currency_code='JPY' where id='88888888-8888-8888-8888-888888888800'$$,'42501',null,'owner cannot bypass guarded group changes');
select lives_ok($$select public.rename_group('88888888-8888-8888-8888-888888888800','Guarded rename')$$,'guarded rename still works');
select lives_ok($$select public.create_expense('88888888-8888-8888-8888-888888888800','Security dinner',1000,now(),jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where user_id=auth.uid()),'amount_minor',1000)),jsonb_build_array(jsonb_build_object('member_id','88888888-8888-8888-8888-888888888802','amount_minor',1000)),'88888888-1111-4111-8111-111111111101')$$,'guarded expense works after privilege tightening');
select throws_ok($$select public.remove_group_member('88888888-8888-8888-8888-888888888800','88888888-8888-8888-8888-888888888802')$$,'P0001','A member must settle their balance before removal','unsettled member remains protected');
select is((select count(*) from public.get_financial_operation('88888888-1111-4111-8111-111111111101')),1::bigint,'creator can reconcile a committed operation');
select is((select count(*) from public.get_financial_operation('88888888-1111-4111-8111-111111111102')),0::bigint,'unknown operation has no invented success');
select throws_ok($$select public.leave_group('88888888-8888-8888-8888-888888888800')$$,'P0001','Transfer ownership before leaving this group','owner must transfer before leaving');
reset role;
insert into auth.users(id,email) values ('88888888-1111-4111-8111-111111111102','guarded-outsider@example.test');
select set_config('request.jwt.claim.sub','88888888-1111-4111-8111-111111111102',true);
set local role authenticated;
select is((select count(*) from public.get_financial_operation('88888888-1111-4111-8111-111111111101')),0::bigint,'outsider cannot reconcile another account operation');
select throws_ok($$select public.remove_group_member('88888888-8888-8888-8888-888888888800','88888888-8888-8888-8888-888888888802')$$,'P0001','Only an active group owner or administrator can remove members','outsider cannot remove a member');
select throws_ok($$update public.group_members set removed_at=now()$$,'42501',null,'outsider direct updates are denied');
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
select throws_ok($$select * from public.get_financial_operation('88888888-1111-4111-8111-111111111101')$$,'42501',null,'anonymous cannot query reconciliation RPC');
reset role;
select ok(not has_column_privilege('authenticated','public.group_members','removed_at','UPDATE'),'removed_at column privilege is revoked');
select ok(not has_column_privilege('authenticated','public.settlements','voided_at','UPDATE'),'settlement direct void privilege is revoked');
select ok(not has_column_privilege('authenticated','public.expenses','total_amount_minor','UPDATE'),'expense amount column privilege is revoked');
select * from finish();
rollback;
