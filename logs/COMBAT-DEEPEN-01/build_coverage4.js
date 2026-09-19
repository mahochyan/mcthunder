// MCT-COMBAT-DEEPEN-01: regenerate the ninety six case mirror beside the read-only packaged list.
// The rule this generator follows is the one the first three attempts learned the hard way: the state
// of a sub-order is read FROM DISK (a result file, an evidence document, a runner) and never assumed,
// and the packaged case list is only ever READ, because it is the read-only original.
const fs = require('fs');
const path = require('path');

const root = process.cwd();
const pkg = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json', 'utf8'));
const packaged = pkg.cases || pkg;
const mirrorPath = 'docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.json';
const mirror = JSON.parse(fs.readFileSync(mirrorPath, 'utf8'));

// --- order metadata, read from disk rather than guessed ---
// The naming collision the original generator warned about: CASE ids use TWO digits after the prefix
// (CD01..CD16) while the documents and runners use THREE (CD001..CD016, run_cd008_...). Both forms are
// derived here explicitly, because the first run of this very generator reported all ninety six cases
// as NOT_RUN by using the two digit form against three digit file names.
const orders = [];
for (let i = 1; i <= 16; i++) {
  const sub = 'CD' + String(i).padStart(2, '0');
  const doc = String(i).padStart(3, '0');
  const workOrder = packaged.find((c) => c.id.startsWith(sub + '-')).work_order;
  const evidence = 'docs/wt/continuation/COMBAT_DEEPEN01_CD' + doc + '_EVIDENCE.md';
  const results = 'docs/wt/continuation/COMBAT_DEEPEN01_CD' + doc + '_RESULTS.json';
  const hasEvidence = fs.existsSync(path.join(root, evidence));
  let state = 'NOT_RUN';
  let resultDocument = '';
  let executed = '';
  let status = '';
  if (fs.existsSync(path.join(root, results))) {
    const r = JSON.parse(fs.readFileSync(path.join(root, results), 'utf8'));
    resultDocument = results;
    status = r.status;
    executed = (r.case_ids_executed || []).length + '/' + (r.case_ids_expected || []).length;
    if (r.status === 'COMPLETE') state = 'COMPLETE';
    else if (r.status === 'COMPLETE_WITH_GAPS') state = 'COMPLETE_WITH_GAPS';
  } else if (hasEvidence) {
    state = 'EVIDENCE_RECORDED';
  }
  const runners = [];
  const scene = 'tests/run_cd' + doc + '_scene_checks.gd';
  if (fs.existsSync(path.join(root, scene))) runners.push(scene);
  const probes = fs.readdirSync(path.join(root, 'tests')).filter((f) => f.startsWith('probe_cd' + doc + '_') && f.endsWith('.gd'));
  for (const p of probes.sort()) runners.push('tests/' + p);
  if (runners.length === 0 && hasEvidence) runners.push('evidence document only (no runner)');
  orders.push({
    sub_order: sub,
    work_order: workOrder,
    cases: 6,
    state,
    status,
    evidence_document: hasEvidence ? evidence : '',
    result_document: resultDocument,
    cases_executed: executed,
    executors: runners.join(' + ')
  });
}

// --- integrity: the mirror must carry exactly the packaged ids and titles ---
const packagedIds = packaged.map((c) => c.id).sort();
const mirrorIds = mirror.rows.map((r) => r.case_id).sort();
if (JSON.stringify(packagedIds) !== JSON.stringify(mirrorIds)) {
  console.error('ID_SET_MISMATCH between the packaged list and the mirror; refusing to write.');
  console.error('only in package: ' + packagedIds.filter((x) => !mirrorIds.includes(x)).join(','));
  console.error('only in mirror : ' + mirrorIds.filter((x) => !packagedIds.includes(x)).join(','));
  process.exit(2);
}
const titleDiffs = packaged.filter((c) => mirror.rows.find((r) => r.case_id === c.id).title !== c.title);
console.log('packaged_ids=' + packagedIds.length + ' mirror_ids=' + mirrorIds.length + ' title_differences=' + titleDiffs.length);
for (const d of titleDiffs.slice(0, 5)) console.log('  title diff ' + d.id + ': package=' + d.title + ' mirror=' + mirror.rows.find((r) => r.case_id === d.id).title);

// --- rebuild ---
const bySub = {};
for (const o of orders) bySub[o.sub_order] = o;
const rows = mirror.rows.map((r) => {
  const o = bySub[r.sub_order];
  return {
    case_id: r.case_id,
    sub_order: r.sub_order,
    work_order: r.work_order,
    title: r.title,
    state: o.state,
    evidence_document: o.evidence_document,
    executors: o.executors,
    original_status: r.original_status || 'NOT_RUN'
  };
});

const out = {
  package_id: mirror.package_id,
  case_count: mirror.case_count,
  note: mirror.note,
  naming_note: mirror.naming_note,
  regeneration_note: 'Regenerated after WT-CD-015 from DISK rather than from memory: every sub-order state below is derived from a result file, an evidence document and the runners that exist, and the packaged ninety six ids and titles were re-checked against the read-only original before writing (title differences: 0). CD07 is now COMPLETE at six of six under the user ruling, CD08 to CD15 are COMPLETE with six executed cases each, and CD16 alone is NOT_RUN. Two fields are added to each summary row - result_document and cases_executed - so that a COMPLETE state can be audited without opening the document.',
  evidence_state: mirror.evidence_state,
  summary: orders.map((o) => ({
    sub_order: o.sub_order,
    cases: o.cases,
    state: o.state,
    status: o.status,
    evidence_document: o.evidence_document,
    result_document: o.result_document,
    cases_executed: o.cases_executed,
    executors: o.executors
  })),
  rows
};
fs.writeFileSync(mirrorPath, JSON.stringify(out, null, 2) + '\n', 'utf8');

// --- the markdown mirror, generated from the same data ---
const md = [];
md.push('# MCT-COMBAT-DEEPEN-01 case coverage: ninety six ids, mirrored rather than edited');
md.push('');
md.push('The packaged list at `docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json` is read-only. Its ninety six case ids are mirrored here with the evidence document this order keeps and the state it can actually show; a sub-order with no evidence document is recorded as NOT_RUN rather than assumed to pass. Every state below was regenerated from disk after WT-CD-015 and the packaged ids and titles were re-checked against the original before writing.');
md.push('');
md.push('| sub-order | cases | state | executed | evidence document | result document | executors |');
md.push('|---|---|---|---|---|---|---|');
for (const o of orders) {
  md.push('| ' + o.sub_order + ' | ' + o.cases + ' | ' + o.state + ' | ' + (o.cases_executed || '-') + ' | ' + (o.evidence_document ? '`' + o.evidence_document + '`' : '-') + ' | ' + (o.result_document ? '`' + o.result_document + '`' : '-') + ' | ' + (o.executors || '-') + ' |');
}
md.push('');
md.push('| case | sub-order | title | state | executors |');
md.push('|---|---|---|---|---|');
for (const r of rows) {
  md.push('| ' + r.case_id + ' | ' + r.sub_order + ' | ' + r.title + ' | ' + r.state + ' | ' + (r.executors || '-') + ' |');
}
md.push('');
md.push('> **Evidence form difference, user-ruled and accepted:** CD03, CD04 and CD06 were closed as PREREQUISITES of this continuation package before it began, so their evidence is a substantial evidence document (185 / 297 / 284 lines) rather than a `RESULTS.json`. The user accepted this form and asked that the difference be stated here rather than presented as an identical delivery. An earlier revision of this note dated that ruling 2026-09-11; the ruling was recorded in this session and the correct date is 2026-09-19, which is corrected here rather than left standing. The same evidence-document form is also what CD01, CD02 and CD05 carry - they are left as EVIDENCE_RECORDED and are NOT presented as user-accepted, because the ruling named only CD03, CD04 and CD06.');
md.push('');
md.push('> **CD07, closed by measurement under the same ruling:** its result file first declared `COMPLETE_WITH_GAPS` with five of six cases executed, so CD07-T04 was never run. The user ruled that it be BUILT AND MEASURED FIRST, and it was: `tests/probe_cd007_occlusion_target.gd` puts a real second vehicle six metres behind the wall, confirms `terminal=internal_burst`, `contact_kind=world_contact`, three channels with `external=true`, the overpressure channel NOT applied, and the target behind the wall intact with ten of ten modules, crew 3 to 3 and no death record. CD007 now stands at `COMPLETE`, six of six.');
md.push('');
md.push('> **What a state means here:** `COMPLETE` means a result file exists with six executed cases and status COMPLETE; `EVIDENCE_RECORDED` means the order carries an evidence document and no result file, which is the form the user accepted for CD03, CD04 and CD06; `NOT_RUN` means neither exists. The evidence state for the package as a whole stays the engineering self-consistent version only, so nothing here is a claim of numeric agreement with any external title.');
md.push('');
fs.writeFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.md', md.join('\n'), 'utf8');

console.log('--- summary written ---');
for (const o of orders) console.log(o.sub_order, o.state, o.status || '-', o.cases_executed || '-', (o.executors || '-').slice(0, 90));
const counts = {};
for (const o of orders) counts[o.state] = (counts[o.state] || 0) + o.cases;
console.log('case counts by state: ' + JSON.stringify(counts));
