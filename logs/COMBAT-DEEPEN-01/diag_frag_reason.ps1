$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$q="$c\tests\probe_cd007_wall_occlusion.gd"
$tv = Get-Content $q -Raw -Encoding UTF8
$a = '	var burst: Dictionary = state.burst if state.burst is Dictionary else {}'
$b = @'
	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	# DIAGNOSTIC: every fragment already carries why it stopped, how many queries it made and what it struck, so the
	# reason names the failing link without touching the production file at all.
	var reason_counts := {}
	for fragment in state.fragments:
		var reason := str(fragment.get("reason",""))
		reason_counts[reason] = int(reason_counts.get(reason,0)) + 1
	print("[CD07 occl] fragments=%d reasons=%s" % [state.fragments.size(),JSON.stringify(reason_counts)])
	for i in range(mini(6,state.fragments.size())):
		var fr: Dictionary = state.fragments[i]
		print("[CD07 occl]   fragment %d reason=%-18s queries=%d contacts=%d path=%d dir=%s" % [
			i,str(fr.get("reason","")),int(fr.get("queries",0)),(fr.get("contacts",[]) as Array).size(),
			(fr.get("path",[]) as Array).size(),str(fr.get("direction",Vector3.ZERO))])
'@
$n = ([regex]::Matches($tv,[regex]::Escape($a))).Count
$tv = $tv.Replace($a,$b)
[IO.File]::WriteAllText($q, $tv, (New-Object Text.UTF8Encoding($false)))
"  diagnostic_insert=$n"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_wall_occlusion.gd *> "$L\parse-dg.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-dg.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-dg.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-dg.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-dg.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl' | Select-Object -First 12 | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
