// Explicit local app setup. No hosted commands, global installs or env overwrite.
import {createHash} from 'node:crypto';
import {existsSync, readFileSync, mkdirSync, readdirSync, copyFileSync, writeFileSync, realpathSync, cpSync} from 'node:fs';
import {delimiter, dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const workdir = join(root, '.local-dev');
const configPath = join(workdir, 'supabase', 'config.toml');
const envPath = join(root, 'mobile', '.env');
const cli = join(root, 'node_modules', 'supabase', 'dist', 'supabase.js');
const project = `oweloop-dev-${createHash('sha256').update(realpathSync(root)).digest('hex').slice(0, 10)}`;

function run(command, args, timeout = 30000) {
  const result = spawnSync(command, args, {cwd: root, encoding: 'utf8', timeout, maxBuffer: 8 * 1024 * 1024});
  if (result.status !== 0) throw Error(`${command === process.execPath ? 'Local Supabase CLI' : command} failed. Check installation/Docker/port availability; no configuration values are printed.`);
  return result.stdout;
}
function localDocker() {
  const context = JSON.parse(run('docker', ['context', 'inspect']))[0];
  const endpoint = process.env.DOCKER_HOST || context.Endpoints.docker.Host;
  if (!/^(npipe:|unix:|tcp:\/\/(127\.0\.0\.1|localhost)(:|\/|$))/.test(endpoint)) throw Error('Remote Docker is refused. Select a local Docker context.');
  if (run('docker', ['info', '--format', '{{.OSType}}']).trim() !== 'linux') throw Error('Start Docker Desktop with its Linux engine.');
}
function supabase(args) {
  if (!existsSync(cli)) throw Error('Local Supabase CLI missing. Run npm ci from the repository root.');
  return run(process.execPath, [cli, ...args, '--workdir', workdir], 300000);
}
function ownsConfig() {
  const ids = existsSync(configPath) ? [...readFileSync(configPath, 'utf8').matchAll(/^project_id\s*=\s*"([^"]+)"\s*$/gm)] : [];
  if (ids.length !== 1 || ids[0][1] !== project) throw Error('No matching generated local project. Run npm run dev:start in this checkout first.');
}
function configuredStatus() {
  ownsConfig();
  const status = JSON.parse(supabase(['status', '-o', 'json']));
  if (!['127.0.0.1', 'localhost', '::1'].includes(new URL(status.API_URL).hostname)) throw Error('Non-local API refused.');
  return status;
}
function onPath(name) {
  const extensions = process.platform === 'win32' ? ['', '.exe', '.bat', '.cmd'] : [''];
  return (process.env.PATH || '').split(delimiter).some(folder => extensions.some(ext => existsSync(join(folder, name + ext))));
}
function main() {
  const [action = 'check', ...flags] = process.argv.slice(2);
  if (!['check', 'start', 'status', 'stop'].includes(action)) throw Error('Usage: node scripts/dev-local.mjs check|start|status|stop [--storage] [--configure-mobile] [--client-host=127.0.0.1] [--port-base=61420]');
  const allowed = flags.every(flag => flag === '--configure-mobile' || flag === '--storage' || /^--client-host=(127\.0\.0\.1|localhost|10\.0\.2\.2)$/.test(flag) || /^--port-base=\d+$/.test(flag));
  if (!allowed || (action !== 'start' && flags.length)) throw Error('Unsupported setup option; configuration flags are start-only.');
  if (Number(process.versions.node.split('.')[0]) < 22) throw Error('Use Node 22 (CI version) or newer.');
  if (action === 'check') {
    let ready = true;
    for (const command of ['git', 'flutter', 'dart', 'docker']) {
      const found = onPath(command);
      console.log(`${found ? 'OK' : 'MISSING'}: ${command} on PATH`);
      ready &&= found;
    }
    console.log(`${existsSync(cli) ? 'OK' : 'MISSING'}: project-local Supabase CLI (npm ci)`);
    ready &&= existsSync(cli);
    try { localDocker(); console.log('OK: local Docker Linux engine'); } catch (error) { console.log(`NOT READY: ${error.message}`); ready = false; }
    console.log(`${existsSync(envPath) ? 'PRESENT' : 'ABSENT'}: mobile/.env (contents never printed)`);
    console.log('Next: npm run dev:start -- --configure-mobile; then cd mobile and flutter doctor -v / flutter run.');
    process.exitCode = ready ? 0 : 1;
    return;
  }
  localDocker();
  if (action === 'start') {
    const port = Number(flags.find(value => value.startsWith('--port-base='))?.split('=')[1] || 61420);
    if (port < 1024 || port > 65520) throw Error('Choose a port base between 1024 and 65520.');
    const host = flags.find(value => value.startsWith('--client-host='))?.split('=')[1] || '10.0.2.2';
    let config = readFileSync(join(root, 'supabase', 'config.toml'), 'utf8').replace('project_id = "oweloop-local"', `project_id = "${project}"`);
    for (let i = 0; i <= 9; i++) config = config.replaceAll(String(55420 + i), String(port + i));
    config = config.replace('sql_paths = ["./seed.sql"]', 'sql_paths = []');
    if(flags.includes('--storage')) {
      config=config.replace(/(\[storage\]\s*\r?\n)enabled = false/,'$1enabled = true')
        .replace(/(\[edge_runtime\]\s*\r?\n)enabled = false/,'$1enabled = true')
        .replace('inspector_port = 8083',`inspector_port = ${port+10}`);
    }
    if (existsSync(configPath) && readFileSync(configPath, 'utf8') !== config) throw Error('Existing generated project has different settings. Keep its port/configuration or use a separate checkout; no files were replaced.');
    mkdirSync(dirname(configPath), {recursive: true});
    writeFileSync(configPath, config);
    for (const folder of ['migrations', 'tests/database']) {
      const source = join(root, 'supabase', folder), target = join(workdir, 'supabase', folder);
      mkdirSync(target, {recursive: true});
      for (const file of readdirSync(source).filter(name => name.endsWith('.sql'))) copyFileSync(join(source, file), join(target, file));
    }
    cpSync(join(root,'supabase','functions'),join(workdir,'supabase','functions'),{recursive:true});
    console.log(`Starting only ${project}; API ${port + 1}, DB ${port + 2}. First image download can take several minutes.`);
    supabase(['start']);
    const status = configuredStatus();
    if (flags.includes('--configure-mobile')) {
      const url = new URL(status.API_URL); url.hostname = host;
      const content = `# Generated public values for this disposable local backend only.\nSUPABASE_URL=${url.origin}\nSUPABASE_ANON_KEY=${status.ANON_KEY}\n`;
      if (typeof status.ANON_KEY !== 'string' || !status.ANON_KEY) throw Error('Local anon key unavailable; mobile configuration was not written.');
      if (existsSync(envPath)) {
        if (readFileSync(envPath, 'utf8') !== content) throw Error('mobile/.env already exists and was preserved. Backend is running. Keep it or move it aside yourself before configuring this disposable backend.');
      } else writeFileSync(envPath, content, {flag: 'wx'});
      console.log('OK: mobile/.env contains only this backend public URL/anon key; no values printed.');
    }
    console.log(`Ready: host API ${status.API_URL}. Backend stays running. Stop only this project with npm run dev:stop.`);
    console.log('New migrations: npx supabase migration up --local --workdir .local-dev (after dev:start copies them).');
  } else if (action === 'status') {
    const status = configuredStatus();
    console.log(`Running: ${project}; host API ${status.API_URL}. Mobile env ${existsSync(envPath) ? 'present' : 'absent'}.`);
  } else {
    ownsConfig();
    supabase(['stop']);
    console.log(`Stopped only ${project}; local data retained by Supabase. No mobile env or user file removed.`);
  }
}
try { main(); } catch (error) { console.error(`Setup: ${error.message}`); process.exitCode = 1; }
