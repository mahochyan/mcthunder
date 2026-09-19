// Compare this project ammunition against the REAL War Thunder gun and round definitions.
//
// HONESTY RULES, the same as the armour comparison:
//   * our own shells carry a `source_bullet_type` field, so the pairing uses THAT when it names a real round and
//     falls back to a family keyword only where it does not - and the rule used is printed per row;
//   * raw War Thunder values are stored as the file states them, with no unit invented;
//   * rounds the game has that this project does not model are LISTED rather than ignored.
const fs = require('fs');
const path = require('path');

const gunDir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/weapons/groundmodels_weapons';
const ourDir = 'configs/vehicles/engineering';
const outPath = 'docs/wt/wt-reference/WT_AMMO_COMPARISON.json';

const GUNS = {
  ussr_t_80b: { file: '125mm_2a46_2_user_cannon.blk', label: 'T-80B 2A46-2 125 mm', family_hint: { APFSDS: /APDS_FS/i, HEAT: /HEAT_FS/i, HE: /_HE$/i } },
  germ_leopard_2a4: { file: '120mm_rheinmetall_l44_user_cannon.blk', label: 'Leopard 2A4 Rheinmetall L44 120 mm', family_hint: { APFSDS: /APDS_FS/i, HEAT: /HEAT_FS/i, HE: /_HE$/i } }
};

const out = {
  reference_kind: 'ammunition_comparison_against_local_war_thunder',
  game_build: '2.59.0.13',
  boundary: 'derived values and provenance only; the extracted game data stays outside the repository',
  compared_at: new Date().toISOString().slice(0, 19),
  notes: {
    firing_cadence: 'the gun file states shotFreq, which is rounds per second, and the unit file states no reload of its own; the reciprocal is recorded as the cadence the file implies and is NOT the same quantity as this project reload_time, so the two are shown side by side rather than declared equal',
    speed_units: 'speed is stored raw as the file states it; the gun and round files do not restate a unit, and it is read as metres per second because every value matches the class of the weapon'
  },
  vehicles: []
};

for (const [ourName, gun] of Object.entries(GUNS)) {
  const gp = path.join(gunDir, gun.file);
  const gj = JSON.parse(fs.readFileSync(gp, 'utf8'));
  const rounds = [];
  for (const key of Object.keys(gj)) {
    const entry = gj[key];
    if (!entry || typeof entry !== 'object' || !entry.bullet) continue;
    const b = entry.bullet;
    rounds.push({
      round: key,
      speed: b.speed === undefined ? null : b.speed,
      mass: b.mass === undefined ? null : b.mass,
      caliber: b.caliber === undefined ? null : b.caliber,
      bulletType: b.bulletType === undefined ? null : b.bulletType,
      explosiveType: b.explosiveType === undefined ? null : b.explosiveType,
      explosiveMass: b.explosiveMass === undefined ? null : b.explosiveMass,
      maxDistance: b.maxDistance === undefined ? null : b.maxDistance,
      normalizationPreset: b.normalizationPreset === undefined ? null : b.normalizationPreset,
      ricochetPreset: b.ricochetPreset === undefined ? null : b.ricochetPreset
    });
  }
  const ours = JSON.parse(fs.readFileSync(path.join(ourDir, ourName + '.json'), 'utf8'));
  const rows = [];
  const usedRounds = {};
  for (const shell of (ours.shell_catalog && ours.shell_catalog.shells) || []) {
    let pairingRule = 'source_bullet_type';
    let match = rounds.find((r) => shell.source_bullet_type && r.round.toLowerCase() === String(shell.source_bullet_type).toLowerCase());
    if (!match) {
      pairingRule = 'family keyword fallback';
      const pattern = (gun.family_hint[shell.family] || null);
      match = pattern ? rounds.find((r) => pattern.test(r.round) && !usedRounds[r.round]) : null;
    }
    if (match) usedRounds[match.round] = true;
    rows.push({
      our_shell: shell.id,
      our_family: shell.family,
      our_caliber_mm: shell.caliber_mm,
      our_muzzle_velocity_mps: shell.muzzle_velocity_mps === undefined ? null : shell.muzzle_velocity_mps,
      our_source_bullet_type: shell.source_bullet_type === undefined ? null : shell.source_bullet_type,
      pairing_rule: pairingRule,
      wt_round: match ? match.round : null,
      wt_speed: match ? match.speed : null,
      wt_mass: match ? match.mass : null,
      wt_bullet_type: match ? match.bulletType : null,
      wt_explosive_type: match ? match.explosiveType : null,
      wt_explosive_mass: match ? match.explosiveMass : null,
      velocity_delta_mps: match && typeof match.speed === 'number' && typeof shell.muzzle_velocity_mps === 'number' ? +(shell.muzzle_velocity_mps - match.speed).toFixed(1) : null,
      outcome: match ? (typeof match.speed === 'number' && shell.muzzle_velocity_mps === match.speed ? 'velocity_equal' : 'velocity_differs') : 'no_wt_round_paired'
    });
  }
  out.vehicles.push({
    vehicle: ourName,
    gun_file: 'gamedata/weapons/groundmodels_weapons/' + gun.file,
    gun_label: gun.label,
    wt_shot_freq_rps: gj.shotFreq === undefined ? null : gj.shotFreq,
    wt_implied_seconds_between_shots: gj.shotFreq ? +(1 / gj.shotFreq).toFixed(3) : null,
    our_reload_time_s: (() => { const e = ours.facts && ours.facts['runtime.reload_time']; return e && typeof e === 'object' ? e.value : (e === undefined ? null : e); })(),
    wt_rounds_available: rounds,
    wt_rounds_not_modelled_by_us: rounds.filter((r) => !usedRounds[r.round]).map((r) => r.round),
    rows
  });
}

const tally = {};
for (const v of out.vehicles) for (const r of v.rows) tally[r.outcome] = (tally[r.outcome] || 0) + 1;
out.summary = { rows: Object.values(tally).reduce((a, b) => a + b, 0), by_outcome: tally };
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n', 'utf8');

for (const v of out.vehicles) {
  console.log('=== ' + v.gun_label + '   (' + v.gun_file + ')');
  console.log('  shotFreq=' + v.wt_shot_freq_rps + ' rps -> one shot every ' + v.wt_implied_seconds_between_shots + ' s   |   our reload_time=' + v.our_reload_time_s + ' s');
  console.log('  rounds in the file (' + v.wt_rounds_available.length + '):');
  for (const r of v.wt_rounds_available) console.log('    ' + r.round.padEnd(26) + ' speed=' + String(r.speed).padStart(6) + '  mass=' + String(r.mass).padStart(7) + '  cal=' + r.caliber + '  type=' + r.bulletType + '  expl=' + r.explosiveType + '/' + r.explosiveMass);
  console.log('  our shells vs the file:');
  for (const r of v.rows) console.log('    ' + r.our_shell.padEnd(22) + String(r.our_muzzle_velocity_mps).padStart(5) + ' m/s  vs  ' + String(r.wt_round).padEnd(26) + ' file=' + String(r.wt_speed).padStart(6) + '  delta=' + String(r.velocity_delta_mps).padStart(7) + '  ' + r.outcome + '  [' + r.pairing_rule + ']');
  if (v.wt_rounds_not_modelled_by_us.length) console.log('  rounds the game has that we do NOT model: ' + v.wt_rounds_not_modelled_by_us.join(', '));
}
console.log('summary: ' + JSON.stringify(out.summary));
console.log('written: ' + outPath);
