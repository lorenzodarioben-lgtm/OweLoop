begin;

select plan(123);

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

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

insert into public.groups (id, name, currency_code)
values (
  '99999999-9999-9999-9999-999999999999',
  'Expense test group',
  'USD'
);

reset role;
insert into public.group_members (
  id,
  group_id,
  user_id,
  display_name,
  removed_at
) values (
  '99999999-9999-9999-9999-999999999901',
  '99999999-9999-9999-9999-999999999999',
  '22222222-2222-2222-2222-222222222222',
  'Expense member',
  null
), (
  '99999999-9999-9999-9999-999999999902',
  '99999999-9999-9999-9999-999999999999',
  null,
  'Expense guest',
  null
), (
  '99999999-9999-9999-9999-999999999903',
  '99999999-9999-9999-9999-999999999999',
  '55555555-5555-5555-5555-555555555555',
  'Expense successor',
  null
), (
  '99999999-9999-9999-9999-999999999904',
  '99999999-9999-9999-9999-999999999999',
  null,
  'Removed expense guest',
  now()
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    '  Dinner with everyone  ',
    1000,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array[
      '99999999-9999-9999-9999-999999999903'::uuid,
      '99999999-9999-9999-9999-999999999901'::uuid,
      '99999999-9999-9999-9999-999999999902'::uuid
    ]
  )$$,
  'an active member can create and post an equal expense atomically'
);

select is(
  (
    select status
    from public.expenses
    where description = 'Dinner with everyone'
  ),
  'posted'::public.expense_status,
  'the equal expense is posted before the function returns'
);

select is(
  (
    select description
    from public.expenses
    where description = 'Dinner with everyone'
  ),
  'Dinner with everyone'::text,
  'equal expense creation trims the description'
);

select is(
  (
    select sum(payer.amount_minor)::bigint
    from public.expense_payers as payer
    where payer.expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
  ),
  1000::bigint,
  'the equal expense payer total exactly matches the expense total'
);

select is(
  (
    select sum(split.amount_minor)::bigint
    from public.expense_splits as split
    where split.expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
  ),
  1000::bigint,
  'the equal expense split total exactly matches the expense total'
);

select is(
  (
    select amount_minor
    from public.expense_splits
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
      and group_member_id = '99999999-9999-9999-9999-999999999901'
  ),
  334::bigint,
  'the first member UUID receives the deterministic remainder unit'
);

select is(
  (
    select amount_minor
    from public.expense_splits
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
      and group_member_id = '99999999-9999-9999-9999-999999999902'
  ),
  333::bigint,
  'the second member UUID receives the base equal share'
);

select is(
  (
    select amount_minor
    from public.expense_splits
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
      and group_member_id = '99999999-9999-9999-9999-999999999903'
  ),
  333::bigint,
  'the third member UUID receives the base equal share'
);

select lives_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Solo expense',
    333,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'an equal expense permits one participant'
);

select lives_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Guest paid',
    500,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999902',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'an active guest can be recorded as the payer'
);

select lives_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Guest participated',
    500,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999902'::uuid]
  )$$,
  'an active guest can be recorded as a participant'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    '   ',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Expense description cannot be blank',
  'blank equal-expense descriptions are rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Zero total',
    0,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Expense total must be greater than zero',
  'zero equal-expense totals are rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Negative total',
    -1,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Expense total must be greater than zero',
  'negative equal-expense totals are rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'No participants',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array[]::uuid[]
  )$$,
  'P0001',
  'Select at least one active participant',
  'an equal expense requires at least one participant'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Duplicate participant',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array[
      '99999999-9999-9999-9999-999999999901'::uuid,
      '99999999-9999-9999-9999-999999999901'::uuid
    ]
  )$$,
  'P0001',
  'Participants cannot be selected more than once',
  'duplicate equal-expense participants are rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Cross-group payer',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Payer must be an active member of this group',
  'a cross-group payer is rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Cross-group participant',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array[
      '99999999-9999-9999-9999-999999999901'::uuid,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'::uuid
    ]
  )$$,
  'P0001',
  'Participants must be active members of this group',
  'a cross-group participant is rejected'
);

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Removed participant',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999904'::uuid]
  )$$,
  'P0001',
  'Participants must be active members of this group',
  'a removed participant is rejected'
);

insert into public.groups (id, name, currency_code)
values (
  '88888888-8888-8888-8888-888888888888',
  'Archived expense group',
  'USD'
);

update public.groups
set archived_at = now()
where id = '88888888-8888-8888-8888-888888888888';

select throws_ok(
  $$select public.create_equal_expense(
    '88888888-8888-8888-8888-888888888888',
    'Archived expense',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    (
      select id
      from public.group_members
      where group_id = '88888888-8888-8888-8888-888888888888'
        and user_id = '11111111-1111-1111-1111-111111111111'
    ),
    array[(
      select id
      from public.group_members
      where group_id = '88888888-8888-8888-8888-888888888888'
        and user_id = '11111111-1111-1111-1111-111111111111'
    )]
  )$$,
  'P0001',
  'Expenses cannot be added to an archived group',
  'an archived group rejects equal-expense creation'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Unauthenticated expense',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Authentication is required to create an expense',
  'unauthenticated callers cannot create equal expenses'
);

reset role;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
set local role authenticated;

select public.complete_profile('Outsider');

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Outsider expense',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['99999999-9999-9999-9999-999999999901'::uuid]
  )$$,
  'P0001',
  'Only an active group member can create an expense',
  'an unrelated user cannot create an equal expense'
);

reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select throws_ok(
  $$select public.create_equal_expense(
    '99999999-9999-9999-9999-999999999999',
    'Atomic validation failure',
    100,
    '2026-07-29T12:00:00Z'::timestamptz,
    '99999999-9999-9999-9999-999999999901',
    array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'::uuid]
  )$$,
  'P0001',
  'Participants must be active members of this group',
  'a failed equal-expense validation aborts the transaction'
);

select is(
  (
    select count(*)
    from public.expenses
    where description = 'Atomic validation failure'
  ),
  0::bigint,
  'a failed equal-expense validation persists no partial expense'
);

select lives_ok(
  $$update public.expense_payers
    set amount_minor = 999
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )$$,
  'posted payer writes are ignored by row-level access'
);

select is(
  (
    select amount_minor
    from public.expense_payers
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
  ),
  1000::bigint,
  'posted payer amounts remain immutable'
);

select lives_ok(
  $$update public.expense_splits
    set amount_minor = 999
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
      and group_member_id = '99999999-9999-9999-9999-999999999901'$$,
  'posted split writes are ignored by row-level access'
);

select is(
  (
    select amount_minor
    from public.expense_splits
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
      and group_member_id = '99999999-9999-9999-9999-999999999901'
  ),
  334::bigint,
  'posted split amounts remain immutable'
);

select is(
  (
    select count(*)
    from public.expense_events
    where expense_id = (
      select id from public.expenses where description = 'Dinner with everyone'
    )
  ),
  6::bigint,
  'equal-expense creation records the existing audit events'
);

reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

insert into public.groups (id, name, currency_code)
values (
  '77777777-7777-7777-7777-777777777777',
  'Balance test group',
  'USD'
);

reset role;
insert into public.group_members (
  id,
  group_id,
  user_id,
  display_name,
  removed_at
) values (
  '77777777-7777-7777-7777-777777777701',
  '77777777-7777-7777-7777-777777777777',
  '22222222-2222-2222-2222-222222222222',
  'Alex Member',
  null
), (
  '77777777-7777-7777-7777-777777777702',
  '77777777-7777-7777-7777-777777777777',
  null,
  'Guest Ledger',
  null
), (
  '77777777-7777-7777-7777-777777777703',
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  'Zero Member',
  null
), (
  '77777777-7777-7777-7777-777777777704',
  '77777777-7777-7777-7777-777777777777',
  null,
  'Removed Guest',
  null
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e01',
  '77777777-7777-7777-7777-777777777777',
  'Shared dinner',
  6000,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e01',
  '77777777-7777-7777-7777-777777777777',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  6000
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e01',
  '77777777-7777-7777-7777-777777777777',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  3000
), (
  '77777777-7777-7777-7777-777777777e01',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777701',
  3000
);

select public.finalize_expense('77777777-7777-7777-7777-777777777e01');

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e02',
  '77777777-7777-7777-7777-777777777777',
  'Alex paid for the guest',
  300,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e02',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777701',
  300
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e02',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777702',
  300
);

select public.finalize_expense('77777777-7777-7777-7777-777777777e02');

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e03',
  '77777777-7777-7777-7777-777777777777',
  'Guest paid the snacks',
  1000,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e03',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777702',
  1000
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e03',
  '77777777-7777-7777-7777-777777777777',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  500
), (
  '77777777-7777-7777-7777-777777777e03',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777702',
  500
);

select public.finalize_expense('77777777-7777-7777-7777-777777777e03');

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e04',
  '77777777-7777-7777-7777-777777777777',
  'Removed guest share',
  200,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e04',
  '77777777-7777-7777-7777-777777777777',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  200
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e04',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777704',
  200
);

select public.finalize_expense('77777777-7777-7777-7777-777777777e04');

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e05',
  '77777777-7777-7777-7777-777777777777',
  'Voided balance expense',
  400,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.expense_payers (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e05',
  '77777777-7777-7777-7777-777777777777',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  400
);

insert into public.expense_splits (expense_id, group_id, group_member_id, amount_minor)
values (
  '77777777-7777-7777-7777-777777777e05',
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777701',
  400
);

select public.finalize_expense('77777777-7777-7777-7777-777777777e05');
select public.void_expense('77777777-7777-7777-7777-777777777e05');

insert into public.expenses (
  id,
  group_id,
  description,
  total_amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777e06',
  '77777777-7777-7777-7777-777777777777',
  'Unfinished balance draft',
  999,
  '11111111-1111-1111-1111-111111111111'
);

insert into public.settlements (
  group_id,
  paying_member_id,
  receiving_member_id,
  amount_minor,
  created_by
) values (
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777701',
  (
    select id
    from public.group_members
    where group_id = '77777777-7777-7777-7777-777777777777'
      and user_id = '11111111-1111-1111-1111-111111111111'
  ),
  500,
  '11111111-1111-1111-1111-111111111111'
), (
  '77777777-7777-7777-7777-777777777777',
  '77777777-7777-7777-7777-777777777702',
  '77777777-7777-7777-7777-777777777701',
  777,
  '11111111-1111-1111-1111-111111111111'
);

update public.settlements
set voided_at = now()
where group_id = '77777777-7777-7777-7777-777777777777'
  and amount_minor = 777;

update public.group_members
set removed_at = now()
where id = '77777777-7777-7777-7777-777777777704';

select lives_ok(
  $$select * from public.get_group_balances('77777777-7777-7777-7777-777777777777')$$,
  'an active registered member can load balances for their group'
);

select is(
  (select count(*) from public.get_group_balances('77777777-7777-7777-7777-777777777777')),
  5::bigint,
  'active members and a removed member with history are returned'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where is_current_user
  ),
  2200::bigint,
  'a payer who also participates has the exact positive USD balance'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777701'
  ),
  (-2200)::bigint,
  'a payer who is not a participant aggregates to the exact negative balance'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777702'
  ),
  200::bigint,
  'a guest payer and participant has the correct balance'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777704'
  ),
  (-200)::bigint,
  'a removed member with historical debt remains visible'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777703'
  ),
  0::bigint,
  'an active zero-balance member remains visible'
);

select is(
  (select sum(net_balance_minor)::bigint from public.get_group_balances('77777777-7777-7777-7777-777777777777')),
  0::bigint,
  'valid USD group balances sum exactly to zero'
);

select is(
  array(select display_name from public.get_group_balances('77777777-7777-7777-7777-777777777777')),
  array['Owner A', 'Alex Member', 'Guest Ledger', 'Zero Member', 'Removed Guest']::text[],
  'balances order the current member, active members, then removed members deterministically'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where is_current_user
  ),
  2200::bigint,
  'draft expenses do not contribute to balances'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777701'
  ),
  (-2200)::bigint,
  'voided expenses do not contribute to balances'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777701'
  ),
  (-2200)::bigint,
  'a non-voided settlement increases the paying member balance by its amount'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where is_current_user
  ),
  2200::bigint,
  'a non-voided settlement decreases the receiving member balance by its amount'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '77777777-7777-7777-7777-777777777702'
  ),
  200::bigint,
  'a voided settlement does not contribute to balances'
);

insert into public.groups (id, name, currency_code)
values (
  '55555555-5555-5555-5555-555555555556',
  'Zero balance group',
  'USD'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  '55555555-5555-5555-5555-555555555501',
  '55555555-5555-5555-5555-555555555556',
  null,
  'Zero guest'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select is(
  (select count(*) from public.get_group_balances('55555555-5555-5555-5555-555555555556')),
  2::bigint,
  'a group with no expenses returns all active members'
);

select is(
  (select sum(net_balance_minor)::bigint from public.get_group_balances('55555555-5555-5555-5555-555555555556')),
  0::bigint,
  'a group with no expenses returns exact zero balances'
);

insert into public.groups (id, name, currency_code)
values (
  '66666666-6666-6666-6666-666666666666',
  'JPY balance group',
  'JPY'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  '66666666-6666-6666-6666-666666666601',
  '66666666-6666-6666-6666-666666666666',
  null,
  'JPY one'
), (
  '66666666-6666-6666-6666-666666666602',
  '66666666-6666-6666-6666-666666666666',
  null,
  'JPY two'
), (
  '66666666-6666-6666-6666-666666666603',
  '66666666-6666-6666-6666-666666666666',
  null,
  'JPY three'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$select public.create_equal_expense(
    '66666666-6666-6666-6666-666666666666',
    'JPY remainder',
    1000,
    '2026-07-31T12:00:00Z'::timestamptz,
    (
      select id
      from public.group_members
      where group_id = '66666666-6666-6666-6666-666666666666'
        and user_id = '11111111-1111-1111-1111-111111111111'
    ),
    array[
      '66666666-6666-6666-6666-666666666601'::uuid,
      '66666666-6666-6666-6666-666666666602'::uuid,
      '66666666-6666-6666-6666-666666666603'::uuid
    ]
  )$$,
  'a JPY equal expense records exact integer remainder balances'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('66666666-6666-6666-6666-666666666666')
    where group_member_id = '66666666-6666-6666-6666-666666666601'
  ),
  (-334)::bigint,
  'the deterministic JPY remainder split contributes exact minor units'
);

select is(
  (
    select net_balance_minor
    from public.get_group_balances('66666666-6666-6666-6666-666666666666')
    where is_current_user
  ),
  1000::bigint,
  'JPY balance totals remain bigint integer units'
);

select is(
  (select sum(net_balance_minor)::bigint from public.get_group_balances('66666666-6666-6666-6666-666666666666')),
  0::bigint,
  'JPY group balances sum exactly to zero'
);

insert into public.groups (id, name, currency_code)
values (
  '44444444-4444-4444-4444-444444444446',
  'Other balance group',
  'USD'
);

reset role;
insert into public.group_members (id, group_id, user_id, display_name)
values (
  '44444444-4444-4444-4444-444444444401',
  '44444444-4444-4444-4444-444444444446',
  null,
  'Other group guest'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select is_empty(
  $$select 1
    from public.get_group_balances('77777777-7777-7777-7777-777777777777')
    where group_member_id = '44444444-4444-4444-4444-444444444401'$$,
  'cross-group members cannot leak into a group balance result'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;

select throws_ok(
  $$select * from public.get_group_balances('77777777-7777-7777-7777-777777777777')$$,
  'P0001',
  'Authentication is required to load group balances',
  'unauthenticated callers cannot load balances'
);

reset role;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
set local role authenticated;

select throws_ok(
  $$select * from public.get_group_balances('77777777-7777-7777-7777-777777777777')$$,
  'P0001',
  'Group is unavailable',
  'an unrelated authenticated user cannot access group balances'
);

reset role;

select ok(
  not pg_catalog.has_function_privilege(
    'anon'::name,
    'public.get_group_balances(uuid)'::regprocedure,
    'execute'::text
  ),
  'unauthenticated roles cannot execute the balance operation'
);

select is(
  pg_catalog.to_regprocedure('public.get_group_balances(uuid,uuid)'),
  null::regprocedure,
  'the balance operation never accepts a caller user or member id'
);

select is(
  pg_catalog.to_regclass('public.group_balances'),
  null::regclass,
  'no mutable group-balance table exists'
);

select is_empty(
  $$select 1
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'net_balance_minor'$$,
  'no mutable net-balance column exists'
);

set local session_replication_role = replica;
update public.expense_payers
set amount_minor = 5999
where expense_id = '77777777-7777-7777-7777-777777777e01';
set local session_replication_role = origin;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select throws_ok(
  $$select * from public.get_group_balances('77777777-7777-7777-7777-777777777777')$$,
  'P0001',
  'Financial records are inconsistent',
  'the balance operation fails safely when posted financial records are inconsistent'
);

reset role;
set local session_replication_role = replica;
update public.expense_payers
set amount_minor = 6000
where expense_id = '77777777-7777-7777-7777-777777777e01';
set local session_replication_role = origin;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

select is(
  (select sum(net_balance_minor)::bigint from public.get_group_balances('77777777-7777-7777-7777-777777777777')),
  0::bigint,
  'balance loading recovers after consistent financial records are restored'
);

select * from finish();

rollback;
