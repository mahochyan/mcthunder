// Build the War Thunder reference record for the two vehicles this project actually models.
//
// BOUNDARY, stated because it governs everything this script does:
//   * the extracted game data lives OUTSIDE the repository (E:/AIprogram/wt-datamine) and is never committed;
//   * this script reads it there and writes only DERIVED VALUES plus PROVENANCE into the repo, so no game asset
//     and no game file is redistributed - the record is a citation, not a copy;
//   * every War Thunder number is stored RAW as the file states it, and every conversion is stored SEPARATELY
//     with the assumption it rests on, because the file does not document the units of maxAccel/maxAngSpeed and
//     an interpretation recorded as a fact is exactly what this project forbids.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const wtDir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/units/tankmodels';
const ourDir = 'configs/vehicles/engineering';
const outDir = 'docs/wt/wt-reference';
const sha256 = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');

const pairs = [
  { wt: 'ussr_t_80b', ours: 'ussr_t_80b', label: 'T-80B' },
  { wt: 'germ_leopard_2a4', ours: 'germ_leopard_2a4', label: 'Leopard 2A4' }
];
const WT_FIELDS = ['model', 'subclass', 'type', 'moveType', 'onRadarAs', 'mass', 'maxFwdSpeed', 'maxRevSpeed',
  'maxAngSpeed', 'maxAccel', 'maxDecel', 'maxAngAccel', 'maxAngAccel0', 'maxAngAccelV', 'groundNormSmoothViscosity',
  'smokeScreenActivateTime', 'smokeScreenEffectTime', 'smokeScreenRad', 'rearmSmokeTimeOnField', 'autoSightDistanceCorrection'];

const record = {
  reference_kind: 'war_thunder_local_install_extraction',  game_build: '2.59.0.13',
  game_build_source: 'vromf_version reports 2.59.0.13 for aces.vromfs.bin, char.vromfs.bin, game.vromfs.bin and mis.vromfs.bin of the local install at E:/WarThunder',
  install_path: 'E:/WarThunder',
  tool: {
    name: 'wt_ext_cli',
    release: 'v0.6.6',
    binary_commit: '764867e35eb7ead01425781ecae0bc6488be4e22',
    release_asset: 'wt_ext_cli-x86_64-pc-windows-msvc.zip',
    asset_sha256: '2e7593535f341ae88956583a9ba6aada3500d153f4c4a26196cae89ecdb685af',
    license_file: 'E:/AIprogram/wt-tools/wt_ext_cli/LICENSE (carried with the tool, outside the repository)'
  },
  extracted_to: 'E:/AIprogram/wt-datamine (OUTSIDE the repository; never committed, never packaged)',
  boundary: 'Only derived values and provenance are recorded here. No War Thunder file, model, texture, sound or data dump is copied into this repository or into any package this project builds, and no claim is made that these values are the project own design values - they are the reference the project is measured against.',
  extracted_at: new Date().toISOString().slice(0, 19),
  units_note: 'mass is stored as the file states it and is kilograms; maxFwdSpeed/maxRevSpeed are stored raw and are read as km/h in the conversions below; maxAccel/maxDecel have no unit in the file and are read as m/s^2 in the conversions, which is an ASSUMPTION recorded as such; maxAngSpeed/maxAngAccel have no unit and are read as degrees per second ALSO AS AN ASSUMPTION. The raw values are authoritative; the conversions are interpretations.',
  vehicles: []
};

// Our own facts are recorded as objects carrying provenance, so the numeric value has to be dug out of the
// entry rather than read directly - a first attempt printed [object Object] for every one of them.
function factValue(entry) {
  if (entry === undefined || entry === null) return null;
  if (typeof entry === 'number' || typeof entry === 'string' || typeof entry === 'boolean') return entry;
  if (typeof entry === 'object') {
    for (const k of ['value', 'amount', 'v', 'design_mass_kg', 'forward_speed_mps', 'mps', 'seconds']) {
      if (entry[k] !== undefined && entry[k] !== null) return entry[k];
    }
  }
  return null;
}
for (const pair of pairs) {
  const wtPath = path.join(wtDir, pair.wt + '.blk');
  const wt = JSON.parse(fs.readFileSync(wtPath, 'utf8'));
  const ours = JSON.parse(fs.readFileSync(path.join(ourDir, pair.ours + '.json'), 'utf8'));
  const facts = ours.facts || {};
  const raw = {};
  for (const f of WT_FIELDS) if (Object.prototype.hasOwnProperty.call(wt, f)) raw[f] = wt[f];
  const crew = wt.tank_crew && typeof wt.tank_crew === 'object' ? Object.keys(wt.tank_crew).filter((k) => k !== 'changeTimeMult') : [];
  const weapons = [];
  const weaponBlock = (wt.commonWeapons && wt.commonWeapons.Weapon) || null;
  if (weaponBlock && typeof weaponBlock === 'object') {
    for (const k of Object.keys(weaponBlock)) {
      const w = weaponBlock[k];
      weapons.push({ trigger: k, triggerGroup: (w && w.triggerGroup) || null, blk: (w && w.blk) || null, name: (w && w.name) || null });
    }
  }
  const damageParts = (wt.DamageParts && typeof wt.DamageParts === 'object') ? Object.keys(wt.DamageParts).filter((k) => k !== 'formatVersion' && k !== 'armorClass' && k !== 'hp') : [];
  record.vehicles.push({
    label: pair.label,
    war_thunder: {
      unit_file: 'gamedata/units/tankmodels/' + pair.wt + '.blk',
      unit_file_sha256: sha256(wtPath),
      unit_file_bytes: fs.statSync(wtPath).size,
      raw_values: raw,
      conversions: {
        forward_max_speed_mps: typeof raw.maxFwdSpeed === 'number' ? +(raw.maxFwdSpeed / 3.6).toFixed(3) : null,
        reverse_max_speed_mps: typeof raw.maxRevSpeed === 'number' ? +(raw.maxRevSpeed / 3.6).toFixed(3) : null,
        acceleration_mps2_assumed: raw.maxAccel === undefined ? null : raw.maxAccel,
        deceleration_mps2_assumed: raw.maxDecel === undefined ? null : raw.maxDecel,
        turn_rate_deg_s_assumed: raw.maxAngSpeed === undefined ? null : raw.maxAngSpeed
      },
      mass_kg: typeof raw.mass === 'number' ? raw.mass : null,
      crew_entries: crew.length,
      crew_keys: crew,
      weapon_names: weapons,
      damage_parts_count: damageParts.length,
      damage_part_sample: damageParts.slice(0, 8),
      sections_available: Object.keys(wt).filter((k) => wt[k] && typeof wt[k] === 'object'),
      ammo_stowage_keys: wt.ammoStowages && typeof wt.ammoStowages === 'object' ? Object.keys(wt.ammoStowages) : [],
      modification_keys: wt.modifications && typeof wt.modifications === 'object' ? Object.keys(wt.modifications) : []
    },
    mcthunder: {
      packet: 'configs/vehicles/engineering/' + pair.ours + '.json',
      declared: {
        design_mass_kg: factValue(facts['mobility.design_mass_kg']),
        engine: factValue(facts['mobility.engine']),
        forward_speed_mps: factValue(facts['mobility.forward_speed_mps']),
        acceleration: factValue(facts['runtime.acceleration']),
        forward_max_speed: factValue(facts['runtime.forward_max_speed']),
        reverse_max_speed: factValue(facts['runtime.reverse_max_speed']),
        hull_turn_speed: factValue(facts['runtime.hull_turn_speed']),
        turret_yaw_speed: factValue(facts['runtime.turret_yaw_speed']),
        turret_pitch_speed: factValue(facts['runtime.turret_pitch_speed']),
        reload_time: factValue(facts['runtime.reload_time']),
        caliber_mm: factValue(facts['weapon.caliber_mm']),
        crew_count: Array.isArray(ours.crew) ? ours.crew.length : null,
        drive_profile_origin: (ours.drive_profile && ours.drive_profile.origin) || null
      },
      provenance_of_our_values: 'Read from the packet facts entries, which themselves record origin, source_refs and a location note; where the entry says origin=warthunder_reference the project already copied that figure from a reference dossier, and this record is the first time it has been checked against the actual extracted game file.',
      comparison_state: 'NOW_COMPARABLE: both sides are on disk with a named War Thunder build, so a row can be filled with actual_reference instead of NOT_COMPARED.'
    }
  });
}
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'WT_REFERENCE_UNITS.json'), JSON.stringify(record, null, 2) + '\n', 'utf8');

for (const v of record.vehicles) {
  const wtv = v.war_thunder.raw_values;
  const mv = v.mcthunder.declared;
  console.log('=== ' + v.label);
  console.log('  WT   mass=' + wtv.mass + ' kg | fwd=' + wtv.maxFwdSpeed + ' km/h (' + v.war_thunder.conversions.forward_max_speed_mps + ' m/s) | rev=' + wtv.maxRevSpeed + ' km/h | accel=' + wtv.maxAccel + ' | decel=' + wtv.maxDecel + ' | turn=' + wtv.maxAngSpeed);
  console.log('  OURS mass=' + mv.design_mass_kg + ' kg | fwd=' + mv.forward_max_speed + ' m/s | rev=' + mv.reverse_max_speed + ' m/s | accel=' + mv.acceleration + ' | turn=' + mv.hull_turn_speed + ' | reload=' + mv.reload_time + ' | caliber=' + mv.caliber_mm + ' | crew=' + mv.crew_count);
  console.log('  WT crew entries=' + v.war_thunder.crew_entries + ' weapons=' + v.war_thunder.weapon_names.join('/') + ' damage_parts=' + v.war_thunder.damage_parts_count);
}
console.log('written: ' + path.join(outDir, 'WT_REFERENCE_UNITS.json'));
