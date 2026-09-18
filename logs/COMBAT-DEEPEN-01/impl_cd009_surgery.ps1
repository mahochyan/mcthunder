$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\damage\vehicle_capabilities.gd"
$lines = Get-Content $p -Encoding UTF8

# Deterministic line surgery: find the loop header, then replace its body by index rather than by text anchor.
$head = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'for id in state\.module_states') { $head = $i; break } }
'  loop header at line ' + ($head+1)
$prefix = @()
for ($i=0; $i -le $head; $i++) { $prefix += $lines[$i] }
$suffix = @()
for ($i=$head+1; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match ('^'+$T+'match str\(m\.get\("kind"')) { $suffix += $lines[$i]; continue }
  if ($suffix.Count -gt 0) { $suffix += $lines[$i] } else { continue }
}
'  suffix starts with: ' + $suffix[0].Trim()
$body = @(
  ($T+$T+'var m: Dictionary=state.module_states[id]'),
  ($T+$T+'var fraction := clampf(float(m.get("integrity",0))/maxf(0.0001,float(m.get("max_integrity",1))),0,1)'),
  ($T+$T+'# CD09: the response is chosen PER KIND by the module response profile, not by one uniform multiplier for every' + $T+'module'),
  ($T+$T+'# and not all-or-nothing at zero. This function remains the only place ability is derived.'),
  ($T+$T+'var cd009_kind := str(m.get("kind",""))'),
  ($T+$T+'var cd009_response := ModuleResponseProfile.factor_for(cd009_kind,fraction)'),
  ($T+$T+'if cd009_kind=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,cd009_response)'),
  ($T+$T+'if cd009_kind=="turret_vertical_drive": pitch_scale=minf(pitch_scale,cd009_response)'),
  ($T+$T+'if fraction >= 1.0:'),
  ($T+$T+$T+'continue'),
  ($T+$T+'if cd009_response > 0.0:'),
  ($T+$T+$T+'reasons.append(cd009_kind+":"+ModuleResponseProfile.strategy_for(cd009_kind)+":%.2f"%fraction)'),
  ($T+$T+$T+'continue')
)
$out = @()
$out += $prefix
$out += $body
$out += $suffix
[IO.File]::WriteAllLines($p, $out, (New-Object Text.UTF8Encoding($false)))
"  new file lines=" + $out.Count + " ; profile_used=" + ((Get-Content $p -Raw -Encoding UTF8).Contains('ModuleResponseProfile.factor_for'))

& $g --headless --path $c --import *> "$L\impB.log" 2>&1 | Out-Null
& $g --headless --path $c --check-only --script res://scripts/damage/vehicle_capabilities.gd *> "$L\pc9c3.log" 2>&1 | Out-Null
"  capabilities parse_errors=" + @(Get-Content "$L\pc9c3.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pc9c3.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pc9c3.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "     " + $_.Line.Trim().Substring(0,[Math]::Min(185,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9impl3.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9impl3.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09\] S1|CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(225,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
$tp=0;$tf=0;$bad=@()
foreach ($s in @('run_damage_checks','run_recovery_checks','run_historical_checks','run_loading_checks','run_fire_control_checks','run_ai_combat_checks','run_modern_equipment_checks','run_shell_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\ck-$s.log"
  $o2 = Get-Content "$L\ck-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o2|Select-String '^\[PASS\]').Count; $ff=@($o2|Select-String '^\[FAIL\]').Count
  $tp+=$pp;$tf+=$ff; if ($ff -gt 0) { $bad += $s }
  "  {0,-30} PASS={1,4} FAIL={2}" -f $s,$pp,$ff
  @($o2|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(165,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
