// Replays the released baseline, seeds non-empty financial history, then applies
// only forward migrations in a uniquely named disposable database on local PG.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {readdirSync,readFileSync} from 'node:fs';
const context=spawnSync('docker',['context','inspect'],{encoding:'utf8'});
assert.equal(context.status,0,'Docker must be available.');
const endpoint=process.env.DOCKER_HOST||JSON.parse(context.stdout)[0].Endpoints.docker.Host;
assert.match(endpoint,/^(npipe:|unix:|tcp:\/\/(127\.0\.0\.1|localhost)(:|\/|$))/,'A local Docker engine is required.');
const container=process.env.OWELOOP_DB_CONTAINER||'supabase_db_oweloop-local';
assert.match(container,/^supabase_db_[a-zA-Z0-9_-]+$/,'Only a local Supabase DB container may be used.');
const database=`oweloop_upgrade_${randomBytes(8).toString('hex')}`;
assert.ok(process.argv.slice(2).every(arg=>arg==='--sprint-ii'),'Only --sprint-ii is supported.');
const sprintII=process.argv.includes('--sprint-ii');
assert.match(database,/^oweloop_upgrade_[0-9a-f]{16}$/);
function sql(source,db=database) {
  const result=spawnSync('docker',['exec','-i',container,'psql','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-q','-A','-t'],{input:source,encoding:'utf8'});
  if(result.status!==0) throw new Error(result.stderr||'Local upgrade SQL failed.');
  return result.stdout.trim();
}
let created=false;
try {
  sql(`create database ${database};`,'postgres');created=true;
  sql(`create schema auth; create schema extensions;
    create table auth.users(id uuid primary key,email text,created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth to authenticated,anon;
    grant execute on function auth.uid() to authenticated,anon;`);
  const migrationUrl=new URL('../supabase/migrations/',import.meta.url);
  const files=readdirSync(migrationUrl).filter(name=>name.endsWith('.sql')).sort();
  const boundary=sprintII?'20261028000000':'20261025000000';
  const baseline=files.filter(name=>name<boundary);
  const forward=files.filter(name=>name>=boundary);
  for(const name of baseline) sql(readFileSync(new URL(name,migrationUrl),'utf8'));
  const identity="select set_config('request.jwt.claim.sub','cccccccc-1111-4111-8111-111111111101',false);";
  sql(`insert into auth.users(id,email) values('cccccccc-1111-4111-8111-111111111101','upgrade@example.test');
    ${identity} select public.complete_profile('Upgrade owner');
    insert into public.groups(id,name,currency_code) values('cccccccc-1111-4111-8111-111111111100','Retained upgrade ledger','AUD');
    insert into public.group_members(id,group_id,display_name) values('cccccccc-1111-4111-8111-111111111102','cccccccc-1111-4111-8111-111111111100','Upgrade guest');
    select public.create_expense('cccccccc-1111-4111-8111-111111111100','Preserved upgrade dinner',1000,now(),
      jsonb_build_array(jsonb_build_object('member_id',(select id from public.group_members where user_id=auth.uid()),'amount_minor',1000)),
      jsonb_build_array(jsonb_build_object('member_id','cccccccc-1111-4111-8111-111111111102','amount_minor',1000)),gen_random_uuid());`);
  const tables=['profiles','groups','group_members','expenses','expense_payers','expense_splits','settlements','expense_events','financial_operations'];
  if(sprintII) {
    sql(`${identity} select public.save_expense_template('cccccccc-1111-4111-8111-111111111100','Preserved Sprint II template','{"description":"Retained template","amount":"10.00","split_method":"equal"}');`);
    tables.push('expense_templates','group_lifecycle_events');
  }
  const snapshot=()=>Object.fromEntries(tables.map(table=>[table,JSON.parse(sql(`select coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]'::jsonb)::text from public.${table} t;`))]));
  const before=snapshot();
  const balance=()=>sql(`${identity} select jsonb_agg(to_jsonb(b) order by b.group_member_id)::text from public.get_group_balances('cccccccc-1111-4111-8111-111111111100') b;`);
  const oldBalance=balance();
  for(const name of forward) sql(readFileSync(new URL(name,migrationUrl),'utf8'));
  const after=snapshot();
  for (const table of tables) {
    assert.equal(after[table].length,before[table].length,`${table} row count must survive upgrade.`);
    const preserved=after[table].map((row,index)=>Object.fromEntries(Object.keys(before[table][index]).map(key=>[key,row[key]])));
    assert.deepEqual(preserved,before[table],`${table}: every pre-existing column must remain exactly unchanged.`);
  }
  for (const expense of after.expenses) assert.equal(expense.category_key,null,'Historical expenses remain uncategorized.');
  assert.equal(balance(),oldBalance,'Canonical balances must remain identical.');
  console.log(`PASS: ${baseline.length} released migrations + ${forward.length} forward migrations; ${tables.length} non-empty/empty ledger table snapshots and canonical balances preserved on local PostgreSQL.`);
} finally {
  if(created) sql(`drop database ${database};`,'postgres');
}
