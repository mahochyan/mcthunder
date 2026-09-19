// WT-EXPANSION-02 / CD16-T04: append the expectation migration for the in-game live-round (life) verifier's new-life
// round total, in the SAME PowerShell ConvertTo-Json style the table uses, with the serialiser self-checked against the
// previous entry before anything is written.
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
  old_rule_version: 'cd16-modern-life-fixture-eight-round-v1',
  new_rule_version: 'cd16-modern-life-fixture-derived-edit-v1',
  affected_vehicles: 'ussr_t_80b',
  affected_modes: 'player_live_round',
  fields: ['modern_life_verifier.expected_new_life_rounds'],
  reason: 'The same-life live-round fixture asserts that a new player life restores the edited loadout, and it carried a literal 8 - four rounds for each of TWO shells. CD07 delivered the third round, so the fixture edits twelve and the literal was stale in exactly the way the modern-match verifier 18 was. The fixture had ALSO stopped working for a second and more serious reason: it looked crew_states up by STATION id, while CD08-T02 separated the person identity from the station and the role, so no seat was ever found alive, fire_requested was never set and the scripted enemy never fired - measured as shots=0 with query_events empty while the SAME case passed on three 2026-09-17 builds (9 checks, exit 0). Both are repaired here: the seat is resolved through the production mapping DamageResolver uses, and the expected total is derived from the fixture own edit.',
  reference_sources: ['the fixture own edit in scripts/diagnostics/modern_life_verifier.gd', 'the production mapping in scripts/damage/damage_resolver.gd station -> role -> person', 'configs/vehicles/engineering/ussr_t_80b.json compatible_shells'],
  old_reference_unchanged: true,
  legacy_behavior_retained: true,
  legacy_entry: 'The fixture itself is untouched in what it proves: a scripted enemy operator, the real river team director, the real weapons, armour, damage, tickets and respawn delay, and a real mouse click on the production respawn button. The older two shell behaviour stays covered because the derived total is 8 for a two shell vehicle, which is the case the literal was written for.',
  legacy_tests: 'the fixture from the source tree: PLAYER_LIVE_ROUND_PASS with waiting.png and respawned.png produced (logs/COMBAT-DEEPEN-01/modern-srcflow/verify-modern-life-20260920-035706-676), against PLAYER_LIVE_ROUND_FAIL with 3 failures in the 5c6a8919 package (logs/WT040-package/5c6a8919.../life-20260920-035442-039) and PASS on three 2026-09-17 builds.',
  new_expected_declared_before_run: 'The scripted enemy must find the first living crew seat through the production station to role to person mapping and actually fire, the same player life must take recorded contact and damage and die exactly once, the production ticket cost must be deducted, and the new life must restore exactly the loadout this fixture edits - derived, not remembered.',
  independent_oracle: 'The production mapping in damage_resolver.gd for the seat, and the fixture own edit for the round total; the death, the ticket deduction and the new life are read from the live director and actor state rather than from the fixture own bookkeeping.',
  measured_before: 'Measured before: PLAYER_LIVE_ROUND_FAIL, 6 checks with 3 failed - enemy actual round records contact and damage on the same player life, that player life dies exactly once from enemy live rounds, one death deducts the production ticket cost - with LIVE_ROUND shots=0 and query_events=[] while the fixture idle for the whole 90 s budget. The check count fell from 9 to 6 because the later legs never ran.',
  measured_after: 'Measured after: PLAYER_LIVE_ROUND_PASS from the source tree on the same fixture, with the enemy firing, the player life dying once, the ticket cost deducted and the new life restoring the derived total; waiting.png and respawned.png are produced. The package case is re-run on the rebuilt package as the CD16-T04 evidence.',
  migration: 'No stored value changes: the fixture edit and the profile format are identical before and after, and old profiles keep their counts. What moves is where the seat and the expected total are read from.',
  rollback: 'Restore the station keyed crew lookup and the literal 8; the fixture then fails again with shots=0 exactly as the 5c6a8919 package did.',
  divergences: 'The expected total is now derived from the fixture own edit, so the historical 8 lives in THIS entry. The four rounds per shell remain the fixture edit policy, a project design value rather than a War Thunder value.'
};

const anchorA = '"divergences":  "The expected total is now derived from the flow own edit rather than stated, so the historical 18 lives in THIS entry instead of inside the check. The per spin counts 12 and 6 remain the flow edit policy, a project design value rather than a War Thunder value, and the check compares the product against that policy and not against the game."\r\n                    }\r\n                ],';
if (!raw.includes(anchorA)) { console.error('ANCHOR_A_MISSING'); process.exit(3); }
let out = raw.replace(anchorA, anchorA.replace('\r\n                    }\r\n                ],', '\r\n                    },\r\n' + ps(entry, 24) + '\r\n                ],'));

const indexLine = 'WT-CD-016: the same-life live-round fixture looked crew up by station id after CD08-T02 separated the person from the station, so its scripted enemy never fired; the seat now resolves through the production mapping and the new-life total is derived from the fixture own edit';
const indexAnchor = '"WT-CD-016: the in-game player-flow verifier carried a hard coded eighteen-round total that CD07 own HE addition made stale, and the spawn, the next match and the fresh process now compare against the loadout the flow actually edits"\r\n                        ],';
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
