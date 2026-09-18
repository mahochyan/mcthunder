$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== apply the production decoupling ==='
$p="$c\scripts\defs\vehicle_runtime_state.gd"
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
$txt = $txt.Replace($anc2, $T+'var person_counter := 0' + "`r`n" + $anc2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  decoupled=$n1"

'=== rewrite the two legs in question WITH a print of every sub-value ==='
$q="$c\tests\run_damage_checks.gd"
$tq = Get-Content $q -Raw -Encoding UTF8
$a1 = '	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")'
$b1 = '	var mover := str(b.state.crew_assignments.get("commander",""))' + "`r`n" + `
  '	var mover_state: Dictionary = (b.state.crew_states.get(mover,{}) as Dictionary).duplicate(true)' + "`r`n" + `
  '	print("[CD08 leg] before: mover=%s alive=%s assignments=%s" % [mover,str(mover_state.get("alive","")),str(b.state.crew_assignments)])' + "`r`n" + `
  '	var moved_ok := b.state.assign_crew("driver",mover)' + "`r`n" + `
  '	print("[CD08 leg] after : moved=%s assignments=%s people_alive=%s" % [str(moved_ok),str(b.state.crew_assignments),str((b.state.crew_states.get(mover,{}) as Dictionary).get("alive",""))])' + "`r`n" + `
  '	_ok(moved_ok,"living person can occupy another role")' + "`r`n" + `
  '	_ok(b.state.crew_states.get(mover,{}) == mover_state,"the moving person keeps their own state rather than becoming someone else")'
$m1 = ([regex]::Matches($tq,[regex]::Escape($a1))).Count
$tq = $tq.Replace($a1,$b1)
$a2 = '	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")'
$b2 = '	print("[CD08 leg] check: commander_slot=%s driver_slot=%s mover=%s" % [str(b.state.crew_assignments.get("commander","<none>")),str(b.state.crew_assignments.get("driver","<none>")),mover])' + "`r`n" + `
  '	_ok(str(b.state.crew_assignments.get("commander","")) == "" and str(b.state.crew_assignments.get("driver","")) == mover,"one person never occupies two roles")'
$m2 = ([regex]::Matches($tq,[regex]::Escape($a2))).Count
$tq = $tq.Replace($a2,$b2)
[IO.File]::WriteAllText($q, $tq, (New-Object Text.UTF8Encoding($false)))
"  legs_rewritten_with_print=$m1/$m2"

& $g --headless --path $c --import *> "$L\imp5.log" 2>&1 | Out-Null
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\leg.log"
$o = Get-Content "$L\leg.log" -Encoding UTF8 -ErrorAction SilentlyContinue
"  damage PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count
$o | Select-String 'CD08 leg|^\[FAIL\]' | Select-Object -First 8 | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(230,$_.Line.Trim().Length)) }
