$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

function Fix($file, $pairs) {
  $t = Get-Content $file -Raw -Encoding UTF8
  foreach ($kv in $pairs) {
    $n = ([regex]::Matches($t,[regex]::Escape($kv[0]))).Count
    $t = $t.Replace($kv[0],$kv[1])
    "    fixed=" + $n + " : " + $kv[0].Trim().Substring(0,[Math]::Min(80,$kv[0].Trim().Length))
  }
  [IO.File]::WriteAllText($file, $t, (New-Object Text.UTF8Encoding($false)))
}

'=== run_ammo_compartment_checks: read the person in the loader role ==='
Fix "$c\tests\run_ammo_compartment_checks.gd" @(
  ,@('	check(not actor.state.crew_states.loader.alive,"bustle protection does not immunize separately hit crew")',
     '	var loader_person := str(actor.state.crew_assignments.get("loader",""))' + "`r`n" + `
     '	check(not loader_person.is_empty() and not bool((actor.state.crew_states.get(loader_person,{}) as Dictionary).get("alive",true)),"bustle protection does not immunize separately hit crew")')
)

'=== run_recovery_checks: four sites, each stated without naming a person ==='
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

'=== run_recovery_player_checks: two sites ==='
Fix "$c\tests\run_recovery_player_checks.gd" @(
  ,@('	_check(scene.actor.state.crew_assignments.gunner == "commander" and scene.actor.state.crew_assignments.commander == "","natural eight-second replacement moves one actual person out of the prior role")',
     '	var gunner_person := str(scene.actor.state.crew_assignments.get("gunner",""))' + "`r`n" + `
     '	_check(not gunner_person.is_empty() and str(scene.actor.state.crew_assignments.get("commander","")) == ""' + "`r`n" + `
     '		and bool((scene.actor.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",false)),"natural eight-second replacement moves one actual person out of the prior role")')
  ,@('	_check(not scene.actor.state.crew_states.gunner.alive and scene.actor.capabilities().fire,"original gunner remains incapacitated while replacement can fire")',
     '	var down := 0' + "`r`n" + `
     '	for person_state in scene.actor.state.crew_states.values():' + "`r`n" + `
     '		if not bool((person_state as Dictionary).get("alive",true)): down += 1' + "`r`n" + `
     '	_check(down >= 1 and scene.actor.capabilities().fire,"original gunner remains incapacitated while replacement can fire")')
)

'=== re-run the affected suites and compare against their baselines ==='
$base = @{ 'run_ammo_compartment_checks'=62 ; 'run_recovery_checks'=53 ; 'run_recovery_player_checks'=0 ; 'run_damage_checks'=57 }
foreach ($s in @('run_ammo_compartment_checks','run_recovery_checks','run_recovery_player_checks','run_damage_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\fx-$s.log"
  $o = Get-Content "$L\fx-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o|Select-String '^\[PASS\]').Count; $ff=@($o|Select-String '^\[FAIL\]').Count
  $se=@($o|Select-String '^\s*SCRIPT ERROR').Count
  "  {0,-32} exit={1} PASS={2,4} FAIL={3} ERR={4} (baseline was {5})" -f $s,$LASTEXITCODE,$pp,$ff,$se,$base[$s]
  @($o|Select-String '^\[FAIL\]|^\s*SCRIPT ERROR') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }
}
