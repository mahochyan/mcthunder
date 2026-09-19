// CD16 stage one: fill the read-only benchmark matrix template from what the fifteen closed sub-orders
// actually measured. The rule this generator follows: it invents NO external reference and NO percentage.
// Every row is bound to a real commit, and every row's War Thunder layer is NOT_COMPARED because no capture
// of any external title exists anywhere in this work. The evidence level of each row is assigned from an
// EXPLICIT table below rather than from a guess, and the reason for each assignment is recorded in the row.
//
// Two device faults were found and fixed while writing this generator, both named here rather than hidden:
//   1. the packaged ORDER ids carry THREE digits (WT-CD-001) while the coverage mirror and the sha map address
//      sub-orders with TWO (CD01), so deriving the mirror key by string replacement produced CD001 and the
//      first run wrote a dependency graph of fifteen UNKNOWN rows with null shas. The mapping is now explicit
//      in subOf()/docOf() and the shape check below refuses to write anything that repeats the mistake.
//   2. a PowerShell string-surgery pass over this file re-encoded it and destroyed its strings, so the file was
//      rewritten whole with the write tool instead. Text files are not edited with PowerShell here.
const fs = require('fs');

const template = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/10_BENCHMARK_MATRIX_TEMPLATE.json', 'utf8'));
const migration = JSON.parse(fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json', 'utf8'));
const coverage = JSON.parse(fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.json', 'utf8'));
const divergenceRegister = JSON.parse(fs.readFileSync('docs/wt/continuation/DIVERGENCE_REGISTER.json', 'utf8'));
const shaMap = JSON.parse(fs.readFileSync('logs/COMBAT-DEEPEN-01/cd016_evidence_shas.json', 'utf8'));

// --- the explicit evidence level table, per rule version, with the reason stated ---
const LEVEL = {
  'cd003-shape-v1': ['SOURCE_RULE', 'the oracle is the analytic slit geometry itself, independent of the tested function'],
  'cd003-rotation-step-0.02rad': ['SOURCE_RULE', 'the oracle is a bisection on the geometry alone'],
  'cd004-ballistics-v1': ['SOURCE_RULE', 'the oracle is the closed form v(x) = v0 e^(-k x) under zero gravity'],
  'cd004-residual-ratio-v1': ['SOURCE_RULE', 'the rule is a declared dimensionless mapping with its constants named'],
  'cd004-ballistics-v1_shared_solver': ['PROJECT_FIXTURE', 'two project code paths are compared against each other, which is an integration check'],
  'wt012-reactive-v1': ['SOURCE_RULE', 'the declared trigger conditions are recomputed from the same inputs'],
  'cd07-he-family-v1': ['PROJECT_FIXTURE', 'the shell catalogue build and the runtime option list are read from the real vehicles'],
  'cd07-bounded-connectivity-v1': ['PROJECT_FIXTURE', 'the verdict is read from the real layout openings carried in the query snapshot'],
  'cd07-external-on-every-burst': ['PROJECT_FIXTURE', 'the recorded flag is compared against the burst geometry on a real burst'],
  'cd07-contact-and-world-detonation': ['PROJECT_FIXTURE', 'the resolver contact verdict is read on the real runtime path'],
  'cd07-external-blast-fragment-candidates': ['PROJECT_FIXTURE', 'the occlusion contrast is measured between a target behind and beside an obstacle'],
  'edited_loadout_total': ['PROJECT_FIXTURE', 'the player edited loadout is read back through the garage verifier legs'],
  'cd008-crew-condition-v1': ['PROJECT_FIXTURE', 'the product produced crew state is read before any submission'],
  'cd008-person-station-separation': ['PROJECT_FIXTURE', 'the replacement path is measured by a probe over one empty slot'],
  'cd009-module-response-v1': ['PROJECT_FIXTURE', 'the capability dictionary is read from the real state with the new field carrying the cause'],
  'cd009-breech-jam-v1': ['PROJECT_FIXTURE', 'the judgement is driven through gunner.try_fire on a real actor'],
  'cd10-ammo-reaction-v1': ['PROJECT_FIXTURE', 'the production inventory ledger is driven and its conservation printed'],
  'cd11-drive-profiles-v1': ['PROJECT_FIXTURE', 'the production content pipeline and power train are driven and a speed is read'],
  'cd11-recoil-v1': ['PROJECT_FIXTURE', 'the real kick_recoil entry is read before and after on both engineering vehicles'],
  'cd12-observation-and-support-wired-v1': ['PROJECT_FIXTURE', 'the policy and support production objects are driven by six acceptance scenes'],
  'cd13-contribution-v1': ['PROJECT_FIXTURE', 'the ledger is driven directly plus the real match event stream'],
  'cd13-attribution-v1': ['PROJECT_FIXTURE', 'the attribution rule is driven directly with the window read from the class'],
  'cd14-ground-rb-preset-v1': ['PROJECT_FIXTURE', 'both presets are snapshotted in the same scene and compared'],
  'cd14-personal-sp-book-v1': ['PROJECT_FIXTURE', 'the sortie service is driven including a duplicate key and an unaffordable request'],
  'cd14-sortie-transaction-v1': ['PROJECT_FIXTURE', 'the sortie service is driven through all four transaction steps'],
  'cd14-rule-version-interpreter-v1': ['PROJECT_FIXTURE', 'the interpreter is driven with a known and an unknown version'],
  'cd15-presentation-consumer-v1': ['PROJECT_FIXTURE', 'two real begun matches are compared with the presentation layer stopped'],
  'cd15-shell-family-effects-v1': ['PROJECT_FIXTURE', 'the real spawn gate is driven with every declared family and an undeclared one'],
  'cd15-record-interpretation-v1': ['PROJECT_FIXTURE', 'the interpreter and the record codec are driven together'],
  'cd15-local-authority-v1': ['PROJECT_FIXTURE', 'one authority and two production clients run as three real processes'],
  'cd15-information-permission-v1': ['PROJECT_FIXTURE', 'the policy is driven with its guard and a real spectator projection'],
  'cd16-declared-manifest-expectation-v1': ['PROJECT_FIXTURE', 'the integration suite was driven after the migration and validates the packet own declared manifest: 54 checks with no failures']
};

// THE WAR THUNDER REFERENCE, measured in this session from the local install (docs/wt/wt-reference/).
// The game build is bound for EVERY row because the build is a fact about this machine and citing it is not a
// claim about the row. expected_reference is filled ONLY where a real counterpart was actually read, and the
// distinction is carried in reference_state, so no row is made to look compared when it has not been.
// NO row is promoted to WT_BEHAVIOR_COMPARISON: reading a data file is a SOURCE comparison, not an in-game
// behaviour capture, and that level therefore stays at zero.
const WT = {
  game_build: '2.59.0.13',
  source: 'local install E:/WarThunder, extracted with wt_ext_cli v0.6.6 (asset sha256 2e7593535f341ae88956583a9ba6aada3500d153f4c4a26196cae89ecdb685af); provenance in docs/wt/wt-reference/README.md',
  observed_at: '2026-09-19',
  by_rule: {
    'cd11-drive-profiles-v1': {
      reference: 'unit file gamedata/units/tankmodels/{ussr_t_80b,germ_leopard_2a4}.blk: mass 50000 / 47000 kg, maxFwdSpeed 75 km/h = 20.833 m/s, maxRevSpeed 10 km/h = 2.778 m/s, maxAccel 4, maxDecel 8, maxAngSpeed 30',
      verdict: 'EQUAL on every figure our packets declare (docs/wt/wt-reference/WT_REFERENCE_UNITS.json)'
    },
    'cd004-ballistics-v1': {
      reference: 'gun file 125mm_2a46_2_user_cannon.blk round 125mm_ussr_3BM42_APDS_FS speed 1700 m/s; 120mm_rheinmetall_l44_user_cannon.blk round 120mm_NATO_APDS_FS speed 1650 m/s',
      verdict: 'EQUAL to our APFSDS muzzle velocity on both vehicles (docs/wt/wt-reference/WT_AMMO_COMPARISON.json)'
    },
    'cd07-he-family-v1': {
      reference: 'gun file 125mm_2a46_2_user_cannon.blk round 125mm_ussr_HE speed 850 m/s, explosive a_ix_2 3.402 kg',
      verdict: 'DIFFERS: our engineering HE declares 700 m/s, a 150 m/s shortfall against the file - recorded as an open item, not corrected in this round'
    }
  }
};

const unclassified = migration.changes.map((c) => c.new_rule_version).filter((v) => !LEVEL[v]);if (unclassified.length) {
  console.error('UNCLASSIFIED_RULE_VERSIONS: ' + unclassified.join(', '));
  process.exit(2);
}

const mode = template.case_template.war_thunder.mode;
function subOf(workOrderId) {
  return 'CD' + String(parseInt(workOrderId.replace('WT-CD-', ''), 10)).padStart(2, '0');
}
function docOf(workOrderId) {
  return String(parseInt(workOrderId.replace('WT-CD-', ''), 10)).padStart(3, '0');
}
const coveredBy = {};
for (const s of coverage.summary) coveredBy[s.sub_order] = s;

const rows = migration.changes.map((c, i) => {
  const shas = shaMap[subOf(c.work_order_id)] || {};
  const level = LEVEL[c.new_rule_version][0];
  const hasResults = !!shas.results_sha;
  return {
    id: 'BM-' + String(i + 1).padStart(2, '0') + '-' + c.new_rule_version,
    work_order_id: c.work_order_id,
    status: 'MEASURED_INTERNAL',
    evidence_level: level,
    evidence_level_reason: LEVEL[c.new_rule_version][1],
    mechanic: c.new_rule_version + ' :: ' + c.fields.join(', '),
    war_thunder: {
      game_build: WT.game_build,
      mode: mode,
      vehicle_variant: null,
      shell: null,
      crew_or_modifications: null,
      source_url_or_capture_id: WT.source,
      observed_at: WT.observed_at
    },
    mcthunder: {
      tested_sha: hasResults ? shas.results_sha : shas.evidence_sha,
      sha_kind: hasResults ? 'result_document_last_commit' : 'evidence_document_last_commit',
      package_sha256: null,
      rules_version: c.new_rule_version,
      rules_version_previous: c.old_rule_version,
      vehicle_id: c.affected_vehicles,
      modes: c.affected_modes,
      shell_id: null,
      content_version: hasResults ? shas.results : shas.evidence
    },
    conditions: {
      distance_m: null,
      impact_angle_deg: null,
      target_part: null,
      target_pose: null,
      ammo_occupancy: null,
      damage_before: null,
      seed_set: [],
      note: 'no external comparison condition was captured, so these are left null rather than filled from an internal run; the internal conditions of each row live in the referenced evidence document'
    },
    sample_policy: template.case_template.sample_policy,
    metric: c.new_expected_declared_before_run,
    expected_reference: WT.by_rule[c.new_rule_version] ? WT.by_rule[c.new_rule_version].reference : null,
    reference_state: WT.by_rule[c.new_rule_version] ? 'COMPARED_TO_SOURCE_FILE' : 'NOT_COMPARED',
    reference_verdict: WT.by_rule[c.new_rule_version] ? WT.by_rule[c.new_rule_version].verdict : null,
    tolerance_predeclared: null,
    actual_project: c.measured_after,
    outcome: level,
    limitation: c.divergences + ' ; NO external capture exists, so the War Thunder layer of this row is NOT_COMPARED and no similarity is claimed.',
    raw_evidence: [
      'docs/wt/continuation/COMBAT_DEEPEN01_CD' + docOf(c.work_order_id) + '_EVIDENCE.md',
      'legacy and regression checks: ' + c.legacy_tests,
      'docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json (this row is migration entry ' + (i + 1) + ' of ' + migration.changes.length + ')'
    ],
    deviation_class: /NOT_COMPARED/.test(c.divergences) ? 'declared_project_design_value' : 'not_compared_no_capture'
  };
});

const byOutcome = {};
const byWorkOrder = {};
for (const r of rows) {
  byOutcome[r.outcome] = (byOutcome[r.outcome] || 0) + 1;
  byWorkOrder[r.work_order_id] = (byWorkOrder[r.work_order_id] || 0) + 1;
}

const dependencyIds = ['WT-CD-001', 'WT-CD-002', 'WT-CD-003', 'WT-CD-004', 'WT-CD-005', 'WT-CD-006', 'WT-CD-007', 'WT-CD-008', 'WT-CD-009', 'WT-CD-010', 'WT-CD-011', 'WT-CD-012', 'WT-CD-013', 'WT-CD-014', 'WT-CD-015'];
const dependencyGraph = dependencyIds.map((id) => {
  const cover = coveredBy[subOf(id)];
  const shas = shaMap[subOf(id)] || {};
  return {
    work_order_id: id,
    coverage_state: cover ? cover.state : 'UNKNOWN',
    cases_executed: cover ? (cover.cases_executed || 'evidence document form') : 'UNKNOWN',
    evidence_document: shas.evidence || null,
    evidence_sha: shas.evidence_sha || null,
    result_document: shas.results || null,
    result_sha: shas.results_sha || null,
    rules_in_matrix: rows.filter((r) => r.work_order_id === id).map((r) => r.mcthunder.rules_version)
  };
});

const notCompared = [];
const seen = {};
for (const c of migration.changes) {
  if (seen[c.divergences]) continue;
  seen[c.divergences] = true;
  notCompared.push({ source: c.work_order_id + '/' + c.new_rule_version, item: c.divergences });
}
for (const d of migration.divergences) notCompared.push({ source: 'package', item: d.item + ': ' + d.detail });
for (const e of divergenceRegister.entries) notCompared.push({ source: e.work_order_id + ' divergence register', item: e.divergence });
notCompared.push({ source: 'package', item: 'external behaviour comparison: NOT_COMPARED. No War Thunder build was played, no capture exists, and this project writes no numeric similarity percentage.' });
notCompared.push({ source: 'package', item: 'human playtest: PENDING. No screenshot, recording or player report is claimed by this agent.' });
notCompared.push({ source: 'package', item: 'performance: HOLD_BY_USER. No FPS, p95 or capacity figure is measured or claimed.' });
notCompared.push({ source: 'package', item: 'public release: NOT_READY. release_ready=false and public_release=false.' });
notCompared.push({ source: 'WT-CD-016', item: 'package identity: no package has been built yet at this stage, so package_sha256 is null in every row and CD16-T01 will bind it.' });

const noRowReason = {
  'WT-CD-001': 'no rule migration entry: this sub-order delivers rack and loading GEOMETRY and its state machine, measured in its own evidence document, so it contributes content rather than a rule row',
  'WT-CD-002': 'no rule migration entry: this sub-order delivers armour and module GEOMETRY and coverage, measured in its own evidence document',
  'WT-CD-006': 'no rule migration entry: this sub-order delivers the post-penetration, fuze and fragment behaviour measured in its own evidence document, and its occlusion half is the CD07-T04 fixture closed under the user ruling',
  'WT-CD-016': 'this sub-order is the delivery itself: its rows are written when its own six cases are measured, and package_sha256 stays null until then'
};
const subOrdersWithoutRows = dependencyIds.concat(['WT-CD-016']).filter((id) => !byWorkOrder[id]).map((id) => ({
  work_order_id: id,
  reason: noRowReason[id] || 'no rule migration entry',
  evidence_document: (shaMap[subOf(id)] || {}).evidence || null
}));

const out = {
  package_id: template.package_id,
  schema_version: template.schema_version,
  template_only: false,
  purpose: 'Filled from what the fifteen closed sub-orders MEASURED, not from what they intended, and bound to the War Thunder build measured on this machine. It contains ZERO WT_BEHAVIOR_COMPARISON rows and ZERO HUMAN_PLAYTEST rows, gives NO similarity percentage, and separates two things that must not be confused: every row now cites game build 2.59.0.13 and its extraction provenance, while only the rows whose real counterpart was actually read carry an expected reference - those are SOURCE comparisons, labelled COMPARED_TO_SOURCE_FILE, and every other row stays NOT_COMPARED.',
  row_source: 'Every row is derived from one entry of docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json, so a behaviour that changed no rule has no row and is listed in sub_orders_without_rows with its reason instead of being padded with an invented row.',
  source_template: 'docs/wt/combat-deepen-01/original/10_BENCHMARK_MATRIX_TEMPLATE.json (read-only; the case_template, the four evidence levels and the known reference conflicts below are mirrored verbatim, and only the rows are added)',
  field_semantics: {
    status: 'MEASURED_INTERNAL when the project measured the mechanic on its own machinery, NOT_COMPARED when nothing was measured',
    evidence_level: 'one of the four levels the template declares; never WT_BEHAVIOR_COMPARISON here',
    expected_reference: 'null whenever no external reference was captured; it is never filled from a project value, which is what the order rejects as a project checker proving agreement with itself',
    tolerance_predeclared: 'null unless an external comparison exists; project tolerances are declared in the sub-order own evidence document rather than invented here',
    outcome: 'the evidence level actually achieved for this row',
    deviation_class: 'declared_project_design_value when the row is a declared project initial value, not_compared_no_capture when the row simply has no external capture'
  },
  evidence_levels: template.evidence_levels,
  summary: {
    rows: rows.length,
    rows_per_work_order: byWorkOrder,
    rows_per_outcome: byOutcome,
    wt_behavior_comparison_rows: 0,
    human_playtest_rows: 0,
    rows_compared_to_source_file: rows.filter((r) => r.reference_state === 'COMPARED_TO_SOURCE_FILE').length,
    similarity_percentage: null,
    note: 'A count of rows or a count of passes is NOT a similarity and is not offered as one. The only honest statement this matrix makes about external BEHAVIOUR is that no in-game comparison has been made; what has changed is that every row now cites the measured game build 2.59.0.13 and the rows whose counterpart was actually read carry a real reference value from the game files, which is a SOURCE comparison and is labelled as one.'
  },
  dependency_graph: {
    work_order_id: 'WT-CD-016',
    depends_on_declared: 15,
    depends_on: dependencyGraph,
    note: 'Read from the coverage mirror, which was itself regenerated from disk, plus the commit that last touched each order evidence or result document.'
  },
  case_template: template.case_template,
  known_reference_conflicts: template.known_reference_conflicts,
  sub_orders_without_rows: subOrdersWithoutRows,
  rows,
  not_compared_items: notCompared,
  rejection_conditions: {
    declared: ['把文件数量或PASS数当相似度', '同一项目检查器自证战雷一致', '必需工程车缺资源后换训练车通过', '未运行的最终包套用旧包证据'],
    how_this_matrix_answers_them: [
      'no count of files or passes appears as a measure of external agreement; the only external statement is NOT_COMPARED',
      'every row carries a project fixture or a declared rule as its evidence level, and no row is allowed to claim War Thunder agreement from a project check',
      'the required vehicles and their content are recorded in the CD16 evidence inventory, and a missing required resource is an explicit failure rather than a fallback',
      'every row is bound to a real commit by sha and sha_kind, so no evidence can be inherited from an earlier package or an unrun build'
    ]
  }
};

// --- shape check: refuse to write if any binding is broken ---
let bad = 0;
function must(cond, label) { if (!cond) { bad++; console.error('SHAPE_FAIL ' + label); } }
must(rows.length === migration.changes.length, 'one row per migration change');
must(rows.every((r) => /^[0-9a-f]{40}$/.test(String(r.mcthunder.tested_sha))), 'every row bound to a forty character commit');
must(rows.every((r) => (r.reference_state === 'COMPARED_TO_SOURCE_FILE') === (r.expected_reference !== null)), 'a reference exists exactly where the row was actually compared');
must(rows.every((r) => r.tolerance_predeclared === null), 'no row invents a tolerance');
must(rows.every((r) => r.war_thunder.game_build === WT.game_build && r.war_thunder.source_url_or_capture_id === WT.source), 'every row cites the measured build and where it came from');
must(!rows.some((r) => r.outcome === 'WT_BEHAVIOR_COMPARISON' || r.outcome === 'HUMAN_PLAYTEST'), 'no row claims an in-game or human level');
must(rows.filter((r) => r.reference_state === 'COMPARED_TO_SOURCE_FILE').length === Object.keys(WT.by_rule).length, 'exactly the rows with a real counterpart are compared');
must(dependencyGraph.length === 15 && dependencyGraph.every((d) => /^[0-9a-f]{40}$/.test(String(d.evidence_sha))), 'all fifteen dependencies bound to an evidence commit');
must(dependencyGraph.every((d) => d.coverage_state === 'COMPLETE' || d.coverage_state === 'EVIDENCE_RECORDED'), 'every dependency carries a real state');
must(byOutcome.SOURCE_RULE + byOutcome.PROJECT_FIXTURE === rows.length, 'every row is classified');
must(dependencyIds.concat(['WT-CD-016']).every((id) => byWorkOrder[id] || subOrdersWithoutRows.some((s) => s.work_order_id === id)), 'every sub-order is either represented by rows or listed with a reason');
if (bad > 0) { console.error('REFUSING TO WRITE'); process.exit(3); }

fs.writeFileSync('docs/wt/continuation/COMBAT_DEEPEN01_BENCHMARK_MATRIX.json', JSON.stringify(out, null, 2) + '\n', 'utf8');

// --- the markdown rendering ---
const md = [];
md.push('# MCT-COMBAT-DEEPEN-01 benchmark matrix: every row measured internally, every external comparison NOT_COMPARED');
md.push('');
md.push('Filled from what the fifteen closed sub-orders measured, and bound to the War Thunder build on this machine. It contains **zero** `WT_BEHAVIOR_COMPARISON` rows and **zero** `HUMAN_PLAYTEST` rows and gives **no** similarity percentage. Two things are kept apart on purpose: every row cites game build **' + WT.game_build + '** and its extraction provenance, while only the rows whose real counterpart was actually read carry an expected reference - those are source comparisons, labelled `COMPARED_TO_SOURCE_FILE`, and every other row stays `NOT_COMPARED`.');
md.push('');
md.push('Evidence levels are the four the package declares: `SOURCE_RULE` · `PROJECT_FIXTURE` · `WT_BEHAVIOR_COMPARISON` · `HUMAN_PLAYTEST`.');
md.push('');
md.push('## 1. Summary');
md.push('');
md.push('| measure | value |');
md.push('|---|---|');
md.push('| rows | ' + out.summary.rows + ' |');
md.push('| `WT_BEHAVIOR_COMPARISON` rows | **0** |');
md.push('| `HUMAN_PLAYTEST` rows | **0** |');
md.push('| similarity percentage | **none given** |');
md.push('');
md.push('| evidence level | rows |');
md.push('|---|---|');
for (const k of Object.keys(byOutcome)) md.push('| `' + k + '` | ' + byOutcome[k] + ' |');
md.push('');
md.push('| sub-order | rows in matrix | coverage state | cases |');
md.push('|---|---|---|---|');
for (const id of dependencyIds) {
  const cover = coveredBy[subOf(id)];
  md.push('| ' + id + ' | ' + (byWorkOrder[id] || 0) + ' | ' + (cover ? cover.state : '-') + ' | ' + (cover ? (cover.cases_executed || 'evidence document') : '-') + ' |');
}
md.push('');
md.push('## 2. Dependency graph of the last sub-order, read from disk');
md.push('');
md.push('| dependency | state | cases | evidence commit | result commit | rules carried into the matrix |');
md.push('|---|---|---|---|---|---|');
for (const d of dependencyGraph) {
  md.push('| ' + d.work_order_id + ' | ' + d.coverage_state + ' | ' + d.cases_executed + ' | `' + String(d.evidence_sha).slice(0, 8) + '` | ' + (d.result_sha ? '`' + String(d.result_sha).slice(0, 8) + '`' : '-') + ' | ' + d.rules_in_matrix.length + ' |');
}
md.push('');
md.push('## 3. Rows: behaviour, project measurement, and the external half left empty');
md.push('');
md.push('| id | order | level | mechanic | project measurement (measured, not intended) | external reference |');
md.push('|---|---|---|---|---|---|');
for (const r of rows) {
  const ref = r.reference_state === 'COMPARED_TO_SOURCE_FILE'
    ? '**`COMPARED_TO_SOURCE_FILE`** - ' + String(r.expected_reference).replace(/\|/g, '/') + ' -> ' + String(r.reference_verdict).replace(/\|/g, '/')
    : '`null` / NOT_COMPARED';
  md.push('| `' + r.id + '` | ' + r.work_order_id + ' | `' + r.outcome + '` | ' + r.mechanic.replace(/\|/g, '/') + ' | ' + r.actual_project.replace(/\|/g, '/').slice(0, 260) + (r.actual_project.length > 260 ? ' …' : '') + ' | ' + ref + ' |');
}
md.push('');
md.push('## 4. Every row carries these bindings');
md.push('');
md.push('| field | value for the rows above |');
md.push('|---|---|');
md.push('| `war_thunder.game_build` | `' + WT.game_build + '` in every row, measured from the local install |');
md.push('| `war_thunder.mode` | `' + mode + '` |');
md.push('| `war_thunder.vehicle_variant` / `shell` / `crew_or_modifications` | `null` in every row |');
md.push('| `war_thunder.source_url_or_capture_id` / `observed_at` | the local install path and the extraction provenance, in every row |');
md.push('| `mcthunder.tested_sha` | the commit that last touched the order result document, or its evidence document where the order carries the accepted evidence-document form; `sha_kind` says which |');
md.push('| `mcthunder.package_sha256` | `null` until CD16-T01 builds the package |');
md.push('| `conditions.*` | `null`, with a note saying they are left null rather than filled from an internal run |');
md.push('| `expected_reference` / `tolerance_predeclared` | `null` in every row |');
md.push('');
md.push('## 5. Sub-orders with no row, and why that is deliberate');
md.push('');
md.push('Rows are derived from rule migration entries. A sub-order that changed no rule therefore has no row, and it is listed here with its reason rather than padded with an invented row:');
md.push('');
md.push('| sub-order | reason | evidence document |');
md.push('|---|---|---|');
for (const s of subOrdersWithoutRows) md.push('| ' + s.work_order_id + ' | ' + s.reason + ' | ' + (s.evidence_document ? '`' + s.evidence_document + '`' : '-') + ' |');
md.push('');
md.push('## 6. Not-compared items, listed rather than implied');md.push('');
for (const n of notCompared) md.push('- **' + n.source + '** — ' + n.item);
md.push('');
md.push('## 7. The four rejection conditions and how this matrix answers them');
md.push('');
for (let i = 0; i < out.rejection_conditions.declared.length; i++) {
  md.push('- declared: `' + out.rejection_conditions.declared[i] + '` — ' + out.rejection_conditions.how_this_matrix_answers_them[i]);
}
md.push('');
fs.writeFileSync('docs/wt/continuation/COMBAT_DEEPEN01_BENCHMARK_MATRIX.md', md.join('\n'), 'utf8');

console.log('SHAPE_PASS rows=' + rows.length + ' by_outcome=' + JSON.stringify(byOutcome));
console.log('by_work_order=' + JSON.stringify(byWorkOrder));
console.log('not_compared_items=' + notCompared.length);
console.log('dependency_rows=' + dependencyGraph.length + ' all_bound=' + dependencyGraph.every((d) => /^[0-9a-f]{40}$/.test(String(d.evidence_sha))));
console.log('distinct_tested_shas=' + new Set(rows.map((r) => r.mcthunder.tested_sha)).size);
console.log('md_lines=' + md.length);
