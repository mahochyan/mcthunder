// Probe the extracted War Thunder unit files: print the top-level key list and the values our own packets
// need to be compared against. READ ONLY - the extracted game data stays outside the repository; only derived
// values plus provenance are ever written into the repo.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const dir = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/units/tankmodels';
const sha256 = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for (const name of ['ussr_t_80b', 'germ_leopard_2a4']) {
  const p = path.join(dir, name + '.blk');
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log('=== ' + name + '  sha256=' + sha256(p).slice(0, 16) + '  bytes=' + fs.statSync(p).size);
  const keys = Object.keys(j);
  console.log('top_keys(' + keys.length + '): ' + keys.join(', '));
  const scalar = {};
  for (const k of keys) {
    const v = j[k];
    if (typeof v === 'number' || typeof v === 'string' || typeof v === 'boolean') scalar[k] = v;
  }
  console.log('scalars: ' + JSON.stringify(scalar).slice(0, 1400));
  const sections = keys.filter((k) => j[k] && typeof j[k] === 'object');
  console.log('sections: ' + sections.join(', '));
}
