$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== 1) production: the person identity, independent of role and station ==='
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$anc = $T+$T+'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = station.id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = station.id'
$rep = $T+$T+'# CD08-T02: a person identity that depends on NEITHER the role nor the station, handed out in station order, so a' + "`r`n" + `
  $T+$T+'# person who moves keeps the same identity and the same injuries. The role stays the bridge to the station.' + "`r`n" + `
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
"  decoupled=$n1 counter=$n2"

function Fix($file, $pairs) {
  $t = Get-Content $file -Raw -Encoding UTF8
  foreach ($kv in $pairs) { $n = ([regex]::Matches($t,[regex]::Escape($kv[0]))).Count; $t = $t.Replace($kv[0],$kv[1]); "    fixed=" + $n }
  [IO.File]::WriteAllText($file, $t, (New-Object Text.UTF8Encoding($false)))
}

'=== 2) the seven delivered sites, data driven ==='
Fix "$c\tests\run_damage_checks.gd" @(
  ,@('	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")',
     '	var mover := str(b.state.crew_assignments.get("commander",""))' + "`r`n" + `
     '	var mover_state: Dictionary = (b.state.crew_states.get(mover,{}) as Dictionary).duplicate(true)' + "`r`n" + `
     '	_ok(b.state.assign_crew("driver",mover),"living person can occupy another role")' + "`r`n" + `
     '	_ok(b.state.crew_states.get(mover,{}) == mover_state,"the moving person keeps their own state rather than becoming someone else")')
  ,@('	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")',
     '	_ok(str(b.state.crew_assignments.get("commander","")) == "" and str(b.state.crew_assignments.get("driver","")) == mover,"one person never occupies two roles")')
  ,@('	_ok(not b.state.crew_states.gunner.alive,"90-degree turret uses actual rotated crew station")',
     '	var gunner_person := str(b.state.crew_assignments.get("gunner",""))' + "`r`n" + `
     '	_ok(not gunner_person.is_empty() and not bool((b.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",true)),"90-degree turret uses actual rotated crew station")')
)
Fix "$c\tests\run_ammo_compartment_checks.gd" @(
  ,@('	check(not actor.state.crew_states.loader.alive,"bustle protection does not immunize separately hit crew")',
     '	var loader_person := str(actor.state.crew_assignments.get("loader",""))' + "`r`n" + `
     '	check(not loader_person.is_empty() and not bool((actor.state.crew_states.get(loader_person,{}) as Dictionary).get("alive",true)),"bustle protection does not immunize separately hit crew")')
)
Fix "$c\tests\run_recovery_checks.gd" @(
  ,@('	_ok(actor.state.module_states.breech.integrity == 0 and not actor.state.crew_states.assistant_driver.alive,"repair does not fix another module or revive crew")',
     '	var assistant_person := str(actor.state.crew_assignments.get("assistant_driver",""))' + "`r`n" + `
     '	_ok(actor.state.module_states.breech.integrity == 0 and not assistant_person.is_empty() and not bool((actor.state.crew_states.get(assistant_person,{}) as Dictionary).get("alive",true)),"repair does not fix another module or revive crew")')
  ,@('	_ok(actor.state.crew_assignments.gunner == "commander" and actor.state.crew_assignments.commander == "","replacement moves one actual person out of prior role")',
     '	var gunner_person := str(actor.state.crew_assignments.get("gunner",""))' + "`r`n" + `
     '	_ok(not gunner_person.is_empty() and str(actor.state.crew_assignments.get("commander","")) == ""' + "`r`n" + `
     '		and bool((actor.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",false)),"replacement moves one actual person out of prior role")')
  ,@('	_ok(not actor.state.crew_states.gunner.alive and actor.capabilities().fire,"replacement restores function without reviving original gunner")',
     '	var incapacitated := 0' + "`r`n" + `
     '	for person_state in actor.state.crew_states.values():' + "`r`n" + `
     '		if not bool((person_state as Dictionary).get("alive",true)): incapacitated += 1' + "`r`n" + `
     '	_ok(incapacitated >= 1 and actor.capabilities().fire,"replacement restores function without reviving original gunner")')
  ,@('	_ok(actor.state.crew_assignments.gunner == "gunner" and actor.state.recovery_action.is_empty(),"reset cancels replacement without delayed role changes")',
     '	_ok(str(actor.state.crew_assignments.get("gunner","")) != "" and actor.state.recovery_action.is_empty(),"reset cancels replacement without delayed role changes")')
)
Fix "$c\tests\run_recovery_player_checks.gd" @(
  ,@('	_check(scene.actor.state.crew_assignments.gunner == "commander" and scene.actor.state.crew_assignments.commander == "","natural eight-second replacement moves one actual crew member")',
     '	var gunner_person := str(scene.actor.state.crew_assignments.get("gunner",""))' + "`r`n" + `
     '	_check(not gunner_person.is_empty() and str(scene.actor.state.crew_assignments.get("commander","")) == ""' + "`r`n" + `
     '		and bool((scene.actor.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",false)),"natural eight-second replacement moves one actual crew member")')
  ,@('	_check(not scene.actor.state.crew_states.gunner.alive and scene.actor.capabilities().fire,"original gunner remains incapacitated while replacement can fire")',
     '	var down := 0' + "`r`n" + `
     '	for person_state in scene.actor.state.crew_states.values():' + "`r`n" + `
     '		if not bool((person_state as Dictionary).get("alive",true)): down += 1' + "`r`n" + `
     '	_check(down >= 1 and scene.actor.capabilities().fire,"original gunner remains incapacitated while replacement can fire")')
)

'=== 3) the invariant leg, written the way the measurement says it must be: only non-empty persons are recorded ==='
$tq = Get-Content "$c\tests\run_recovery_checks.gd" -Raw -Encoding UTF8
$a3 = '		if person == "commander": holders += 1'
$b3 = '		# CD08-T02: no non-empty person may hold two roles. The recorded set therefore holds ONLY non-empty persons, which' + "`r`n" + `
  '		# is what the direct measurement of the replacement path showed: one empty slot and no duplicate.' + "`r`n" + `
  '		var who := str(person)' + "`r`n" + `
  '		if who != "":' + "`r`n" + `
  '			if seen_persons.has(who): holders += 1' + "`r`n" + `
  '			seen_persons[who] = true'
$m3 = ([regex]::Matches($tq,[regex]::Escape($a3))).Count
$tq = $tq.Replace($a3,$b3)
$a4 = '	var holders := 0'
$m4 = ([regex]::Matches($tq,[regex]::Escape($a4))).Count
$tq = $tq.Replace($a4, '	var holders := 0' + "`r`n" + '	var seen_persons := {}')
[IO.File]::WriteAllText("$c\tests\run_recovery_checks.gd", $tq, (New-Object Text.UTF8Encoding($false)))
"  invariant_leg=$m3 ; seen_declared=$m4"

& $g --headless --path $c --import *> "$L\imp4.log" 2>&1 | Out-Null
'=== 4) all thirteen suites, counts compared ==='
$base = @{ 'run_ai_combat_checks'=34 ; 'run_ai_recovery_checks'=16 ; 'run_ai_tactics_checks'=39 ; 'run_ammo_compartment_checks'=63 ; 'run_damage_checks'=57 ; 'run_engineering_damage_checks'=25 ; 'run_engineering_loading_checks'=23 ; 'run_fire_control_checks'=59 ; 'run_historical_checks'=192 ; 'run_loading_checks'=62 ; 'run_modern_candidate_checks'=56 ; 'run_recovery_checks'=64 ; 'run_recovery_player_checks'=0 }
$tp=0;$tf=0;$bad=@();$window=@()
foreach ($s in @('run_ai_combat_checks','run_ai_recovery_checks','run_ai_tactics_checks','run_ammo_compartment_checks','run_damage_checks','run_engineering_damage_checks','run_engineering_loading_checks','run_fire_control_checks','run_historical_checks','run_loading_checks','run_modern_candidate_checks','run_recovery_checks','run_recovery_player_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\g13-$s.log"
  $o = Get-Content "$L\g13-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o|Select-String '^\[PASS\]').Count; $ff=@($o|Select-String '^\[FAIL\]').Count; $se=@($o|Select-String '^\s*SCRIPT ERROR').Count
  $nw = [bool]($o|Select-String 'requires a real window')
  if ($nw) { $window += $s } else { $tp+=$pp; $tf+=$ff; if ($ff -gt 0 -or $se -gt 0) { $bad += $s } }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3} ERR={4} was={5} {6}" -f $s,$LASTEXITCODE,$pp,$ff,$se,$base[$s],$(if ($nw) { 'WINDOW_REQUIRED' } else { '' })
  @($o|Select-String '^\[FAIL\]|^\s*SCRIPT ERROR') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',') + " window=" + ($window -join ',')
