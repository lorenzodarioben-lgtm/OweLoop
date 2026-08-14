begin;

select plan(23);

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

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_expense(uuid,text,bigint,timestamp with time zone,jsonb,jsonb,uuid)'::regprocedure,
    'execute'
  ),
  'authenticated callers can use the idempotent expense RPC'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.create_expense_unchecked_internal(uuid,text,bigint,timestamp with time zone,jsonb,jsonb)'::regprocedure,
    'execute'
  ),
  'authenticated callers cannot bypass idempotent expense recording'
);

select lives_ok(
  $$select public.create_expense(
    '88888888-8888-8888-8888-888888888800',
    'Retry-safe dinner',
    1000,
    '2026-08-15T12:00:00Z'::timestamptz,
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
      'amount_minor', 1000
    )),
    jsonb_build_array(jsonb_build_object(
      'member_id', '88888888-8888-8888-8888-888888888802',
      'amount_minor', 1000
    )),
    '88888888-8888-4888-8888-888888888801'
  )$$,
  'an expense can be created through the idempotent RPC'
);

select is(
  (select (public.create_expense(
    '88888888-8888-8888-8888-888888888800',
    'Retry-safe dinner',
    1000,
    '2026-08-15T12:00:00Z'::timestamptz,
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
      'amount_minor', 1000
    )),
    jsonb_build_array(jsonb_build_object(
      'member_id', '88888888-8888-8888-8888-888888888802',
      'amount_minor', 1000
    )),
    '88888888-8888-4888-8888-888888888801'
  )).id),
  (select id from public.expenses where description = 'Retry-safe dinner'),
  'an identical expense replay returns the original financial record'
);

select is(
  (select count(*) from public.expenses where description = 'Retry-safe dinner'),
  1::bigint,
  'an identical expense replay creates no duplicate financial record'
);

select throws_ok(
  $$select public.create_expense(
    '88888888-8888-8888-8888-888888888800',
    'Conflicting retry',
    900,
    '2026-08-15T12:00:00Z'::timestamptz,
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
      'amount_minor', 900
    )),
    jsonb_build_array(jsonb_build_object(
      'member_id', '88888888-8888-8888-8888-888888888802',
      'amount_minor', 900
    )),
    '88888888-8888-4888-8888-888888888801'
  )$$,
  'P0001',
  'This operation ID was already used for a different financial request',
  'a conflicting expense replay is rejected safely'
);

select throws_ok(
  $$select public.record_settlement(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802',
    (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
    1000,
    now() + interval '1 year',
    '88888888-8888-4888-8888-888888888803'
  )$$,
  'P0001',
  'Settlement date cannot be in the future',
  'future settlement timestamps are rejected at the RPC boundary'
);

select throws_ok(
  $$select public.remove_group_member(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802'
  )$$,
  'P0001',
  'A member must settle their balance before removal',
  'an unsettled guest cannot be removed from a group'
);

select lives_ok(
  $$select public.record_settlement(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802',
    (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
    1000,
    now(),
    '88888888-8888-4888-8888-888888888804'
  )$$,
  'an exact settlement can resolve the guest balance'
);

select is(
  (select (public.record_settlement(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802',
    (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
    1000,
    now(),
    '88888888-8888-4888-8888-888888888804'
  )).id),
  (select id from public.settlements where group_id = '88888888-8888-8888-8888-888888888800'),
  'an identical settlement replay returns the original financial record'
);

select is(
  (select count(*) from public.settlements where group_id = '88888888-8888-8888-8888-888888888800'),
  1::bigint,
  'an identical settlement replay creates no duplicate record'
);

select throws_ok(
  $$select public.record_settlement(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802',
    (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
    999,
    now(),
    '88888888-8888-4888-8888-888888888804'
  )$$,
  'P0001',
  'This operation ID was already used for a different financial request',
  'a conflicting settlement replay is rejected safely'
);

select is(
  (select net_balance_minor from public.get_group_balances('88888888-8888-8888-8888-888888888800') where group_member_id = '88888888-8888-8888-8888-888888888802'),
  0::bigint,
  'the guest balance is exactly zero after settlement'
);

select lives_ok(
  $$select public.remove_group_member(
    '88888888-8888-8888-8888-888888888800',
    '88888888-8888-8888-8888-888888888802'
  )$$,
  'a settled guest can be removed without deleting history'
);

select ok(
  (select removed_at is not null from public.group_members where id = '88888888-8888-8888-8888-888888888802'),
  'the settled guest retains the original durable group-member ID'
);

select lives_ok(
  $$select public.archive_group('88888888-8888-8888-8888-888888888800')$$,
  'an owner can archive the settled group'
);

select lives_ok(
  $$select * from public.get_group_balances('88888888-8888-8888-8888-888888888800')$$,
  'an archived group remains readable for financial history'
);

select throws_ok(
  $$select public.create_expense(
    '88888888-8888-8888-8888-888888888800',
    'Archived write',
    100,
    now(),
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
      'amount_minor', 100
    )),
    jsonb_build_array(jsonb_build_object(
      'member_id', (select id from public.group_members where group_id = '88888888-8888-8888-8888-888888888800' and user_id = auth.uid()),
      'amount_minor', 100
    )),
    '88888888-8888-4888-8888-888888888805'
  )$$,
  'P0001',
  'Expenses cannot be added to an archived group',
  'an archived group rejects new financial entries'
);

reset role;

select ok(
  not has_table_privilege('authenticated', 'public.financial_operations', 'select'),
  'financial operation rows are not directly readable by ordinary clients'
);

select ok(
  not has_table_privilege('authenticated', 'public.financial_operations', 'insert'),
  'financial operation rows are only written by guarded RPCs'
);

select ok(
  not has_table_privilege('authenticated', 'public.expenses', 'insert'),
  'ordinary clients cannot bypass expense idempotency with direct inserts'
);

select * from finish();

rollback;
