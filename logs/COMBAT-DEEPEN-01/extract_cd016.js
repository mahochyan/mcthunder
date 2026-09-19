// CD16 stage zero: pull the order and its six cases out of the READ-ONLY packaged list, into a file,
// because the console cannot be trusted to render the packaged Chinese correctly.
const fs = require('fs');
const orders = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/07_WORK_ORDERS.json', 'utf8'));
const items = orders.items || orders.work_orders || orders;
const wo = items.find((o) => o.id === 'WT-CD-016' || o.work_order_id === 'WT-CD-016');
const cases = JSON.parse(fs.readFileSync('docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json', 'utf8'));
const list = (cases.cases || cases).filter((c) => c.work_order === 'WT-CD-016' || c.id.startsWith('CD16-'));
const out = [];
out.push('# WT-CD-016 as the package states it (verbatim, read-only source)');
out.push('');
out.push('```json');
out.push(JSON.stringify(wo, null, 2));
out.push('```');
out.push('');
out.push('## Six acceptance cases');
out.push('');
for (const c of list) {
  out.push('### ' + c.id + ' | ' + c.title);
  out.push('');
  out.push('```json');
  out.push(JSON.stringify(c, null, 2));
  out.push('```');
  out.push('');
}
fs.writeFileSync('logs/COMBAT-DEEPEN-01/cd016_order_extract.md', out.join('\n'), 'utf8');
console.log('orders_file_keys=' + Object.keys(orders).join(','));
console.log('work_order_fields=' + Object.keys(wo).join(','));
console.log('cases=' + list.length + ' ids=' + list.map((c) => c.id).join(','));
console.log('extract_lines=' + out.length);
