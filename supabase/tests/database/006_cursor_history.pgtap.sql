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

do $$
declare v_owner uuid; i integer;
begin
  select id into v_owner from public.group_members where user_id=auth.uid() and group_id='88888888-8888-8888-8888-888888888800';
  for i in 1..1105 loop
    perform public.create_expense('88888888-8888-8888-8888-888888888800','History '||i,1,
      '2026-01-01T12:00:00Z'::timestamptz,
      jsonb_build_array(jsonb_build_object('member_id',v_owner,'amount_minor',1)),
      jsonb_build_array(jsonb_build_object('member_id',v_owner,'amount_minor',1)),gen_random_uuid());
  end loop;
end;
$$;
select is((select count(*) from public.get_expense_page('88888888-8888-8888-8888-888888888800',100)),101::bigint,'page includes exactly one lookahead row');
create temporary table seen_expense_ids(id uuid primary key);
do $$
declare v_rows jsonb[]; v_last jsonb; v_occurred timestamptz; v_created timestamptz; v_id uuid; v_row jsonb;
begin
  loop
    select array_agg(row_value) into v_rows from public.get_expense_page('88888888-8888-8888-8888-888888888800',100,v_occurred,v_created,v_id) row_value;
    exit when v_rows is null;
    foreach v_row in array v_rows[1:100] loop
      insert into seen_expense_ids values((v_row->>'id')::uuid);
      v_last:=v_row;
    end loop;
    exit when array_length(v_rows,1)<=100;
    v_occurred:=(v_last->>'occurred_at')::timestamptz;
    v_created:=(v_last->>'created_at')::timestamptz;
    v_id:=(v_last->>'id')::uuid;
  end loop;
end;
$$;
select is((select count(*) from seen_expense_ids),1105::bigint,'all 1105 same-date records are reachable with no duplicate cursor rows');
select is((select count(*) from public.get_expense_page('88888888-8888-8888-8888-888888888800',100,null,null,null,'History 1105')),1::bigint,'search is evaluated before pagination');
select throws_ok($$select public.get_expense_page('88888888-8888-8888-8888-888888888800',1001)$$,'P0001','Invalid history request','oversized pages are rejected explicitly');
select throws_ok($$select public.get_expense_page('88888888-8888-8888-8888-888888888800',10,now())$$,'P0001','Invalid history request','partial cursors are rejected');
select is((select sum(net_balance_minor)::bigint from public.get_group_balances('88888888-8888-8888-8888-888888888800')),0::bigint,'large history reconciles exactly');
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
select throws_ok($$select public.get_expense_page('88888888-8888-8888-8888-888888888800')$$,'42501',null,'anonymous history RPC is denied');
reset role;
insert into public.group_members(group_id,display_name)
select '88888888-8888-8888-8888-888888888800','Synthetic member '||i from generate_series(1,1105) i;
select set_config('request.jwt.claim.sub','88888888-8888-8888-8888-888888888881',true);
set local role authenticated;
select is(jsonb_array_length(public.get_group_member_snapshot('88888888-8888-8888-8888-888888888800')),1107,'member snapshot includes more than the API row limit');
select set_config('test.balance_started',clock_timestamp()::text,true);
select is(jsonb_array_length(public.get_group_balance_snapshot('88888888-8888-8888-8888-888888888800')),1107,'complete zero-sum balance snapshot includes all active members');
select diag('Synthetic 1105-expense / 1107-member balance snapshot: '||round(extract(epoch from (clock_timestamp()-current_setting('test.balance_started')::timestamptz))*1000,3)||' ms');
select * from finish();
rollback;
