// Real Auth + PostgREST integration. Refuses every non-loopback endpoint.
// Disposable identities/passwords are generated in memory and never printed.
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createDeleteAccountHandler } from '../supabase/functions/delete-account/handler.mjs';

const envFile = (() => {try {return readFileSync(new URL('../mobile/.env',import.meta.url),'utf8');} catch {return '';}})();
const value = key => process.env[key] || envFile.match(new RegExp(`^${key}=(.*)$`,'m'))?.[1]?.trim();
const url = value('SUPABASE_URL');
const key = value('SUPABASE_ANON_KEY');
if(!url || !key) throw new Error('Set SUPABASE_URL and SUPABASE_ANON_KEY for the disposable local stack.');
if(!['127.0.0.1','localhost','[::1]'].includes(new URL(url).hostname)) throw new Error('Integration tests require a disposable loopback Supabase endpoint. Hosted endpoints are refused.');
let assertions=0;
function check(condition,message) {assert.ok(condition,message);assertions++;}
async function request(path,{user,method='POST',body,allowed=[200,201,204]}={}) {
  const response=await fetch(`${url}${path}`,{method,headers:{apikey:key,Authorization:`Bearer ${user?.token||key}`,'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
  const text=await response.text();
  let data;try {data=text?JSON.parse(text):null;} catch {throw new Error(`Non-JSON response from ${path.split('?')[0]} (${response.status})`);}
  assert.ok(allowed.includes(response.status),`Unexpected HTTP ${response.status} from ${path.split('?')[0]}: ${data?.code||''} ${data?.message||''}`);
  return {status:response.status,data};
}
const rpc=async(user,name,body,allowed)=>request(`/rest/v1/rpc/${name}`,{user,body,allowed});
const unwrap=data=>Array.isArray(data)?data[0]:data;
async function account(label) {
  const email=`oweloop-${Date.now()}-${randomBytes(4).toString('hex')}-${label}@example.com`;
  const password=randomBytes(24).toString('base64url');
  const response=await request('/auth/v1/signup',{body:{email,password}});
  const token=response.data.access_token;
  check(typeof token==='string','Local email confirmations must be disabled for disposable tests.');
  const user={token,email,id:response.data.user.id,password};
  await rpc(user,'complete_profile',{p_display_name:`Integration ${label}`});
  return user;
}

const a=await account('A'),b=await account('B'),c=await account('C');
const group=unwrap((await rpc(a,'create_group',{p_name:'Disposable integration ledger',p_currency_code:'AUD'})).data);
let members=(await request(`/rest/v1/group_members?group_id=eq.${group.id}`,{user:a,method:'GET'})).data;
const owner=members.find(member=>member.user_id===a.id);
await rpc(a,'create_group_invitation',{p_group_id:group.id,p_recipient_email:b.email});
const invitation=(await rpc(b,'get_pending_group_invitations',{})).data.find(row=>row.group_id===group.id);
check(Boolean(invitation),'Intended recipient sees invitation.');
await rpc(c,'accept_group_invitation',{p_invitation_id:invitation.invitation_id},[400]);
const acceptance=await Promise.all([rpc(b,'accept_group_invitation',{p_invitation_id:invitation.invitation_id},[200,400]),rpc(b,'accept_group_invitation',{p_invitation_id:invitation.invitation_id},[200,400])]);
check(acceptance.filter(result=>result.status===200).length===1,'Concurrent invitation acceptance succeeds exactly once.');
members=(await request(`/rest/v1/group_members?group_id=eq.${group.id}`,{user:b,method:'GET'})).data;
const member=members.find(row=>row.user_id===b.id);
const guest=unwrap((await rpc(a,'add_guest_member',{p_group_id:group.id,p_display_name:'Integration guest'})).data);
const operationId=randomUUID();
const expensePayload={p_group_id:group.id,p_description:'Multi-payer unequal dinner',p_total_amount_minor:1001,p_occurred_at:new Date().toISOString(),p_payers:[{member_id:owner.id,amount_minor:600},{member_id:member.id,amount_minor:401}],p_splits:[{member_id:member.id,amount_minor:500},{member_id:guest.id,amount_minor:501}],p_operation_id:operationId};
const concurrent=await Promise.all(Array.from({length:5},()=>rpc(a,'create_expense',expensePayload)));
const expense=unwrap(concurrent[0].data);
check(concurrent.every(result=>unwrap(result.data).id===expense.id),'Concurrent financial retries return one expense.');
// Deliberately ignore the original result and retry through a fresh HTTP request.
check(unwrap((await rpc(a,'create_expense',expensePayload)).data).id===expense.id,'Lost-response recovery returns the original record.');
await rpc(a,'create_expense',{...expensePayload,p_description:'Conflicting retry'},[400]);
let balances=(await rpc(b,'get_group_balances',{p_group_id:group.id})).data;
check(balances.reduce((sum,row)=>sum+row.net_balance_minor,0)===0,'Shared ledger reconciles.');
check(balances.find(row=>row.group_member_id===guest.id).net_balance_minor===-501,'Guest owes exactly the allocated amount.');
check((await rpc(b,'get_group_balance_snapshot',{p_group_id:group.id})).data.length===3,'Complete balance snapshot includes all members.');
check((await rpc(b,'get_group_member_snapshot',{p_group_id:group.id})).data.length===3,'Complete membership snapshot includes all active participants.');
check((await rpc(b,'get_current_groups_snapshot',{})).data.some(row=>row.id===group.id),'Complete current-group snapshot respects membership.');
await rpc(a,'remove_group_member',{p_group_id:group.id,p_member_id:guest.id},[400]);
await request(`/rest/v1/group_members?id=eq.${guest.id}`,{user:a,method:'PATCH',body:{removed_at:new Date().toISOString()},allowed:[403]});
await request(`/rest/v1/groups?id=eq.${group.id}`,{user:a,method:'PATCH',body:{currency_code:'JPY'},allowed:[403]});
check((await request(`/rest/v1/groups?id=eq.${group.id}`,{user:c,method:'GET'})).data.length===0,'Outsider cannot read the group.');
await rpc(a,'create_guest_claim_request',{p_group_id:group.id,p_guest_member_id:guest.id,p_recipient_email:c.email});
const claim=(await rpc(c,'get_pending_guest_claim_requests',{})).data.find(row=>row.group_id===group.id);
await rpc(b,'accept_guest_claim_request',{p_claim_request_id:claim.claim_request_id},[400]);
const claimResults=await Promise.all([rpc(c,'accept_guest_claim_request',{p_claim_request_id:claim.claim_request_id},[200,400]),rpc(c,'accept_guest_claim_request',{p_claim_request_id:claim.claim_request_id},[200,400])]);
check(claimResults.filter(result=>result.status===200).length===1,'Concurrent guest claim succeeds exactly once.');
const claimed=unwrap(claimResults.find(result=>result.status===200).data);
check(claimed.id===guest.id&&claimed.user_id===c.id,'Claim preserves durable membership identity.');
balances=(await rpc(c,'get_group_balances',{p_group_id:group.id})).data;
check(balances.find(row=>row.group_member_id===guest.id).net_balance_minor===-501,'Claim preserves the existing balance.');
const settlementPayload={p_group_id:group.id,p_paying_member_id:guest.id,p_receiving_member_id:owner.id,p_amount_minor:501,p_settled_at:new Date().toISOString(),p_operation_id:randomUUID()};
const settlements=await Promise.all(Array.from({length:4},()=>rpc(b,'record_settlement',settlementPayload)));
check(settlements.every(result=>unwrap(result.data).id===unwrap(settlements[0].data).id),'Concurrent settlement retries return one record.');
await rpc(b,'record_settlement',{...settlementPayload,p_paying_member_id:member.id,p_amount_minor:99,p_operation_id:randomUUID()});
balances=(await rpc(a,'get_group_balances',{p_group_id:group.id})).data;
check(balances.every(row=>row.net_balance_minor===0),'Both external payment records settle all members exactly.');
const page=(await rpc(a,'get_expense_page',{p_group_id:group.id,p_limit:1,p_query:'unequal'})).data;
check(page.length===1&&page[0].id===expense.id,'Searchable history returns the financial record.');
check((await rpc(a,'get_settlement_page',{p_group_id:group.id,p_limit:1})).data.length===2,'History returns one lookahead record for pagination.');
check((await rpc(a,'get_expense_activity',{p_expense_id:expense.id})).data.length>0,'Expense audit activity is readable.');
check((await rpc(a,'get_expense_activity_snapshot',{p_expense_id:expense.id})).data.length>0,'Complete safe activity snapshot is readable.');
const restored=(await request('/auth/v1/user',{user:c,method:'GET'})).data;
check(restored.id===c.id,'A restored disposable session retains the claimed identity.');
await rpc(b,'leave_group',{p_group_id:group.id});
check((await request(`/rest/v1/groups?id=eq.${group.id}`,{user:b,method:'GET'})).data.length===0,'Leaving immediately revokes group reads.');
await rpc(a,'archive_group',{p_group_id:group.id});
await rpc(a,'create_expense',{...expensePayload,p_operation_id:randomUUID()},[400]);
await rpc(a,'void_settlement',{p_settlement_id:unwrap(settlements[0].data).id},[400]);
check((await rpc(c,'get_expense_page',{p_group_id:group.id})).data.length===1,'Archived history remains readable.');
const exported=(await rpc(c,'export_personal_data',{})).data;
check(exported.profile.id===c.id,'Personal export contains only the caller profile.');
check(exported.memberships.every(row=>row.user_id===c.id),'Personal export isolates membership identities.');
const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(serviceKey) {
  const handler=createDeleteAccountHandler({url,anonKey:key,serviceKey});
  const deletionRequest=password=>new Request('http://localhost/delete-account',{method:'POST',headers:{Authorization:`Bearer ${a.token}`,'Content-Type':'application/json'},body:JSON.stringify({password,user_id:c.id})});
  check((await handler(deletionRequest('incorrect-password'))).status===401,'Deletion requires the correct current password.');
  const deleted=await handler(deletionRequest(a.password));
  check(deleted.status===200&&JSON.parse(await deleted.text()).deleted===true,'Trusted deletion removes the verified account through the real local Admin API.');
  const retained=(await request(`/rest/v1/groups?id=eq.${group.id}`,{user:c,method:'GET'})).data;
  check(retained.length===1&&retained[0].created_by===null,'Deletion preserves and de-identifies the archived shared group.');
  check((await request(`/rest/v1/groups?id=eq.${group.id}`,{user:a,method:'GET'})).data.length===0,'Old access token cannot read shared data after account deletion.');
  check((await rpc(c,'get_expense_page',{p_group_id:group.id})).data[0].total_amount_minor===1001,'Deletion preserves exact shared financial history.');
} else {
  console.log('SKIP: real Admin API deletion requires the disposable local SUPABASE_SERVICE_ROLE_KEY.');
}
console.log(`PASS: ${assertions} integration assertions; real local Auth, PostgREST, three accounts, concurrent retries/acceptance, guest claiming, settlement, leave, archive, export, and configured deletion checks.`);
