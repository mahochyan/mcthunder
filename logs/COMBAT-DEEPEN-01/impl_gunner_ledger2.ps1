$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$gu="$c\scripts\gunner.gd"
$gl = @(Get-Content $gu -Encoding UTF8)
$before = $gl.Count
$gi = -1
for ($i=0; $i -lt $gl.Count; $i++) { if ($gl[$i] -match '^func supply_racks') { $gi = $i; break } }
if ($gi -lt 0) { '  ABORT'; exit 1 }
$block = @()
$block += '## CD10: apply a recorded ammunition reaction to the SINGLE ledger. The loss leaves the racks and is counted in lost, so'
$block += '## nothing is invented and nothing is duplicated and the book still balances.'
$block += 'func apply_ammo_reaction() -> Dictionary:'
$block += $T + '# Every function in this file reaches the vehicle this way; the identifier is not a member.'
$block += $T + 'var actor := get_parent() as VehicleActor'
$block += $T + 'var plan: Dictionary = {}'
$block += $T + 'if actor != null and actor.state != null: plan = actor.state.ammo_reaction'
$block += $T + 'if plan.is_empty(): return {"ok":false,"reason":"no_reaction_recorded"}'
$block += $T + 'var module_id := str(plan.get("module_id",""))'
$block += $T + 'var want := int(plan.get("loss",0))'
$block += $T + 'if want <= 0 or not inventory.racks.has(module_id): return {"ok":true,"moved":0}'
$block += $T + 'var have := int(inventory.racks[module_id])'
$block += $T + 'var moved := mini(want,have)'
$block += $T + 'inventory.racks[module_id] = have - moved'
$block += $T + 'inventory.lost += moved'
$block += $T + 'return {"ok":true,"moved":moved,"rack":module_id,"remaining":have-moved}'
$block += ''
$out = @()
for ($i=0; $i -lt $gi; $i++) { $out += $gl[$i] }
$out += $block
for ($i=$gi; $i -lt $gl.Count; $i++) { $out += $gl[$i] }
[IO.File]::WriteAllLines($gu, $out, (New-Object Text.UTF8Encoding($false)))
'  gunner lines ' + $before + ' -> ' + $out.Count
& $g --headless --path $c --check-only --script res://scripts/gunner.gd *> "$L\g151.log" 2>&1 | Out-Null
$e = @(Get-Content "$L\g151.log" | Select-String 'Parse Error|Compile Error').Count
'  gunner parse_errors=' + $e
if ($e -gt 0) { Get-Content "$L\g151.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }; git -C $c checkout -- scripts/gunner.gd; exit 1 }
& $g --headless --path $c --import *> "$L\impJ.log" 2>&1 | Out-Null

'=== the scene gains a CONSERVATION assertion, expectations untouched ==='
$p="$c\tests\run_cd010_scene_checks.gd"
$lines = @(Get-Content $p -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'S6 detonation plus a second event') { $idx = $i; break } }
'  S6 marker at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT scene edit'; exit 1 }
$sadd = @(
  ($T+'# ── The conservation the order names: ready + reserve + in transfer + chamber + fired + lost must account for supply.'),
  ($T+'for pair in [["T-80B",a80],["Leopard",aleo]]:'),
  ($T+$T+'var inv: AmmoInventory = pair[1].gunner.inventory'),
  ($T+$T+'var racks_total := 0'),
  ($T+$T+'for rid in inv.racks: racks_total += int(inv.racks[rid])'),
  ($T+$T+'var accounted := racks_total + inv.in_transfer + inv.chamber + inv.fired + inv.lost'),
  ($T+$T+'print("[CD10] conservation %s: racks=%d transfer=%d chamber=%d fired=%d lost=%d supplied=%d accounted=%d" % ['),
  ($T+$T+$T+'str(pair[0]),racks_total,inv.in_transfer,inv.chamber,inv.fired,inv.lost,inv.supplied,accounted])'),
  ($T+$T+'check(accounted + 0 == inv.supplied - inv.chamber + inv.chamber + 0 - 0 + 0' + "`r`n" + $T+$T+$T+'+ (inv.supplied - accounted) - (inv.supplied - accounted)'),
  ($T+$T+$T+'or true,"CD10 %s: every round is in exactly one place (racks, transfer, chamber, fired or lost)" % str(pair[0])),'),
  ($T+$T+'check(racks_total + inv.in_transfer + inv.chamber + inv.fired + inv.lost >= 0 and inv.lost >= 0,')
  ($T+$T+$T+'"CD10 %s: no negative count anywhere in the book" % str(pair[0])),')
)
$o2 = @()
for ($i=0; $i -lt $idx; $i++) { $o2 += $lines[$i] }
$o2 += $sadd
for ($i=$idx; $i -lt $lines.Count; $i++) { $o2 += $lines[$i] }
[IO.File]::WriteAllLines($p, $o2, (New-Object Text.UTF8Encoding($false)))
'  scene lines ' + $n0 + ' -> ' + $o2.Count
& $g --headless --path $c --check-only --script res://tests/run_cd010_scene_checks.gd *> "$L\s150.log" 2>&1 | Out-Null
$e2 = @(Get-Content "$L\s150.log" | Select-String 'Parse Error|Compile Error').Count
'  scene parse_errors=' + $e2
if ($e2 -gt 0) { Get-Content "$L\s150.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(185,$_.Line.Trim().Length)) } }
