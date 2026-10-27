import test from 'node:test';
import assert from 'node:assert/strict';
import {createDeleteAccountHandler} from '../supabase/functions/delete-account/handler.mjs';

const request=body=>new Request('http://localhost/delete-account',{method:'POST',headers:{Authorization:'Bearer user-token','Content-Type':'application/json'},body:JSON.stringify(body)});
function fixture(responses) {
  const calls=[];
  const handler=createDeleteAccountHandler({url:'http://localhost',anonKey:'local-public',serviceKey:'server-only',fetcher:async(url,options)=>{
    calls.push({url,options});const next=responses.shift();assert.ok(next,'Unexpected backend request');return Response.json(next.body,{status:next.status??200});
  }});
  return {handler,calls};
}
test('rejects unauthenticated requests without contacting a backend',async()=>{
  const {handler,calls}=fixture([]);
  assert.equal((await handler(new Request('http://localhost',{method:'POST'}))).status,401);
  assert.equal(calls.length,0);
});
test('malformed password payloads return safe validation without a backend call',async()=>{
  const {handler,calls}=fixture([]);
  for (const body of [null, [], {}, {password:12}, {password:''}]) {
    assert.equal((await handler(request(body))).status,400);
  }
  assert.equal(calls.length,0);
});
test('wrong password never invokes privileged deletion',async()=>{
  const {handler,calls}=fixture([{body:{id:'verified-user',email:'verified@example.test'}},{status:400,body:{}}]);
  assert.equal((await handler(request({password:'wrong',user_id:'victim'}))).status,401);
  assert.equal(calls.length,2);
  assert.equal(JSON.parse(calls[1].options.body).email,'verified@example.test');
});
test('ownership and balance blockers prevent privileged deletion',async()=>{
  const {handler,calls}=fixture([{body:{id:'verified-user',email:'verified@example.test'}},{body:{user:{id:'verified-user'}}},{body:[{reason:'ownership'}]}]);
  assert.equal((await handler(request({password:'current'}))).status,409);
  assert.equal(calls.length,3);
});
test('deletes only verified identity and never returns service credentials',async()=>{
  const {handler,calls}=fixture([{body:{id:'verified-user',email:'verified@example.test'}},{body:{user:{id:'verified-user'}}},{body:[]},{body:{}}]);
  const response=await handler(request({password:'current',user_id:'victim'}));
  assert.equal(response.status,200);assert.deepEqual(await response.json(),{deleted:true});
  assert.ok(calls[3].url.endsWith('/verified-user'));
  assert.equal(calls[3].options.headers.Authorization,'Bearer server-only');
});
test('failed admin deletion never reports success',async()=>{
  const {handler}=fixture([{body:{id:'verified-user',email:'verified@example.test'}},{body:{user:{id:'verified-user'}}},{body:[]},{status:500,body:{}}]);
  assert.equal((await handler(request({password:'current'}))).status,409);
});
