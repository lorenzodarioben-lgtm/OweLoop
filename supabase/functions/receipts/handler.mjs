export const MAX_RECEIPT_BYTES=4*1024*1024;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function receiptMime(bytes) {
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  const dimensions=(w,h)=>w>0&&h>0&&w<=4096&&h<=4096;
  if(bytes.length>=45 && [137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v)) {
    let offset=8,header=false,data=false,end=false;
    while(offset+12<=bytes.length) {
      const length=view.getUint32(offset),type=String.fromCharCode(...bytes.slice(offset+4,offset+8));
      if(length>MAX_RECEIPT_BYTES||offset+12+length>bytes.length)break;
      if(!header) {
        if(type!=='IHDR'||length!==13||!dimensions(view.getUint32(offset+8),view.getUint32(offset+12)))break;
        header=true;
      } else if(type==='IHDR')break;
      if(type==='IDAT')data=true;
      offset+=12+length;
      if(type==='IEND'){end=length===0&&offset===bytes.length;break;}
    }
    if(header&&data&&end)return 'image/png';
  }
  if(bytes.length>=12&&bytes[0]===255&&bytes[1]===216&&bytes.at(-2)===255&&bytes.at(-1)===217) {
    let offset=2;
    while(offset+4<=bytes.length) {
      if(bytes[offset++]!==255)break;
      while(bytes[offset]===255)offset++;
      const marker=bytes[offset++];
      if(marker===0xda||marker===0xd9)break;
      const length=view.getUint16(offset);
      if(length<2||offset+length>bytes.length)break;
      if([0xc0,0xc1,0xc2].includes(marker)&&length>=8&&dimensions(view.getUint16(offset+5),view.getUint16(offset+3)))return 'image/jpeg';
      offset+=length;
    }
  }
  throw new Error('Invalid receipt image');
}
async function digest(bytes) {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');
}
async function boundedJson(request) {
  const reader=request.body?.getReader();
  if(!reader)throw new Error('Missing body');
  const chunks=[];let size=0;
  try {
    while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;
      if(size>6*1024*1024){await reader.cancel();throw new Error('Large body');}chunks.push(value);}
  } finally {reader.releaseLock();}
  const bytes=new Uint8Array(size);let at=0;for(const chunk of chunks){bytes.set(chunk,at);at+=chunk.length;}
  return JSON.parse(new TextDecoder().decode(bytes));
}

export function createReceiptHandler({url,anonKey,serviceKey,fetcher=fetch}) {
  const json=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
  return async request=>{
    if(request.method!=='POST')return json(405,{error:'Use POST.'});
    if(!url||!anonKey||!serviceKey)return json(503,{error:'Receipts are not configured.'});
    const authorization=request.headers.get('Authorization');
    if(!authorization?.startsWith('Bearer '))return json(401,{error:'Sign in again.'});
    const headers={apikey:anonKey,Authorization:authorization,'Content-Type':'application/json'};
    const admin={apikey:serviceKey,Authorization:`Bearer ${serviceKey}`};
    const rpc=async(name,body,privileged=false)=>{
      const response=await fetcher(`${url}/rest/v1/rpc/${name}`,{method:'POST',headers:privileged?{...admin,'Content-Type':'application/json'}:headers,body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error('Receipt state was not confirmed');
      const value=await response.json();return Array.isArray(value)?value[0]:value;
    };
    try {
      const auth=await fetcher(`${url}/auth/v1/user`,{headers,signal:AbortSignal.timeout(15000)});
      if(!auth.ok)return json(401,{error:'Sign in again.'});
      const user=await auth.json();
      if(!uuid.test(user?.id||''))return json(401,{error:'Sign in again.'});
      let body,bytes,mime,hash;
      try {
        body=await boundedJson(request);
        if(!body||!uuid.test(body.receipt_id||'')||!['upload','delete'].includes(body.action))throw new Error('Invalid action');
        if(body.action==='upload') {
          if(!uuid.test(body.expense_id||'')||typeof body.data_base64!=='string'||body.data_base64.length>Math.ceil(MAX_RECEIPT_BYTES/3)*4)throw new Error('Invalid upload');
          const decoded=atob(body.data_base64);bytes=Uint8Array.from(decoded,v=>v.charCodeAt(0));
          if(!bytes.length||bytes.length>MAX_RECEIPT_BYTES)throw new Error('Invalid size');
          mime=receiptMime(bytes);
          if(body.mime_type!==mime)throw new Error('MIME mismatch');
          hash=await digest(bytes);
        }
      } catch {return json(400,{error:'Choose a PNG or JPEG up to 4 MiB and 4096 pixels per side.'});}
      if(body.action==='delete') {
        const receipt=await rpc('delete_expense_receipt',{p_receipt_id:body.receipt_id});
        if(receipt.state!=='deleted') {
          const removed=await fetcher(`${url}/storage/v1/object/oweloop-receipts`,{method:'DELETE',headers:{...admin,'Content-Type':'application/json'},body:JSON.stringify({prefixes:[receipt.object_key]}),signal:AbortSignal.timeout(15000)});
          if(!removed.ok)throw new Error('Object deletion unconfirmed');
          await rpc('finish_expense_receipt',{p_receipt_id:receipt.id,p_actor_id:user.id,p_deleted:true},true);
        }
        return json(200,{receipt_id:receipt.id,state:'deleted'});
      }
      const receipt=await rpc('reserve_expense_receipt',{p_receipt_id:body.receipt_id,p_expense_id:body.expense_id,p_sha256:hash,p_mime_type:mime,p_size_bytes:bytes.length});
      if(receipt.state!=='ready') {
        const path=`${url}/storage/v1/object/oweloop-receipts/${receipt.object_key}`;
        const uploaded=await fetcher(path,{method:'POST',headers:{...admin,'Content-Type':mime,'x-upsert':'false','cache-control':'0'},body:bytes,signal:AbortSignal.timeout(15000)});
        if(!uploaded.ok) {
          // Interrupted/concurrent upload may already have stored these exact bytes.
          // Never overwrite another object or infer ready from a duplicate response.
          if(![400,409].includes(uploaded.status))throw new Error('Upload unconfirmed');
          const existing=await fetcher(path,{headers:admin,signal:AbortSignal.timeout(15000)});
          if(!existing.ok||await digest(new Uint8Array(await existing.arrayBuffer()))!==hash)throw new Error('Stored receipt mismatch');
        }
        // A lost finalize response can have committed. Keep the object for same-ID
        // recovery; never delete a possibly ready receipt as error cleanup.
        await rpc('finish_expense_receipt',{p_receipt_id:receipt.id,p_actor_id:user.id,p_deleted:false},true);
      }
      return json(200,{receipt_id:receipt.id,state:'ready'});
    } catch {return json(409,{error:'Receipt outcome is not confirmed. Refresh or retry the same upload. Financial records are unchanged.'});}
  };
}
