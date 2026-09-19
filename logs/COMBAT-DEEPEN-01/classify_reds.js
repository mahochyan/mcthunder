// Classify the three reds reproduced in the working tree, and compare run_checks with the log from the
// 2026-09-17 build where it was judged PASS. The point is to separate a real check failure from a
// watchdog/timing failure, because the remedy is entirely different.
const fs = require('fs');
const path = require('path');
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
function summarize(label, p) {
  if (!fs.existsSync(p)) { console.log('=== ' + label + ' :: MISSING ' + p); return; }
  const t = readText(p);
  const lines = t.split(/\r?\n/);
  const fails = lines.filter((l) => l.includes('[FAIL]'));
  const passes = lines.filter((l) => l.includes('[PASS]'));
  const watchdog = lines.filter((l) => /WATCHDOG/.test(l));
  const result = lines.filter((l) => /结果|result:|项检查|checks,/.test(l));
  const markers = lines.filter((l) => /_PASS|_FAIL|PASS$|FAIL$/.test(l));
  console.log('=== ' + label);
  console.log('   lines=' + lines.length + ' pass=' + passes.length + ' fail=' + fails.length);
  if (fails.length) { console.log('   FAIL lines:'); for (const f of fails.slice(0, 8)) console.log('     ' + f); }
  if (watchdog.length) console.log('   watchdog: ' + watchdog.join(' | '));
  if (result.length) console.log('   result: ' + result.slice(-3).join(' | '));
  if (markers.length) console.log('   markers: ' + markers.slice(-3).join(' | '));
  console.log('   tail: ' + lines.filter((l) => l.trim()).slice(-3).join(' || '));
}
const prev = 'logs/031/15026f1a45329387ffd5b261a32b69ed135b003b/build-20260917-193728-106/regression';
summarize('working tree run_checks (this round)', 'logs/COMBAT-DEEPEN-01/c16r-run_checks.log');
summarize('clean source run_checks (build)', 'backups/builds/031/6c945fb263b23b80b69ae1fa5124b0a5e213bbf0/20260919-122619-427/clean-source/logs/031-clean/6c945fb263b23b80b69ae1fa5124b0a5e213bbf0/20260919-122845/run_checks_stdout.log');
summarize('2026-09-17 run_checks (judged PASS)', path.join(prev, 'run_checks_stdout.log'));
summarize('working tree village (this round)', 'logs/COMBAT-DEEPEN-01/c16r-run_village_battle_checks.log');
summarize('2026-09-17 village (judged PASS)', path.join(prev, 'run_village_battle_checks_stdout.log'));
summarize('working tree engineering runtime (this round)', 'logs/COMBAT-DEEPEN-01/c16r-run_engineering_runtime_checks.log');
summarize('2026-09-17 engineering runtime (judged PASS)', path.join(prev, 'run_engineering_runtime_checks_stdout.log'));
