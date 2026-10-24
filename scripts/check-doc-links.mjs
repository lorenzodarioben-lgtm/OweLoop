// File targets only: no network, credentials or third-party Markdown dependency.
import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync} from 'node:fs';
import {dirname, isAbsolute, relative, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const files = [...new Set(execFileSync('git', ['-C', root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', '*.md'], {encoding: 'utf8'}).split('\0').filter(Boolean))];
const failures = [];
let links = 0;
for (const file of files) {
  const absolute = resolve(root, file);
  if (!existsSync(absolute)) continue;
  const text = readFileSync(absolute, 'utf8').replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm, '');
  const destinations = [...text.matchAll(/\]\(\s*(<[^>]+>|[^)\s]+)(?:\s+["'][^"']*["'])?\s*\)/g), ...text.matchAll(/^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|[^\s]+)/gm)];
  for (const match of destinations) {
    const destination = match[1].replace(/^<|>$/g, '');
    if (/^(https?|mailto|codex|plugin|app|data):/i.test(destination)) continue;
    let target;
    try { target = decodeURIComponent(destination.split('#')[0].split('?')[0]); } catch { failures.push(`${file}: invalid encoded link`); continue; }
    if (!target) continue;
    links++;
    const resolved = resolve(dirname(absolute), target);
    if (isAbsolute(target) || /^[A-Za-z]:[\\/]/.test(target) || relative(root, resolved).startsWith('..')) failures.push(`${file}: nonportable link ${target}`);
    else if (!existsSync(resolved)) failures.push(`${file}: missing ${target}`);
  }
}
for (const failure of failures) console.error(failure);
console.log(`${failures.length ? 'FAIL' : 'PASS'}: ${files.length} Markdown files, ${links} relative file targets; ${failures.length} errors. External URLs and heading fragments are not checked.`);
process.exitCode = failures.length ? 1 : 0;
