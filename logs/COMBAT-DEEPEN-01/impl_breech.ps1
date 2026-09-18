$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) the state records a committed breech failure ==='
$st="$c\scripts\defs\vehicle_runtime_state.gd"
$lines = @(Get-Content $st -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'var legacy_migration: Dictionary = \{\}') { $idx = $i; break } }
'  anchor line found at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT: anchor not found, nothing changed'; exit 1 }
$add = @(
  '## CD09-T03: the committed record of a breech failure judged at a real fire request. Each entry carries the shot it was',
  '## judged for, the seed it was rolled from, the rule and its version, and the ability before and after, so the judgement is',
  '## auditable and can never be silently re-rolled.',
  'var breech_failures: Array[Dictionary] = []',
  'var breech_failure: Dictionary = {}'
)
$out = @()
for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($st, $out, (New-Object Text.UTF8Encoding($false)))
'  state lines ' + $n0 + ' -> ' + $out.Count + ' (expect +' + $add.Count + ')'

'=== (b) the gunner judges it once, from the same seed the shot already uses ==='
$gu="$c\scripts\gunner.gd"
$gl = @(Get-Content $gu -Encoding UTF8)
$g0 = $gl.Count
$gi = -1
for ($i=0; $i -lt $gl.Count; $i++) { if ($gl[$i] -match 'var next_shot_id := shot_id \+ 1') { $gi = $i; break } }
'  next_shot_id line found at ' + $(if ($gi -ge 0) { $gi+1 } else { 'NONE' })
if ($gi -lt 0) { '  ABORT: fire path anchor not found, nothing changed'; exit 1 }
$gadd = @(
  ($T+'# CD09-T03: the breech failure is judged HERE, once, at a real fire request, and never per frame. The roll comes from',
   $T+'# the SAME deterministic seed the shot itself uses, so a repeated request for the same shot yields the same outcome and',
   $T+'# a held trigger cannot re-roll it. The module response profile declares which kinds roll at all and with what chance.'),
  ($T+'var breech_kind := "breech"'),
  ($T+'if ModuleResponseProfile.rolls_per_request(breech_kind) and actor != null and actor.state != null:'),
  ($T+$T+'var breech_state: Dictionary = actor.state.module_states.get("breech",{})'),
  ($T+$T+'var breech_fraction := clampf(float(breech_state.get("integrity",1))/maxf(0.0001,float(breech_state.get("max_integrity",1))),0,1)'),
  ($T+$T+'if breech_fraction < 1.0:'),
  ($T+$T+$T+'var roll_seed := hash(JSON.stringify([_current_round(),shooter_id,tank.life_id,shot_id+1,"breech"]))'),
  ($T+$T+$T+'var roll := float(roll_seed % 1000) / 1000.0'),
  ($T+$T+$T+'var chance := ModuleResponseProfile.failure_chance_for(breech_kind) * (1.0 - breech_fraction)'),
  ($T+$T+$T+'if roll < chance:'),
  ($T+$T+$T+$T+'var before_ability := VehicleCapabilities.compute(actor.state)'),
  ($T+$T+$T+$T+'actor.state.breech_failure = {"shot_id":shot_id+1,"seed":roll_seed,"roll":roll,"chance":chance,'),
  ($T+$T+$T+$T+$T+'"rule":"cd009-breech-jam-v1","round_consumed":false,"before_fire":bool(before_ability.get("fire",true))}'),
  ($T+$T+$T+$T+'actor.state.breech_failures.append(actor.state.breech_failure.duplicate(true))'),
  ($T+$T+$T+$T+'blocked_reason = "breech_jam"'),
  ($T+$T+$T+$T+'last_shot_result = "blocked:breech_jam"'),
  ($T+$T+$T+$T+'return false')
)
$gout = @()
for ($i=0; $i -lt $gi; $i++) { $gout += $gl[$i] }
$gout += $gadd
for ($i=$gi; $i -lt $gl.Count; $i++) { $gout += $gl[$i] }
[IO.File]::WriteAllLines($gu, $gout, (New-Object Text.UTF8Encoding($false)))
'  gunner lines ' + $g0 + ' -> ' + $gout.Count + ' (expect +' + $gadd.Count + ')'

'=== SHAPE FIRST ==='
& $g --headless --path $c --check-only --script res://scripts/defs/vehicle_runtime_state.gd *> "$L\sd1.log" 2>&1 | Out-Null
'  state parse_errors=' + @(Get-Content "$L\sd1.log" | Select-String 'Parse Error|Compile Error').Count
& $g --headless --path $c --check-only --script res://scripts/gunner.gd *> "$L\sd2.log" 2>&1 | Out-Null
'  gunner parse_errors=' + @(Get-Content "$L\sd2.log" | Select-String 'Parse Error|Compile Error').Count
foreach ($f in @("$L\sd1.log","$L\sd2.log")) { @(Get-Content $f | Select-String 'Parse Error|at:') | Select-Object -First 3 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) } }
& $g --headless --path $c --import *> "$L\impD.log" 2>&1 | Out-Null
'  import done'
