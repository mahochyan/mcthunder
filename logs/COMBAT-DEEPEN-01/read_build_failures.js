// Read the failing suite logs from the clean-source build run, because a package build that stops must
// explain itself from its own captured output rather than from a guess.
const fs = require('fs');
const path = require('path');
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
const base = process.argv[2];
const dir = path.join(base, 'clean-source/logs/031-clean');
const results = [];
function walk(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name === 'RESULTS.json') results.push(p); } }
walk(dir);
results.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
const resultsPath = results[0];
const logDir = path.dirname(resultsPath);
console.log('# log dir ' + logDir);
for (const suite of ['run_checks', 'run_village_battle_checks', 'run_industrial_battle_checks']) {
  for (const kind of ['stdout', 'stderr']) {
    const p = path.join(logDir, suite + '_' + kind + '.log');
    if (!fs.existsSync(p)) { console.log('=== ' + suite + ' ' + kind + ' MISSING'); continue; }
    const t = readText(p);
    const lines = t.split(/\r?\n/);
    const interesting = lines.filter((l) => /ERROR|error|FAIL|fail|Cannot|Cannot open|Parse|SCRIPT|assert|Assert|abort|crash|=== |PASS|passed|marker/i.test(l));
    console.log('=== ' + suite + ' ' + kind + ' :: lines=' + lines.length + ' bytes=' + t.length);
    console.log('--- first 12 non-empty lines ---');
    console.log(lines.filter((l) => l.trim()).slice(0, 12).join('\n'));
    console.log('--- last 12 non-empty lines ---');
    console.log(lines.filter((l) => l.trim()).slice(-12).join('\n'));
    console.log('--- interesting lines (' + interesting.length + ') ---');
    console.log(interesting.slice(0, 20).join('\n'));
  }
}
