// The bisect refused to start and said why: the "good" commit I picked, 15026f1a, is NOT an ancestor of HEAD -
// it is on a divergent line - so the merge base a005b681 had to be tested and it is BAD too. `git diff A..B`
// compares two TREES and does not imply a linear range, which is exactly the mistake. This scan finds a real
// good ancestor: it reads every earlier clean build's village verdict from the copied regression logs and asks
// git whether that build's commit is an ancestor of HEAD.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
function isAncestor(sha) {
  try { execFileSync('git', ['merge-base', '--is-ancestor', sha, 'HEAD'], { stdio: 'ignore' }); return true; }
  catch (e) { return false; }
}
const root = 'logs/031';
const rows = [];
for (const sha of fs.readdirSync(root)) {
  const shaDir = path.join(root, sha);
  if (!fs.statSync(shaDir).isDirectory()) continue;
  for (const build of fs.readdirSync(shaDir)) {
    const reg = path.join(shaDir, build, 'regression');
    if (!fs.existsSync(reg)) continue;
    const log = path.join(reg, 'run_village_battle_checks_stdout.log');
    if (!fs.existsSync(log)) continue;
    const t = readText(log);
    const verdict = t.includes('VILLAGE_BATTLE_CHECKS_PASS') ? 'PASS' : (t.includes('VILLAGE_BATTLE_CHECKS_FAIL') ? 'FAIL' : 'NO_VERDICT');
    const date = fs.statSync(path.join(shaDir, build)).mtime.toISOString().slice(0, 16);
    rows.push({ sha, short: sha.slice(0, 8), build, date, verdict, ancestor: isAncestor(sha) });
  }
}
rows.sort((a, b) => (a.date < b.date ? -1 : 1));
console.log('=== earlier clean builds with a village verdict, in date order');
for (const r of rows) console.log(r.date + '  ' + r.short + '  ancestor_of_HEAD=' + r.ancestor + '  ' + r.verdict + '  ' + r.build);
const goodAncestors = rows.filter((r) => r.ancestor && r.verdict === 'PASS');
console.log('=== ancestors of HEAD where the village suite PASSED: ' + goodAncestors.length);
for (const r of goodAncestors) console.log('   ' + r.short + '  ' + r.date);
const badAncestors = rows.filter((r) => r.ancestor && r.verdict === 'FAIL');
console.log('=== ancestors of HEAD where the village suite FAILED: ' + badAncestors.length);
for (const r of badAncestors) console.log('   ' + r.short + '  ' + r.date);
