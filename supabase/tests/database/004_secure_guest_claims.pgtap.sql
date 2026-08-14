begin;

select plan(31);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('aaaaaaaa-1111-1111-1111-111111111101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-owner@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('aaaaaaaa-1111-1111-1111-111111111102', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-admin@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('aaaaaaaa-1111-1111-1111-111111111103', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-member@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('aaaaaaaa-1111-1111-1111-111111111104', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-target@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('aaaaaaaa-1111-1111-1111-111111111105', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-unrelated@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('aaaaaaaa-1111-1111-1111-111111111106', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'claim-existing@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111101', true);
set local role authenticated;
select lives_ok($$select public.complete_profile('Claim owner')$$, 'the claim owner can complete onboarding');
select lives_ok(
  $$insert into public.groups (id, name, currency_code) values ('aaaaaaaa-1111-1111-1111-111111111100', 'Claim group', 'AUD')$$,
  'the claim owner can create a group'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name, role) values
  ('aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111102', 'Claim admin', 'admin'),
  ('aaaaaaaa-1111-1111-1111-111111111112', 'aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111103', 'Claim member', 'member'),
  ('aaaaaaaa-1111-1111-1111-111111111113', 'aaaaaaaa-1111-1111-1111-111111111100', null, 'Morgan guest', 'member'),
  ('aaaaaaaa-1111-1111-1111-111111111114', 'aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111106', 'Existing member', 'member');

select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111101', true);
set local role authenticated;
select lives_ok(
  $$select public.create_expense(
    'aaaaaaaa-1111-1111-1111-111111111100',
    'Claim-history dinner',
    1000,
    now(),
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = 'aaaaaaaa-1111-1111-1111-111111111100' and user_id = auth.uid()),
      'amount_minor', 1000
    )),
    jsonb_build_array(jsonb_build_object(
      'member_id', 'aaaaaaaa-1111-1111-1111-111111111113',
      'amount_minor', 1000
    )),
    'aaaaaaaa-1111-4111-8111-111111111115'
  )$$,
  'a guest can have financial history before an account claim'
);
select set_config(
  'test.guest_balance',
  (select net_balance_minor::text from public.get_group_balances('aaaaaaaa-1111-1111-1111-111111111100') where group_member_id = 'aaaaaaaa-1111-1111-1111-111111111113'),
  true
);
select lives_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'claim-target@example.test')$$,
  'an owner can initiate a claim for one active guest'
);
select is(
  (select count(*) from public.get_group_guest_claim_requests('aaaaaaaa-1111-1111-1111-111111111100')),
  1::bigint,
  'an owner can view the pending guest claim'
);
select lives_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'CLAIM-TARGET@example.test')$$,
  'a duplicate claim initiation has a safe generic result'
);
select is(
  (select count(*) from public.get_group_guest_claim_requests('aaaaaaaa-1111-1111-1111-111111111100')),
  1::bigint,
  'one guest has only one open claim request'
);
select lives_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'not-registered@example.test')$$,
  'an unknown claim email receives no account-specific RPC error'
);
select lives_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'claim-existing@example.test')$$,
  'an existing member receives no account-specific claim error'
);

reset role;
select set_config(
  'test.claim_request_id',
  (select id::text from public.guest_claim_requests where guest_member_id = 'aaaaaaaa-1111-1111-1111-111111111113'),
  true
);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111103', true);
set local role authenticated;
select throws_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'claim-unrelated@example.test')$$,
  'P0001', 'Only an active group owner or administrator can create guest claim requests',
  'an ordinary member cannot initiate a guest claim'
);
select throws_ok(
  $$select * from public.get_group_guest_claim_requests('aaaaaaaa-1111-1111-1111-111111111100')$$,
  'P0001', 'Only an active group owner or administrator can view guest claim requests',
  'an ordinary member cannot enumerate group claim requests'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;
select throws_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111113', 'claim-unrelated@example.test')$$,
  'P0001', 'Authentication is required to create a guest claim request',
  'an unauthenticated caller cannot initiate a guest claim'
);

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111105', true);
set local role authenticated;
select is(
  (select count(*) from public.get_pending_guest_claim_requests()),
  0::bigint,
  'an unrelated account cannot read another pending claim'
);
select throws_ok(
  $$select public.accept_guest_claim_request(current_setting('test.claim_request_id')::uuid)$$,
  'P0001', 'Guest claim request is unavailable',
  'an unrelated account cannot accept a guest claim'
);

reset role;
update public.profiles
set onboarding_completed_at = now()
where id = 'aaaaaaaa-1111-1111-1111-111111111104';
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111104', true);
set local role authenticated;
select is(
  (select count(*) from public.get_pending_guest_claim_requests()),
  1::bigint,
  'only the intended account can read its pending claim'
);
select lives_ok(
  $$select public.accept_guest_claim_request(current_setting('test.claim_request_id')::uuid)$$,
  'the intended account can accept the guest claim'
);
select is(
  (select id from public.group_members where group_id = 'aaaaaaaa-1111-1111-1111-111111111100' and user_id = auth.uid() and removed_at is null),
  'aaaaaaaa-1111-1111-1111-111111111113'::uuid,
  'claim acceptance preserves the guest durable membership ID'
);
select is(
  (select net_balance_minor from public.get_group_balances('aaaaaaaa-1111-1111-1111-111111111100') where group_member_id = 'aaaaaaaa-1111-1111-1111-111111111113'),
  current_setting('test.guest_balance')::bigint,
  'claim acceptance preserves the guest balance'
);
select is(
  (select count(*) from public.expenses where group_id = 'aaaaaaaa-1111-1111-1111-111111111100'),
  1::bigint,
  'claim acceptance preserves the guest financial history'
);
select is(
  (select role::text from public.group_members where id = 'aaaaaaaa-1111-1111-1111-111111111113'),
  'member',
  'claim acceptance cannot grant a privileged group role'
);
select throws_ok(
  $$select public.accept_guest_claim_request(current_setting('test.claim_request_id')::uuid)$$,
  'P0001', 'Guest claim request is unavailable',
  'an accepted claim cannot be reused'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name, role)
values ('aaaaaaaa-1111-1111-1111-111111111116', 'aaaaaaaa-1111-1111-1111-111111111100', null, 'Robin guest', 'member');
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111102', true);
set local role authenticated;
select lives_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111116', 'claim-unrelated@example.test')$$,
  'an administrator can initiate a guest claim'
);

reset role;
select set_config(
  'test.revoke_claim_request_id',
  (select id::text from public.guest_claim_requests where guest_member_id = 'aaaaaaaa-1111-1111-1111-111111111116'),
  true
);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111101', true);
set local role authenticated;
select lives_ok(
  $$select public.revoke_guest_claim_request(current_setting('test.revoke_claim_request_id')::uuid)$$,
  'an owner can revoke a pending guest claim'
);

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111105', true);
set local role authenticated;
select throws_ok(
  $$select public.accept_guest_claim_request(current_setting('test.revoke_claim_request_id')::uuid)$$,
  'P0001', 'Guest claim request is unavailable',
  'a revoked guest claim cannot be accepted'
);

reset role;
insert into public.guest_claim_requests (
  id, group_id, guest_member_id, recipient_user_id, recipient_email,
  initiated_by_member_id, created_at, expires_at
) values (
  'aaaaaaaa-1111-1111-1111-111111111117',
  'aaaaaaaa-1111-1111-1111-111111111100',
  'aaaaaaaa-1111-1111-1111-111111111116',
  'aaaaaaaa-1111-1111-1111-111111111105',
  'claim-unrelated@example.test',
  (select id from public.group_members where group_id = 'aaaaaaaa-1111-1111-1111-111111111100' and user_id = 'aaaaaaaa-1111-1111-1111-111111111101'),
  now() - interval '2 minutes',
  now() - interval '1 minute'
);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111105', true);
set local role authenticated;
select throws_ok(
  $$select public.accept_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111117')$$,
  'P0001', 'Guest claim request is unavailable',
  'an expired guest claim cannot be accepted'
);

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-1111-1111-1111-111111111101', true);
set local role authenticated;
select lives_ok(
  $$insert into public.groups (id, name, currency_code) values ('aaaaaaaa-1111-1111-1111-111111111118', 'Separate claim group', 'AUD')$$,
  'the owner can create a second group for isolation testing'
);
select throws_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111118', 'aaaaaaaa-1111-1111-1111-111111111116', 'claim-unrelated@example.test')$$,
  'P0001', 'This guest is unavailable for account claiming',
  'a guest from another group cannot be claimed across group boundaries'
);
select lives_ok(
  $$select public.archive_group('aaaaaaaa-1111-1111-1111-111111111100')$$,
  'an owner can archive a group with guest claim history'
);
select throws_ok(
  $$select public.create_guest_claim_request('aaaaaaaa-1111-1111-1111-111111111100', 'aaaaaaaa-1111-1111-1111-111111111116', 'claim-unrelated@example.test')$$,
  'P0001', 'Group is unavailable',
  'an archived group cannot initiate a guest claim'
);

reset role;
select ok(
  not has_table_privilege('authenticated', 'public.guest_claim_requests', 'select'),
  'ordinary clients cannot read guest claim records directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.guest_claim_requests', 'insert'),
  'ordinary clients cannot insert guest claim records directly'
);

select * from finish();
rollback;
