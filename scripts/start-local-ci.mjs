// CLI startup normally prints local service/S3 credentials. CI needs only a
// bounded success/error diagnostic; status JSON goes separately to process env.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const context=spawnSync('docker',['context','inspect'],{encoding:'utf8'});
assert.equal(context.status,0,'Docker context must be available.');
const endpoint=process.env.DOCKER_HOST||JSON.parse(context.stdout)[0].Endpoints.docker.Host;
assert.match(endpoint,/^(npipe:|unix:|tcp:\/\/(127\.0\.0\.1|localhost)(:|\/|$))/,'Remote Docker is refused.');
const result=spawnSync(process.execPath,['node_modules/supabase/dist/supabase.js','start'],{encoding:'utf8',timeout:300000,maxBuffer:8*1024*1024});
if(result.status!==0){
  const safe=(result.stdout+'\n'+result.stderr).split(/\r?\n/)
    .filter(line=>/error|failed|denied|not found|port/i.test(line)&&!/key|token|secret|password|credential|postgresql:\/\/|Bearer |eyJ[A-Za-z0-9_-]+\./i.test(line));
  for(const line of safe.slice(-10))console.error(line);
  throw Error('Disposable local startup failed; credentials were suppressed.');
}
console.log('PASS: disposable local Supabase startup; credentials suppressed.');
