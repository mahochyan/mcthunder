$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

'=== fix the scene device: read the person BY ROLE, never by a hard coded index ==='
$q="$c\tests\run_cd008_scene_checks.gd"
$tq = Get-Content $q -Raw -Encoding UTF8
$a1 = '	_crew_submission(state,"person_2"'
$n1 = ([regex]::Matches($tq,[regex]::Escape($a1))).Count
$tq = $tq.Replace($a1,'	_crew_submission(state,str(state.crew_assignments.get("gunner",""))')
$tq = $tq.Replace('_crew_submission(state,"person_1"','_crew_submission(state,str(state.crew_assignments.get("driver",""))')
$tq = $tq.Replace('(snap0.get("people",{}).get("person_2",{}) as Dictionary)','(snap0.get("people",{}).get(str(state.crew_assignments.get("gunner","")),{}) as Dictionary)')
$tq = $tq.Replace('after_first.get("person_2",{})','after_first.get(str(state.crew_assignments.get("gunner","")),{})')
[IO.File]::WriteAllText($q, $tq, (New-Object Text.UTF8Encoding($false)))
"  scene device by role: gunner_sites=" + $n1

'=== measure the ammo suite against its own HEAD version, label set to label set ==='
$head = (git -C $c show HEAD:tests/run_ammo_compartment_checks.gd) -join "`n"
[IO.File]::WriteAllText("$c\tests\_tmp_ammo_head.gd", $head, (New-Object Text.UTF8Encoding($false)))
& $g --headless --path $c --fixed-fps 60 -s res://tests/_tmp_ammo_head.gd *> "$L\ammo-head.log"
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_ammo_compartment_checks.gd *> "$L\ammo-now2.log"
$a = @(Get-Content "$L\ammo-head.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[PASS\]' | ForEach-Object { $_.Line.Trim().Substring(6).Trim() })
$b = @(Get-Content "$L\ammo-now2.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '^\[PASS\]' | ForEach-Object { $_.Line.Trim().Substring(6).Trim() })
$gone = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject })
$new = @(Compare-Object -ReferenceObject $a -DifferenceObject $b | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject })
"  HEAD labels=" + $a.Count + " now=" + $b.Count + " GONE=" + $gone.Count + " NEW=" + $new.Count
$gone | ForEach-Object { '    - ' + $_ }
$new | ForEach-Object { '    + ' + $_ }
Remove-Item "$c\tests\_tmp_ammo_head.gd" -Force -ErrorAction SilentlyContinue

'=== re-run the scenes ==='
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd008_scene_checks.gd *> "$L\sc-final2.log"
$o = Get-Content "$L\sc-final2.log" -Encoding UTF8 -ErrorAction SilentlyContinue
"  scenes PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count
$o | Select-String 'CD08-T0|not_yet_met=|CD08_SCENES' | ForEach-Object { '    ' + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }
