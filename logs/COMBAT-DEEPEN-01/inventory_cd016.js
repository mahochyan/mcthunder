// CD16 stage zero inventory: measure the required content rather than assume it.
const fs = require('fs');
const path = require('path');
function lines(p) { const t = fs.readFileSync(p, 'utf8'); return t.split(/\r?\n/).length - (t.endsWith('\n') ? 1 : 0); }
const out = {};
for (const p of ['tests/build_release.ps1', 'tests/run_suite_checks.ps1', 'tests/run_modern_player_flow.ps1', 'tests/run_player_flow_checks.ps1']) {
  out[p] = lines(p) + ' lines';
}
for (const v of ['ussr_t_80b', 'germ_leopard_2a4']) {
  const p = 'configs/vehicles/engineering/' + v + '.json';
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  const top = Object.keys(j);
  const shells = j.shells || j.ammunition || (j.armament && j.armament.shells) || null;
  const modules = j.modules || j.internal_modules || null;
  out[p] = {
    bytes: fs.statSync(p).size,
    top_keys: top.join(','),
    sources: j.sources ? Object.keys(j.sources).length : 0,
    shells: Array.isArray(shells) ? shells.length : (shells ? Object.keys(shells).length : 0),
    modules: Array.isArray(modules) ? modules.length : (modules ? Object.keys(modules).length : 0),
    has_drive_profile: Object.prototype.hasOwnProperty.call(j, 'drive_profile'),
    has_armor: top.some((k) => /armor|armour/i.test(k)),
    has_layout: top.some((k) => /layout/i.test(k))
  };
}
for (const v of ['us_m4a3_75w_vvss_1944', 'us_m24_m6_t85e1_1951', 'us_m26_m3_1945', 'us_m36_m4a1_1945']) {
  const p = 'configs/vehicles/historical/' + v + '.json';
  out[p] = fs.statSync(p).size + ' bytes';
}
const scenes = [];
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.tscn')) scenes.push(p.split(path.sep).join('/'));
  }
}
if (fs.existsSync('scenes')) walk('scenes');
out.scenes = scenes;
out.river_scripts = fs.readdirSync('scripts/maps').filter((f) => f.includes('river')).length;
out.river_tests = fs.readdirSync('tests').filter((f) => f.includes('river') && f.endsWith('.gd')).length;
out.export_presets = fs.readFileSync('export_presets.cfg', 'utf8').split(/\r?\n/).filter((l) => l.startsWith('name=')).map((l) => l.slice(5));
out.package_doc_names = lines('tests/package_doc_names.json');
out.prior_package_runs = fs.existsSync('logs/WT040-package') ? fs.readdirSync('logs/WT040-package').length + ' entries' : 'none';
out.benchmark_matrix_delivered = fs.readdirSync('docs/wt/continuation').filter((f) => /BENCHMARK/i.test(f));
console.log(JSON.stringify(out, null, 2));
