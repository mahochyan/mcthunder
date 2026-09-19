// CD15 phase six shape check: assert the shape of every artifact this phase wrote BEFORE believing any of it.
const fs = require('fs');
let bad = 0;
function ok(cond, label, detail) {
  if (!cond) bad++;
  console.log((cond ? 'PASS ' : 'FAIL ') + label + (detail === undefined ? '' : ' :: ' + detail));
}
function lines(p) { return fs.readFileSync(p, 'utf8').split(/\r?\n/).length - (fs.readFileSync(p, 'utf8').endsWith('\n') ? 1 : 0); }

const migPath = 'docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json';
const mig = JSON.parse(fs.readFileSync(migPath, 'utf8'));
ok(mig.changes.length === 31, 'migration carries thirty one changes', mig.changes.length);
const cd15 = mig.changes.filter((c) => c.work_order_id === 'WT-CD-015');
ok(cd15.length === 5, 'five CD15 entries', cd15.length);
ok(mig.changes.every((c) => Object.keys(c).length === 20), 'every entry keeps the twenty field shape');
ok(mig.migration_index.some((l) => l.startsWith('WT-CD-015:')), 'the migration index names WT-CD-015');
ok(mig.full_run_evidence.before.startsWith('CD15 start'), 'full run before is the CD15 reading');
ok(mig.full_run_evidence.after.startsWith('CD15 close'), 'full run after is the CD15 reading');
ok(cd15.every((c) => c.old_reference_unchanged === true && c.legacy_behavior_retained === true && String(c.rollback).length > 20), 'each CD15 entry keeps the old reference, the legacy behaviour and a rollback');

const resPath = 'docs/wt/continuation/COMBAT_DEEPEN01_CD015_RESULTS.json';
const resRaw = fs.readFileSync(resPath, 'utf8');
const res = JSON.parse(resRaw);
const tpl = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/templates_RESULTS.template.json', 'utf8'));
const cd14 = JSON.parse(fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CD014_RESULTS.json', 'utf8'));
ok(JSON.stringify(Object.keys(res)) === JSON.stringify(Object.keys(tpl)), 'the result uses every template field in template order');
ok(JSON.stringify(Object.keys(res)) === JSON.stringify(Object.keys(cd14)), 'and the same key set as the CD014 result');
ok(res.template_only === false && res.actual_game_test_executed === true, 'the result declares itself real rather than a template');
ok(res.status === 'COMPLETE' && res.exit_code === 0 && res.timed_out === false, 'status COMPLETE with a real exit code', res.status + '/' + res.exit_code);
ok(res.case_ids_expected.length === 6 && JSON.stringify(res.case_ids_expected) === JSON.stringify(res.case_ids_executed), 'six cases expected and six executed');
ok(typeof res.script_errors === 'string' && res.script_errors.includes('ammo_compartment'), 'the out-of-scope suite defect is stated rather than nulled');
ok(res.not_run.length >= 6, 'the not run list is explicit', res.not_run.length);

const cov = JSON.parse(fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.json', 'utf8'));
ok(cov.rows.length === 96 && cov.case_count === 96, 'the mirror still carries ninety six cases');
const byState = {};
for (const r of cov.rows) byState[r.state] = (byState[r.state] || 0) + 1;
ok(byState.COMPLETE === 54 && byState.EVIDENCE_RECORDED === 36 && byState.NOT_RUN === 6, 'states measured from disk', JSON.stringify(byState));
ok(cov.rows.filter((r) => r.sub_order === 'CD15').every((r) => r.state === 'COMPLETE'), 'CD15 is COMPLETE in every mirrored row');
ok(cov.rows.filter((r) => r.sub_order === 'CD16').every((r) => r.state === 'NOT_RUN'), 'CD16 stays NOT_RUN');
ok(cov.summary.find((s) => s.sub_order === 'CD15').result_document.endsWith('CD015_RESULTS.json'), 'the CD15 summary names its result document');
ok(cov.summary.every((s) => s.state !== 'COMPLETE' || s.cases_executed === '6/6'), 'every COMPLETE order shows six of six executed');

ok(fs.existsSync('docs/wt/continuation/COMBAT_DEEPEN01_CD015_DELIVERY.md'), 'the delivery document exists');
const dl = fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CD015_DELIVERY.md', 'utf8');
ok(/## 2\. Six deliverable classes/.test(dl) && /## 4\. War Thunder behaviour -> code location -> case id/.test(dl) && /## 5\. Five validation layers/.test(dl), 'the delivery carries the six classes, the behaviour map and the five layers');
ok(/CD15-T01[\s\S]*CD15-T06/.test(dl), 'all six cases appear in the delivery');
const ev = fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CD015_EVIDENCE.md', 'utf8');
ok(/## 10\. Phases four to six/.test(ev), 'the evidence document carries the phase four to six record');
const written = resRaw + dl + ev + fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.md', 'utf8');
ok(!written.includes('\uFFFD'), 'no replacement character in the documents this phase wrote', written.length + ' chars scanned');

console.log(bad === 0 ? 'CD15_SHAPE_PASS' : 'CD15_SHAPE_FAIL (' + bad + ')');
process.exit(bad === 0 ? 0 : 1);
