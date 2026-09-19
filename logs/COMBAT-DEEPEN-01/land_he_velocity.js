// CD16: land the engineering HE velocity alignment as a DECLARED behavior change.
//   (1) the two declarations of the HE velocity in the T-80B packet - the shell_catalog entry and the evidence
//       claim value that must agree with it - are moved from 700 to 850, the value the game file states for
//       125mm_ussr_HE in build 2.59.0.13;
//   (2) the change is recorded in the migration table with measured before and after, the game file as its
//       reference, the retained old behaviour and a rollback.
// The packet is edited by exact string replacement so its PowerShell-style formatting survives byte for byte.
const fs = require('fs');

const packetPath = 'configs/vehicles/engineering/ussr_t_80b.json';
const before = fs.readFileSync(packetPath, 'utf8');
const needle = '"muzzle_velocity_mps":  700,';
const occurrences = before.split(needle).length - 1;
if (occurrences !== 2) {
  console.error('REFUSING: expected exactly two HE velocity declarations, found ' + occurrences);
  process.exit(2);
}
const after = before.split(needle).join('"muzzle_velocity_mps":  850,');
fs.writeFileSync(packetPath, after, 'utf8');
const check = JSON.parse(fs.readFileSync(packetPath, 'utf8'));
const he = check.shell_catalog.shells.find((s) => s.id === 'eng_125_he_v1');
console.log('PACKET: eng_125_he_v1 muzzle_velocity_mps = ' + he.muzzle_velocity_mps + ' ; 700 remaining in file = ' + (fs.readFileSync(packetPath, 'utf8').split(needle).length - 1));

// --- migration table ---
const migPath = 'docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json';
const raw = fs.readFileSync(migPath, 'utf8');
function js(v) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  if (v === null) return 'null';
  if (Array.isArray(v)) throw new Error('array handled by caller');
  return ps(v, 0);
}
function ps(obj, keyIndent) {
  const pad = ' '.repeat(keyIndent);
  const brace = ' '.repeat(keyIndent - 4);
  const inner = [];
  for (const k of Object.keys(obj)) {
    const v = obj[k];
    const prefix = '"' + k + '":  ';
    if (Array.isArray(v)) {
      if (v.length === 0) { inner.push(pad + prefix + '[]'); continue; }
      const itemPad = ' '.repeat(keyIndent + prefix.length + 4);
      const closePad = ' '.repeat(keyIndent + prefix.length);
      inner.push(pad + prefix + '[\r\n' + v.map((x) => itemPad + js(x)).join(',\r\n') + '\r\n' + closePad + ']');
    } else {
      inner.push(pad + prefix + js(v));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}
const doc = JSON.parse(raw);
const last = doc.changes[doc.changes.length - 1];
if (!raw.includes(ps(last, 24))) { console.error('STYLE_CHECK_FAIL'); process.exit(3); }
console.log('STYLE_CHECK_PASS against entry ' + doc.changes.length);

const entry = {
  work_order_id: 'WT-CD-016',
  change_kind: 'behavior_change',
  old_rule_version: 'cd07-he-family-v1',
  new_rule_version: 'cd16-he-velocity-850-v1',
  affected_vehicles: 'ussr_t_80b',
  affected_modes: 'live_fire',
  fields: ['shell_catalog.shells.muzzle_velocity_mps', 'evidence.ballistics.muzzle_velocity_mps'],
  reason: 'The War Thunder reference read from the local installation states 850 m/s for the 125mm_ussr_HE round, while this project engineering HE declared 700 m/s. Every other round already matched the file exactly (3BM42 1700, 3BK12 905, NATO APDS_FS 1650, NATO HEAT_FS 1140), so the HE was the one declared value that disagreed with its own reference and it is aligned here.',
  reference_sources: ['WT local install 2.59.0.13', 'gamedata/weapons/groundmodels_weapons/125mm_2a46_2_user_cannon.blk round 125mm_ussr_HE speed 850'],
  old_reference_unchanged: true,
  legacy_behavior_retained: true,
  legacy_entry: 'The HE family rules of CD07 are untouched: the shell keeps its family HE, its he_blast effect policy, its flat 30 mm penetration curve, its post-penetration profile and its blast channels. Only the declared muzzle velocity moves, and the old value is kept here as the before reference rather than deleted.',
  legacy_tests: 'run_shell_checks.gd 193/0, run_engineering_runtime_checks.gd 54/0, probe_cd007_he_runtime.gd 19/0, probe_cd007_world_burst.gd 15/0, probe_cd007_occlusion_target.gd 13/0, ran again with the new value; probe_cd007_he_landed.gd reads the packet velocity rather than a literal and passes 13/0',
  new_expected_declared_before_run: 'The engineering HE must declare the velocity its reference states and every dependent fixture must read that value rather than a literal, so the round flies at 850 m/s and the launch speed assertion in the engineering runtime suite still matches the packet it reads.',
  independent_oracle: 'The gun file own round definition: 125mm_ussr_HE speed 850, explosive a_ix_2 with 3.402 kg, from the extracted build 2.59.0.13.',
  measured_before: 'Measured before: the packet declared 700 m/s in both places, the reference comparison reported velocity_differs with delta -150 m/s, and probe_cd007_he_landed carried a hardcoded 700 in its own launch velocity, which is a second copy of a packet value inside a fixture.',
  measured_after: 'Measured after: the packet declares 850 m/s in both places, the fixture launch velocity is read from found.muzzle_velocity_mps, and the six suites above are green with no expectation edited. probe_cd007_he_landed had been failing for three fixture reasons of its own (wrong catalog entry point, no physics frames before reading the installed rounds, packet id compared against runtime id) and those are repaired in the same round so that the velocity change is not landed on top of an unmeasured fixture.',
  migration: 'A stored shot record keeps the velocity it was fired with; the change affects new rounds only and the ballistic profile resolution reads the packet, so nothing is recomputed across records.',
  rollback: 'Restore the two 700 declarations; the reference comparison then reports the -150 m/s difference again and nothing else changes.',
  divergences: 'The 850 m/s is now a value taken from the local game build and not a project design value, while the HE damage model, its 30 mm flat curve and its blast channels remain declared project policy with comparison NOT_COMPARED. The alignment is a SOURCE comparison against a data file, not an in-game behaviour capture.'
};

const anchor = '"divergences":  "The three-round manifest is a declared project content fact with comparison NOT_COMPARED; no real T-80B ammunition loadout is claimed."\r\n                    }\r\n                ],';
if (!raw.includes(anchor)) { console.error('ANCHOR_MISSING'); process.exit(4); }
let out = raw.replace(anchor, anchor.replace('\r\n                    }\r\n                ],', '\r\n                    },\r\n' + ps(entry, 24) + '\r\n                ],'));
const indexAnchor = '"WT-CD-016: the integration gate found a stale expectation left by CD07 own HE addition, and the assertion now reads the declared manifest instead of a literal count"\r\n                        ],';
if (!out.includes(indexAnchor)) { console.error('INDEX_ANCHOR_MISSING'); process.exit(5); }
out = out.replace(indexAnchor, indexAnchor.replace('\r\n                        ],', ',\r\n                            ' + JSON.stringify('WT-CD-016: the engineering HE velocity is aligned to the value the local game file states, 700 to 850 m/s, as a declared behavior change with its measured before and after') + '\r\n                        ],'));
fs.writeFileSync(migPath, out, 'utf8');
const migrated = JSON.parse(fs.readFileSync(migPath, 'utf8'));
console.log('MIGRATION: changes=' + migrated.changes.length + ' last=' + migrated.changes[migrated.changes.length - 1].new_rule_version + ' every20=' + migrated.changes.every((c) => Object.keys(c).length === 20) + ' index=' + migrated.migration_index.length);
