begin;

select plan(27);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('99999999-9999-9999-9999-999999999901', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-owner@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('99999999-9999-9999-9999-999999999902', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-admin@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('99999999-9999-9999-9999-999999999903', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-member@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('99999999-9999-9999-9999-999999999904', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-recipient@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('99999999-9999-9999-9999-999999999905', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-unrelated@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('99999999-9999-9999-9999-999999999906', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'invite-existing@example.test', '$2a$10$testhash', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999901', true);
set local role authenticated;
select lives_ok($$select public.complete_profile('Invite owner')$$, 'the invitation owner can complete onboarding');
select lives_ok(
  $$insert into public.groups (id, name, currency_code) values ('99999999-9999-9999-9999-999999999900', 'Invitation group', 'AUD')$$,
  'the invitation owner can create an invitation group'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name, role) values
  ('99999999-9999-9999-9999-999999999911', '99999999-9999-9999-9999-999999999900', '99999999-9999-9999-9999-999999999902', 'Invite admin', 'admin'),
  ('99999999-9999-9999-9999-999999999912', '99999999-9999-9999-9999-999999999900', '99999999-9999-9999-9999-999999999903', 'Invite member', 'member'),
  ('99999999-9999-9999-9999-999999999913', '99999999-9999-9999-9999-999999999900', '99999999-9999-9999-9999-999999999906', 'Existing member', 'member');

select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999901', true);
set local role authenticated;
select lives_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-recipient@example.test')$$,
  'an owner can create an invitation for a registered account'
);
select is(
  (select count(*) from public.get_group_invitations('99999999-9999-9999-9999-999999999900')),
  1::bigint,
  'an owner can view the group pending invitation'
);
select lives_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'INVITE-RECIPIENT@example.test')$$,
  'a duplicate invitation submission has a safe generic result'
);
select is(
  (select count(*) from public.get_group_invitations('99999999-9999-9999-9999-999999999900')),
  1::bigint,
  'only one open invitation exists for one recipient and group'
);
select lives_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'not-registered@example.test')$$,
  'an unknown email receives no account-specific RPC error'
);
select is(
  (select count(*) from public.get_group_invitations('99999999-9999-9999-9999-999999999900')),
  1::bigint,
  'an unknown email creates no invitation'
);
select lives_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-existing@example.test')$$,
  'an existing member receives no account-specific RPC error'
);
select is(
  (select count(*) from public.get_group_invitations('99999999-9999-9999-9999-999999999900')),
  1::bigint,
  'an existing active member receives no invitation'
);

reset role;
select set_config(
  'test.invitation_id',
  (select id::text from public.group_invitations where recipient_user_id = '99999999-9999-9999-9999-999999999904'),
  true
);
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999903', true);
set local role authenticated;
select throws_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-unrelated@example.test')$$,
  'P0001', 'Only an active group owner or administrator can create invitations',
  'an ordinary member cannot create an invitation'
);
select throws_ok(
  $$select * from public.get_group_invitations('99999999-9999-9999-9999-999999999900')$$,
  'P0001', 'Only an active group owner or administrator can view invitations',
  'an ordinary member cannot enumerate group invitations'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;
select throws_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-unrelated@example.test')$$,
  'P0001', 'Authentication is required to create a group invitation',
  'an unauthenticated caller cannot create an invitation'
);

reset role;
select set_config(
  'test.invitation_id',
  (select id::text from public.group_invitations where recipient_user_id = '99999999-9999-9999-9999-999999999904'),
  true
);
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999905', true);
set local role authenticated;
select is(
  (select count(*) from public.get_pending_group_invitations()),
  0::bigint,
  'an unrelated user cannot read another recipient invitation'
);
select throws_ok(
  $$select public.accept_group_invitation(current_setting('test.invitation_id')::uuid)$$,
  'P0001', 'Invitation is unavailable',
  'an unrelated user cannot accept an invitation'
);

reset role;
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999904', true);
set local role authenticated;
select is(
  (select count(*) from public.get_pending_group_invitations()),
  1::bigint,
  'only the recipient can read their pending invitation'
);
select lives_ok(
  $$select public.accept_group_invitation(current_setting('test.invitation_id')::uuid)$$,
  'the recipient can accept their invitation'
);
select is(
  (select role::text from public.group_members where group_id = '99999999-9999-9999-9999-999999999900' and user_id = auth.uid() and removed_at is null),
  'member',
  'acceptance can grant only the member role'
);
select throws_ok(
  $$select public.accept_group_invitation(current_setting('test.invitation_id')::uuid)$$,
  'P0001', 'Invitation is unavailable',
  'an accepted invitation cannot be reused'
);

reset role;
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999901', true);
set local role authenticated;
select lives_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-unrelated@example.test')$$,
  'an owner can create an invitation to revoke'
);

reset role;
select set_config(
  'test.revoke_invitation_id',
  (select id::text from public.group_invitations where recipient_user_id = '99999999-9999-9999-9999-999999999905' order by created_at desc limit 1),
  true
);
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999901', true);
set local role authenticated;
select lives_ok(
  $$select public.revoke_group_invitation(current_setting('test.revoke_invitation_id')::uuid)$$,
  'an owner can revoke a pending invitation'
);

reset role;
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999905', true);
set local role authenticated;
select throws_ok(
  $$select public.accept_group_invitation(current_setting('test.revoke_invitation_id')::uuid)$$,
  'P0001', 'Invitation is unavailable',
  'a revoked invitation cannot be accepted'
);

reset role;
insert into public.group_invitations (id, group_id, recipient_user_id, recipient_email, inviter_member_id, created_at, expires_at)
values (
  '99999999-9999-9999-9999-999999999920',
  '99999999-9999-9999-9999-999999999900',
  '99999999-9999-9999-9999-999999999905',
  'invite-unrelated@example.test',
  (select id from public.group_members where group_id = '99999999-9999-9999-9999-999999999900' and user_id = '99999999-9999-9999-9999-999999999901'),
  now() - interval '2 minutes',
  now() - interval '1 minute'
);
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999905', true);
set local role authenticated;
select throws_ok(
  $$select public.accept_group_invitation('99999999-9999-9999-9999-999999999920')$$,
  'P0001', 'Invitation is unavailable',
  'an expired invitation cannot be accepted'
);

reset role;
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999901', true);
set local role authenticated;
select lives_ok(
  $$select public.archive_group('99999999-9999-9999-9999-999999999900')$$,
  'an owner can archive an invitation group'
);
select throws_ok(
  $$select public.create_group_invitation('99999999-9999-9999-9999-999999999900', 'invite-unrelated@example.test')$$,
  'P0001', 'Group is unavailable',
  'an archived group cannot create invitations'
);

reset role;
select ok(
  not has_table_privilege('authenticated', 'public.group_invitations', 'select'),
  'ordinary clients cannot read invitation rows directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.group_invitations', 'insert'),
  'ordinary clients cannot insert invitation rows directly'
);

select * from finish();
rollback;
