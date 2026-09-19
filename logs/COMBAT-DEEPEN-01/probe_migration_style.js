const fs = require('fs');
const raw = fs.readFileSync('docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json', 'utf8');
function show(seg) {
  return seg.split('\r\n').map((l) => String(l.length - l.trimStart().length) + '|' + l.trim()).join('\n');
}
const i = raw.indexOf('"work_order_id":  "WT-CD-014"');
const start = raw.lastIndexOf('{', i);
console.log('--- last entry head ---');
console.log(show(raw.slice(start, start + 420)));
const j = raw.indexOf('"divergences":  "The known version table', start);
console.log('--- last entry tail ---');
console.log(show(raw.slice(j, j + 160)));
const k = raw.indexOf('"changes"');
console.log('--- changes head ---');
console.log(show(raw.slice(k, k + 90)));
const m = raw.indexOf('"migration_index"');
console.log('--- migration index head ---');
console.log(show(raw.slice(m, m + 130)));
const f = raw.indexOf('"fields":  [', start);
console.log('--- fields array ---');
console.log(show(raw.slice(f, f + 150)));
const r = raw.indexOf('"reference_sources":  [', start);
console.log('--- reference_sources array ---');
console.log(show(raw.slice(r, r + 120)));
