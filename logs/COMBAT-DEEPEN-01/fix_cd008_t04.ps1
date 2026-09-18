$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

# (T04) land the guard with the REAL indentation: three tabs.
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$a = $T+$T+$T+'crew_states[person] = after.duplicate(true)'
$b = $T+$T+$T+'# CD08-T04: an incapacitated person does not come back in this life. Recovery for lesser conditions is a declared' + "`r`n" + `
  $T+$T+$T+'# rule that this version does not have, so raising anyone out of incapacitation is refused by name.' + "`r`n" + `
  $T+$T+$T+'var was_incapacitated := CrewDamageProfile.is_incapacitated(str((crew_states[person] as Dictionary).get("condition","")))' + "`r`n" + `
  $T+$T+$T+'var now_available := bool(after.get("alive",false)) and CrewDamageProfile.is_available(str(after.get("condition",CrewDamageProfile.CONDITION_HEALTHY)))' + "`r`n" + `
  $T+$T+$T+'if was_incapacitated and now_available:' + "`r`n" + `
  $T+$T+$T+$T+'return {"ok":false,"reason":"incapacitated_in_this_life"}' + "`r`n" + `
  $T+$T+$T+'crew_states[person] = after.duplicate(true)'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  incap_guard_landed=$n1"

# (T02 device) the scenes resolve the PERSON, because a person is no longer named by a station.
$q="$c\tests\run_cd008_scene_checks.gd"
$tv = Get-Content $q -Raw -Encoding UTF8
$before = $tv
$tv = $tv.Replace('_crew_submission(state,"station_gunner"','_crew_submission(state,"person_gunner"')
$tv = $tv.Replace('_crew_submission(state,"station_driver"','_crew_submission(state,"person_driver"')
$tv = $tv.Replace('(snap0.get("people",{}).get("station_gunner",{}) as Dictionary)','(snap0.get("people",{}).get("person_gunner",{}) as Dictionary)')
$tv = $tv.Replace('after_first.get("station_gunner",{})','after_first.get("person_gunner",{})')
[IO.File]::WriteAllText($q, $tv, (New-Object Text.UTF8Encoding($false)))
"  scene_device_updated=" + [int]($tv -ne $before)
$g2 = & $g --headless --path $c --check-only --script res://tests/run_cd008_scene_checks.gd *> "$L\pc5.log" 2>&1; 
$e=@(Get-Content "$L\pc5.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$e"
if ($e -gt 0) { Get-Content "$L\pc5.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "     " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
& $g --headless --path $c --check-only --script res://scripts/defs/vehicle_runtime_state.gd *> "$L\pc6.log" 2>&1 | Out-Null
"  state_parse_errors=" + @(Get-Content "$L\pc6.log" | Select-String 'Parse Error|Compile Error').Count
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd008_scene_checks.gd *> "$L\cd008-scenes8.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd008-scenes8.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD08\]|CD08-T0|CD08_SCENES|=== 结果|NOT_YET_MET ' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
