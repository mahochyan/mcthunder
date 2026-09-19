// WT-EXPANSION-01 item B step 3: add the input action the secondary weapon needs.
// Written as a FILE rather than an inline command because the inline form hit PowerShell quoting for the fourth time
// this session - the same recorded lesson, applied late.
const fs = require('fs');
const p = 'project.godot';
const t = fs.readFileSync(p, 'utf8');
const anchor = 'shell_2={\r\n"deadzone": 0.5,\r\n"events": [Object(InputEventKey,"physical_keycode":50)]\r\n}\r\n';
if (!t.includes(anchor)) { console.error('ANCHOR_MISSING'); process.exit(2); }
if (t.includes('fire_secondary=')) { console.error('ALREADY_PRESENT'); process.exit(3); }
// physical_keycode 72 is H. The action fires the SECONDARY channel, which is separate from `fire` (mouse left) and
// from shell_1 / shell_2 (the main gun selection), so no existing binding changes meaning.
const add = 'fire_secondary={\r\n"deadzone": 0.5,\r\n"events": [Object(InputEventKey,"physical_keycode":72)]\r\n}\r\n';
fs.writeFileSync(p, t.replace(anchor, anchor + add), 'utf8');
const after = fs.readFileSync(p, 'utf8');
console.log('fire_secondary_present=' + after.includes('fire_secondary=') + ' bytes=' + after.length);
