// Read the [FAIL] lines of a named suite from the current candidate build, and report whether that suite
// existed in the previous clean build at all. A red that is new AND in scope must be understood, not registered.
const fs = require('fs');
const path = require('path');
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
const suite = process.argv[2];
const dirs = {
  'current 2026-09-19': 'backups/builds/031/6c945fb263b23b80b69ae1fa5124b0a5e213bbf0/20260919-122619-427/clean-source/logs',
  'previous 2026-09-17': 'logs/031/15026f1a45329387ffd5b261a32b69ed135b003b/build-20260917-193728-106/regression'
};
for (const [label, dir] of Object.entries(dirs)) {
  const hits = [];
  function walk(d) {
    if (!fs.existsSync(d)) return;
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name === suite + '_stdout.log') hits.push(p);
      else if (e.name === 'RESULTS.json') {
        const j = JSON.parse(readText(p));
        const rows = Array.isArray(j) ? j : (j.rows || []);
        const row = rows.find((r) => r.suite === suite);
        if (row) console.log(label + ' :: row exists: passed=' + row.passed + ' checks=' + row.checks + ' exit=' + row.exit_code + ' timeout=' + row.timed_out);
      }
    }
  }
  walk(dir);
  for (const p of hits) {
    const t = readText(p);
    const fails = t.split(/\r?\n/).filter((l) => l.includes('[FAIL]'));
    const result = t.split(/\r?\n/).filter((l) => /结果|result:|checks/.test(l));
    const watchdog = t.split(/\r?\n/).filter((l) => /WATCHDOG/.test(l));
    console.log('=== ' + label + ' :: ' + path.relative(process.cwd(), p));
    console.log('   FAIL lines (' + fails.length + '):');
    for (const f of fails.slice(0, 12)) console.log('     ' + f);
    if (watchdog.length) console.log('   WATCHDOG: ' + watchdog.join(' | '));
    console.log('   result lines: ' + (result.slice(-2).join(' | ') || 'none'));
    console.log('   total lines=' + t.split(/\r?\n/).length);
  }
  if (!hits.length) console.log('=== ' + label + ' :: NO ' + suite + '_stdout.log');
}
