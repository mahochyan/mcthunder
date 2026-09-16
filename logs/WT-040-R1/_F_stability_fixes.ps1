$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
function Patch([string]$rel, [string]$old, [string]$new, [string]$label) {
    $p = Join-Path $c $rel
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $o = $old.Replace("`n", $nl); $n = $new.TrimEnd("`r","`n").Replace("`n", $nl)
    $cnt = ([regex]::Matches($t, [regex]::Escape($o))).Count
    if ($cnt -eq 1) { [System.IO.File]::WriteAllText($p, $t.Replace($o, $n), $enc); Show ("  OK   " + $label); return $true }
    Show ("  MISS " + $label + " (x" + $cnt + ")"); return $false
}

$f = 'tests/run_checks.gd'
$p = Join-Path $c $f
$g = & git -C $c show ("HEAD:" + $f)
[System.IO.File]::WriteAllText($p, (($g -join "`r`n") + "`r`n"), $enc)
Show "restored run_checks.gd from HEAD"
$all = $true

# --- A) _stable_converge reporting: record the error on every frame, so a never-converged run tells the truth
$r = Patch $f '		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
				max_err = err
			continue' @'
		# WT-040-R1: record the error on EVERY frame, including before the first crossing. The old code skipped
		# this while first_cross was still -1, so a run that never entered tolerance reported max_err=0.00 and
		# final_err=0.00 - which says nothing about how close it came. This is reporting only: the 0.5 degree
		# threshold and the one second hold are unchanged.
		max_err = maxf(max_err, err)
		final_err = err
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
			continue' 'stab: record error every frame'; $all = $r -and $all

$r = Patch $f '	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:' @'
	# WT-040-R1: name the residual on the timeout path, bounded and one line, so a never-converged run can be
	# told apart from a short observation window by data instead of by guesswork.
	print("[stab] NOT converged first_cross=%d hold=%.2fs max_err=%.3fdeg final_err=%.3fdeg" % [first_cross, hold_time, max_err, final_err])
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:' 'stab: timeout diagnostic'; $all = $r -and $all

# --- B) wait for the value that is about to be asserted, with a bound -------------------------------------
$r = Patch $f 'func _ok(cond: bool, label: String) -> void:' @'
func _wait_trial_hits(m: Node, target: int, max_frames: int = 480) -> void:
	# WT-040-R1: a projectile leaving the world and the trial-hit counter being incremented are not necessarily
	# observed on the same frame, so the assertions below wait for the value they are about to assert, with a
	# bound. The assertions themselves are unchanged - this only removes the one-frame race.
	for i in max_frames:
		if m.trial_hits >= target: return
		await physics_frame

func _ok(cond: bool, label: String) -> void:' 'helper: bounded trial-hit wait'; $all = $r -and $all

foreach ($pair in @(
    @('	await _wait_flight_done(main)   # 006-d锛氱湡瀹為琛?
	_ok(main.trial_hits == 1, "T003-06 鐪熷疄鍛戒腑鎺ㄨ繘璇曞皠璁℃暟 (hits=%d)" % main.trial_hits)', '1'),
    @('	await _wait_flight_done(main)   # 006-d锛氱湡瀹為琛?
	_ok(main.trial_hits == 2, "T003-06 绗簩娆″懡涓帹杩?(hits=%d)" % main.trial_hits)', '2'),
    @('	await _wait_flight_done(main)   # 006-d锛氱湡瀹為琛?
	_ok(main.trial_hits == 3, "T003-06 绗笁娆″懡涓畬鎴愯瘯灏?(hits=%d)" % main.trial_hits)', '3'),
    @('	await _wait_flight_done(main)   # 006-d锛氱湡瀹為琛?
	_ok(main.trial_hits == 3, "T003-06 瀹屾垚鍚庡啀鍛戒腑涓嶈秴璁?(hits=%d)" % main.trial_hits)', '3')
)) {
    $old = $pair[0] -replace '锛氱湡瀹為\ue000琛\?', '锛氱湡瀹為琛?'
    # the comments in this file are stored mojibake'd; anchor on the ASCII part of each site instead
    $lines = $pair[0] -split "`n"
    $tail = $lines[$lines.Count-1]
    $newtail = "	await _wait_trial_hits(main, " + $pair[1] + ")" + "`n" + $tail
    $r2 = Patch $f ($lines[0] + "`n" + $tail) ($lines[0] + "`n" + $newtail) ("T003-06 wait target=" + $pair[1])
    if (-not $r2) {
        # fall back: match only the assertion line and insert the wait before it
        $r2 = Patch $f $tail ("	await _wait_trial_hits(main, " + $pair[1] + ")`n" + $tail) ("T003-06 wait (fallback) target=" + $pair[1])
    }
    $all = $r2 -and $all
}

if (-not $all) { Show "PATCH ANCHORS MISSED - aborting"; exit 1 }
$g2 = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g2 --headless --path $c --check-only --script res://tests/run_checks.gd *> (Join-Path $c 'logs\WT-040-R1\chkRC.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC.log') | Select-String 'Parse Error' | Select-Object -First 4 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

foreach ($n in 1,2,3) {
    $sl = Join-Path $c ("logs\WT-040-R1\RC-stability-$n.log")
    Show ("run " + $n + " / 3")
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites run_checks *> $sl
    Get-Content $sl | Select-String 'run_checks:' | ForEach-Object { Show ("  " + $_.Line.Trim()) }
    $own = Get-ChildItem "$c\logs" -Recurse -File -Filter 'run_checks_stdout.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($own) {
        Get-Content $own.FullName | Select-String '=== ' | Select-Object -Last 1 | ForEach-Object { Show ("    own: " + $_.Line.Trim()) }
        Get-Content $own.FullName | Select-String '^\[FAIL\]|\[stab\] NOT converged' | Select-Object -First 6 | ForEach-Object { Show ("      " + $_.Line.Trim().Substring(0, [Math]::Min(165, $_.Line.Trim().Length))) }
    }
}
Show '=== stability probe done (not committing yet) ==='
