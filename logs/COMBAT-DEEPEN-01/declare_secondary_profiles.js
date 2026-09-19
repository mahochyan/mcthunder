// WT-EXPANSION-01 step 3: give the secondary rounds their OWN declared impact profile, so a channel can fire
// instead of refusing with secondary_round_profile_missing.
//
// The profile is the project's classic AP shape - the same fields the main gun rounds must carry - with its
// provenance stated per field: the CALIBRE, the BELT and the ROUND SPEED come from the extracted game file, while
// the penetration and ricochet coefficients are declared PROJECT policy, because the gun file states a bullet type
// and a speed and no penetration table this project may copy.
//
// The member is replaced by bracket-matching so the rest of the 238 KB packet survives byte for byte, and the
// candidate is PARSED before it is written.
const fs = require('fs');

const PROFILES = {
  'ap_i_ball': {
    family: 'AP', provenance: 'game_rule', reason: 'Project policy for a rifle-calibre armour-piercing incendiary round: the game file states the round type and its speed, not a penetration table, so the coefficients below are declared project values and not a decoded curve.',
    normalization_deg: 4, overmatch_ratio: 3, ricochet_deg: 70,
    material_coefficients: { rolled: 1.0, cast: 0.95 },
    penetration_curve: [[0, 12], [100, 9], [500, 5]],
    evidence_origin: 'game_rule', evidence_status: 'design', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'round identity and speed from the extracted machine gun file; the penetration curve is project policy'
  },
  'ap_i_t_ball': {    family: 'AP', provenance: 'game_rule', reason: 'Project policy for a heavy-calibre armour-piercing incendiary tracer round: the file names the round type ap_i_t_ball and its 865 m/s speed, while the penetration values are declared project values rather than a decoded curve.',
    normalization_deg: 5, overmatch_ratio: 4, ricochet_deg: 70,
    material_coefficients: { rolled: 1.0, cast: 0.95 },
    penetration_curve: [[0, 22], [100, 17], [500, 9], [1000, 5]],
    evidence_origin: 'game_rule', evidence_status: 'design', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'round identity, speed and 3400 m reach from the extracted 12.7 mm gun file; the penetration curve is project policy'
  },
  'ap_ball': {
    family: 'AP', provenance: 'game_rule', reason: 'Project policy for the 7.92 mm armour-piercing ball round the MG3 belt carries: the file names the round type ap_ball and its 853 m/s speed, while the penetration values are declared project values rather than a decoded curve.',
    normalization_deg: 4, overmatch_ratio: 3, ricochet_deg: 70,
    material_coefficients: { rolled: 1.0, cast: 0.95 },
    penetration_curve: [[0, 11], [100, 8], [500, 4]],
    evidence_origin: 'game_rule', evidence_status: 'design', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'round identity and speed from the extracted MG3 gun file; the penetration curve is project policy'
  }
};

function js(v, parentKeyIndent) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  if (v === null) return 'null';
  if (Array.isArray(v)) {
    const itemPad = ' '.repeat(parentKeyIndent + 4);
    const closePad = ' '.repeat(parentKeyIndent);
    if (!v.length) return '[]';
    return '[\r\n' + v.map((x) => itemPad + js(x, parentKeyIndent + 4)).join(',\r\n') + '\r\n' + closePad + ']';
  }
  const innerPad = ' '.repeat(parentKeyIndent + 4);
  const closePad = ' '.repeat(parentKeyIndent);
  return '{\r\n' + Object.keys(v).map((k) => innerPad + '"' + k + '":  ' + js(v[k], parentKeyIndent + 4)).join(',\r\n') + '\r\n' + closePad + '}';
}
function member(key, value, keyIndent) {
  const prefix = '"' + key + '":  ';
  if (Array.isArray(value)) {
    const itemPad = ' '.repeat(keyIndent + prefix.length + 4);
    const closePad = ' '.repeat(keyIndent + prefix.length);
    return ' '.repeat(keyIndent) + prefix + '[\r\n' + value.map((x) => itemPad + ps(x, keyIndent + prefix.length + 8)).join(',\r\n') + '\r\n' + closePad + ']';
  }
  return ' '.repeat(keyIndent) + prefix + js(value, keyIndent);
}
function ps(obj, keyIndent) {
  const brace = ' '.repeat(keyIndent - 4);
  const inner = [];
  for (const k of Object.keys(obj)) {
    const v = obj[k];
    const prefix = '"' + k + '":  ';
    if (Array.isArray(v)) {
      const itemPad = ' '.repeat(keyIndent + prefix.length + 4);
      const closePad = ' '.repeat(keyIndent + prefix.length);
      inner.push(' '.repeat(keyIndent) + prefix + '[\r\n' + v.map((x) => itemPad + js(x, keyIndent + prefix.length + 4)).join(',\r\n') + '\r\n' + closePad + ']');
    } else {
      inner.push(' '.repeat(keyIndent) + prefix + js(v, keyIndent));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}
// find the span of the top-level secondary_weapons member by bracket matching
function spanOf(text, key) {
  const needle = '"' + key + '":  [';
  const at = text.indexOf(needle);
  if (at < 0) return null;
  let i = text.indexOf('[', at);
  let depth = 0;
  for (let p = i; p < text.length; p++) {
    const c = text[p];
    if (c === '[' || c === '{') depth++;
    else if (c === ']' || c === '}') { depth--; if (depth === 0) return { start: at, end: p + 1 }; }
  }
  return null;
}

for (const id of ['ussr_t_80b', 'germ_leopard_2a4']) {
  const p = 'configs/vehicles/engineering/' + id + '.json';
  const text = fs.readFileSync(p, 'utf8');
  const parsed = JSON.parse(text);
  const rows = parsed.secondary_weapons;
  for (const row of rows) {
    const prof = PROFILES[row.round];
    if (!prof) { console.error('NO PROFILE for round ' + row.round); process.exit(2); }
    row.impact_profile = prof;
  }
  const span = spanOf(text, 'secondary_weapons');
  if (!span) { console.error('SPAN_NOT_FOUND in ' + p); process.exit(3); }
  const replacement = member('secondary_weapons', rows, 4);
  const out = text.slice(0, span.start) + replacement + text.slice(span.end);
  const check = JSON.parse(out);
  if (check.secondary_weapons.length !== rows.length || !check.secondary_weapons[0].impact_profile) { console.error('PARSE_CHECK_FAILED ' + p); process.exit(4); }
  if ((check.shell_catalog.shells || []).length !== (parsed.shell_catalog.shells || []).length) { console.error('SHELL CATALOG CHANGED ' + p); process.exit(5); }
  fs.writeFileSync(p, out, 'utf8');
  const after = JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(p + ' :: secondary_weapons=' + after.secondary_weapons.length + ' profile_families=' + after.secondary_weapons.map((r) => r.impact_profile.family + '/' + r.impact_profile.penetration_curve.length + 'pts').join(',') + ' shells=' + after.shell_catalog.shells.length + ' bytes=' + out.length);
}
