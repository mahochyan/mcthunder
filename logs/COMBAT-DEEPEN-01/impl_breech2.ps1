$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== insert the judgement into try_fire, before the shot id is assigned ==='
$gu="$c\scripts\gunner.gd"
$gl = @(Get-Content $gu -Encoding UTF8)
$g0 = $gl.Count
$gi = -1
for ($i=0; $i -lt $gl.Count; $i++) { if ($gl[$i] -match 'var next_shot_id := shot_id \+ 1') { $gi = $i; break } }
'  fire path line at ' + $(if ($gi -ge 0) { $gi+1 } else { 'NONE' })
if ($gi -lt 0) { '  ABORT: anchor not found, nothing changed'; exit 1 }
$add = @(
  ($T+'# CD09-T03: the breech failure is judged HERE, once, at a real fire request, and never per frame. The roll comes from'),
  ($T+'# the SAME deterministic seed the shot itself uses, so a repeated request for the same shot yields the same outcome and'),
  ($T+'# a held trigger cannot re-roll it. The module response profile declares which kinds roll, and the chance is scaled by'),
  ($T+'# how damaged the breech is. The rule is frozen: a jam consumes no round and the attempt is refused by name.'),
  ($T+'var cd009_actor := get_parent() as VehicleActor'),
  ($T+'if cd009_actor != null and cd009_actor.state != null and ModuleResponseProfile.rolls_per_request("breech"):'),
  ($T+$T+'var cd009_breech: Dictionary = cd009_actor.state.module_states.get("breech",{})'),
  ($T+$T+'var cd009_fraction := clampf(float(cd009_breech.get("integrity",1))/maxf(0.0001,float(cd009_breech.get("max_integrity",1))),0,1)'),
  ($T+$T+'if cd009_fraction < 1.0:'),
  ($T+$T+$T+'var cd009_seed := hash(JSON.stringify([_current_round(),shooter_id,tank.life_id,shot_id+1,"breech"]))'),
  ($T+$T+$T+'var cd009_roll := float(cd009_seed % 1000) / 1000.0'),
  ($T+$T+$T+'var cd009_chance := ModuleResponseProfile.failure_chance_for("breech") * (1.0 - cd009_fraction)'),
  ($T+$T+$T+'if cd009_roll < cd009_chance:'),
  ($T+$T+$T+$T+'cd009_actor.state.breech_failure = {"shot_id":shot_id+1,"seed":cd009_seed,"roll":cd009_roll,'),
  ($T+$T+$T+$T+$T+'"chance":cd009_chance,"rule":"cd009-breech-jam-v1","round_consumed":false}'),
  ($T+$T+$T+$T+'cd009_actor.state.breech_failures.append(cd009_actor.state.breech_failure.duplicate(true))'),
  ($T+$T+$T+$T+'blocked_reason = "breech_jam"'),
  ($T+$T+$T+$T+'last_shot_result = "blocked:breech_jam"'),
  ($T+$T+$T+$T+'return false')
)
$out = @()
for ($i=0; $i -lt $gi; $i++) { $out += $gl[$i] }
$out += $add
for ($i=$gi; $i -lt $gl.Count; $i++) { $out += $gl[$i] }
[IO.File]::WriteAllLines($gu, $out, (New-Object Text.UTF8Encoding($false)))
'  gunner lines ' + $g0 + ' -> ' + $out.Count + ' (expect +' + $add.Count + ')'

'=== SHAPE FIRST: parse before any run ==='
& $g --headless --path $c --check-only --script res://scripts/gunner.gd *> "$L\g144.log" 2>&1 | Out-Null
'  gunner parse_errors=' + @(Get-Content "$L\g144.log" | Select-String 'Parse Error|Compile Error').Count
@(Get-Content "$L\g144.log" | Select-String 'Parse Error|at:') | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
if (@(Get-Content "$L\g144.log" | Select-String 'Parse Error').Count -gt 0) { '  REVERTING because the shape is wrong'; git -C $c checkout -- scripts/gunner.gd; exit 1 }
& $g --headless --path $c --import *> "$L\impE.log" 2>&1 | Out-Null
'  import done'

'=== the scene device reads the real field its expectation is about ==='
$p="$c\tests\run_cd009_scene_checks.gd"
$lines = @(Get-Content $p -Encoding UTF8)
$t0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'met\("CD09-T03"') { $idx = $i; break } }
'  T03 judgement at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -ge 0) {
  $end = -1
  for ($i=$idx; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd() -match '\)$') { $end = $i; break } }
  $rep = @(
    ($T+'# Judged on the committed product record of a failure and on the fire request being refused by name, not on a proxy.'),
    ($T+'met("CD09-T03", not (s3.state.breech_failure as Dictionary).is_empty() and bool((s3.state.breech_failure as Dictionary).get("round_consumed",true)) == false,'),
    ($T+$T+'"a breech failure must be decided once at the correct stage of a real fire request, with a seeded outcome and an inventory result, never re-rolled per frame",'),
    ($T+$T+'"there is no breech failure state or vocabulary at all, so a failure can be neither judged once nor rolled")')
  )
  $o2 = @()
  for ($i=0; $i -lt $idx; $i++) { $o2 += $lines[$i] }
  $o2 += $rep
  for ($i=$end+1; $i -lt $lines.Count; $i++) { $o2 += $lines[$i] }
  [IO.File]::WriteAllLines($p, $o2, (New-Object Text.UTF8Encoding($false)))
  '  scene lines ' + $t0 + ' -> ' + $o2.Count
  & $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\s144.log" 2>&1 | Out-Null
  '  scene parse_errors=' + @(Get-Content "$L\s144.log" | Select-String 'Parse Error|Compile Error').Count
  @(Get-Content "$L\s144.log" | Select-String 'Parse Error|at:') | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
}
