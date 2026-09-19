// WT-EXPANSION-01 step 1: declare the REAL secondary armament in both engineering packets, in the same
// PowerShell-style formatting the packets already use, and in the same provenance style their other values use.
// The edit is an insertion before the top-level shell_catalog key so the rest of the file survives byte for byte;
// the anchor is checked for uniqueness and the result is parsed before it is written.
const fs = require('fs');

// FLAT ON PURPOSE: a first attempt nested an `evidence` object inside each entry, and the serializer produced a
// closing brace at the wrong level, which the parse check refused before anything was written. The provenance is
// therefore carried as flat fields in the same shape the rest of the packet uses for scalar values, and the
// source list is an array of strings, which is the shape the serializer has already been validated against.
const DECL = {
  ussr_t_80b: [
    { group: 'coaxial', gun: '7.62mm_PKT_user_machinegun', caliber_mm: 7.62, belt: 750, reload_s: 8, cadence_rps: 11.66, round: 'ap_i_ball', speed_mps: 817.5, trigger: 'gunner1', trigger_group: 'coaxial', evidence_origin: 'warthunder_reference', evidence_status: 'reference', evidence_unit: 'structured', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'gamedata/weapons/groundmodels_weapons/7_62mm_pkt_user_machinegun.blk: belt 750, reloadTime 8, shotFreq 11.66, round ap_i_ball at 817.5 m/s' },
    { group: 'machinegun', gun: '12_7mm_NSV_t_80_user_cannon', caliber_mm: 12.7, belt: 250, reload_s: 5, cadence_rps: 11.666, round: 'ap_i_t_ball', speed_mps: 865, trigger: 'gunner2', trigger_group: 'machinegun', evidence_origin: 'warthunder_reference', evidence_status: 'reference', evidence_unit: 'structured', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'gamedata/weapons/groundmodels_weapons/12_7mm_nsv_t_80_user_cannon.blk: belt 250, reloadTime 5, shotFreq 11.666, round ap_i_t_ball at 865 m/s, aimMaxDist 3400 m' }
  ],
  germ_leopard_2a4: [
    { group: 'coaxial', gun: '7_92mm_MG3_user_machinegun', caliber_mm: 7.92, belt: 200, reload_s: 8, cadence_rps: 20, round: 'ap_ball', speed_mps: 853, trigger: 'gunner1', trigger_group: 'coaxial', evidence_origin: 'warthunder_reference', evidence_status: 'reference', evidence_unit: 'structured', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'gamedata/weapons/groundmodels_weapons/7_92mm_mg3_user_machinegun.blk: belt 200, reloadTime 8, shotFreq 20, round ap_ball at 853 m/s' },
    { group: 'machinegun', gun: '7_92mm_MG3_user_machinegun', caliber_mm: 7.92, belt: 200, reload_s: 8, cadence_rps: 20, round: 'ap_ball', speed_mps: 853, trigger: 'gunner2', trigger_group: 'machinegun', evidence_origin: 'warthunder_reference', evidence_status: 'reference', evidence_unit: 'structured', evidence_source_refs: ['wt-2.59.0.13'], evidence_location: 'gamedata/weapons/groundmodels_weapons/7_92mm_mg3_user_machinegun.blk: belt 200, reloadTime 8, shotFreq 20, round ap_ball at 853 m/s' }
  ]
};

function js(v, parentKeyIndent) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  if (v === null) return 'null';
  if (Array.isArray(v)) throw new Error('array handled by caller');
  // A nested object keys sit four columns deeper than the key that holds it, which is the same rule the arrays use.
  return ps(v, parentKeyIndent + 4);
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
      inner.push(pad + prefix + '[\r\n' + v.map((x) => itemPad + js(x, keyIndent + prefix.length + 4)).join(',\r\n') + '\r\n' + closePad + ']');
    } else {
      inner.push(pad + prefix + js(v, keyIndent));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}

// A single MEMBER line for insertion into an existing object. A first attempt serialised a whole wrapper object
// with ps({secondary_weapons: ...}) and spliced it in, which added an extra brace level and produced a file whose
// parse error pointed at the first inserted line - refused by the guard before anything was written.
function member(key, value, keyIndent) {
  const prefix = '"' + key + '":  ';
  if (Array.isArray(value)) {
    const itemPad = ' '.repeat(keyIndent + prefix.length + 4);
    const closePad = ' '.repeat(keyIndent + prefix.length);
    return ' '.repeat(keyIndent) + prefix + '[\r\n' + value.map((x) => itemPad + ps(x, keyIndent + prefix.length + 8)).join(',\r\n') + '\r\n' + closePad + ']';
  }
  return ' '.repeat(keyIndent) + prefix + js(value, keyIndent);
}

for (const [id, entries] of Object.entries(DECL)) {
  const p = 'configs/vehicles/engineering/' + id + '.json';
  const text = fs.readFileSync(p, 'utf8');
  // the top-level shell_catalog key: smallest indentation of any line that starts with that key
  const lines = text.split('\r\n');
  let anchorIndex = -1, anchorIndent = 0;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trimStart();
    if (t.startsWith('"shell_catalog":')) { const ind = lines[i].length - t.length; if (anchorIndex < 0 || ind < anchorIndent) { anchorIndex = i; anchorIndent = ind; } }
  }
  if (anchorIndex < 0) { console.error('ANCHOR_MISSING in ' + p); process.exit(2); }
  const keyIndent = anchorIndent + 4;                 // keys of this object sit four columns deeper than the key line
  const block = member('secondary_weapons', entries, keyIndent);
  lines.splice(anchorIndex, 0, block + ',');
  const out = lines.join('\r\n');
  const parsed = JSON.parse(out);                     // refuse to write anything that does not parse
  if (!Array.isArray(parsed.secondary_weapons) || parsed.secondary_weapons.length !== entries.length) { console.error('PARSE_CHECK_FAILED for ' + p); process.exit(3); }
  fs.writeFileSync(p, out, 'utf8');
  const after = JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(p + ' :: anchor line ' + (anchorIndex + 1) + ' indent ' + anchorIndent + ' | secondary_weapons=' + after.secondary_weapons.length +
    ' | ' + after.secondary_weapons.map((w) => w.group + ':' + w.caliber_mm + 'mm/' + w.belt + '/' + w.cadence_rps + 'rps').join(' , ') +
    ' | shell_catalog intact=' + ((after.shell_catalog.shells || []).length));
}
