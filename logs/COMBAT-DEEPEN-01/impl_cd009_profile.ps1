$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\damage\vehicle_capabilities.gd"
$t = Get-Content $p -Raw -Encoding UTF8

'=== replace the all-or-nothing skip with the per-kind profile, keeping ONE derivation ==='
$a = $T+$T+'var fraction := clampf(float(m.get("integrity",0))/maxf(0.0001,float(m.get("max_integrity",1))),0,1)' + "`r`n" + `
  $T+$T+'if m.get("kind")=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,fraction)' + "`r`n" + `
  $T+$T+'if m.get("kind")=="turret_vertical_drive": pitch_scale=minf(pitch_scale,fraction)' + "`r`n" + `
  $T+$T+'if float(m.get("integrity",0)) > 0:' + "`r`n" + `
  $T+$T+$T+'continue'
$b = $T+$T+'var fraction := clampf(float(m.get("integrity",0))/maxf(0.0001,float(m.get("max_integrity",1))),0,1)' + "`r`n" + `
  $T+$T+'# CD09: the response is chosen PER KIND rather than one uniform multiplier, and rather than all-or-nothing at zero.' + "`r`n" + `
  $T+$T+'# The profile is the only place that decision is made; this function stays the only place ability is derived.' + "`r`n" + `
  $T+$T+'var kind := str(m.get("kind",""))' + "`r`n" + `
  $T+$T+'var response := ModuleResponseProfile.factor_for(kind,fraction)' + "`r`n" + `
  $T+$T+'if kind=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,response)' + "`r`n" + `
  $T+$T+'if kind=="turret_vertical_drive": pitch_scale=minf(pitch_scale,response)' + "`r`n" + `
  $T+$T+'if fraction >= 1.0:' + "`r`n" + `
  $T+$T+$T+'continue' + "`r`n" + `
  $T+$T+'if response > 0.0 and fraction > 0.0 and ModuleResponseProfile.strategy_for(kind) != "binary_at_zero":' + "`r`n" + `
  $T+$T+$T+'reasons.append(kind+":"+ModuleResponseProfile.strategy_for(kind)+":%.2f"%fraction)' + "`r`n" + `
  $T+$T+'if response > 0.0:' + "`r`n" + `
  $T+$T+$T+'continue'
$n = ([regex]::Matches($t,[regex]::Escape($a))).Count
$t = $t.Replace($a,$b)
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))
"  binary_skip_replaced=$n ; profile_used=" + $t.Contains('ModuleResponseProfile.factor_for')
& $g --headless --path $c --import *> "$L\imp9.log" 2>&1 | Out-Null
& $g --headless --path $c --check-only --script res://scripts/damage/vehicle_capabilities.gd *> "$L\pc9c.log" 2>&1 | Out-Null
"  capabilities parse_errors=" + @(Get-Content "$L\pc9c.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pc9c.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pc9c.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "     " + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }; exit 1 }
'=== the CD09 scenes ==='
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9impl.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9impl.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09\] S|CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(230,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
'=== a broad slice, because the capability outputs changed ==='
$tp=0;$tf=0;$bad=@()
foreach ($s in @('run_damage_checks','run_recovery_checks','run_historical_checks','run_loading_checks','run_fire_control_checks','run_ai_combat_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\ci-$s.log"
  $o2 = Get-Content "$L\ci-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o2|Select-String '^\[PASS\]').Count; $ff=@($o2|Select-String '^\[FAIL\]').Count
  $tp+=$pp;$tf+=$ff; if ($ff -gt 0) { $bad += $s }
  "  {0,-28} PASS={1,4} FAIL={2}" -f $s,$pp,$ff
  @($o2|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(165,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
