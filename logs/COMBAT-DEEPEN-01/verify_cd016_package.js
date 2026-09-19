// CD16 case T01 gate: from the package built at an explicit integration commit, verify EVERY identity.
// The order's expectation is that source, content, rules and package identity are traceable and that an
// UNKNOWN exit status or a script error REJECTS the package. This verifier therefore recomputes the hashes
// from disk instead of trusting the manifest, checks that every recorded process has a REAL exit status and
// did not time out, scans the recorded output for SCRIPT ERROR, and re-checks the registered candidate
// failures against their own signatures rather than trusting the manifest list.
//
// One honest note on the regression row: in candidate mode the regression run legitimately exits non-zero
// when a REGISTERED suite fails, so that row's `passed` is false while every other row must be true. The
// verifier encodes exactly that, and separately proves the failures are the registered ones.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

let bad = 0;
let checked = 0;
function ok(cond, label, detail) {
  checked++;
  if (!cond) bad++;
  console.log((cond ? 'PASS ' : 'FAIL ') + label + (detail === undefined ? '' : ' :: ' + detail));
}
function sha256(p) { return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase(); }
function readText(p) {
  const b = fs.readFileSync(p);
  let t = (b[0] === 0xFF && b[1] === 0xFE) ? b.toString('utf16le') : b.toString('utf8');
  // The build writes its JSON with Windows PowerShell `Set-Content -Encoding utf8`, which emits a UTF-8 BOM.
  // JSON.parse refuses it, and the dry run against the earlier package is exactly what found this.
  return t.charCodeAt(0) === 0xFEFF ? t.slice(1) : t;
}
function readJson(p) { return JSON.parse(readText(p)); }
function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

// --- locate the newest build run, without being told which one it is ---
const root = process.cwd();
const buildRoot = path.join(root, 'backups/builds/031');
if (!fs.existsSync(buildRoot)) { console.error('NO BUILD RUNS: ' + buildRoot); process.exit(2); }
const runs = [];
for (const sha of fs.readdirSync(buildRoot)) {
  const shaDir = path.join(buildRoot, sha);
  if (!fs.statSync(shaDir).isDirectory()) continue;
  for (const stamp of fs.readdirSync(shaDir)) {
    const runDir = path.join(shaDir, stamp);
    const logDir = path.join(root, 'logs/031', sha, 'build-' + stamp);
    if (!fs.existsSync(path.join(runDir, 'package')) && !fs.existsSync(logDir)) continue;
    runs.push({ sha, stamp, runDir, logDir, mtime: fs.statSync(runDir).mtimeMs });
  }
}
if (!runs.length) { console.error('NO COMPLETE BUILD RUN FOUND'); process.exit(2); }
runs.sort((a, b) => b.mtime - a.mtime);
// Optional first argument selects a run by source-commit prefix, so the verifier can be dry-run against an
// EARLIER package to prove its own logic before the current build finishes. With no argument it takes the newest.
const selector = process.argv[2] || '';
const candidates = selector ? runs.filter((r) => r.sha.startsWith(selector)) : runs;
if (!candidates.length) { console.error('NO RUN MATCHES SELECTOR ' + selector); process.exit(2); }
const run = candidates[0];
console.log('# verifying run ' + run.sha.slice(0, 8) + ' / ' + run.stamp + (selector ? ' (selected by ' + selector + ')' : ' (newest of ' + runs.length + ' runs on disk)'));

const packageDir = path.join(run.runDir, 'package');
const manifestPath = path.join(packageDir, 'BUILD_MANIFEST.json');
const packagePath = path.join(run.logDir, 'PACKAGE.json');
ok(fs.existsSync(manifestPath), 'the package carries BUILD_MANIFEST.json');
ok(fs.existsSync(packagePath), 'the run carries PACKAGE.json');
if (!fs.existsSync(manifestPath) || !fs.existsSync(packagePath)) { console.log('CD16_T01_GATE_FAIL'); process.exit(1); }
const manifest = readJson(manifestPath);
const pkg = readJson(packagePath);

// --- 1. source identity: traceable to an explicit integration commit ---
ok(/^[0-9a-f]{40}$/.test(String(manifest.source_sha)), 'the manifest names a forty character source commit', manifest.source_sha);
ok(String(manifest.source_sha).startsWith(run.sha), 'the manifest commit matches the directory it was built into');
ok(pkg.source_sha === manifest.source_sha, 'PACKAGE.json and the manifest agree on the source commit');
ok(manifest.committed_snapshot === true, 'the package was built from the committed snapshot');
ok(Array.isArray(manifest.excluded_worktree_files) && manifest.excluded_worktree_files.length === 0, 'nothing tracked was excluded from the build');
// The version is NOT hardcoded here: an earlier revision of this verifier asserted the literal string "0.0.1",
// which the dry run against the 2026-09-17 package refuted - the project declares 1.0.0-rc.3-dev. A hardcoded
// expectation would have failed the real gate for no reason, so the check compares the manifest against the
// version actually declared by the built source instead.
{
  const projPath = path.join(run.runDir, 'clean-source', 'project.godot');
  let declared = '';
  if (fs.existsSync(projPath)) {
    const m = readText(projPath).match(/config\/version="([^"]+)"/);
    if (m) declared = m[1];
  }
  ok(declared.length > 0, 'the built source declares a project version', declared || 'not found');
  ok(String(manifest.version) === declared, 'the manifest version equals the one the built source declares', manifest.version + ' vs ' + declared);
}

// --- 2. engine, template and configuration identity ---
ok(manifest.engine === '4.7.2.stable.official.ed1daf0bf', 'the engine identity is the fixed one', manifest.engine);
ok(/^[0-9A-F]{64}$/.test(String(manifest.template_sha256)), 'the export template hash is recorded', String(manifest.template_sha256).slice(0, 12));
ok(manifest.platform === 'Windows x64' && manifest.configuration === 'release' && manifest.renderer === 'gl_compatibility', 'platform, configuration and renderer are the declared ones');
ok(manifest.challenge_rules === 1 && manifest.settings_schema === 2 && manifest.profile_schema === 3, 'the rules, settings and profile schemas are declared', manifest.challenge_rules + '/' + manifest.settings_schema + '/' + manifest.profile_schema);
ok(manifest.clean_import === true, 'the package came from a clean import, not the working cache');

// --- 3. package identity recomputed from disk ---
let fileMismatch = 0;
for (const f of manifest.files) {
  const p = path.join(packageDir, f.name);
  if (!fs.existsSync(p)) { fileMismatch++; console.log('   MISSING ' + f.name); continue; }
  const actual = sha256(p);
  if (actual !== String(f.sha256).toUpperCase() || fs.statSync(p).size !== f.bytes) {
    fileMismatch++;
    console.log('   hash mismatch for ' + f.name + ': manifest=' + f.sha256 + ' disk=' + actual + ' bytes=' + fs.statSync(p).size + '/' + f.bytes);
  }
}
ok(manifest.files.length >= 2, 'the package lists its files', manifest.files.map((f) => f.name).join(', '));
ok(fileMismatch === 0, 'every recorded file hash and size matches the package on disk', fileMismatch + ' mismatches');
ok(fs.existsSync(path.join(packageDir, 'PixelArmor.exe')), 'the package carries the executable');
ok(String(pkg.build_manifest_sha256).toUpperCase() === sha256(manifestPath), 'PACKAGE.json names the manifest hash it actually has');
ok(fs.existsSync(pkg.zip) && sha256(pkg.zip) === String(pkg.zip_sha256).toUpperCase(), 'the recorded zip hash matches the zip on disk');

// --- 4. every recorded process has a REAL exit status, and only the regression row may be non-passing ---
const unknown = manifest.verification.filter((v) => v.exit_code === null || v.exit_known !== true);
const timedOut = manifest.verification.filter((v) => v.timed_out === true);
const badArtifact = manifest.verification.filter((v) => v.artifact_ok !== true);
const otherNotPassed = manifest.verification.filter((v) => v.passed !== true && v.name !== 'regression');
ok(manifest.verification.length >= 6, 'the build recorded a verification row per step', manifest.verification.length + ' rows: ' + manifest.verification.map((v) => v.name).join(', '));
ok(unknown.length === 0, 'NO step has an UNKNOWN exit status, which the order rejects outright', unknown.map((v) => v.name).join(',') || 'none');
ok(timedOut.length === 0, 'no step timed out', timedOut.map((v) => v.name).join(',') || 'none');
ok(badArtifact.length === 0, 'every required artefact was produced', badArtifact.map((v) => v.name).join(',') || 'none');
ok(otherNotPassed.length === 0, 'every step except the candidate regression gate passed', otherNotPassed.map((v) => v.name).join(',') || 'none');

// --- 5. SCRIPT ERROR anywhere rejects; the failures must be the REGISTERED ones ---
const logs = walk(run.logDir, []).filter((f) => /\.(log|txt)$/.test(f));
let scriptErrors = 0;
const scriptErrorFiles = [];
for (const f of logs) {
  const t = readText(f);
  const n = (t.match(/SCRIPT ERROR:/g) || []).length;
  if (n) { scriptErrors += n; scriptErrorFiles.push(path.relative(run.logDir, f) + ':' + n); }
}
ok(logs.length > 0, 'the run recorded its own logs', logs.length + ' files under ' + path.relative(root, run.logDir));
ok(scriptErrors === 0, 'no SCRIPT ERROR anywhere in the recorded output', scriptErrorFiles.join(', ') || 'none');

const regFails = {};
let regFailTotal = 0;
for (const f of walk(run.logDir, []).filter((x) => x.endsWith('_stdout.log'))) {
  const t = readText(f);
  const fl = t.split(/\r?\n/).filter((l) => l.includes('[FAIL]'));
  if (fl.length) {
    const suite = path.basename(f).replace('_stdout.log', '');
    regFails[suite] = fl;
    regFailTotal += fl.length;
  }
}
const register = [
  { suite: 'run_industrial_battle_checks', failures: 1, must_match: 'physically reach central approaches' },
  { suite: 'run_challenge_checks', failures: 2, must_match: 'finite waves with opponent AI untouched' }
];
ok(regFailTotal === manifest.regression_failed_checks, 'the failing checks found in the logs equal the manifest count', regFailTotal + ' vs ' + manifest.regression_failed_checks);
ok(Object.keys(regFails).length === register.length, 'exactly the two registered suites carry failures', Object.keys(regFails).join(', ') || 'none');
for (const r of register) {
  const lines = regFails[r.suite] || [];
  ok(lines.length === r.failures, r.suite + ' failed exactly the registered number of checks', lines.length + '/' + r.failures);
  ok(lines.some((l) => l.includes(r.must_match)), r.suite + ' carries the registered signature', r.must_match);
}
const unregistered = Object.keys(regFails).filter((s) => !register.some((r) => r.suite === s));
ok(unregistered.length === 0, 'no UNREGISTERED suite has a failing check in a candidate build', unregistered.join(',') || 'none');
ok(manifest.known_failures.length === register.length && manifest.known_failures.every((k) => register.some((r) => r.suite === k.suite && k.failures === r.failures)), 'the manifest known_failures list is exactly the register');

// --- 6. content identity: the two modern vehicles and the river map, recomputed from the built source ---
const source = path.join(run.runDir, 'clean-source');
ok(fs.existsSync(source), 'the clean committed source used for the build is still on disk');
ok(manifest.modern_river_required === true, 'the package records that modern river content is REQUIRED');
ok(Array.isArray(manifest.required_modern_content) && manifest.required_modern_content.length === 2, 'both required modern vehicles are recorded', (manifest.required_modern_content || []).map((r) => r.vehicle_id).join(', '));
if (Array.isArray(manifest.required_modern_content)) {
  const registry = readJson(path.join(source, 'configs/vehicles/model_sources.json'));
  for (const row of manifest.required_modern_content) {
    const src = path.join(source, row.packet.replace('res://', ''));
    ok(fs.existsSync(src), 'the required packet is in the built source: ' + row.vehicle_id);
    if (fs.existsSync(src)) ok(sha256(src) === String(row.packet_sha256).toUpperCase(), 'the packet hash matches the built source: ' + row.vehicle_id);
    const reg = registry.models[row.vehicle_id];
    ok(!!reg && reg.path === row.model_path && String(reg.sha256).toUpperCase() === String(row.model_sha256).toUpperCase(), 'the model binding matches the registry: ' + row.vehicle_id, row.model_path);
    const modelFile = path.join(source, String(row.model_path).replace('res://', ''));
    ok(fs.existsSync(modelFile), 'the bound model file exists in the built source: ' + row.vehicle_id);
    if (fs.existsSync(modelFile)) ok(sha256(modelFile) === String(row.model_sha256).toUpperCase(), 'the model file hash matches the manifest: ' + row.vehicle_id);
  }
}
ok(manifest.required_map === 'res://scenes/maps/map_river_team.tscn', 'the required map is the river valley', manifest.required_map);
ok(fs.existsSync(path.join(source, 'scenes/maps/map_river_team.tscn')), 'the required map exists in the built source');
ok(manifest.full_player_flow === 'PENDING_SEPARATE_VERIFICATION', 'the full player flow is declared PENDING rather than implied', String(manifest.full_player_flow));

// --- 7. the standing flags ---
ok(manifest.release_ready === false, 'release_ready is false', String(manifest.release_ready));
ok(manifest.candidate === true, 'the package is marked a candidate');
ok(manifest.human === 'PENDING', 'human stays PENDING', manifest.human);
ok(manifest.public_release === false, 'public_release is false', String(manifest.public_release));
ok(pkg.release_ready === false, 'PACKAGE.json also records release_ready false');

console.log('checked=' + checked + ' failed=' + bad);
console.log(bad === 0 ? 'CD16_T01_GATE_PASS' : 'CD16_T01_GATE_FAIL');
process.exit(bad === 0 ? 0 : 1);
