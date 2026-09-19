// Probe the real gun definitions: what the game states about the cannon, its reload and the rounds it fires.
// READ ONLY against the extraction (outside the repository).
const fs = require('fs');
const path = require('path');
const root = 'E:/AIprogram/wt-datamine/aces/aces.vromfs.bin_u/gamedata/weapons/groundmodels_weapons';
const files = [
  { label: 'T-80B 2A46-2 125mm', name: '125mm_2a46_2_user_cannon.blk' },
  { label: 'Leopard 2A4 Rh L44 120mm', name: '120mm_rheinmetall_l44_user_cannon.blk' }
];
for (const f of files) {
  const p = path.join(root, f.name);
  if (!fs.existsSync(p)) { console.log('=== ' + f.label + ' :: MISSING ' + f.name); continue; }
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log('=== ' + f.label + '  (' + f.name + ', ' + fs.statSync(p).size + ' bytes, top keys ' + Object.keys(j).length + ')');
  const scalar = {};
  for (const k of Object.keys(j)) {
    const v = j[k];
    if (typeof v === 'number' || typeof v === 'string' || typeof v === 'boolean') scalar[k] = v;
  }
  console.log('  scalars: ' + JSON.stringify(scalar).slice(0, 1200));
  for (const k of Object.keys(j)) {
    const v = j[k];
    if (Array.isArray(v)) console.log('  array ' + k + ' length=' + v.length + '  first=' + JSON.stringify(v[0]).slice(0, 300));
    else if (v && typeof v === 'object') console.log('  object ' + k + ' keys=' + Object.keys(v).slice(0, 18).join(','));
  }
}
