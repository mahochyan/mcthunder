$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\damage\vehicle_capabilities.gd"
$t = Get-Content $p -Raw -Encoding UTF8

'=== edit 1: compute the per-kind response right after the fraction (single-line anchor) ==='
$a1 = $T+$T+'var fraction := clampf(float(m.get("integrity",0))/maxf(0.0001,float(m.get("max_integrity",1))),0,1)'
$b1 = $a1 + "`r`n" + `
  $T+$T+'# CD09: the response is chosen PER KIND by the profile, not by one uniform multiplier and not all-or-nothing at zero.' + "`r`n" + `
  $T+$T+'var cd009_kind := str(m.get("kind",""))' + "`r`n" + `
  $T+$T+'var cd009_response := ModuleResponseProfile.factor_for(cd009_kind,fraction)'
$n1 = ([regex]::Matches($t,[regex]::Escape($a1))).Count
$t = $t.Replace($a1,$b1)

'=== edit 2: the axis scales and the skip test use the response (single-line anchors) ==='
$a2 = $T+$T+'if m.get("kind")=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,fraction)'
$n2 = ([regex]::Matches($t,[regex]::Escape($a2))).Count
$t = $t.Replace($a2, $T+$T+'if cd009_kind=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,cd009_response)')
$a3 = $T+$T+'if m.get("kind")=="turret_vertical_drive": pitch_scale=minf(pitch_scale,fraction)'
$n3 = ([regex]::Matches($t,[regex]::Escape($a3))).Count
$t = $t.Replace($a3, $T+$T+'if cd009_kind=="turret_vertical_drive": pitch_scale=minf(pitch_scale,cd009_response)')
$a4 = $T+$T+'if float(m.get("integrity",0)) > 0:'
$n4 = ([regex]::Matches($t,[regex]::Escape($a4))).Count
$b4 = $T+$T+'# A module at full integrity cannot reduce anything; anything below it that still has a response records its kind,' + "`r`n" + `
  $T+$T+'# its strategy and its fraction, so the reason list says WHY ability changed rather than only that it did.' + "`r`n" + `
  $T+$T+'if fraction >= 1.0:' + "`r`n" + `
  $T+$T+$T+'continue' + "`r`n" + `
  $T+$T+'if cd009_response > 0.0:' + "`r`n" + `
  $T+$T+$T+'reasons.append(cd009_kind+":"+ModuleResponseProfile.strategy_for(cd009_kind)+":%.2f"%fraction)' + "`r`n" + `
  $T+$T+$T+'continue'
$t = $t.Replace($a4,$b4)
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))
"  fraction_anchor=$n1 axes=$n2/$n3 skip_anchor=$n4 ; profile_used=" + $t.Contains('ModuleResponseProfile.factor_for')

& $g --headless --path $c --import *> "$L\impA.log" 2>&1 | Out-Null
& $g --headless --path $c --check-only --script res://scripts/damage/vehicle_capabilities.gd *> "$L\pc9c2.log" 2>&1 | Out-Null
"  capabilities parse_errors=" + @(Get-Content "$L\pc9c2.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pc9c2.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pc9c2.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "     " + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9impl2.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9impl2.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09\] S1|CD09\] S2|CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(230,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
$tp=0;$tf=0;$bad=@()
foreach ($s in @('run_damage_checks','run_recovery_checks','run_historical_checks','run_loading_checks','run_fire_control_checks','run_ai_combat_checks','run_modern_equipment_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\cj-$s.log"
  $o2 = Get-Content "$L\cj-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o2|Select-String '^\[PASS\]').Count; $ff=@($o2|Select-String '^\[FAIL\]').Count
  $tp+=$pp;$tf+=$ff; if ($ff -gt 0) { $bad += $s }
  "  {0,-30} PASS={1,4} FAIL={2}" -f $s,$pp,$ff
  @($o2|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(165,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
