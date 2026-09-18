$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# T02 proper: a person identity independent of BOTH the role and the station, assigned by station order and stable across moves.
$a = $T+$T+'# CD08-T02 REVERTED: binding a person identity to the role made a move change who the person is, and the existing' + "`r`n" + `
  $T+$T+'# suite already asserts that a living person can occupy another role. The proper fix needs an identity independent of' + "`r`n" + `
  $T+$T+'# both the role and the station, which is the next step; until then this stays exactly as it was.' + "`r`n" + `
  $T+$T+'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = station.id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = station.id'
$b = $T+$T+'# CD08-T02: a person identity that depends on NEITHER the role nor the station. It is handed out in station order,' + "`r`n" + `
  $T+$T+'# so a person who moves to another role keeps the same identity and the same injuries, which is what the order asks' + "`r`n" + `
  $T+$T+'# for: the thing that moves is the person, not a copy of them. The role remains the bridge, as before.' + "`r`n" + `
  $T+$T+'person_counter += 1' + "`r`n" + `
  $T+$T+'var person_id := "person_%d" % person_counter' + "`r`n" + `
  $T+$T+'crew_states[person_id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = person_id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = person_id'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)

# the counter is local to initialisation, so a rebuilt layout never reuses an identity from a previous one
$a2 = $T+'for station in layout.crew_stations:'
$b2 = $T+'var person_counter := 0' + "`r`n" + $T + 'for station in layout.crew_stations:'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  person_index_scheme=$n1 ; counter=$n2"
& $g --headless --path $c --check-only --script res://scripts/defs/vehicle_runtime_state.gd *> "$L\pc8.log" 2>&1 | Out-Null
$e=@(Get-Content "$L\pc8.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$e"
if ($e -gt 0) { Get-Content "$L\pc8.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "     " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd008_scene_checks.gd *> "$L\cd008-scenes9.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd008-scenes9.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD08\] baseline|CD08\] S2|CD08-T0|CD08_SCENES|NOT_YET_MET |=== 结果' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(230,$_.Line.Trim().Length)) }
'  --- the existing crew legs ---'
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\dm2.log"
$o=Get-Content "$L\dm2.log" -ErrorAction SilentlyContinue
"  run_damage_checks PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count
@($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
