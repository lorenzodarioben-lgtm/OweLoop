begin;
select no_plan();
insert into auth.users(id,email) values
('e1111111-1111-4111-8111-111111111101','template-owner@example.test'),
('e1111111-1111-4111-8111-111111111102','template-member@example.test'),
('e1111111-1111-4111-8111-111111111103','template-successor@example.test');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111102',true);select public.complete_profile('Template member');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111103',true);select public.complete_profile('Template successor');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111101',true);select public.complete_profile('Template owner');
insert into public.groups(id,name,currency_code) values('e1111111-1111-4111-8111-111111111100','Templates','AUD');
insert into public.group_members(id,group_id,user_id,display_name) values
('e1111111-1111-4111-8111-111111111112','e1111111-1111-4111-8111-111111111100','e1111111-1111-4111-8111-111111111102','Template member'),
('e1111111-1111-4111-8111-111111111113','e1111111-1111-4111-8111-111111111100','e1111111-1111-4111-8111-111111111103','Successor');
set local role authenticated;
select lives_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Rent','{"description":"Monthly rent","amount":"10.00","split_method":"equal","category_key":"household"}')$$,'group template saves without posting');
select is((select count(*) from public.expenses),0::bigint,'template is not a financial transaction');
select lives_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Rent','{"description":"Monthly rent","amount":"10.00","split_method":"equal","category_key":"household"}')$$,'lost save response can safely replay unchanged name and configuration');
select is((select count(*) from public.expense_templates),1::bigint,'retry does not duplicate templates');
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Rent','{"description":"Different"}')$$,'P0001','A template with this name already exists','duplicate names cannot overwrite silently');
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Unsafe','{"description":"Unsafe","operation_id":"hidden"}')$$,'P0001','Unsupported template field','operation identities cannot enter templates');
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Foreign','{"description":"Foreign","single_payer":"e1111111-1111-4111-8111-111111111199"}')$$,'P0001','Template payer must be active in this group','foreign member reference rejected');
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Large','{"description":"Large","amount":"9223372036854775807"}')$$,'P0001','Template amount exceeds supported range','template amount scaling is checked');
select throws_ok($$insert into public.expense_templates(group_id,name,payload) values('e1111111-1111-4111-8111-111111111100','Bypass','{}')$$,'42501',null,'direct template mutations denied');
select lives_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Rent updated','{"description":"Reviewed rent"}',id,updated_at) from public.expense_templates$$,'creator updates with optimistic version');
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Stale','{"description":"Stale"}',id,'2000-01-01') from public.expense_templates$$,'P0001','Template changed; reload before editing','stale edits cannot overwrite');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111102',true);
select is(jsonb_array_length(public.get_expense_templates('e1111111-1111-4111-8111-111111111100')),1,'member reads shared configuration');
select is(public.get_expense_templates('e1111111-1111-4111-8111-111111111100')->0->>'can_edit','false','ordinary member is not given edit controls');
select throws_ok($$select public.delete_expense_template(id,updated_at) from public.expense_templates$$,'P0001','Template is unavailable','ordinary member cannot delete another creator template');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111101',true);
select public.archive_group('e1111111-1111-4111-8111-111111111100');
select throws_ok($$select public.delete_expense_template(id,updated_at) from public.expense_templates$$,'P0001','Archived group templates are read only','archived templates cannot be deleted');
reset role;
select lives_ok($$delete from auth.users where id='e1111111-1111-4111-8111-111111111101'$$,'deleting settled archived creator retains shared templates');
select is((select count(*) from public.expense_templates where created_by is null),1::bigint,'template creator is deidentified');
set local role service_role;
select public.recover_ownerless_archived_group('e1111111-1111-4111-8111-111111111100','e1111111-1111-4111-8111-111111111113','Reviewed template lifecycle recovery');
reset role;
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111102',true);
set local role authenticated;
select throws_ok($$select public.save_expense_template('e1111111-1111-4111-8111-111111111100','Hijack','{"description":"Hijack"}',id,updated_at) from public.expense_templates$$,'P0001','Template is unavailable','NULL creator does not confer ownership');
select throws_ok($$select public.delete_expense_template(id,updated_at) from public.expense_templates$$,'P0001','Template is unavailable','ordinary member cannot delete orphaned configuration');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111103',true);
select lives_ok($$select public.delete_expense_template(id,updated_at) from public.expense_templates$$,'recovered owner may manage orphaned templates');
select is(jsonb_array_length(public.get_expense_templates('e1111111-1111-4111-8111-111111111100')),0,'deletion removes only the configuration');
select is((select count(*) from public.expenses),0::bigint,'template lifecycle never posted expenses');
select set_config('request.jwt.claim.sub','e1111111-1111-4111-8111-111111111199',true);
select throws_ok($$select public.get_expense_templates('e1111111-1111-4111-8111-111111111100')$$,'P0001','Group is unavailable','outsider cannot read template JSON');
reset role;
select * from finish();
rollback;
