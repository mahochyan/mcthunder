// WT-EXPANSION-01 step 5: the profile contract needs `version`, which ArmorImpactProfile.validate requires and my
// declared profiles did not carry - that is why the real manager refused with invalid_impact_profile.
const fs = require('fs');
function js(v, indent) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  if (v === null) return 'null';
  if (Array.isArray(v)) {
    const itemPad = ' '.repeat(indent + 4), closePad = ' '.repeat(indent);
    if (!v.length) return '[]';
    return '[\r\n' + v.map((x) => itemPad + js(x, indent + 4)).join(',\r\n') + '\r\n' + closePad + ']';
  }
  const innerPad = ' '.repeat(indent + 4), closePad = ' '.repeat(indent);
  return '{\r\n' + Object.keys(v).map((k) => innerPad + '"' + k + '":  ' + js(v[k], indent + 4)).join(',\r\n') + '\r\n' + closePad + '}';
}
function member(key, value, keyIndent) {
  const prefix = '"' + key + '":  ';
  if (Array.isArray(value)) {
    const itemPad = ' '.repeat(keyIndent + prefix.length + 4), closePad = ' '.repeat(keyIndent + prefix.length);
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
      const itemPad = ' '.repeat(keyIndent + prefix.length + 4), closePad = ' '.repeat(keyIndent + prefix.length);
      inner.push(' '.repeat(keyIndent) + prefix + '[\r\n' + v.map((x) => itemPad + js(x, keyIndent + prefix.length + 4)).join(',\r\n') + '\r\n' + closePad + ']');
    } else {
      inner.push(' '.repeat(keyIndent) + prefix + js(v, keyIndent));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}
function spanOf(text, key) {
  const at = text.indexOf('"' + key + '":  [');
  if (at < 0) return null;
  const i = text.indexOf('[', at);
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
  for (const row of parsed.secondary_weapons) {
    const prof = row.impact_profile;
    // The validator keys on `version` FIRST: an unknown or missing version is refused before any other field is read.
    prof.version = 'wt012-full-caliber-v1';
    row.impact_profile = prof;
  }
  const span = spanOf(text, 'secondary_weapons');
  if (!span) { console.error('SPAN_NOT_FOUND ' + p); process.exit(2); }
  const out = text.slice(0, span.start) + member('secondary_weapons', parsed.secondary_weapons, 4) + text.slice(span.end);
  const check = JSON.parse(out);
  if (check.secondary_weapons.some((r) => r.impact_profile.version !== 'wt012-full-caliber-v1')) { console.error('VERSION_MISSING ' + p); process.exit(3); }
  if ((check.shell_catalog.shells || []).length !== (parsed.shell_catalog.shells || []).length) { console.error('SHELLS_CHANGED ' + p); process.exit(4); }
  fs.writeFileSync(p, out, 'utf8');
  console.log(p + ' :: profiles=' + check.secondary_weapons.map((r) => r.impact_profile.version + '/' + r.impact_profile.family + '/norm' + r.impact_profile.normalization_deg + '/rich' + r.impact_profile.ricochet_deg + '/mat' + Object.keys(r.impact_profile.material_coefficients).join('+')).join(' , ') + ' shells=' + check.shell_catalog.shells.length);
}
