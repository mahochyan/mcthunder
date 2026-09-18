$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\tests\run_damage_checks.gd"
$t = Get-Content $p -Raw -Encoding UTF8

'=== every dotted crew access in the damage suite, rewritten in one pass ==='
# Pattern 1: <state>.crew_states.<name>.alive  ->  read the person in that role
$m1 = [regex]::Matches($t,'crew_states\.([a-z_]+)\.alive')
"  dotted crew_states.<name>.alive occurrences=" + $m1.Count
foreach ($hit in $m1) { "    " + $hit.Value }
$t = [regex]::Replace($t,'crew_states\.([a-z_]+)\.alive','bool((b.state.crew_states.get(str(b.state.crew_assignments.get("$1","")),{}) as Dictionary).get("alive",true))')
# Pattern 2: <state>.crew_assignments.<role>  ->  the same as a map read
$m2 = [regex]::Matches($t,'crew_assignments\.([a-z_]+)')
"  dotted crew_assignments.<role> occurrences=" + $m2.Count
foreach ($hit in $m2) { "    " + $hit.Value }
$t = [regex]::Replace($t,'crew_assignments\.([a-z_]+)','str(b.state.crew_assignments.get("$1",""))')
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))

'=== the recovery leg: print what the two reads actually give ==='
$q="$c\tests\run_recovery_checks.gd"
$tq = Get-Content $q -Raw -Encoding UTF8
$a = '	var assistant_person := str(actor.state.crew_assignments.get("assistant_driver",""))'
$b = '	print("[CD08 rec] assignment keys=%s values=%s" % [str(actor.state.crew_assignments.keys()),str(actor.state.crew_assignments.values())])' + "`r`n" + `
  '	print("[CD08 rec] people keys=%s station_roles=%s" % [str(actor.state.crew_states.keys()),str(actor.state.station_roles)])' + "`r`n" + `
  '	var assistant_person := str(actor.state.crew_assignments.get("assistant_driver",""))' + "`r`n" + `
  '	print("[CD08 rec] assistant_person=[%s]" % assistant_person)'
$n = ([regex]::Matches($tq,[regex]::Escape($a))).Count
$tq = $tq.Replace($a,$b)
[IO.File]::WriteAllText($q, $tq, (New-Object Text.UTF8Encoding($false)))
"  recovery_print=$n"

& $g --headless --path $c --import *> "$L\imp6.log" 2>&1 | Out-Null
foreach ($s in @('run_damage_checks','run_recovery_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\p2-$s.log"
  $o = Get-Content "$L\p2-$s.log" -Encoding UTF8 -ErrorAction SilentlyContinue
  "  {0,-24} exit={1} PASS={2,4} FAIL={3} ERR={4}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count,@($o|Select-String '^\s*SCRIPT ERROR').Count
  @($o|Select-String '^\[FAIL\]|^\s*SCRIPT ERROR|CD08 rec|CD08 leg') | Select-Object -First 6 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(215,$_.Line.Trim().Length)) }
}
