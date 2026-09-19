// WT-EXPANSION-02 / CD16-T02-T03: append the expectation migration for the in-game player-flow verifier's round total,
// in the SAME PowerShell ConvertTo-Json style the table already uses. As with the CD15 and CD16 appends, the serialiser
// PROVES itself against the last existing entry before anything is written and refuses to write when that fails.
const fs = require('fs');
const path = 'E:/AIprogram/mcthunder-cont/docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json';
const raw = fs.readFileSync(path, 'utf8');

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
      const items = v.map((x) => itemPad + js(x)).join(',\r\n');
      inner.push(pad + prefix + '[\r\n' + items + '\r\n' + closePad + ']');
    } else {
      inner.push(pad + prefix + js(v));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}

const doc = JSON.parse(raw);
const last = doc.changes[doc.changes.length - 1];
if (!raw.includes(ps(last, 24))) {
  console.error('STYLE_CHECK_FAIL: the serialiser does not reproduce the existing last entry byte for byte.');
  process.exit(2);
}
console.log('STYLE_CHECK_PASS: the serialiser reproduces entry ' + doc.changes.length + ' byte for byte.');

const entry = {
  work_order_id: 'WT-CD-016',
  change_kind: 'expectation_migration',
  old_rule_version: 'cd16-modern-player-flow-literal-18-v1',
  new_rule_version: 'cd16-modern-player-flow-derived-edit-v1',
  affected_vehicles: 'ussr_t_80b',
  affected_modes: 'player_flow',
  fields: ['modern_match_verifier.expected_rounds', 'modern_match_verifier.resume_proof_total'],
  reason: 'scripts/diagnostics/modern_match_verifier.gd asserted a hard coded total of 18 rounds in three places. That literal was correct while the T-80B carried TWO shells, 12 primary plus 6 secondary; CD07 then delivered the third round HE, so the SAME edit of every shell spin produces 12 + 6 + 6 = 24 and the assertion failed for a delivered rule change it never followed. The user standing ruling is to migrate the expectation under the protocol rather than relax it, so this entry records the migration. Measured on the 4a2c9744 candidate package and reproduced in the source tree: MODERN_SPAWN id=ussr_t_80b rounds=24 against the literal 18, with the saved loadout 12/6/6 AND the profile save check passing - the spawn matched the edit exactly and only the literal was stale.',
  reference_sources: ['the flow own edit in scripts/diagnostics/modern_match_verifier.gd', 'configs/vehicles/engineering/ussr_t_80b.json compatible_shells eng_125_apfsds_v1, eng_125_heat_v1, eng_125_he_v1'],
  old_reference_unchanged: true,
  legacy_behavior_retained: true,
  legacy_entry: 'The flow itself is untouched: its garage edit, its deploy click, its keyboard and mouse pilot, its captures and its separate process restart all stay. The older two shell behaviour remains covered because the derived total is 18 for a two shell vehicle, which is exactly the case the literal was written for.',
  legacy_tests: 'the in game player flow: 30 checks, 0 failed, MODERN_MATCH_PASS in the source tree after the migration (logs/COMBAT-DEEPEN-01/modern-srcflow/20260920-020804-483), against 30 checks and 2 failed before it (logs/COMBAT-DEEPEN-01/modern-srcflow/20260920-020246-510). The 4a2c9744 package run that found it is kept as the before evidence (logs/WT040-modern-player/4a2c9744.../20260920-015630-506).',
  new_expected_declared_before_run: 'The spawn, the next match and the fresh process must each consume EXACTLY the loadout this flow edits, derived from the edit itself through edited_count per shell spin instead of a remembered number, so a delivered change to the vehicle shell set can never leave a stale literal behind again.',
  independent_oracle: 'The flow own edit is the oracle for the spawn and for the next match. For the fresh process the oracle is the profile read back from disk in a separate process, checked shell by shell against the same edit rule rather than against a total.',
  measured_before: 'Measured before: 30 checks and 2 failed, both on the literal 18 - actual player spawn consumes edited eighteen-round loadout and result button starts next river match with selected vehicle and saved loadout - in the 4a2c9744 package AND in the source tree, while the diagnostic showed the spawn carried the edited total exactly and the profile save check passed.',
  measured_after: 'Measured after: 30 checks, 0 failed, MODERN_MATCH_PASS in the source tree on the same scenario, with MODERN_SPAWN printing rounds=24 wanted_rounds=24. The package flow, which additionally runs the separate process resume proof and captures 06_fresh_process, is re-run on the rebuilt package and is the CD16 T02 T03 T06 evidence.',
  migration: 'No stored value changes and no profile format changes: the edit and the on disk loadout are identical before and after, and old profiles keep their counts. Only the source of truth for the assertion moves.',
  rollback: 'Restore the literal 18 in the three places; the two checks fail again with the same MODERN_SPAWN diagnostic line.',
  divergences: 'The expected total is now derived from the flow own edit rather than stated, so the historical 18 lives in THIS entry instead of inside the check. The per spin counts 12 and 6 remain the flow edit policy, a project design value rather than a War Thunder value, and the check compares the product against that policy and not against the game.'
};

const anchorA = '"divergences":  "The 850 m/s is now a value taken from the local game build and not a project design value, while the HE damage model, its 30 mm flat curve and its blast channels remain declared project policy with comparison NOT_COMPARED. The alignment is a SOURCE comparison against a data file, not an in-game behaviour capture."\r\n                    }\r\n                ],';
if (!raw.includes(anchorA)) { console.error('ANCHOR_A_MISSING'); process.exit(3); }
let out = raw.replace(anchorA, anchorA.replace('\r\n                    }\r\n                ],', '\r\n                    },\r\n' + ps(entry, 24) + '\r\n                ],'));

const indexLine = 'WT-CD-016: the in-game player-flow verifier carried a hard coded eighteen-round total that CD07 own HE addition made stale, and the spawn, the next match and the fresh process now compare against the loadout the flow actually edits';
const indexAnchor = '"WT-CD-016: the engineering HE velocity is aligned to the value the local game file states, 700 to 850 m/s, as a declared behavior change with its measured before and after"\r\n                        ],';
if (!out.includes(indexAnchor)) { console.error('ANCHOR_B_MISSING'); process.exit(4); }
out = out.replace(indexAnchor, indexAnchor.replace('\r\n                        ],', ',\r\n                            ' + JSON.stringify(indexLine) + '\r\n                        ],'));

fs.writeFileSync(path, out, 'utf8');
const check = JSON.parse(fs.readFileSync(path, 'utf8'));
console.log('changes=' + check.changes.length);
console.log('last=' + check.changes[check.changes.length - 1].work_order_id + ' / ' + check.changes[check.changes.length - 1].change_kind + ' / ' + check.changes[check.changes.length - 1].new_rule_version);
console.log('every_entry_20_keys=' + check.changes.every((c) => Object.keys(c).length === 20));
console.log('migration_index_lines=' + check.migration_index.length);
const bytes = fs.readFileSync(path);
console.log('non_ascii_bytes=' + bytes.filter((x) => x > 127).length + ' BOM=' + (bytes[0] === 0xEF));
