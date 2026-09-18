$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

'=== the last two delivered sites ==='
$p1="$c\tests\run_recovery_checks.gd"
$t1 = Get-Content $p1 -Raw -Encoding UTF8
$a1 = '		if person == "commander": holders += 1'
$b1 = '		# CD08-T02: stated without naming a person. No non-empty person may hold more than one role, which is the' + "`r`n" + `
  '		# invariant the leg was always about and is stronger than watching one particular name.' + "`r`n" + `
  '		if str(person) != "" and seen_persons.has(str(person)): holders += 1' + "`r`n" + `
  '		seen_persons[str(person)] = true'
$n1 = ([regex]::Matches($t1,[regex]::Escape($a1))).Count
$t1 = $t1.Replace($a1,$b1)
$a1b = '	var holders := 0'
$b1b = '	var holders := 0' + "`r`n" + '	var seen_persons := {}'
$n1b = ([regex]::Matches($t1,[regex]::Escape($a1b))).Count
$t1 = $t1.Replace($a1b,$b1b)
[IO.File]::WriteAllText($p1, $t1, (New-Object Text.UTF8Encoding($false)))
"  recovery_invariant=$n1 ; seen_persons=$n1b"

$p2="$c\tests\run_recovery_player_checks.gd"
$t2 = Get-Content $p2 -Raw -Encoding UTF8
$a2 = '	_check(scene.actor.state.crew_assignments.gunner == "commander" and scene.actor.state.crew_assignments.commander == "","natural eight-second replacement moves one actual crew member")'
$b2 = '	var gunner_person := str(scene.actor.state.crew_assignments.get("gunner",""))' + "`r`n" + `
  '	_check(not gunner_person.is_empty() and str(scene.actor.state.crew_assignments.get("commander","")) == ""' + "`r`n" + `
  '		and bool((scene.actor.state.crew_states.get(gunner_person,{}) as Dictionary).get("alive",false)),"natural eight-second replacement moves one actual crew member")'
$n2 = ([regex]::Matches($t2,[regex]::Escape($a2))).Count
$t2 = $t2.Replace($a2,$b2)
[IO.File]::WriteAllText($p2, $t2, (New-Object Text.UTF8Encoding($false)))
"  player_site=$n2"

'=== all thirteen suites that touch crew state: failures AND result counts ==='
$base = @{ 'run_ai_combat_checks'=34 ; 'run_ai_recovery_checks'=16 ; 'run_ai_tactics_checks'=39 ; 'run_ammo_compartment_checks'=62 ; 'run_damage_checks'=57 ; 'run_engineering_damage_checks'=25 ; 'run_engineering_loading_checks'=23 ; 'run_fire_control_checks'=59 ; 'run_historical_checks'=192 ; 'run_loading_checks'=62 ; 'run_modern_candidate_checks'=56 ; 'run_recovery_checks'=53 ; 'run_recovery_player_checks'=0 }
$tp=0;$tf=0;$bad=@();$window=@()
foreach ($s in @('run_ai_combat_checks','run_ai_recovery_checks','run_ai_tactics_checks','run_ammo_compartment_checks','run_damage_checks','run_engineering_damage_checks','run_engineering_loading_checks','run_fire_control_checks','run_historical_checks','run_loading_checks','run_modern_candidate_checks','run_recovery_checks','run_recovery_player_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\f13-$s.log"
  $o = Get-Content "$L\f13-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o|Select-String '^\[PASS\]').Count; $ff=@($o|Select-String '^\[FAIL\]').Count; $se=@($o|Select-String '^\s*SCRIPT ERROR').Count
  $needsWindow = [bool]($o|Select-String 'requires a real window')
  if ($needsWindow) { $window += $s } else { $tp+=$pp; $tf+=$ff; if ($ff -gt 0 -or $se -gt 0) { $bad += $s } }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3} ERR={4} was={5} {6}" -f $s,$LASTEXITCODE,$pp,$ff,$se,$base[$s],$(if ($needsWindow) { 'WINDOW_REQUIRED (excluded, by design)' } else { '' })
  @($o|Select-String '^\[FAIL\]|^\s*SCRIPT ERROR') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',') + " ; window-required=" + ($window -join ',')
'=== damage and recovery counts against their baselines ==='
foreach ($s in @('run_damage_checks','run_recovery_checks','run_ammo_compartment_checks')) {
  $o = Get-Content "$L\f13-$s.log" -ErrorAction SilentlyContinue
  "  " + $s + " now=" + @($o|Select-String '^\[PASS\]').Count + " was=" + $base[$s]
}
