$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$f = 'tests/run_checks.gd'
$p = Join-Path $c $f
$g = & git -C $c show ("HEAD:" + $f)
[System.IO.File]::WriteAllText($p, (($g -join "`r`n") + "`r`n"), $enc)
Show "restored run_checks.gd from HEAD"
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$ok = $true

# --- A) _stable_converge: record the error on every frame (reporting only) ---------------------------------
$oldA = @'
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
				max_err = err
			continue
'@
$newA = @'
		# WT-040-R1: record the error on EVERY frame, including before the first crossing. The old code skipped
		# this while first_cross was still -1, so a run that never entered tolerance reported max_err=0.00 and
		# final_err=0.00, which says nothing about how close it came. Reporting only: the 0.5 degree threshold and
		# the one second hold are unchanged.
		max_err = maxf(max_err, err)
		final_err = err
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
			continue
'@
$nA = ([regex]::Matches($t, [regex]::Escape($oldA.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  stab reporting anchor x" + $nA)
if ($nA -eq 1) { $t = $t.Replace($oldA.TrimEnd("`r","`n").Replace("`n",$nl), $newA.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

# --- B) _stable_converge: name the residual on the timeout path -------------------------------------------
$oldB = @'
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:
'@
$newB = @'
	# WT-040-R1: name the residual on the timeout path, bounded and one line, so a never-converged run can be
	# told apart from a short observation window by data rather than by guesswork.
	print("[stab] NOT converged first_cross=%d hold=%.2fs max_err=%.3fdeg final_err=%.3fdeg" % [first_cross, hold_time, max_err, final_err])
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:
'@
$nB = ([regex]::Matches($t, [regex]::Escape($oldB.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  stab timeout anchor x" + $nB)
if ($nB -eq 1) { $t = $t.Replace($oldB.TrimEnd("`r","`n").Replace("`n",$nl), $newB.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

# --- C) bounded wait helper, anchored on an ASCII signature ------------------------------------------------
$oldC = 'func _ok(cond: bool, label: String) -> void:'
$newC = @'
func _wait_trial_hits(m: Node, target: int, max_frames: int = 480) -> void:
	# WT-040-R1: a projectile leaving the world and the trial-hit counter being incremented are not necessarily
	# observed on the same frame, so the assertions below wait for the value they are about to assert, with a
	# bound. The assertions themselves are unchanged - this removes a one-frame race, not a criterion.
	for i in max_frames:
		if m.trial_hits >= target: return
		await physics_frame

func _ok(cond: bool, label: String) -> void:
'@
$nC = ([regex]::Matches($t, [regex]::Escape($oldC))).Count
Show ("  helper anchor x" + $nC)
if ($nC -eq 1) { $t = $t.Replace($oldC, $newC.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

# --- D) insert the bounded wait BEFORE each trial_hits assertion, purely by ASCII line prefix ---------------
$lines = $t -split "`r?`n"
$outLines = New-Object System.Collections.Generic.List[string]
$targets = @(1,2,3,3)
$inserted = 0
$seen = 0
foreach ($ln in $lines) {
    $trim = $ln.TrimStart()
    if ($trim.StartsWith('_ok(main.trial_hits == ') -and $seen -lt $targets.Count) {
        $outLines.Add("`tawait _wait_trial_hits(main, " + $targets[$seen] + ")")
        $inserted++
        $seen++
    }
    $outLines.Add($ln)
}
Show ("  trial_hits assertion sites=" + $seen + " (inserted " + $inserted + ")")
if ($seen -lt 1) { $ok = $false }
$t = ($outLines -join "`r`n")

[System.IO.File]::WriteAllText($p, $t, $enc)
if (-not $ok) { Show "ANCHOR MISSED - aborting without running"; exit 1 }

$g2 = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g2 --headless --path $c --check-only --script res://tests/run_checks.gd *> (Join-Path $c 'logs\WT-040-R1\chkRC2.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC2.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC2.log') | Select-String 'Parse Error' | Select-Object -First 4 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }
Select-String -Path $p -Pattern '_wait_trial_hits|\[stab\] NOT converged|final_err = err' | ForEach-Object { Show ("  L" + $_.LineNumber + ": " + $_.Line.Trim().Substring(0, [Math]::Min(120, $_.Line.Trim().Length))) }

foreach ($n in 1,2,3) {
    $sl = Join-Path $c ("logs\WT-040-R1\RC2-stability-$n.log")
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
