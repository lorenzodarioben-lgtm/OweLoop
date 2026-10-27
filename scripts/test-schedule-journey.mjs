import {randomUUID} from 'node:crypto';

// Called only by the existing loopback-guarded real Auth/PostgREST suite.
export async function scheduleJourney({a,b,c,rpc,request,check,unwrap}) {
  const group=unwrap((await rpc(a,'create_group',{p_name:'Disposable schedule ledger',p_currency_code:'AUD'})).data);
  await rpc(a,'create_group_invitation',{p_group_id:group.id,p_recipient_email:b.email});
  const invite=(await rpc(b,'get_pending_group_invitations',{})).data.find(x=>x.group_id===group.id);
  await rpc(b,'accept_group_invitation',{p_invitation_id:invite.invitation_id});
  const owner=(await rpc(a,'get_group_member_snapshot',{p_group_id:group.id})).data.find(x=>x.user_id===a.id);
  const template=unwrap((await rpc(a,'save_expense_template',{p_group_id:group.id,p_name:'Pinned scheduled draft',p_payload:{description:'Review scheduled amount',amount:'10.00',split_method:'equal',single_payer:owner.id,participant_ids:[owner.id]}})).data);
  let schedule=unwrap((await rpc(a,'create_expense_schedule',{p_template_id:template.id,p_name:'Daily review',p_cadence:'daily',p_anchor_date:'2000-01-01',p_timezone:'UTC'})).data);
  const snapshot=()=>rpc(a,'get_expense_schedule_page',{p_group_id:group.id});
  const [one,two]=await Promise.all([snapshot(),snapshot()]);
  check(one.data.occurrences.map(x=>x.id).join()===two.data.occurrences.map(x=>x.id).join(),'Concurrent group opens discover identical proposal identities.');
  check(one.data.occurrences.length===51,'Schedule API returns bounded keyset lookahead.');
  check((await request(`/rest/v1/expenses?group_id=eq.${group.id}`,{user:a,method:'GET'})).data.length===0,'Schedule create and discovery write zero financial rows.');
  await rpc(a,'save_expense_template',{p_group_id:group.id,p_template_id:template.id,p_expected_updated_at:template.updated_at,p_name:template.name,p_payload:{description:'Edited live template'}});
  check((await snapshot()).data.occurrences[0].payload.description==='Review scheduled amount','Pinned occurrence survives template edit.');
  const occurrence=one.data.occurrences[0],older=one.data.occurrences[1];
  const configuration={p_schedule_id:schedule.id,p_expected_revision:schedule.revision,p_name:schedule.name,p_cadence:schedule.cadence,p_anchor_date:schedule.anchor_date,p_timezone:schedule.timezone,p_enabled:false};
  schedule=unwrap((await rpc(a,'update_expense_schedule',configuration)).data);
  await rpc(a,'update_expense_schedule',configuration,[400]);
  check((await snapshot()).data.occurrences.every(x=>!x.can_review),'Paused schedule cannot be reviewed.');
  const payload={p_occurrence_id:occurrence.id,p_group_id:group.id,p_description:'Explicit scheduled post',p_total_amount_minor:1000,p_occurred_at:`${occurrence.due_date}T12:00:00Z`,p_payers:[{member_id:owner.id,amount_minor:1000}],p_splits:[{member_id:owner.id,amount_minor:1000}],p_operation_id:randomUUID(),p_category_key:null};
  await rpc(a,'post_scheduled_expense',payload,[400]);
  schedule=unwrap((await rpc(a,'update_expense_schedule',{...configuration,p_expected_revision:schedule.revision,p_enabled:true})).data);
  await rpc(b,'update_expense_schedule',{...configuration,p_expected_revision:schedule.revision},[400]);
  await rpc(c,'get_expense_schedule_page',{p_group_id:group.id},[400]);
  await request(`/rest/v1/expense_occurrences?id=eq.${occurrence.id}`,{user:c,method:'PATCH',body:{state:'completed'},allowed:[403]});
  // Treat the first real response as lost, then replay concurrent reviewers.
  const committed=unwrap((await rpc(a,'post_scheduled_expense',payload)).data);
  const replays=await Promise.all([rpc(a,'post_scheduled_expense',payload),rpc(b,'post_scheduled_expense',{...payload,p_operation_id:randomUUID()})]);
  check(replays.every(x=>unwrap(x.data).id===committed.id),'Lost response and different-account replay return one authoritative expense.');
  check((await request(`/rest/v1/expenses?group_id=eq.${group.id}`,{user:a,method:'GET'})).data.length===1,'Only one explicit scheduled expense exists.');
  await rpc(a,'post_scheduled_expense',{...payload,p_description:'Changed review'},[400]);
  check((await rpc(a,'get_financial_operation',{p_operation_id:payload.p_operation_id})).data[0].expense_id===committed.id,'Ordinary caller-only pending recovery sees scheduled posting.');
  await Promise.all([rpc(a,'skip_expense_occurrence',{p_occurrence_id:older.id}),rpc(b,'skip_expense_occurrence',{p_occurrence_id:older.id})]);
  await rpc(a,'post_scheduled_expense',{...payload,p_occurrence_id:older.id,p_operation_id:randomUUID()},[400]);
  const after=(await snapshot()).data;
  check(after.occurrences.find(x=>x.id===older.id).state==='skipped','Concurrent skip is retained without posting.');
  check(after.occurrences.find(x=>x.id===occurrence.id).expense_id===committed.id,'Completion links to confirmed expense in same transaction.');
  const cursor=after.occurrences[49];
  const next=(await rpc(a,'get_expense_schedule_page',{p_group_id:group.id,p_before_date:cursor.due_date,p_before_id:cursor.id})).data;
  check(next.occurrences.length===41&&!next.occurrences.some(x=>x.id===cursor.id),'Older occurrence page traverses remaining bounded history.');
  await rpc(a,'archive_group',{p_group_id:group.id});
  check((await snapshot()).data.occurrences.every(x=>!x.can_review),'Archive keeps readable nonactionable history.');
  await rpc(a,'reopen_group',{p_group_id:group.id});
  const bMember=(await rpc(a,'get_group_member_snapshot',{p_group_id:group.id})).data.find(x=>x.user_id===b.id);
  await rpc(a,'remove_group_member',{p_group_id:group.id,p_member_id:bMember.id});
  await rpc(b,'get_expense_schedule_page',{p_group_id:group.id},[400]);
  await rpc(b,'post_scheduled_expense',payload,[400]);
  check((await rpc(a,'export_personal_data',{})).data.readable_schedules.some(x=>x.id===schedule.id),'Personal export includes currently readable schedule data.');
  check((await rpc(a,'get_group_balances',{p_group_id:group.id})).data.every(x=>x.net_balance_minor===0),'Schedule journey preserves canonical zero balances.');
  await rpc(a,'archive_group',{p_group_id:group.id});
}
