// CD16 stage two shape check: the contract is only worth writing if its factual claims are checkable.
// This verifies the contract against the filesystem and against the READ-ONLY packaged order, and it fails
// loudly when a claim cannot be confirmed - a contract whose numbers do not match disk is worse than none.
const fs = require('fs');

const contractPath = 'docs/wt/continuation/COMBAT_DEEPEN01_CD016_CONTRACT.md';
let bad = 0;
function ok(cond, label, detail) {
  if (!cond) bad++;
  console.log((cond ? 'PASS ' : 'FAIL ') + label + (detail === undefined ? '' : ' :: ' + detail));
}

ok(fs.existsSync(contractPath), 'the contract document exists');
const contract = fs.readFileSync(contractPath, 'utf8');

// 1. every section the contract declares is present
for (const heading of ['## 1. The four deliverable classes, each with the gate that proves it',
  '## 2. The four rejection conditions, and the check that must FAIL on each',
  '## 3. Required content: missing means FAIL, never a downgrade',
  '## 4. The gate order, shortest first',
  '## 5. Identity binding',
  '## 6. Explicitly out of scope for this sub-order']) {
  ok(contract.includes(heading), 'section present: ' + heading.slice(0, 42));
}

// 2. the required content it names actually exists
const required = [
  'configs/vehicles/engineering/ussr_t_80b.json',
  'configs/vehicles/engineering/germ_leopard_2a4.json',
  'configs/vehicles/historical/us_m4a3_75w_vvss_1944.json',
  'configs/vehicles/historical/us_m24_m6_t85e1_1951.json',
  'configs/vehicles/historical/us_m26_m3_1945.json',
  'configs/vehicles/historical/us_m36_m4a1_1945.json',
  'scenes/maps/map_river_team.tscn',
  'scenes/maps/river_junction_range.tscn',
  'scenes/app.tscn',
  'export_presets.cfg',
  'tests/package_doc_names.json',
  'tests/build_release.ps1'
];
for (const p of required) ok(fs.existsSync(p), 'required content exists: ' + p);

// 3. the two byte counts the contract quotes must match disk, because a contract with stale numbers misleads
const sizes = { 'configs/vehicles/engineering/ussr_t_80b.json': 238360, 'configs/vehicles/engineering/germ_leopard_2a4.json': 183977 };
for (const [p, n] of Object.entries(sizes)) {
  const actual = fs.statSync(p).size;
  ok(actual === n, 'quoted size matches disk for ' + p, 'contract=' + n + ' disk=' + actual);
  ok(contract.includes(String(n) + ' bytes'), 'the contract quotes the measured size for ' + p);
}

// 4. the four rejection conditions in the contract must be the packaged ones, read from the read-only original
const orders = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/07_WORK_ORDERS.json', 'utf8'));
const wo = orders.items.find((o) => o.id === 'WT-CD-016');
for (const r of wo.rejection_conditions) ok(contract.includes(r), 'packaged rejection condition quoted: ' + r);
ok(wo.deliverables.every((d) => contract.includes(d)), 'all four packaged deliverables named in the contract');

// 5. the standing flags must be declared and none flipped
for (const flag of ['release_ready=false', 'public_release=false', 'human=PENDING', 'performance=HOLD_BY_USER']) {
  ok(contract.includes(flag), 'standing flag declared: ' + flag);
}

// 6. the gate order must name all six cases in order
let last = -1;
let ordered = true;
for (const c of ['CD16-T01', 'CD16-T02', 'CD16-T03', 'CD16-T04', 'CD16-T05', 'CD16-T06']) {
  const at = contract.indexOf(c);
  if (at < 0 || at < last) ordered = false;
  last = at;
}
ok(ordered && last >= 0, 'all six case ids appear in the contract in order');

console.log(bad === 0 ? 'CD16_CONTRACT_SHAPE_PASS' : 'CD16_CONTRACT_SHAPE_FAIL (' + bad + ')');
process.exit(bad === 0 ? 0 : 1);
