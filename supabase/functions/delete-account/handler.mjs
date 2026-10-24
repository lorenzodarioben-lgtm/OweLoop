// Framework-neutral handler, tested with Node's native test runner and the
// local Supabase Admin API. The service credential is never returned or logged.
export function createDeleteAccountHandler({url,anonKey,serviceKey,fetcher=fetch}) {
  const json=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
  return async request=>{
    if(request.method!=='POST') return json(405,{error:'Use POST.'});
    if(!url||!anonKey||!serviceKey) return json(503,{error:'Account deletion is not configured.'});
    const authorization=request.headers.get('Authorization');
    if(!authorization?.startsWith('Bearer ')) return json(401,{error:'Sign in again before deleting your account.'});
    let body;
    try {body=await request.json();} catch {return json(400,{error:'Enter your current password.'});}
    if(!body || Array.isArray(body) || typeof body.password!=='string'||body.password.length<1||body.password.length>1024) return json(400,{error:'Enter your current password.'});
    try {
      const verified=await fetcher(`${url}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:authorization},signal:AbortSignal.timeout(15000)});
      if(!verified.ok) return json(401,{error:'Sign in again before deleting your account.'});
      const user=await verified.json();
      if(!user?.id||!user?.email) return json(401,{error:'The current account could not be verified.'});
      // Reauthenticate with a server-verified email, never a caller-supplied ID.
      const reauth=await fetcher(`${url}/auth/v1/token?grant_type=password`,{method:'POST',headers:{apikey:anonKey,'Content-Type':'application/json'},body:JSON.stringify({email:user.email,password:body.password}),signal:AbortSignal.timeout(15000)});
      if(!reauth.ok) return json(401,{error:'Check your current password and try again.'});
      const authenticated=await reauth.json();
      if(authenticated.user?.id!==user.id) return json(401,{error:'The account identity could not be verified.'});
      const blockers=await fetcher(`${url}/rest/v1/rpc/get_account_deletion_blockers`,{method:'POST',headers:{apikey:anonKey,Authorization:authorization,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(15000)});
      if(!blockers.ok) return json(409,{error:'Account checks could not complete. No deletion is confirmed.'});
      if((await blockers.json()).length) return json(409,{error:'Transfer ownership or archive owned groups, and settle all balances before deleting your account.'});
      const deleted=await fetcher(`${url}/auth/v1/admin/users/${encodeURIComponent(user.id)}`,{method:'DELETE',headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`},signal:AbortSignal.timeout(15000)});
      if(!deleted.ok) return json(409,{error:'Deletion could not complete. Check ownership and balances, then retry. No deletion is confirmed.'});
      return json(200,{deleted:true});
    } catch {
      return json(503,{error:'The deletion outcome is not confirmed. Check your connection and sign-in status before retrying.'});
    }
  };
}
