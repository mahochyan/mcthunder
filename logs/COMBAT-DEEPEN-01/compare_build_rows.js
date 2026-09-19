// Compare the current candidate build's regression rows with the previous clean-source build's rows, so a
// failure is classified against a real baseline instead of being called new or old by guesswork.
const fs = require('fs');
const path = require('path');
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
function rowsFor(buildDir) {
  const out = [];
  function walk(d) {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name === 'RESULTS.json') out.push(p);
    }
  }
  if (fs.existsSync(buildDir)) walk(buildDir);
  if (!out.length) return null;
  out.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  const j = JSON.parse(readText(out[0]));
  return { path: out[0], rows: Array.isArray(j) ? j : (j.rows || j.suites || []) };
}
const dirs = {
  'current 2026-09-19': 'backups/builds/031/6c945fb263b23b80b69ae1fa5124b0a5e213bbf0/20260919-122619-427/clean-source/logs',
  'previous 2026-09-17': 'logs/031/15026f1a45329387ffd5b261a32b69ed135b003b/build-20260917-193728-106/regression',
  'earlier 2026-09-16': 'logs/031/10908aa5f761adab6429c8852152127cf7a47337/build-20260916-212113-234/regression'
};
const data = {};
for (const [label, d] of Object.entries(dirs)) {
  const r = rowsFor(d);
  data[label] = r;
  if (!r) { console.log(label + ': no regression rows on disk'); continue; }
  const failed = r.rows.filter((x) => !x.passed);
  console.log('=== ' + label + ' :: ' + r.rows.length + ' rows, ' + failed.length + ' failing');
  for (const f of failed) console.log('   FAIL ' + f.suite + ' checks=' + f.checks + ' timeout=' + f.timed_out + ' exit=' + f.exit_code + ' script_error=' + f.script_error);
}
const suites = ['run_checks', 'run_village_battle_checks', 'run_industrial_battle_checks', 'run_industrial_checks', 'run_challenge_checks'];
console.log('\n=== per-suite comparison');
for (const s of suites) {
  const cells = [];
  for (const [label, r] of Object.entries(data)) {
    if (!r) { cells.push(label + '=n/a'); continue; }
    const row = r.rows.find((x) => x.suite === s);
    cells.push(label + '=' + (row ? (row.passed ? 'PASS' : 'FAIL') + '(checks=' + row.checks + ',timeout=' + row.timed_out + ',exit=' + row.exit_code + ')' : 'absent'));
  }
  console.log(s + ' :: ' + cells.join(' | '));
}
