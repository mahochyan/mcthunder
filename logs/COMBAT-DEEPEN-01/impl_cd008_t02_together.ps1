$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# (a) the delivered leg that hard-coded a role name as a person id: make it data driven and STRONGER, not weaker.
$p1="$c\tests\run_damage_checks.gd"
$t1 = Get-Content $p1 -Raw -Encoding UTF8
$a1 = '	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")'
$b1 = '	# CD08-T02: the person is read from the state instead of being named by a role, because a person is no longer a station.' + "`r`n" + `
  '	var mover := str(b.state.crew_assignments.get("commander",""))' + "`r`n" + `
  '	_ok(not mover.is_empty() and mover != "commander","the person who occupies the commander station is identified apart from the station")' + "`r`n" + `
  '	var injuries_before: Dictionary = (b.state.crew_states.get(mover,{}) as Dictionary).duplicate(true)' + "`r`n" + `
  '	_ok(b.state.assign_crew("driver",mover),"living person can occupy another role")' + "`r`n" + `
  '	_ok(b.state.crew_states.get(mover,{}) == injuries_before,"the moving person keeps their own state rather than becoming someone else")'
$n1 = ([regex]::Matches($t1,[regex]::Escape($a1))).Count
$t1 = $t1.Replace($a1,$b1)
$a2 = '	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")'
$b2 = '	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == mover,"one person never occupies two roles")'
$n2 = ([regex]::Matches($t1,[regex]::Escape($a2))).Count
$t1 = $t1.Replace($a2,$b2)
[IO.File]::WriteAllText($p1, $t1, (New-Object Text.UTF8Encoding($false)))
"  delivered_leg_datadriven=$n1 ; second_leg=$n2"

# (b) the scene device: name the person by identity, not by role. The expectation text is untouched.
$p2="$c\tests\run_cd008_scene_checks.gd"
$t2 = Get-Content $p2 -Raw -Encoding UTF8
$t2 = $t2.Replace('_crew_submission(state,"person_gunner"','_crew_submission(state,"person_2"')
$t2 = $t2.Replace('_crew_submission(state,"person_driver"','_crew_submission(state,"person_1"')
$t2 = $t2.Replace('(snap0.get("people",{}).get("person_gunner",{}) as Dictionary)','(snap0.get("people",{}).get("person_2",{}) as Dictionary)')
$t2 = $t2.Replace('after_first.get("person_gunner",{})','after_first.get("person_2",{})')
[IO.File]::WriteAllText($p2, $t2, (New-Object Text.UTF8Encoding($false)))
"  scene_device_person_ids=True"
foreach ($f in @('res://tests/run_damage_checks.gd','res://tests/run_cd008_scene_checks.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\pc9.log" 2>&1 | Out-Null
  "  " + $f + " parse_errors=" + @(Get-Content "$L\pc9.log" | Select-String 'Parse Error|Compile Error').Count
}
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd008_scene_checks.gd *> "$L\sc10.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Get-Content "$L\sc10.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD08-T0|CD08_SCENES|not_yet_met=|=== 结果' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_damage_checks.gd *> "$L\dm3.log"
$o=Get-Content "$L\dm3.log" -ErrorAction SilentlyContinue
"  run_damage_checks PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count
@($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
