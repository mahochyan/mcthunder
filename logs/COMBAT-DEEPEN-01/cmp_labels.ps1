$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\defs\vehicle_runtime_state.gd"

function Labels($log) {
  return @(Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[PASS\]' | ForEach-Object { $_.Line.Trim().Substring(6).Trim() })
}

'=== A: baseline run, capture the ordered labels ==='
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\cmpA.log"
$a = Labels "$L\cmpA.log"
"  A passes=" + $a.Count + " fails=" + @(Get-Content "$L\cmpA.log" -ErrorAction SilentlyContinue | Select-String '^\[FAIL\]').Count

'=== B: apply the decoupling to production ONLY, run again ==='
$txt = Get-Content $p -Raw -Encoding UTF8
$anc = $T+$T+'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = station.id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = station.id'
$rep = $T+$T+'person_counter += 1' + "`r`n" + `
  $T+$T+'var person_id := "person_%d" % person_counter' + "`r`n" + `
  $T+$T+'crew_states[person_id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = person_id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = person_id'
$n1 = ([regex]::Matches($txt,[regex]::Escape($anc))).Count
$txt = $txt.Replace($anc,$rep)
$anc2 = $T+'for station in layout.crew_stations:'
$n2 = ([regex]::Matches($txt,[regex]::Escape($anc2))).Count
$txt = $txt.Replace($anc2, $T+'var person_counter := 0' + "`r`n" + $anc2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  decoupling_applied anchor=$n1 counter=$n2"
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\cmpB.log"
$b = Labels "$L\cmpB.log"
"  B passes=" + $b.Count + " fails=" + @(Get-Content "$L\cmpB.log" -ErrorAction SilentlyContinue | Select-String '^\[FAIL\]').Count

'=== the labels that STOPPED appearing, and the ones that started ==='
$gone = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject })
$new = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject })
"  GONE (" + $gone.Count + "):"
$gone | ForEach-Object { "    - " + $_ }
"  NEW (" + $new.Count + "):"
$new | ForEach-Object { "    + " + $_ }
'=== the failures in run B ==='
@(Get-Content "$L\cmpB.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[FAIL\]') | ForEach-Object { "    " + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }

'=== revert production immediately ==='
git -C $c checkout -- scripts/defs/vehicle_runtime_state.gd
'  tracked changes=' + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }).Count
