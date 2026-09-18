$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== 1) decouple the person identity from the station in production ==='
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$anc = $T+$T+'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = station.id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = station.id'
$rep = $T+$T+'# CD08-T02: a person identity that depends on NEITHER the role nor the station, handed out in station order, so a' + "`r`n" + `
  $T+$T+'# person who moves keeps the same identity and the same injuries. The role remains the bridge to the station.' + "`r`n" + `
  $T+$T+'person_counter += 1' + "`r`n" + `
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
"  decoupled anchors=$n1 counter=$n2"

'=== 2) the three delivered sites that name a person by a station, made data driven ==='
$q="$c\tests\run_damage_checks.gd"
$tq = Get-Content $q -Raw -Encoding UTF8
$a1 = '	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")'
$b1 = '	var mover := str(b.state.crew_assignments.get("commander",""))' + "`r`n" + `
  '	_ok(not mover.is_empty() and mover != "commander","the person in the commander station is identified apart from the station")' + "`r`n" + `
  '	var mover_state: Dictionary = (b.state.crew_states.get(mover,{}) as Dictionary).duplicate(true)' + "`r`n" + `
  '	_ok(b.state.assign_crew("driver",mover),"living person can occupy another role")' + "`r`n" + `
  '	_ok(b.state.crew_states.get(mover,{}) == mover_state,"the moving person keeps their own state rather than becoming someone else")'
$m1 = ([regex]::Matches($tq,[regex]::Escape($a1))).Count
$tq = $tq.Replace($a1,$b1)
$a2 = '	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")'
$b2 = '	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == mover,"one person never occupies two roles")'
$m2 = ([regex]::Matches($tq,[regex]::Escape($a2))).Count
$tq = $tq.Replace($a2,$b2)
$a3 = '	_ok(not b.state.crew_states.gunner.alive,"90-degree turret uses actual rotated crew station")'
$b3 = '	var gunner_person := str(b.state.crew_assignments.get("gunner",""))' + "`r`n" + `
  '	_ok(not gunner_person.is_empty() and not bool((b.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",true)),"90-degree turret uses actual rotated crew station")'
$m3 = ([regex]::Matches($tq,[regex]::Escape($a3))).Count
$tq = $tq.Replace($a3,$b3)
[IO.File]::WriteAllText($q, $tq, (New-Object Text.UTF8Encoding($false)))
"  sites fixed: assign=$m1 second=$m2 rotated=$m3"

& $g --headless --path $c --import *> "$L\imp3.log" 2>&1 | Out-Null
foreach ($f in @('res://scripts/defs/vehicle_runtime_state.gd','res://tests/run_damage_checks.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\pcx.log" 2>&1 | Out-Null
  "  " + $f + " parse_errors=" + @(Get-Content "$L\pcx.log" | Select-String 'Parse Error|Compile Error').Count
}
'=== 3) the damage suite, with counts compared to the baseline of 57 ==='
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\dmF.log"
$o = Get-Content "$L\dmF.log" -ErrorAction SilentlyContinue
"  run_damage_checks PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count + " SCRIPT_ERROR=" + @($o|Select-String 'SCRIPT ERROR').Count
@($o|Select-String '^\[FAIL\]|SCRIPT ERROR') | Select-Object -First 4 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }
'=== 4) ALL THIRTEEN suites that touch crew state, failures AND counts ==='
$suites = @('run_ai_combat_checks','run_ai_recovery_checks','run_ai_tactics_checks','run_ammo_compartment_checks','run_damage_checks','run_engineering_damage_checks','run_engineering_loading_checks','run_fire_control_checks','run_historical_checks','run_loading_checks','run_modern_candidate_checks','run_recovery_checks','run_recovery_player_checks')
$tp=0;$tf=0;$bad=@()
foreach ($s in $suites) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\c13-$s.log"
  $o2 = Get-Content "$L\c13-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o2|Select-String '^\[PASS\]').Count; $ff=@($o2|Select-String '^\[FAIL\]').Count; $se=@($o2|Select-String 'SCRIPT ERROR').Count
  $tp+=$pp;$tf+=$ff; if ($ff -gt 0 -or $se -gt 0) { $bad+=$s }
  "  {0,-34} exit={1} PASS={2,4} FAIL={3} ERR={4}" -f $s,$LASTEXITCODE,$pp,$ff,$se
  @($o2|Select-String '^\[FAIL\]|SCRIPT ERROR') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
