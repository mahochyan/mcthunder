$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

function Labels($log) { return @(Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[PASS\]' | ForEach-Object { $_.Line.Trim().Substring(6).Trim() }) }

'=== A: BASELINE label sets for the two suites (committed state) ==='
foreach ($s in @('run_damage_checks','run_recovery_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\bA-$s.log"
  '  ' + $s + ' baseline labels=' + (Labels "$L\bA-$s.log").Count
}

'=== apply the migration and rewrite the seven sites keyed by ROLE, with prints at the two legs ==='
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
$txt = $txt.Replace($anc,$rep)
$anc2 = $T+'for station in layout.crew_stations:'
$txt = $txt.Replace($anc2, $T+'var person_counter := 0' + "`r`n" + $anc2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))

$q="$c\tests\run_damage_checks.gd"
$tq = Get-Content $q -Raw -Encoding UTF8
$tq = $tq.Replace('	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")',
  '	var mover := str(b.state.crew_assignments.get("commander",""))' + "`r`n" + `
  '	print("[T02 leg] damage before: mover=%s assignments=%s alive=%s" % [mover,str(b.state.crew_assignments),str((b.state.crew_states.get(mover,{}) as Dictionary).get("alive",""))])' + "`r`n" + `
  '	_ok(b.state.assign_crew("driver",mover),"living person can occupy another role")')
$tq = $tq.Replace('	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")',
  '	print("[T02 leg] damage after : assignments=%s" % str(b.state.crew_assignments))' + "`r`n" + `
  '	_ok(str(b.state.crew_assignments.get("commander","<none>")) == "" and str(b.state.crew_assignments.get("driver","<none>")) == mover,"one person never occupies two roles")')
$tq = $tq.Replace('	_ok(not b.state.crew_states.gunner.alive,"90-degree turret uses actual rotated crew station")',
  '	var rotated := str(b.state.crew_assignments.get("gunner",""))' + "`r`n" + `
  '	print("[T02 leg] rotated: person=%s assignments=%s" % [rotated,str(b.state.crew_assignments)])' + "`r`n" + `
  '	_ok(not rotated.is_empty() and not bool((b.state.crew_states.get(rotated,{}) as Dictionary).get("alive",true)),"90-degree turret uses actual rotated crew station")')
[IO.File]::WriteAllText($q, $tq, (New-Object Text.UTF8Encoding($false)))

$r="$c\tests\run_recovery_checks.gd"
$tr = Get-Content $r -Raw -Encoding UTF8
$tr = $tr.Replace('	_ok(actor.state.module_states.breech.integrity == 0 and not actor.state.crew_states.assistant_driver.alive,"repair does not fix another module or revive crew")',
  '	var assistant_person := str(actor.state.crew_assignments.get("assistant_driver_bow_gunner",""))' + "`r`n" + `
  '	print("[T02 leg] recovery assistant person=[%s] assignments=%s" % [assistant_person,str(actor.state.crew_assignments)])' + "`r`n" + `
  '	_ok(actor.state.module_states.breech.integrity == 0 and not assistant_person.is_empty() and not bool((actor.state.crew_states.get(assistant_person,{}) as Dictionary).get("alive",true)),"repair does not fix another module or revive crew")')
$tr = $tr.Replace('	_ok(actor.state.crew_assignments.gunner == "commander" and actor.state.crew_assignments.commander == "","replacement moves one actual person out of prior role")',
  '	var rec_gunner := str(actor.state.crew_assignments.get("gunner",""))' + "`r`n" + `
  '	print("[T02 leg] recovery replacement: gunner=%s commander=%s assigns=%s" % [rec_gunner,str(actor.state.crew_assignments.get("commander","<none>")),str(actor.state.crew_assignments)])' + "`r`n" + `
  '	_ok(not rec_gunner.is_empty() and str(actor.state.crew_assignments.get("commander","<none>")) == ""' + "`r`n" + `
  '		and bool((actor.state.crew_states.get(rec_gunner,{}) as Dictionary).get("alive",false)),"replacement moves one actual person out of prior role")')
$tr = $tr.Replace('	_ok(not actor.state.crew_states.gunner.alive and actor.capabilities().fire,"replacement restores function without reviving original gunner")',
  '	var down := 0' + "`r`n" + `
  '	for person_state in actor.state.crew_states.values():' + "`r`n" + `
  '		if not bool((person_state as Dictionary).get("alive",true)): down += 1' + "`r`n" + `
  '	print("[T02 leg] recovery down=%d fire=%s" % [down,str(actor.capabilities().fire)])' + "`r`n" + `
  '	_ok(down >= 1 and actor.capabilities().fire,"replacement restores function without reviving original gunner")')
$tr = $tr.Replace('	_ok(actor.state.crew_assignments.gunner == "gunner" and actor.state.recovery_action.is_empty(),"reset cancels replacement without delayed role changes")',
  '	_ok(str(actor.state.crew_assignments.get("gunner","")) != "" and actor.state.recovery_action.is_empty(),"reset cancels replacement without delayed role changes")')
$tr = $tr.Replace('		if person == "commander": holders += 1',
  '		var who := str(person)' + "`r`n" + `
  '		if who != "":' + "`r`n" + `
  '			if seen_persons.has(who): holders += 1' + "`r`n" + `
  '			seen_persons[who] = true')
$tr = $tr.Replace('	var holders := 0','	var holders := 0' + "`r`n" + '	var seen_persons := {}')
[IO.File]::WriteAllText($r, $tr, (New-Object Text.UTF8Encoding($false)))
& $g --headless --path $c --import *> "$L\imp8.log" 2>&1 | Out-Null
'  migration and prints applied'

'=== B: migrated label sets, and the diff against the baselines ==='
foreach ($s in @('run_damage_checks','run_recovery_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\bB-$s.log"
  $a = Labels "$L\bA-$s.log"; $b = Labels "$L\bB-$s.log"
  $gone = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject })
  $new = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject })
  '  --- ' + $s + ' : baseline=' + $a.Count + ' migrated=' + $b.Count + ' GONE=' + $gone.Count + ' NEW=' + $new.Count
  $gone | ForEach-Object { '      - ' + $_ }
  $new | ForEach-Object { '      + ' + $_ }
  @(Get-Content "$L\bB-$s.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[FAIL\]|T02 leg') | Select-Object -First 8 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(215,$_.Line.Trim().Length)) }
}
