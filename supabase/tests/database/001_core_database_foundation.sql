begin;

select plan(65);

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
) values
  (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner-a@example.test',
    '$2a$10$testhash',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'member-a@example.test',
    '$2a$10$testhash',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'outsider@example.test',
    '$2a$10$testhash',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner-b@example.test',
    '$2a$10$testhash',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '55555555-5555-5555-5555-555555555555',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'successor-a@example.test',
    '$2a$10$testhash',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

select is(
  (select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Member'::text,
  'new authenticated users receive a safe fallback profile name'
);

select is(
  (select onboarding_completed_at from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  null::timestamptz,
  'new profiles start with incomplete onboarding'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$select public.complete_profile('  Owner A  ')$$,
  'an authenticated user can complete their own profile'
);

select is(
  (select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Owner A'::text,
  'profile completion trims the display name'
);

select isnt(
  (select onboarding_completed_at from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  null::timestamptz,
  'profile completion records onboarding completion'
);

select throws_ok(
  $$select public.complete_profile('')$$,
  'P0001',
  'Display name cannot be blank',
  'blank display names cannot complete onboarding'
);

select throws_ok(
  $$select public.complete_profile('   ')$$,
  'P0001',
  'Display name cannot be blank',
  'whitespace-only display names cannot complete onboarding'
);

select throws_ok(
  $$select public.complete_profile(repeat('x', 81))$$,
  'P0001',
  'Display name must be 80 characters or fewer',
  'overly long display names cannot complete onboarding'
);

select throws_ok(
  $$update public.profiles
    set display_name = 'Changed by another user'
    where id = '22222222-2222-2222-2222-222222222222'$$,
  '42501',
  'permission denied for table profiles',
  'users cannot modify another user profile directly'
);

select lives_ok(
  $$insert into public.groups (id, name, currency_code, created_by)
    values (
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      '  Weekend trip  ',
      'AUD',
      '22222222-2222-2222-2222-222222222222'
    )$$,
  'an authenticated onboarded user can create a group'
);

select is(
  (select name from public.groups where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Weekend trip'::text,
  'group creation trims the group name'
);

select is(
  (select created_by from public.groups where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'group creation always records the authenticated creator'
);

select is(
  (
    select count(*)
    from public.group_members
    where group_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      and role = 'owner'::public.group_member_role
      and removed_at is null
  ),
  1::bigint,
  'group creation produces exactly one active owner'
);

select is(
  (
    select role
    from public.group_members
    where group_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  'owner'::public.group_member_role,
  'the authenticated creator receives the owner role'
);

select throws_ok(
  $$insert into public.groups (name, currency_code)
    values ('', 'USD')$$,
  'P0001',
  'Group name cannot be blank',
  'blank group names are rejected'
);

select throws_ok(
  $$insert into public.groups (name, currency_code)
    values ('   ', 'USD')$$,
  'P0001',
  'Group name cannot be blank',
  'whitespace-only group names are rejected'
);

select throws_ok(
  $$insert into public.groups (name, currency_code)
    values ('Invalid currency', 'usd')$$,
  'P0001',
  'Currency code must be a three-letter uppercase ISO code',
  'invalid currency codes are rejected'
);

reset role;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
set local role authenticated;

select throws_ok(
  $$insert into public.groups (name, currency_code)
    values ('Incomplete profile', 'USD')$$,
  'P0001',
  'Complete your profile before creating a group',
  'an incomplete profile cannot create a group'
);

select public.complete_profile('Owner B');

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;

select throws_ok(
  $$insert into public.groups (name, currency_code)
    values ('Unauthenticated group', 'USD')$$,
  'P0001',
  'Authentication is required to create a group',
  'unauthenticated callers cannot create groups'
);

reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

insert into public.groups (id, name, currency_code, created_by)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Group A',
  'USD',
  '11111111-1111-1111-1111-111111111111'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '22222222-2222-2222-2222-222222222222',
  'Member A'
), (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '55555555-5555-5555-5555-555555555555',
  'Successor A'
), (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  null,
  'Guest A'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$select public.add_guest_member(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '  Guest from owner  '
  )$$,
  'an active owner can add a guest member'
);

select is(
  (
    select user_id
    from public.group_members
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and display_name = 'Guest from owner'
  ),
  null::uuid,
  'guest memberships have no authenticated user id'
);

select is(
  (
    select role
    from public.group_members
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and display_name = 'Guest from owner'
  ),
  'member'::public.group_member_role,
  'guest memberships always receive the ordinary member role'
);

select is(
  (
    select display_name
    from public.group_members
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and display_name = 'Guest from owner'
  ),
  'Guest from owner'::text,
  'guest creation trims the display name'
);

select throws_ok(
  $$select public.add_guest_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '')$$,
  'P0001',
  'Guest display name cannot be blank',
  'blank guest names are rejected'
);

select throws_ok(
  $$select public.add_guest_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '   ')$$,
  'P0001',
  'Guest display name cannot be blank',
  'whitespace-only guest names are rejected'
);

select throws_ok(
  $$select public.add_guest_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', repeat('x', 81))$$,
  'P0001',
  'Guest display name must be 80 characters or fewer',
  'overly long guest names are rejected'
);

select throws_ok(
  $$insert into public.group_members (group_id, user_id, display_name)
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '33333333-3333-3333-3333-333333333333',
      'Attached account'
    )$$,
  '42501',
  'permission denied for table group_members',
  'clients cannot attach arbitrary authenticated users as members'
);

insert into public.groups (id, name, currency_code)
values (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'Archived group',
  'USD'
);

update public.groups
set archived_at = now()
where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

select throws_ok(
  $$update public.groups
    set name = 'Changed archived group'
    where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'$$,
  'P0001',
  'Archived groups cannot be changed',
  'archived groups reject subsequent writes'
);

select throws_ok(
  $$select public.add_guest_member('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Late guest')$$,
  'P0001',
  'Guests cannot be added to an archived group',
  'guests cannot be added to archived groups'
);

select is(
  pg_catalog.to_regprocedure('public.add_guest_member(uuid,text,public.group_member_role)'),
  null::regprocedure,
  'the guest operation accepts no role parameter'
);

select is(
  pg_catalog.to_regprocedure('public.add_guest_member(uuid,text,uuid)'),
  null::regprocedure,
  'the guest operation accepts no registered-user parameter'
);

reset role;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
set local role authenticated;

insert into public.groups (id, name, currency_code, created_by)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Group B',
  'USD',
  '44444444-4444-4444-4444-444444444444'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  null,
  'Guest B'
), (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '33333333-3333-3333-3333-333333333333',
  'Member B'
);

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
set local role authenticated;

select throws_ok(
  $$select public.add_guest_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Member guest')$$,
  'P0001',
  'Only an active group owner or administrator can add guests',
  'an ordinary member cannot add a guest'
);

reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
set local role authenticated;

select is(
  (select count(*) from public.groups where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'an active member can read their group'
);

select is(
  (select count(*) from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  0::bigint,
  'profile reads remain isolated to the authenticated user'
);

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Shared meal',
  1000,
  '22222222-2222-2222-2222-222222222222'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  1000
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  1000
);

select lives_ok(
  $$select public.finalize_expense('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1')$$,
  'a complete draft can be finalized atomically'
);

select is(
  (select count(*) from public.expenses where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1'),
  1::bigint,
  'an active member can read their group expense'
);

select throws_ok(
  $$update public.group_members
    set role = 'admin'
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'$$,
  '42501',
  'permission denied for table group_members',
  'an ordinary member cannot promote themselves'
);

select throws_ok(
  $$select public.set_group_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'admin'
  )$$,
  'P0001',
  'Only an active group owner can change member roles',
  'a normal member cannot use role management'
);

select throws_ok(
  $$select public.transfer_group_ownership(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'
  )$$,
  'P0001',
  'Only an active group owner can transfer ownership',
  'a normal member cannot transfer ownership'
);

reset role;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
set local role authenticated;

select is(
  (select count(*) from public.groups where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0::bigint,
  'users cannot read unrelated groups'
);

select is(
  (select count(*) from public.expenses where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1'),
  0::bigint,
  'users cannot read unrelated expenses'
);

select is(
  (select count(*) from public.group_members where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0::bigint,
  'group member reads remain isolated to active group members'
);

select throws_ok(
  $$select public.add_guest_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Outside guest')$$,
  'P0001',
  'Only an active group owner or administrator can add guests',
  'a user outside the group cannot add a guest'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;

select throws_ok(
  $$select public.complete_profile('Unauthenticated')$$,
  'P0001',
  'Authentication is required to complete a profile',
  'unauthenticated callers cannot complete a profile'
);

reset role;
select ok(
  not pg_catalog.has_table_privilege(
    'anon'::name,
    'public.groups'::text,
    'select'::text
  ),
  'a guest record grants no unauthenticated group access'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select throws_ok(
  $$select public.set_group_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'admin'
  )$$,
  'P0001',
  'Only registered active group members can be promoted to administrator',
  'an owner cannot promote a guest to administrator'
);

select throws_ok(
  $$select public.transfer_group_ownership(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3'
  )$$,
  'P0001',
  'Ownership successor must be an active registered group member',
  'ownership cannot transfer to a guest'
);

select is(
  (
    select role
    from public.group_members
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  'owner'::public.group_member_role,
  'a failed guest ownership transfer leaves the existing owner unchanged'
);

select lives_ok(
  $$select public.set_group_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'admin'
  )$$,
  'an owner can promote an active registered member to administrator'
);

select is(
  (
    select role
    from public.group_members
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'
  ),
  'admin'::public.group_member_role,
  'the promoted registered member has the administrator role'
);

select lives_ok(
  $$select public.transfer_group_ownership(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'
  )$$,
  'ownership transfers to a different active registered member'
);

select is(
  (
    select role
    from public.group_members
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'
  ),
  'owner'::public.group_member_role,
  'the registered successor becomes the owner'
);

select is(
  (
    select role
    from public.group_members
    where user_id = '11111111-1111-1111-1111-111111111111'
      and group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'admin'::public.group_member_role,
  'the previous owner becomes an administrator'
);

select is(
  (
    select count(*)
    from public.group_members
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and role = 'owner'::public.group_member_role
      and removed_at is null
  ),
  1::bigint,
  'a successful transfer leaves exactly one active owner'
);

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Cross-group guard',
  1000,
  '11111111-1111-1111-1111-111111111111'
);

select throws_ok(
  $$insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
    values (
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      1000
    )$$,
  'P0001',
  'Expense participants must be active members of the expense group',
  'members from another group cannot be attached to an expense'
);

select throws_ok(
  $$insert into public.settlements (
    group_id,
    paying_member_id,
    receiving_member_id,
    amount_minor,
    created_by
  ) values (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    1000,
    '11111111-1111-1111-1111-111111111111'
  )$$,
  'P0001',
  'The receiving settlement member must be active in the settlement group',
  'settlement participants must belong to the same group'
);

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Payer total guard',
  1000,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  900
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  1000
);

select throws_ok(
  $$select public.finalize_expense('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3')$$,
  'P0001',
  'Expense payer amounts must equal the expense total',
  'payer totals must equal the expense total before finalization'
);

update public.expense_payers
set amount_minor = 1000
where expense_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3';

select lives_ok(
  $$select public.finalize_expense('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3')$$,
  'an expense posts after payer totals are corrected'
);

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Split total guard',
  1000,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  1000
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  900
);

select throws_ok(
  $$select public.finalize_expense('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4')$$,
  'P0001',
  'Expense split amounts must equal the expense total',
  'split totals must equal the expense total before finalization'
);

update public.expense_splits
set amount_minor = 1000
where expense_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4';

select lives_ok(
  $$select public.finalize_expense('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4')$$,
  'an expense posts after split totals are corrected'
);

reset role;
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);
set local role authenticated;

update public.group_members
set removed_at = now()
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select throws_ok(
  $$select public.transfer_group_ownership(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  )$$,
  'P0001',
  'Ownership successor must be an active registered group member',
  'a removed registered member cannot receive ownership'
);

select throws_ok(
  $$select public.transfer_group_ownership(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'
  )$$,
  'P0001',
  'Ownership successor must be an active registered group member',
  'a member from another group cannot receive ownership'
);

reset role;

select is_empty(
  $$select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name in (
        'expenses',
        'expense_payers',
        'expense_splits',
        'settlements'
      )
      and data_type in ('real', 'double precision')$$,
  'financial tables do not use floating-point money columns'
);

select ok(
  not pg_catalog.has_table_privilege(
    'authenticated'::name,
    'public.expense_events'::text,
    'update'::text
  ),
  'normal clients cannot edit expense audit events'
);

select throws_ok(
  $$update public.group_members
    set removed_at = now()
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'$$,
  'P0001',
  'A group must retain an active owner',
  'the final group owner cannot be removed without a replacement'
);

select * from finish();

rollback;
