// Probe the War Thunder armour structure so a comparison can be built from real fields rather than guesses.
// READ ONLY against the extraction, which stays outside the repository.
const fs = require('fs');
const path = require('path');
const dir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/units/tankmodels';
function shape(v, depth, maxDepth) {
  if (v === null || v === undefined) return String(v);
  if (Array.isArray(v)) return 'array[' + v.length + ']' + (v.length && depth < maxDepth ? ' of ' + shape(v[0], depth + 1, maxDepth) : '');
  if (typeof v === 'object') {
    const keys = Object.keys(v);
    if (depth >= maxDepth) return 'object{' + keys.slice(0, 10).join(',') + (keys.length > 10 ? ',...' : '') + '}';
    return 'object{' + keys.slice(0, 14).map((k) => k + ':' + shape(v[k], depth + 1, maxDepth)).join(', ') + (keys.length > 14 ? ', ...' : '') + '}';
  }
  return typeof v + '(' + String(v).slice(0, 24) + ')';
}
for (const name of ['ussr_t_80b', 'germ_leopard_2a4']) {
  const j = JSON.parse(fs.readFileSync(path.join(dir, name + '.blk'), 'utf8'));
  const dp = j.DamageParts || {};
  console.log('=== ' + name + ' DamageParts formatVersion=' + dp.formatVersion + ' keys=' + Object.keys(dp).join(','));
  for (const section of ['hull', 'turret', 'hull_composite_armor', 'turret_composite_armor', 'driver_protection', 'body_shields']) {
    if (dp[section] === undefined) continue;
    console.log('  [' + section + '] ' + shape(dp[section], 0, 3).slice(0, 900));
  }
}
