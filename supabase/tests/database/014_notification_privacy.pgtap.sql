begin;
select no_plan();
insert into auth.users(id,email) values
('f1111111-1111-4111-8111-111111111101','notice-owner@example.test'),
('f1111111-1111-4111-8111-111111111102','notice-member@example.test'),
('f1111111-1111-4111-8111-111111111103','notice-invitee@example.test');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111102',true);select public.complete_profile('Notice member');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111103',true);select public.complete_profile('Notice invitee');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111101',true);select public.complete_profile('Notice owner');
insert into public.groups(id,name,currency_code) values('f1111111-1111-4111-8111-111111111100','Private activity','AUD');
insert into public.group_members(id,group_id,user_id,display_name) values('f1111111-1111-4111-8111-111111111112','f1111111-1111-4111-8111-111111111100','f1111111-1111-4111-8111-111111111102','Member');
select public.create_expense('f1111111-1111-4111-8111-111111111100','Private notice',100,now(),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='f1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',100)),
jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where group_id='f1111111-1111-4111-8111-111111111100' and user_id=auth.uid()),'amount_minor',100)),gen_random_uuid());
set local role authenticated;
select is((select count(*) from public.get_notification_page()),1::bigint,'posting creates one derived notification, not per-allocation noise');
select public.mark_notification_read(row->>'notification_key') from public.get_notification_page() row;
select public.mark_notification_read(row->>'notification_key') from public.get_notification_page() row;
select is((select count(*) from public.get_notification_page(p_unread_only=>true)),0::bigint,'repeated marking is idempotent');
select is(jsonb_array_length(public.export_personal_data()->'notification_read_state'),1,'personal export contains caller read state');
select throws_ok($$insert into public.notification_reads values(auth.uid(),'invented',now())$$,'42501',null,'client cannot fabricate read rows');
select throws_ok($$select app_private.notification_rows('f1111111-1111-4111-8111-111111111102')$$,'42501',null,'private projection cannot inspect another account');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111102',true);
select is((select count(*) from public.get_notification_page(p_unread_only=>true)),1::bigint,'another member has independent read status');
select public.mark_notification_read(row->>'notification_key') from public.get_notification_page() row;
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111103',true);
select is((select count(*) from public.get_notification_page()),0::bigint,'outsider receives no financial activity');
select throws_ok($$select public.mark_notification_read((select 'expense:'||id from public.expense_events limit 1))$$,'P0001','Notification is unavailable','outsider cannot mark inaccessible activity');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111101',true);
select public.create_group_invitation('f1111111-1111-4111-8111-111111111100','notice-invitee@example.test');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111103',true);
select is((select row->>'kind' from public.get_notification_page() row),'invitation','recipient sees their invitation without group financial activity');
select public.accept_group_invitation(invitation_id) from public.get_pending_group_invitations();
select is((select count(*) from public.get_notification_page()),1::bigint,'accepted invitation disappears while authorized history becomes readable');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111101',true);
select public.remove_group_member('f1111111-1111-4111-8111-111111111100','f1111111-1111-4111-8111-111111111112');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111102',true);
select is((select count(*) from public.get_notification_page()),0::bigint,'removed member immediately loses notification details');
reset role;
select lives_ok($$delete from auth.users where id='f1111111-1111-4111-8111-111111111102'$$,'settled removed account deletion succeeds');
select is((select count(*) from public.notification_reads where user_id='f1111111-1111-4111-8111-111111111102'),0::bigint,'account deletion removes private read state');
select set_config('request.jwt.claim.sub','f1111111-1111-4111-8111-111111111101',true);
do $$begin for i in 1..12 loop perform public.archive_group('f1111111-1111-4111-8111-111111111100');perform public.reopen_group('f1111111-1111-4111-8111-111111111100');end loop;end$$;
create function pg_temp.walk_notifications() returns text[] language plpgsql as $$
declare seen text[]:='{}'; page jsonb[]; cursor_row jsonb;
begin
  loop
    select array_agg(row) into page from public.get_notification_page(5,(cursor_row->>'occurred_at')::timestamptz,cursor_row->>'notification_key') row;
    if page is null then exit;end if;
    for i in 1..least(5,array_length(page,1)) loop cursor_row:=page[i];seen:=array_append(seen,cursor_row->>'notification_key');end loop;
    if array_length(page,1)<=5 then exit;end if;
    if cardinality(seen)>100 then raise exception 'Notification cursor did not progress';end if;
  end loop;return seen;
end;
$$;
set local role authenticated;
select is(cardinality(pg_temp.walk_notifications()),25,'tied-timestamp notification traversal is complete');
select is((select count(distinct key) from unnest(pg_temp.walk_notifications()) key),25::bigint,'notification keys prevent duplicate pages');
select throws_ok($$select public.get_notification_page(p_before_at=>now())$$,'P0001','Invalid notification request','partial cursor is rejected');
reset role;
set local role anon;
select throws_ok($$select public.get_notification_page()$$,'42501',null,'anonymous cannot read the inbox');
reset role;
select * from finish();
rollback;
