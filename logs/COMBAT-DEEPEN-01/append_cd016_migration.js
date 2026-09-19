// CD16: record the expectation migration the user ruled, in the same PowerShell ConvertTo-Json style the table
// already uses. As with the CD15 append, the serialiser PROVES itself against the last existing entry before
// anything is written, and the script refuses to write when that check fails.
const fs = require('fs');
const path = 'docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json';
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
  old_rule_version: 'engineering_runtime_two_round_manifest_expectation',
  new_rule_version: 'cd16-declared-manifest-expectation-v1',
  affected_vehicles: 'ussr_t_80b and germ_leopard_2a4',
  affected_modes: 'engineering_runtime_checks',
  fields: ['shell_catalog.shells', 'shell_catalog.default', 'shell_options', 'muzzle_velocity_mps', 'effect_policy'],
  reason: 'CD07 deliberately added an HE round to the T-80B packet, so the integration suite fixed two-round expectation became stale and the package gate refused the candidate. The delivery protocol allows a new expectation with an explicit version when a rule changed, provided the old rule regression is kept and the semantic change is explained, so this entry records that migration rather than a relaxation. The user ruled this path explicitly on 2026-09-19.',
  reference_sources: ['R11', 'W07'],
  old_reference_unchanged: true,
  legacy_behavior_retained: true,
  legacy_entry: 'The two-round path is still asserted: the Leopard declares and validates exactly two rounds, and the APFSDS default, the HEAT chemical round, the natural reload of the HEAT round, the two real launches and the reset restoration are still checked for BOTH vehicles.',
  legacy_tests: 'tests/run_engineering_runtime_checks.gd 54/0 after the migration; the same suite stood at 44/0 with the old two-round assertion on the 2026-09-17 clean build and at 26/1 at HEAD before the migration',
  new_expected_declared_before_run: 'Every declared round must be identified and must carry the family policy it declares (APFSDS long_rod, HEAT chemical, HE he_blast), the default must still be the APFSDS long-rod round, and the runtime option count must equal the packet own declaration instead of a literal.',
  independent_oracle: 'The packet own shell_catalog compared against the runtime gunner.shell_options, with the declared default resolving to a declared round.',
  measured_before: 'Measured at HEAD before the migration: 26 checks, 1 failed - ussr_t_80b: the packet carries exactly two authored rounds and a default - and the suite returned early, so twelve further checks never ran. The same suite passed with 44 checks and no failures on the 2026-09-17 clean build, before CD07 added the HE round.',
  measured_after: 'Measured after the migration: 54 checks, 0 failed. The T-80B declares three rounds and all three validate with their own policies; the Leopard declares two and both validate; the HEAT reload, both real launches and the reset restoration still pass for both vehicles.',
  migration: 'The assertion now reads the declaration instead of a literal, so a future authored round is validated rather than breaking the suite, while a round with an undeclared family or a wrong effect policy still fails.',
  rollback: 'Restore the literal two-round assertion; the T-80B HE round then fails the suite again exactly as it did at HEAD.',
  divergences: 'The three-round manifest is a declared project content fact with comparison NOT_COMPARED; no real T-80B ammunition loadout is claimed.'
};

const anchorA = '"divergences":  "Precision, expiry and attenuation values remain declared project design initial values with comparison NOT_COMPARED, and thermal and radar remain explicitly unsupported states rather than a filter standing in for a sensor."\r\n                    }\r\n                ],';
if (!raw.includes(anchorA)) { console.error('ANCHOR_A_MISSING'); process.exit(3); }
let out = raw.replace(anchorA, anchorA.replace('\r\n                    }\r\n                ],', '\r\n                    },\r\n' + ps(entry, 24) + '\r\n                ],'));

const indexAnchor = '"WT-CD-015: the presentation layer, the shell family gate, the replay record interpretation, the local authority across three processes and the information permission are CONFIRMED and DRIVEN on the same chain rather than replaced"\r\n                        ],';
if (!out.includes(indexAnchor)) { console.error('ANCHOR_B_MISSING'); process.exit(4); }
const indexLine = 'WT-CD-016: the integration gate found a stale expectation left by CD07 own HE addition, and the assertion now reads the declared manifest instead of a literal count';
out = out.replace(indexAnchor, indexAnchor.replace('\r\n                        ],', ',\r\n                            ' + JSON.stringify(indexLine) + '\r\n                        ],'));

fs.writeFileSync(path, out, 'utf8');
const check = JSON.parse(fs.readFileSync(path, 'utf8'));
console.log('changes=' + check.changes.length);
console.log('last=' + check.changes[check.changes.length - 1].work_order_id + ' / ' + check.changes[check.changes.length - 1].change_kind + ' / ' + check.changes[check.changes.length - 1].new_rule_version);
console.log('every_entry_20_keys=' + check.changes.every((c) => Object.keys(c).length === 20));
console.log('migration_index_lines=' + check.migration_index.length);
const bytes = fs.readFileSync(path);
console.log('non_ascii_bytes=' + bytes.filter((x) => x > 127).length + ' BOM=' + (bytes[0] === 0xEF));
