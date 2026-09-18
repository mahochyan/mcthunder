$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$gu="$c\scripts\gunner.gd"
$gl = @(Get-Content $gu -Encoding UTF8)
$before = $gl.Count
$gi = -1
for ($i=0; $i -lt $gl.Count; $i++) { if ($gl[$i] -match '^func supply_racks') { $gi = $i; break } }
'  anchor at line ' + $(if ($gi -ge 0) { $gi+1 } else { 'NONE' })
if ($gi -lt 0) { '  ABORT'; exit 1 }

$block = @()
$block += '## CD10: apply a recorded ammunition reaction to the SINGLE ledger. The loss leaves the racks and is counted in lost, so'
$block += '## nothing is invented and nothing is duplicated and the book still balances.'
$block += 'func apply_ammo_reaction() -> Dictionary:'
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

'=== the block as it will be written, whitespace visible (tab=T) ==='
$i = 0
foreach ($b in $block) { $shown = $b -replace "`t",'T'; '  [' + $i + '] ' + $shown.Substring(0,[Math]::Min(110,$shown.Length)); $i += 1 }

$out = @()
for ($i=0; $i -lt $gi; $i++) { $out += $gl[$i] }
$out += $block
for ($i=$gi; $i -lt $gl.Count; $i++) { $out += $gl[$i] }
[IO.File]::WriteAllLines($gu, $out, (New-Object Text.UTF8Encoding($false)))
'  gunner lines ' + $before + ' -> ' + $out.Count + ' (expect +' + $block.Count + ')'

'=== SHAPE FIRST ==='
& $g --headless --path $c --check-only --script res://scripts/gunner.gd *> "$L\g150.log" 2>&1 | Out-Null
$e = @(Get-Content "$L\g150.log" | Select-String 'Parse Error|Compile Error').Count
'  gunner parse_errors=' + $e
if ($e -gt 0) {
  Get-Content "$L\g150.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
  '  the error line, with whitespace visible:'
  $err = @(Get-Content "$L\g150.log" | Select-String 'gunner.gd:(\d+)' | Select-Object -First 1)
  if ($err -and $err.Line -match 'gunner\.gd:(\d+)') {
    $ln = [int]$Matches[1]
    $now = @(Get-Content $gu -Encoding UTF8)
    for ($k=[Math]::Max(0,$ln-3); $k -le [Math]::Min($now.Count-1,$ln+1); $k++) { $s = $now[$k] -replace "`t",'T'; '        L' + ($k+1) + ': [' + $s.Substring(0,[Math]::Min(110,$s.Length)) + ']' }
  }
  '  REVERTING the gunner'; git -C $c checkout -- scripts/gunner.gd; exit 1
}
& $g --headless --path $c --import *> "$L\impI.log" 2>&1 | Out-Null
'  shape good'
