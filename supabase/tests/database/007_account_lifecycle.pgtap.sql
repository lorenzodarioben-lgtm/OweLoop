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

select is((select count(*) from public.get_account_deletion_blockers()),1::bigint,'active ownership blocks deletion');
select is(public.export_personal_data()->'profile'->>'id',auth.uid()::text,'personal export uses the caller identity');
reset role;
select throws_ok($$delete from auth.users where id='88888888-8888-8888-8888-888888888881'$$,'P0001','Transfer ownership or archive owned groups before account deletion','trusted admin deletion still enforces ownership safety');
set local role authenticated;
select public.create_expense('88888888-8888-8888-8888-888888888800','Retained personal history',100,now(),jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where user_id=auth.uid()),'amount_minor',100)),jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where user_id=auth.uid()),'amount_minor',100)),gen_random_uuid());
select public.archive_group('88888888-8888-8888-8888-888888888800');
select is((select count(*) from public.get_account_deletion_blockers()),0::bigint,'settled archived ownership allows deletion');
reset role;
select lives_ok($$delete from auth.users where id='88888888-8888-8888-8888-888888888881'$$,'trusted Auth deletion de-identifies historical data atomically');
select is((select count(*) from public.expenses where group_id='88888888-8888-8888-8888-888888888800'),1::bigint,'shared expense survives deletion');
select is((select total_amount_minor from public.expenses where group_id='88888888-8888-8888-8888-888888888800'),100::bigint,'shared amount is unchanged');
select is((select count(*) from public.group_members where group_id='88888888-8888-8888-8888-888888888800' and display_name='Deleted member' and user_id is null),1::bigint,'membership is de-identified rather than deleted');
select is((select count(*) from app_private.account_deletion_guards),0::bigint,'transactional deletion guards are removed after FK actions');
set local role authenticated;
select is((select count(*) from public.groups where id='88888888-8888-8888-8888-888888888800'),0::bigint,'old JWT identity no longer grants group access');
select throws_ok($$select public.create_group('Resurrection','AUD')$$,'P0001','Complete your profile before creating a group','deleted JWT cannot recreate application data');
reset role;
select ok(not has_table_privilege('authenticated','app_private.account_deletion_guards','INSERT'),'ordinary clients cannot forge trusted deletion guards');
select * from finish();
rollback;
