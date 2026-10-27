import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
export async function cleanupStaleReceipts({url,key,serviceKey,afterId=null}) {
  assert.ok(url&&key&&serviceKey,'Explicit disposable local service configuration required.');
  assert.ok(['127.0.0.1','localhost','[::1]'].includes(new URL(url).hostname),'Hosted cleanup is refused.');
  if(afterId!==null)assert.match(afterId,/^[0-9a-f-]{36}$/i);
  const headers={apikey:key,Authorization:`Bearer ${serviceKey}`,'Content-Type':'application/json'};
  async function rpc(name,body){
    const response=await fetch(`${url}/rest/v1/rpc/${name}`,{method:'POST',headers,body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw Error('Local receipt cleanup state was not confirmed.');
    return response.json();
  }
  const candidates=await rpc('get_stale_receipt_candidates',{p_after_id:afterId});
  let cleaned=0,conflicts=0;
  for(const candidate of candidates){
    let receipt;
    try{receipt=await rpc('claim_stale_receipt',{p_receipt_id:candidate.id,p_expected_updated_at:candidate.updated_at});}
    catch{conflicts++;continue;}
    if(Array.isArray(receipt))receipt=receipt[0];
    const response=await fetch(`${url}/storage/v1/object/oweloop-receipts`,{method:'DELETE',headers,body:JSON.stringify({prefixes:[receipt.object_key]}),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw Error('Local orphan deletion was not confirmed; metadata remains retryable.');
    await rpc('finish_expense_receipt',{p_receipt_id:receipt.id,p_actor_id:null,p_deleted:true});
    cleaned++;
  }
  return {cleaned,conflicts,nextId:candidates.length===50?candidates.at(-1).id:null};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const result=await cleanupStaleReceipts({url:process.env.SUPABASE_URL,key:process.env.SUPABASE_ANON_KEY,
    serviceKey:process.env.SUPABASE_SERVICE_ROLE_KEY,afterId:process.argv[2]||null});
  console.log(JSON.stringify(result));
}
