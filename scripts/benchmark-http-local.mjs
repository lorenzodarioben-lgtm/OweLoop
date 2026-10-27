// Actual HTTP serialization/payload and Node-client memory observations. These
// fictional fixtures live only in the helper's disposable stack and are removed
// when that stack stops; this is not a phone/production load test.
import assert from 'node:assert/strict';
import {randomUUID,randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_ANON_KEY,container=process.env.OWELOOP_DB_CONTAINER;
assert.ok(url&&key,'Explicit disposable API required.');
assert.ok(['localhost','127.0.0.1','[::1]'].includes(new URL(url).hostname),'Hosted benchmarks refused.');
assert.match(container||'',/^supabase_db_oweloop-check-[a-z0-9]+$/,'Only the unique isolated check stack may be seeded.');
async function call(path,body,token=key){
 const response=await fetch(`${url}${path}`,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
 assert.ok(response.ok,`HTTP benchmark request failed: ${path}`);return response.json();
}
const auth=await call('/auth/v1/signup',{email:`http-scale-${randomUUID()}@example.com`,password:randomBytes(24).toString('base64url')});
assert.ok(auth.access_token,'Local confirmations must be disabled.');
const token=auth.access_token,owner=auth.user.id;
await call('/rest/v1/rpc/complete_profile',{p_display_name:'Disposable HTTP benchmark'},token);
const created=await call('/rest/v1/rpc/create_group',{p_name:'Disposable HTTP scale','p_currency_code':'AUD'},token);
const group=(Array.isArray(created)?created[0]:created).id;
for(const id of [owner,group])assert.match(id,/^[a-f0-9-]{36}$/);
const seeded=spawnSync('docker',['exec','-i',container,'psql','-U','postgres','-d','postgres','-q','-v','ON_ERROR_STOP=1'],{encoding:'utf8',timeout:180000,input:`begin;
select set_config('request.jwt.claim.sub','${owner}',true);
insert into public.group_members(group_id,display_name) select '${group}','HTTP fixture '||i from generate_series(2,1000)i;
do $$ declare own uuid;other uuid;begin
select id into own from public.group_members where group_id='${group}' and user_id='${owner}';
select id into other from public.group_members where group_id='${group}' and user_id is null order by id limit 1;
for i in 1..2000 loop perform public.create_expense('${group}','HTTP scale fixture',1,now(),jsonb_build_array(jsonb_build_object('member_id',own,'amount_minor',1)),jsonb_build_array(jsonb_build_object('member_id',other,'amount_minor',1)),gen_random_uuid());end loop;
for i in 1..1000 loop perform public.record_settlement('${group}',other,own,1,now(),gen_random_uuid());end loop;
end $$;commit;`});
assert.equal(seeded.status,0,'Disposable HTTP fixture seeding must succeed.');
const rssBefore=process.memoryUsage().rss;
for(const [name,count] of [['get_group_balance_snapshot',1000],['get_group_member_snapshot',1000],['get_group_expense_export_snapshot',2000],['get_group_settlement_export_snapshot',1000]]){
 const samples=[];let bytes=0;
 for(let i=0;i<3;i++){
   const started=performance.now();
   const response=await fetch(`${url}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({p_group_id:group}),signal:AbortSignal.timeout(30000)});
   assert.ok(response.ok,'Bounded HTTP read must succeed.');
   const text=await response.text();bytes=Buffer.byteLength(text,'utf8');
   const parsed=JSON.parse(text);assert.equal(parsed.length,count,'Complete snapshot count.');
   if(name==='get_group_balance_snapshot')assert.equal(parsed.reduce((sum,row)=>sum+BigInt(row.net_balance_minor),0n),0n,'Exact balance sum.');
   samples.push(Number((performance.now()-started).toFixed(3)));
 }
 console.log(JSON.stringify({scope:'local real HTTP; fictional 1000/2000/1000 fixture; includes serialization and Node parse',rpc:name,rows:count,utf8_bytes:bytes,elapsed_ms:samples}));
}
console.log(JSON.stringify({scope:'Node client only; includes startup/GC/response materialization, not Flutter memory',rss_before_bytes:rssBefore,rss_after_bytes:process.memoryUsage().rss,max_rss_bytes:process.resourceUsage().maxRSS*1024}));
console.log('PASS: bounded actual HTTP payloads, complete counts and exact balances; own disposable stack cleanup removes fixtures.');
