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

$f = 'tests/run_historical_checks.gd'
$p = Join-Path $c $f
$g = & git -C $c show ("HEAD:" + $f)
[System.IO.File]::WriteAllText($p, (($g -join "`r`n") + "`r`n"), $enc)
Show "restored the checks file from HEAD"

$r = Patch $f '	check(garage.vehicle_choice.item_count == 5,"normal garage exposes fixture plus four historical choices")' @'
	# WT-040-R1 (2026-09-17 ruling): the garage now exposes the curated historical roster PLUS the explicitly
	# admitted engineering vehicles, so "five" is no longer the intended roster. The check states the EXACT
	# roster by id instead of a count, which is stricter than before: the training fixture, the four historical
	# types and the two engineering types, in that order. The historical-only contract itself is untouched and is
	# still enforced by the separate check that a fresh load_all registers exactly four configurations.
	var expected_roster: Array = ["player_tank"]
	expected_roster.append_array(VehicleCatalog.IDS)
	expected_roster.append_array(VehicleCatalog.ENGINEERING_IDS)
	var exposed_roster: Array = []
	for roster_index in garage.vehicle_choice.item_count:
		exposed_roster.append(str(garage.vehicle_choice.get_item_metadata(roster_index)))
	check(exposed_roster == expected_roster,"normal garage exposes the fixture, the four historical types and the two admitted engineering types, by id")
'@ 'historical checks: exact roster by id'
if (-not $r) { Show "PATCH ANCHOR MISSED - aborting"; exit 1 }

$g2 = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g2 --headless --path $c --check-only --script res://tests/run_historical_checks.gd *> (Join-Path $c 'logs\WT-040-R1\chkH.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkH.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkH.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

# guard: the four suites that between them cover the flank flow, the garage roster, the readiness gate and the
# historical contract - run_historical_checks is the one my earlier three-suite guard was missing.
$allOk = $true
foreach ($suite in @('run_historical_checks','run_garage_checks','run_team_checks')) {
    $sl = Join-Path $c ('logs\WT-040-R1\H-guard-' + $suite + '.log')
    Show ("guard: " + $suite)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites $suite *> $sl
    Get-Content $sl | Select-String ($suite + ':') | ForEach-Object { Show ("  " + $_.Line.Trim()) }
    $okSuite = ((Get-Content $sl -Raw) -match ($suite + ': checks=\d+.*passed=True'))
    if (-not $okSuite) { $allOk = $false; Show ("  " + $suite + " NOT GREEN") }
    Get-Content $sl | Select-String '^\s*\[FAIL\]' | Select-Object -First 6 | ForEach-Object { Show ("    " + $_.Line.Trim().Substring(0, [Math]::Min(170, $_.Line.Trim().Length))) }
}
$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow15.log'
Show "guard: player flow flank checks"
& $g2 --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
$flank = @(Get-Content $lg | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration').Count
Show ("  flank pass lines=" + $flank)
if ($flank -lt 2) { $allOk = $false }
Show ("all guards green=" + $allOk)
if (-not $allOk) { Show "DEV-TREE GUARD FAILED - not committing, not rebuilding"; exit 1 }

git -C $c add tests/run_historical_checks.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "State the garage's intended roster by id instead of counting five items, because the engineering vehicles now belong in it. The build's own regression caught this before the register did: run_historical_checks failed on the assertion that the garage exposes the fixture plus four historical choices, with 191 of 192 checks passing, because the roster is now the training fixture plus four historical types plus the two explicitly admitted engineering vehicles - which is exactly what the ruling asks for. The check now asserts the exact ordered roster by id, which is stricter than a count: the historical-only contract stays enforced by the separate check that a fresh load_all registers exactly four configurations, and that one still passes. My three-suite dev-tree guard had not included run_historical_checks, so the guard is extended to cover it alongside the garage, team and flank checks" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
