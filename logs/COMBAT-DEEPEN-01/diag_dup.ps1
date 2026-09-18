$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== what my invariant leg actually became ==='
$lines = Get-Content "$c\tests\run_recovery_checks.gd" -Encoding UTF8
$n = (@(Select-String -Path "$c\tests\run_recovery_checks.gd" -Pattern 'one person cannot occupy two roles after replacement' -Encoding UTF8 | Select-Object -First 1)).LineNumber
if ($n) { $lines[([Math]::Max(0,$n-10))..([Math]::Min($lines.Count-1,$n+1))] | ForEach-Object { $s=$_ -replace "`t",'T'; '  L |' + $s.Substring(0,[Math]::Min(150,$s.Length)) } }
'=== the duplicate the leg is reporting, measured directly ==='
$probe = @'
extends "res://tests/run_recovery_checks.gd"
func _run() -> void:
	for key in ["run_recovery_checks duplicate check"]:
		print("[CD08 dup] ",key)
	print("[CD08 dup] assignments=",JSON.stringify(actor.state.crew_assignments))
	var seen := {}
	for role in actor.state.crew_assignments.keys():
		var person := str(actor.state.crew_assignments[role])
		if person == "": continue
		if seen.has(person): print("[CD08 dup] DUPLICATE person=",person," roles=",seen[person]," and ",role)
		seen[person] = role
	print("[CD08 dup] distinct persons=",seen.size()," of ",actor.state.crew_assignments.size()," roles")
	print("=== 结果: 1 项检查, 0 失败 ===")
	print("CD08_DUP_PROBE_PASS")
	quit(0)
'@
[IO.File]::WriteAllText("$c\tests\probe_cd008_dup.gd", $probe, (New-Object Text.UTF8Encoding($false)))
& $g --headless --path $c --check-only --script res://tests/probe_cd008_dup.gd *> "$L\pd.log" 2>&1 | Out-Null
"  probe parse_errors=" + @(Get-Content "$L\pd.log" | Select-String 'Parse Error|Compile Error').Count
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd008_dup.gd *> "$L\dup.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 300; if (-not $d) { Stop-Job $j }; Remove-Job $j
Get-Content "$L\dup.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD08 dup' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(200,$_.Line.Trim().Length)) }