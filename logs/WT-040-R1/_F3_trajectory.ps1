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
		# this while first_cross was still -1, so a never-converged run reported max_err=0.00 and final_err=0.00,
		# which says nothing about how close it came. Reporting only: the 0.5 degree threshold and the one second
		# hold are unchanged.
		max_err = maxf(max_err, err)
		final_err = err
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
			continue
'@
$nA = ([regex]::Matches($t, [regex]::Escape($oldA.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  A stab reporting x" + $nA)
if ($nA -eq 1) { $t = $t.Replace($oldA.TrimEnd("`r","`n").Replace("`n",$nl), $newA.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

$oldD = @'
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:
'@
$newD = @'
	# WT-040-R1: name the residual on the timeout path, bounded and one line, so a never-converged run can be
	# told apart from a short observation window by data rather than by guesswork.
	print("[stab] NOT converged first_cross=%d hold=%.2fs max_err=%.3fdeg final_err=%.3fdeg" % [first_cross, hold_time, max_err, final_err])
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:
'@
$nD = ([regex]::Matches($t, [regex]::Escape($oldD.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  D stab timeout x" + $nD)
if ($nD -eq 1) { $t = $t.Replace($oldD.TrimEnd("`r","`n").Replace("`n",$nl), $newD.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

# bounded trajectory sampling: five lines at most, diagnostic only
$oldE = '		var err: float = rad_to_deg(bdir.angle_to(want))'
$newE = @'
		var err: float = rad_to_deg(bdir.angle_to(want))
		# WT-040-R1: bounded trajectory sampling (at most five lines) so a failing run shows WHEN the turret
		# starts moving instead of only its final residual. Diagnostic only; no criterion is touched.
		if i % 60 == 0:
			print("[stab] frame=%d err=%.3fdeg first_cross=%d" % [i, err, first_cross])
'@
$nE = ([regex]::Matches($t, [regex]::Escape($oldE))).Count
Show ("  E trajectory sampling x" + $nE)
if ($nE -eq 1) { $t = $t.Replace($oldE, $newE.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

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
Show ("  C helper x" + $nC)
if ($nC -eq 1) { $t = $t.Replace($oldC, $newC.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

$lines = $t -split "`r?`n"
$outLines = New-Object System.Collections.Generic.List[string]
$targets = @(1,2,3,3); $seen = 0
foreach ($ln in $lines) {
    $trim = $ln.TrimStart()
    if ($trim.StartsWith('_ok(main.trial_hits == ') -and $seen -lt $targets.Count) {
        $outLines.Add("`tawait _wait_trial_hits(main, " + $targets[$seen] + ")")
        $seen++
    }
    $outLines.Add($ln)
}
Show ("  B trial_hits sites=" + $seen)
if ($seen -lt 1) { $ok = $false }
$t = ($outLines -join "`r`n")
[System.IO.File]::WriteAllText($p, $t, $enc)
if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }

$g2 = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g2 --headless --path $c --check-only --script res://tests/run_checks.gd *> (Join-Path $c 'logs\WT-040-R1\chkRC3.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC3.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkRC3.log') | Select-String 'Parse Error' | Select-Object -First 4 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$captured = $false
foreach ($n in 1,2,3,4) {
    if ($captured) { break }
    $sl = Join-Path $c ("logs\WT-040-R1\RC3-run-$n.log")
    Show ("run " + $n + " / 4")
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites run_checks *> $sl
    $own = Get-ChildItem "$c\logs" -Recurse -File -Filter 'run_checks_stdout.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($own) {
        Get-Content $own.FullName | Select-String '=== ' | Select-Object -Last 1 | ForEach-Object { Show ("  " + $_.Line.Trim()) }
        $bad = @(Get-Content $own.FullName | Select-String '^\[FAIL\]')
        Show ("  FAIL lines=" + $bad.Count)
        Get-Content $own.FullName | Select-String '\[stab\]' | ForEach-Object { Show ("    " + $_.Line.Trim().Substring(0, [Math]::Min(150, $_.Line.Trim().Length))) }
        if ($bad.Count -gt 0) { $captured = $true; Show "  (trajectory captured - stopping the loop)" }
    }
}
Show '=== trajectory probe done (not committing yet) ==='
