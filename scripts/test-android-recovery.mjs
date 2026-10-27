// Only disposable emulators. No credentials, financial payloads or raw app logs
// are printed. APK must be the debug recovery_probe_app.dart target.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {waitForCheckpoint} from './native-checkpoint.mjs';
const [serial,apkArgument]=process.argv.slice(2);
assert.match(serial||'',/^emulator-\d+$/,'Select a disposable Android emulator serial.');
const apk=resolve(apkArgument||'mobile/build/app/outputs/flutter-apk/app-debug.apk');
assert.ok(existsSync(apk),'Build the debug recovery probe APK first.');
const packageId='com.oweloop.oweloop';
function adb(args){const result=spawnSync('adb',['-s',serial,...args],{encoding:'utf8',timeout:30000,maxBuffer:8*1024*1024});assert.equal(result.status,0,`ADB step failed: ${args[0]}`);return result.stdout;}
assert.equal(adb(['shell','getprop','ro.kernel.qemu']).trim(),'1','Physical devices are refused.');
adb(['install','-r',apk]);
async function runPhase(phase,expected){
  adb(['shell','am','force-stop',packageId]);
  adb(['shell','run-as',packageId,'sh','-c',`"mkdir -p files; printf '%s' '${phase}' > files/oweloop-probe-phase"`]);
  adb(['logcat','-c']);
  adb(['shell','am','start','-n',`${packageId}/.MainActivity`]);
  await waitForCheckpoint(()=>adb(['logcat','-d','-s','flutter']),phase,expected);
  console.log(`PASS: ${phase}`);
}
try {
  await runPhase('before','WAIT:before');
  await runPhase('resume-before','PASS:resume-before');
  await runPhase('after','WAIT:after');
  await runPhase('resume-after','PASS:resume-after');
  await runPhase('draft','WAIT:draft');
  await runPhase('resume-draft','PASS:resume-draft');
  console.log('PASS: real Android process termination, secure-store reload and same-ID before/after-commit recovery.');
} finally {adb(['shell','am','force-stop',packageId]);}
