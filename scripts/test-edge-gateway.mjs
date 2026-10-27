// Real local Edge HTTP gateway, Auth and Admin deletion. No direct handler call.
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_ANON_KEY;
assert.ok(url&&key,'Explicit disposable local API configuration is required.');
assert.ok(['127.0.0.1','localhost','[::1]'].includes(new URL(url).hostname),'Hosted gateway tests are refused.');
let assertions=0;
const check=(value,message)=>{assert.ok(value,message);assertions++;};
async function call(path,{token=key,body,method='POST',allowed=[200,201,204]}={}) {
  const response=await fetch(`${url}${path}`,{method,headers:{apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
  assert.ok(allowed.includes(response.status),`Unexpected HTTP ${response.status} at ${path.split('?')[0]}`);
  const text=await response.text();
  return {status:response.status,data:text?JSON.parse(text):null};
}
const rpc=(user,name,body)=>call(`/rest/v1/rpc/${name}`,{token:user.token,body});
const unwrap=data=>Array.isArray(data)?data[0]:data;
async function account(label){
  const password=randomBytes(24).toString('base64url');
  const result=await call('/auth/v1/signup',{body:{email:`edge-${label}-${randomUUID()}@example.com`,password}});
  const user={token:result.data.access_token,password,id:result.data.user.id,email:result.data.user.email};
  assert.ok(user.token,'Local confirmations must be disabled.');
  await rpc(user,'complete_profile',{p_display_name:'Local gateway probe'});
  return user;
}
let ready=false;
for(let attempt=0;attempt<20;attempt++){
  try{
    const result=await call('/functions/v1/delete-account',{body:{password:'invalid'},allowed:[401,503]});
    if(result.status===401){ready=true;break;}
  }catch{/* Only bounded startup attempts; no raw gateway output. */}
  await new Promise(resolve=>setTimeout(resolve,500));
}
assert.ok(ready,'Local Edge gateway did not become ready.');
check((await call('/functions/v1/delete-account',{token:'invalid',body:{password:'invalid'},allowed:[401]})).status===401,'Invalid bearer rejected by actual gateway/handler.');
check((await call('/functions/v1/delete-account',{method:'GET',allowed:[405]})).status===405,'Gateway reaches the handler method contract.');
const a=await account('a'),b=await account('b');
const group=unwrap((await rpc(a,'create_group',{p_name:'Local Edge retained ledger',p_currency_code:'AUD'})).data);
await rpc(a,'create_group_invitation',{p_group_id:group.id,p_recipient_email:b.email});
const invitation=(await rpc(b,'get_pending_group_invitations',{})).data.find(x=>x.group_id===group.id);
await rpc(b,'accept_group_invitation',{p_invitation_id:invitation.invitation_id});
const owner=(await rpc(a,'get_group_member_snapshot',{p_group_id:group.id})).data.find(x=>x.user_id===a.id);
const expense=unwrap((await rpc(a,'create_expense',{p_group_id:group.id,p_description:'Retained gateway history',p_total_amount_minor:101,p_occurred_at:new Date().toISOString(),p_payers:[{member_id:owner.id,amount_minor:101}],p_splits:[{member_id:owner.id,amount_minor:101}],p_operation_id:randomUUID()})).data);
check((await call('/functions/v1/delete-account',{token:a.token,body:{password:'incorrect'},allowed:[401]})).status===401,'Wrong password cannot reach deletion.');
check((await call('/functions/v1/delete-account',{token:a.token,body:{password:a.password},allowed:[409]})).status===409,'Active ownership blocks gateway deletion.');
await rpc(a,'archive_group',{p_group_id:group.id});
const deleted=await call('/functions/v1/delete-account',{token:a.token,body:{password:a.password,user_id:b.id}});
check(deleted.data.deleted===true,'Gateway deletes only the verified password-authenticated caller.');
check((await call('/auth/v1/user',{token:b.token,method:'GET'})).data.id===b.id,'Caller-supplied other user ID cannot delete that user.');
check((await call(`/rest/v1/groups?id=eq.${group.id}`,{token:a.token,method:'GET'})).data.length===0,'Deleted old token loses group reads.');
check((await rpc(b,'get_group_expense_export_snapshot',{p_group_id:group.id})).data.some(x=>x.id===expense.id&&x.total_amount_minor===101),'Shared exact ledger survives actual gateway deletion.');
check((await call('/functions/v1/delete-account',{token:a.token,body:{password:a.password},allowed:[401]})).status===401,'Deleted token cannot replay deletion.');
console.log(`PASS: ${assertions} actual local Edge gateway assertions; never a hosted deployment.`);
