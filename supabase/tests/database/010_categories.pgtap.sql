begin;
select no_plan();
insert into auth.users(id,email) values('b1111111-1111-4111-8111-111111111101','category-owner@example.test');
select set_config('request.jwt.claim.sub','b1111111-1111-4111-8111-111111111101',true);
select public.complete_profile('Category owner');
insert into public.groups(id,name,currency_code) values('b1111111-1111-4111-8111-111111111100','Categories','AUD');
create function pg_temp.category_expense(category text,operation uuid) returns public.expenses language sql as $$
select public.create_categorized_expense('b1111111-1111-4111-8111-111111111100','Category dinner',101,'2026-10-01',
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='b1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',101)),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='b1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',101)),operation,category);
$$;
set local role authenticated;
select is((pg_temp.category_expense('food','b1111111-1111-4111-8111-111111111120')).category_key,'food','category is written atomically before posting');
select is((pg_temp.category_expense('food','b1111111-1111-4111-8111-111111111120')).category_key,'food','same category replay retains original result');
select throws_ok($$select pg_temp.category_expense('travel','b1111111-1111-4111-8111-111111111120')$$,'P0001','This operation ID was already used for a different financial request','same operation cannot silently change category');
select throws_ok($$select pg_temp.category_expense('invented',gen_random_uuid())$$,'23514',null,'database rejects unknown category keys');
select is((select count(*) from public.expenses),1::bigint,'invalid category leaves no partial expense');
select is((select count(*) from public.get_categorized_expense_page('b1111111-1111-4111-8111-111111111100',p_category_key=>'food')),1::bigint,'category filtering runs on server');
select is((select count(*) from public.get_categorized_expense_page('b1111111-1111-4111-8111-111111111100',p_category_key=>'travel')),0::bigint,'other categories are excluded');
select is((pg_temp.category_expense(null,gen_random_uuid())).category_key,null::text,'uncategorized records remain valid');
select is((select count(*) from public.get_categorized_expense_page('b1111111-1111-4111-8111-111111111100',p_category_key=>'')),1::bigint,'uncategorized-only filter is explicit');
select throws_ok($$update public.expenses set category_key='travel'$$,'42501',null,'mobile cannot bypass category immutability');
select public.archive_group('b1111111-1111-4111-8111-111111111100');
select is((select count(*) from public.get_categorized_expense_page('b1111111-1111-4111-8111-111111111100',p_category_key=>'food')),1::bigint,'archived categories remain readable');
select throws_ok($$select pg_temp.category_expense('food',gen_random_uuid())$$,'P0001','Expenses cannot be added to an archived group','category API respects archive guard');
reset role;
select throws_ok($$update public.expenses set category_key='travel' where category_key='food'$$,'P0001','Expense category is immutable; void and duplicate to correct it','trigger preserves posted category even through privileged writes');
select set_config('request.jwt.claim.sub','b1111111-1111-4111-8111-111111111199',true);
set local role authenticated;
select throws_ok($$select public.get_categorized_expense_page('b1111111-1111-4111-8111-111111111100')$$,'P0001','Group is unavailable','category filters do not bypass membership');
select throws_ok($$select app_private.create_categorized_allocations(null,null,1,now(),'[]','[]','food')$$,'42501',null,'unchecked category helper is private');
reset role;
select * from finish();
rollback;
