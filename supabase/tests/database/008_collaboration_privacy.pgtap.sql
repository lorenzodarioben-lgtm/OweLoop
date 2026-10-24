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

select lives_ok($$select public.create_group_invitation('88888888-8888-8888-8888-888888888800','unregistered-privacy@example.test')$$,'unknown account invitation gets a generic successful request');
select is((select count(*) from public.get_group_invitations('88888888-8888-8888-8888-888888888800')),1::bigint,'sender sees a request without learning registration status');
select lives_ok($$select public.create_group_invitation('88888888-8888-8888-8888-888888888800','UNREGISTERED-PRIVACY@example.test')$$,'unbound invitation retry remains generic');
select is((select count(*) from public.get_group_invitations('88888888-8888-8888-8888-888888888800')),1::bigint,'unknown email retries cannot accumulate duplicate requests');
select lives_ok($$select public.create_guest_claim_request('88888888-8888-8888-8888-888888888800','88888888-8888-8888-8888-888888888802','unregistered-privacy@example.test')$$,'unknown claim recipient has a non-oracular sender request');
select is((select count(*) from public.get_group_guest_claim_requests('88888888-8888-8888-8888-888888888800')),1::bigint,'claim sender cannot distinguish registration from request presence');
reset role;
select is((select count(*) from public.group_invitations where recipient_user_id is null),1::bigint,'unknown invitation is unbound and grants no account access');
select is((select count(*) from public.guest_claim_requests where recipient_user_id is null),1::bigint,'unknown claim is unbound and grants no account access');
insert into auth.users(id,email) values('dddddddd-1111-4111-8111-111111111101','unregistered-privacy@example.test');
select set_config('request.jwt.claim.sub','dddddddd-1111-4111-8111-111111111101',true);
set local role authenticated;
select is((select count(*) from public.get_pending_group_invitations()),0::bigint,'later registration cannot automatically attach an old unbound invitation');
select is((select count(*) from public.get_pending_guest_claim_requests()),0::bigint,'later registration cannot automatically claim a guest identity');
select throws_ok($$update public.group_invitations set recipient_user_id=auth.uid()$$,'42501',null,'clients cannot bind unbound invitations themselves');
select throws_ok($$update public.guest_claim_requests set recipient_user_id=auth.uid()$$,'42501',null,'clients cannot bind unbound claims themselves');
select * from finish();
rollback;
