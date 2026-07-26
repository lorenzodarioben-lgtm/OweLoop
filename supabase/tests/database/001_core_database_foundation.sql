begin;

select plan(17);

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
  );

select is(
  (select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Member'::text,
  'new authenticated users receive a safe fallback profile name'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
set local role authenticated;

insert into public.groups (id, name, currency_code, created_by)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Group A',
  'USD',
  '11111111-1111-1111-1111-111111111111'
);

insert into public.group_members (id, group_id, user_id, display_name)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '22222222-2222-2222-2222-222222222222',
  'Member A'
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

insert into public.group_members (id, group_id, display_name)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Guest B'
);

reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
set local role authenticated;

select is(
  (select count(*) from public.groups where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'an active member can read their group'
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

reset role;
select hasnt_table_privilege(
  'anon',
  'public.groups',
  'select',
  'a guest record grants no unauthenticated group access'
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

select hasnt_table_privilege(
  'authenticated',
  'public.expense_events',
  'update',
  'normal clients cannot edit expense audit events'
);

select throws_ok(
  $$update public.group_members
    set removed_at = now()
    where group_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '11111111-1111-1111-1111-111111111111'$$,
  'P0001',
  'A group must retain an active owner',
  'the final group owner cannot be removed without a replacement'
);

select * from finish();

rollback;
