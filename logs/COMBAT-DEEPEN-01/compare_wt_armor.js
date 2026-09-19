// Compare every armour value this project declares against the ACTUAL War Thunder unit files on this machine.
//
// WHY THIS MATTERS: our packets record origin=warthunder_reference with source_refs ["wt-2.57.1.137"], i.e. the
// values were copied from an older build dossier. The install here is 2.59.0.13, so this is the first time those
// figures can be checked - and corrected - against the game itself.
//
// HONESTY RULES this script follows:
//   * a pairing is by REGION KEYWORD with the rule printed next to it, never by hope;
//   * a value is called matched_exact only when a real part carries exactly that thickness; if our number equals
//     a part effective maximum rather than its nominal thickness, that is reported as a separate outcome instead
//     of being called a match;
//   * a value with no counterpart is reported as no_candidate rather than quietly dropped.
const fs = require('fs');
const path = require('path');

const wtDir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/units/tankmodels';
const ourDir = 'configs/vehicles/engineering';
const outPath = 'docs/wt/wt-reference/WT_ARMOR_COMPARISON.json';

const REGION_RULES = {
  'armor.hull_front': { sections: ['hull', 'hull_composite_armor', 'hull_front_composite_armor'], pattern: /(body_front|superstructure_front|hull_front)/i, rule: 'hull front: body_front / superstructure_front' },
  'armor.hull_sides': { sections: ['hull', 'hull_composite_armor', 'heavy_body_screens', 'hull_turret_spaced_armor'], pattern: /(body_side|superstructure_side|body_shield|side_screen)/i, rule: 'hull sides: body_side / superstructure_side / side screens' },
  'armor.hull_rear': { sections: ['hull', 'hull_composite_armor'], pattern: /(body_back|superstructure_back)/i, rule: 'hull rear: body_back / superstructure_back' },
  'armor.hull_roof': { sections: ['hull', 'hull_composite_armor'], pattern: /(body_top|superstructure_top)/i, rule: 'hull roof: body_top / superstructure_top' },
  'armor.hull_floor': { sections: ['hull'], pattern: /(body_bottom|superstructure_bottom|floor)/i, rule: 'hull floor: body_bottom / superstructure_bottom' },
  'armor.turret_front': { sections: ['turret', 'turret_composite_armor', 'mask'], pattern: /front/i, rule: 'turret front: any turret part named front' },
  'armor.turret_sides': { sections: ['turret', 'turret_composite_armor'], pattern: /side/i, rule: 'turret sides: any turret part named side' },
  'armor.turret_rear': { sections: ['turret', 'turret_composite_armor'], pattern: /back/i, rule: 'turret rear: any turret part named back' },
  'armor.turret_roof': { sections: ['turret', 'hull'], pattern: /top/i, rule: 'turret roof: any part named top' },
  'armor.gun_shield': { sections: ['turret', 'mask', 'gun'], pattern: /(mask|shield|gun)/i, rule: 'gun shield: mask / shield / gun parts' }
};
function regionOf(key) {
  for (const prefix of Object.keys(REGION_RULES)) if (key.startsWith(prefix)) return prefix;
  return null;
}
function collectParts(j) {
  const parts = [];
  const dp = j.DamageParts || {};
  for (const section of Object.keys(dp)) {
    const block = dp[section];
    if (!block || typeof block !== 'object' || Array.isArray(block)) continue;
    for (const name of Object.keys(block)) {
      const p = block[name];
      if (!p || typeof p !== 'object' || Array.isArray(p)) continue;
      if (typeof p.armorThickness !== 'number') continue;
      parts.push({
        section, name,
        thickness: p.armorThickness,
        armorClass: p.armorClass || (typeof block.armorClass === 'string' ? block.armorClass : null),
        effectiveMax: typeof p.armorEffectiveThicknessMax === 'number' ? p.armorEffectiveThicknessMax : null,
        genericQuality: typeof p.genericArmorQuality === 'number' ? p.genericArmorQuality : null
      });
    }
  }
  return parts;
}

const out = {
  reference_kind: 'armour_comparison_against_local_war_thunder',
  game_build: '2.59.0.13',
  our_declared_source: 'our packets record origin=warthunder_reference and source_refs ["wt-2.57.1.137"], so this comparison is also a version check: the dossier value was copied from 2.57.1.137 and is now tested against 2.59.0.13',
  boundary: 'derived values and provenance only; the extracted game data stays outside the repository',
  compared_at: new Date().toISOString().slice(0, 19),
  outcome_legend: {
    matched_exact: 'a real part in the current build carries exactly this thickness',
    matches_effective_max: 'no part is that thick nominally, but a part armorEffectiveThicknessMax equals it - our figure came from the effective maximum rather than the plate',
    candidates_include_it: 'the value appears among the region parts but not as a unique plate',
    no_candidate: 'no part in that region carries this thickness - the figure is not supported by the current build'
  },
  vehicles: []
};

for (const [ourName, wtName] of [['ussr_t_80b', 'ussr_t_80b'], ['germ_leopard_2a4', 'germ_leopard_2a4']]) {
  const j = JSON.parse(fs.readFileSync(path.join(wtDir, wtName + '.blk'), 'utf8'));
  const parts = collectParts(j);
  const ours = JSON.parse(fs.readFileSync(path.join(ourDir, ourName + '.json'), 'utf8'));
  const rows = [];
  for (const key of Object.keys(ours.facts)) {
    if (!key.startsWith('armor.')) continue;
    const entry = ours.facts[key];
    const value = entry && typeof entry === 'object' ? entry.value : entry;
    if (typeof value !== 'number') continue;
    const region = regionOf(key);
    const rule = region ? REGION_RULES[region] : null;
    const scope = region ? parts.filter((p) => rule.sections.includes(p.section) && rule.pattern.test(p.name)) : [];
    const exact = scope.filter((p) => p.thickness === value);
    const effMax = parts.filter((p) => p.effectiveMax === value);
    let outcome = 'no_candidate';
    if (exact.length > 0) outcome = exact.length === 1 ? 'matched_exact' : 'candidates_include_it';
    else if (effMax.length > 0) outcome = 'matches_effective_max';
    rows.push({
      our_fact: key,
      our_value_mm: value,
      our_source_refs: (entry && entry.source_refs) || [],
      pairing_rule: rule ? rule.rule : 'no region rule: not paired',
      candidate_parts: scope.map((p) => ({ section: p.section, part: p.name, thickness: p.thickness, armorClass: p.armorClass, effectiveMax: p.effectiveMax })).slice(0, 12),
      candidate_count: scope.length,
      outcome,
      matched_parts: exact.map((p) => p.section + '/' + p.name),
      effective_max_parts: effMax.map((p) => p.section + '/' + p.name + ' (max ' + p.effectiveMax + ')')
    });
  }
  out.vehicles.push({ vehicle: ourName, unit_file: 'gamedata/units/tankmodels/' + wtName + '.blk', parts_total: parts.length, rows });
}

const tally = {};
for (const v of out.vehicles) for (const r of v.rows) tally[r.outcome] = (tally[r.outcome] || 0) + 1;
out.summary = { rows: Object.values(tally).reduce((a, b) => a + b, 0), by_outcome: tally };
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n', 'utf8');

for (const v of out.vehicles) {
  console.log('=== ' + v.vehicle + '  (' + v.parts_total + ' armour parts in the unit file)');
  for (const r of v.rows) {
    console.log('  ' + r.our_fact.padEnd(34) + String(r.our_value_mm).padStart(5) + ' mm  ' + r.outcome.padEnd(22) +
      (r.matched_parts.length ? ' <= ' + r.matched_parts.join(', ') : '') +
      (r.outcome === 'matches_effective_max' ? ' <= ' + r.effective_max_parts.join(', ') : ''));
  }
}
console.log('summary: ' + JSON.stringify(out.summary));
console.log('written: ' + outPath);
