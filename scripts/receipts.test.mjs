import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createReceiptHandler,receiptMime,MAX_RECEIPT_BYTES} from '../supabase/functions/receipts/handler.mjs';
const bytes=Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=','base64'));
const id='a5555555-1111-4111-8111-111111111101',expense='a5555555-1111-4111-8111-111111111102';
const upload={action:'upload',receipt_id:id,expense_id:expense,mime_type:'image/png',data_base64:Buffer.from(bytes).toString('base64')};
const row={id,object_key:`${expense}/${id}.png`,state:'pending'};
const json=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:{'content-type':'application/json'}});
const request=body=>new Request('http://localhost/receipts',{method:'POST',headers:{Authorization:'Bearer user','Content-Type':'application/json'},body:JSON.stringify(body)});
test('image validation rejects active formats, corruption and excessive dimensions',()=>{
  assert.equal(receiptMime(bytes),'image/png');
  for(const data of [new TextEncoder().encode('<svg/>'),bytes.slice(0,30),new Uint8Array([...bytes,1])])assert.throws(()=>receiptMime(data));
  const huge=bytes.slice();new DataView(huge.buffer).setUint32(16,4097);assert.throws(()=>receiptMime(huge));
});
test('missing auth does not contact backend and malformed bytes never reserve',async()=>{
  let calls=0;
  const handler=createReceiptHandler({url:'http://localhost',anonKey:'public',serviceKey:'secret',fetcher:async()=>{calls++;return json({id});}});
  assert.equal((await handler(new Request('http://localhost',{method:'POST'}))).status,401);
  assert.equal(calls,0);
  assert.equal((await handler(request({...upload,data_base64:'PHN2Zy8+'}))).status,400);
  assert.equal(calls,1);
  assert.equal((await handler(request({...upload,mime_type:'text/html'}))).status,400);
  assert.equal((await handler(request({...upload,data_base64:'A'.repeat(Math.ceil(MAX_RECEIPT_BYTES/3)*4+1)}))).status,400);
});
test('lost finalize response preserves possibly ready object and same-ID replay',async()=>{
  const calls=[];let ready=false;
  const handler=createReceiptHandler({url:'http://localhost',anonKey:'public',serviceKey:'secret',fetcher:async(url,options)=>{
    calls.push([url,options.method]);
    if(url.endsWith('/auth/v1/user'))return json({id});
    if(url.endsWith('/reserve_expense_receipt'))return json({...row,state:ready?'ready':'pending'});
    if(url.endsWith('/finish_expense_receipt')){ready=true;throw Error('response lost');}
    if(url.includes('/storage/'))return json({});
    throw Error('unexpected');
  }});
  assert.equal((await handler(request(upload))).status,409);
  const replay=await handler(request(upload));assert.equal(replay.status,200);
  assert.ok(!(await replay.text()).includes('secret'));
  assert.equal(calls.filter(([url])=>url.includes('/storage/')).length,1);
  assert.ok(calls.every(([,method])=>method!=='DELETE'));
});
test('interrupted upload verifies existing bytes before finalizing',async()=>{
  let finalized=false;
  const handler=createReceiptHandler({url:'http://localhost',anonKey:'public',serviceKey:'secret',fetcher:async(url,options)=>{
    if(url.endsWith('/auth/v1/user'))return json({id});
    if(url.endsWith('/reserve_expense_receipt'))return json(row);
    if(url.endsWith('/finish_expense_receipt')){finalized=true;return json({...row,state:'ready'});}
    if(options.method==='POST')return json({},400);
    return new Response(bytes);
  }});
  assert.equal((await handler(request(upload))).status,200);assert.ok(finalized);
});
test('failed object deletion cannot report deleted metadata',async()=>{
  let finalized=false;
  const handler=createReceiptHandler({url:'http://localhost',anonKey:'public',serviceKey:'secret',fetcher:async(url)=>{
    if(url.endsWith('/auth/v1/user'))return json({id});
    if(url.endsWith('/delete_expense_receipt'))return json({...row,state:'deleting'});
    if(url.endsWith('/finish_expense_receipt')){finalized=true;return json({});}
    return json({},503);
  }});
  assert.equal((await handler(request({action:'delete',receipt_id:id}))).status,409);
  assert.equal(finalized,false);
});
