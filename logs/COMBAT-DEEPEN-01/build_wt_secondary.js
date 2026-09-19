// Record the REAL secondary armament of both vehicles and measure the gap against what this project declares.
// READ ONLY against the extraction (outside the repository). Derived values and provenance only are written.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sha256 = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const unitDir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/units/tankmodels';
const root = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u';
const ourDir = 'configs/vehicles/engineering';
const outPath = 'docs/wt/wt-reference/WT_REFERENCE_SECONDARY.json';

const out = {
  reference_kind: 'secondary_armament_from_local_war_thunder',
  game_build: '2.59.0.13',
  boundary: 'derived values and provenance only; the extracted game data stays outside the repository',
  read_at: new Date().toISOString().slice(0, 19),
  vehicles: []
};
for (const id of ['ussr_t_80b', 'germ_leopard_2a4']) {
  const up = path.join(unitDir, id + '.blk');
  const u = JSON.parse(fs.readFileSync(up, 'utf8'));
  const triggers = [];
  const block = (u.commonWeapons && u.commonWeapons.Weapon) || {};
  for (const trigger of Object.keys(block)) {
    const w = block[trigger] || {};
    const rel = w.blk ? String(w.blk) : null;              // e.g. gameData/Weapons/groundModels_weapons/x.blk
    const file = rel ? path.join(root, rel.replace(/^gameData/i, 'gamedata')) : null;
    const row = {
      trigger,
      triggerGroup: w.triggerGroup || null,
      gun_file: rel,
      gun_file_present: file ? fs.existsSync(file) : false,
      gun_file_sha256: file && fs.existsSync(file) ? sha256(file) : null
    };
    if (row.gun_file_present) {
      const g = JSON.parse(fs.readFileSync(file, 'utf8'));
      row.cannon = g.cannon === true;
      row.shotFreq_rps = g.shotFreq === undefined ? null : g.shotFreq;
      const rounds = [];
      for (const k of Object.keys(g)) {
        const e = g[k];
        if (!e || typeof e !== 'object' || !e.bullet) continue;
        rounds.push({ round: k, speed: e.bullet.speed === undefined ? null : e.bullet.speed, mass: e.bullet.mass === undefined ? null : e.bullet.mass, caliber: e.bullet.caliber === undefined ? null : e.bullet.caliber, bulletType: e.bullet.bulletType === undefined ? null : e.bullet.bulletType, explosiveType: e.bullet.explosiveType === undefined ? null : e.bullet.explosiveType, explosiveMass: e.bullet.explosiveMass === undefined ? null : e.bullet.explosiveMass });
      }
      row.rounds = rounds;
      // A MACHINE GUN states its belt under `bullet` as an ARRAY of round blocks rather than in named round
      // objects, so the named scan above finds nothing for it. The fallback records the first belt round and how
      // many the belt holds, which is what the gun actually fires.
      const beltBlock = Array.isArray(g.bullet) ? g.bullet : (g.bullet && typeof g.bullet === 'object' ? [g.bullet] : []);
      if (!rounds.length && beltBlock.length && typeof beltBlock[0].speed === 'number') {
        const b0 = beltBlock[0];
        row.rounds = [{ round: 'belt round 1 of ' + beltBlock.length, speed: b0.speed, mass: b0.mass === undefined ? null : b0.mass, caliber: b0.caliber === undefined ? null : b0.caliber, bulletType: b0.bulletType === undefined ? null : b0.bulletType, bulletName: b0.bulletName === undefined ? null : b0.bulletName, explosiveType: b0.explosiveType === undefined ? null : b0.explosiveType, explosiveMass: b0.explosiveMass === undefined ? null : b0.explosiveMass, maxDistance: b0.maxDistance === undefined ? null : b0.maxDistance }];
      }
      row.belt_bullets = g.bullets === undefined ? null : g.bullets;
      row.belt_reload_s = g.reloadTime === undefined ? null : g.reloadTime;
      row.cartridge = g.bulletsCartridge === undefined ? null : g.bulletsCartridge;
      row.aim_max_distance_m = g.aimMaxDist === undefined ? null : g.aimMaxDist;
    }
    triggers.push(row);
  }
  const ours = JSON.parse(fs.readFileSync(path.join(ourDir, id + '.json'), 'utf8'));
  const ourWeapons = [];
  if (ours.weapon) ourWeapons.push({ id: 'primary', gun: ours.weapon.gun || null, caliber_mm: ours.weapon.caliber_mm || null });
  if (ours.assembly && ours.assembly.gun) ourWeapons.push({ id: 'assembly_gun', gun: ours.assembly.gun });
  out.vehicles.push({
    vehicle: id,
    unit_file: 'gamedata/units/tankmodels/' + id + '.blk',
    war_thunder_triggers: triggers,
    war_thunder_trigger_count: triggers.length,
    war_thunder_secondary_count: triggers.filter((t) => t.triggerGroup).length,
    mcthunder_declared_weapons: ourWeapons,
    mcthunder_declared_weapon_count: ourWeapons.length,
    gap: {
      wt_triggers_not_modelled: triggers.filter((t) => t.triggerGroup).map((t) => ({ trigger: t.trigger, group: t.triggerGroup, gun_file: t.gun_file })),
      note: 'This project declares one gun per vehicle. Every trigger the file marks with a triggerGroup is a secondary weapon this project does not model: the coaxial machine gun, the commander or anti-air machine gun, and any dummy trigger the game keeps for the commander position.'
    }
  });
}
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n', 'utf8');
for (const v of out.vehicles) {
  console.log('=== ' + v.vehicle + '  WT triggers=' + v.war_thunder_trigger_count + '  secondary=' + v.war_thunder_secondary_count + '  ours=' + v.mcthunder_declared_weapon_count);
  for (const t of v.war_thunder_triggers) {
    const r = (t.rounds || [])[0] || {};
    console.log('   trigger=' + t.trigger.padEnd(9) + ' group=' + String(t.triggerGroup).padEnd(11) + ' cannon=' + String(t.cannon).padEnd(5) + ' shotFreq=' + String(t.shotFreq_rps).padEnd(8) + ' round=' + String(r.round).padEnd(22) + ' speed=' + String(r.speed).padStart(5) + ' cal=' + r.caliber + ' type=' + r.bulletType);
  }
}
console.log('written: ' + outPath);
