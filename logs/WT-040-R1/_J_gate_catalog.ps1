$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$f = 'scripts/battle/team_range.gd'
$p = Join-Path $c $f
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$old = '	var catalog := VehicleCatalog.new()
	var checked := VehicleReadiness.eligible(requested,"training",{},catalog)'
$new = @'
	# WT-040-R1 (2026-09-17 ruling): use the definitions the MATCH actually loaded. A fresh VehicleCatalog has an
	# empty packages dictionary, so the readiness gate fell back to VehicleCatalog.IDS and every engineering
	# vehicle was ineligible - the AI slots then took the first historical type instead of the chosen engineering
	# one, which the direct wiring check showed as definition id us_m4a3_75w_vvss_1944 on every AI slot. No gate
	# is widened; the gate now simply sees the same admitted set the spawn path uses.
	var catalog: VehicleCatalog = historical_catalog if historical_catalog != null else VehicleCatalog.new()
	var checked := VehicleReadiness.eligible(requested,"training",{},catalog)
'@
$n = ([regex]::Matches($t, [regex]::Escape($old.Replace("`n",$nl)))).Count
Show ("  gate catalog anchor x" + $n)
if ($n -ne 1) { Show "ANCHOR MISSED - aborting"; exit 1 }
[System.IO.File]::WriteAllText($p, $t.Replace($old.Replace("`n",$nl), $new.TrimEnd("`r","`n").Replace("`n",$nl)), $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
foreach ($pair in @(@('scripts/battle/team_range.gd','team_range.gd'), @('scripts/training/ballistics_range.gd','ballistics_range.gd'), @('tests/check_engineering_wiring.gd','check_engineering_wiring.gd'))) {
    & $g --headless --path $c --check-only --script ('res://' + $pair[0]) *> (Join-Path $c 'logs\WT-040-R1\chkW4.log') 2>&1 | Out-Null
    $perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkW4.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $pair[1] + " errors=" + $perr)
    if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkW4.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

Show "=== rerun the wiring check ==="
$lg = Join-Path $c 'logs\WT-040-R1\engineering-wiring5.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '=== wiring|ENGINEERING_WIRING|^\[FAIL\]|unknown vehicle|TIMEOUT' | Select-Object -First 20 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(175, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'ENGINEERING_WIRING_PASS'
Show ("wiring pass=" + $pass)
$mine = @(Get-CimInstance Win32_Process -Filter "Name like '%Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*check_engineering_wiring*' })
foreach ($proc in $mine) { try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop; Show ("  killed pid=" + $proc.ProcessId) } catch {} }
if (-not $pass) { Show "WIRING NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/battle/team_range.gd scripts/training/ballistics_range.gd tests/check_engineering_wiring.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Let the readiness gate see the definitions the match actually loaded, and load those definitions for any selection, with the direct wiring check that found both. Two wiring defects were located by comparing what was requested with what was really built, not by reading code. First, ballistics_range gated its whole catalog load on the selected vehicle being historical, so choosing an admitted engineering vehicle skipped everything, including the engineering admission, and actor setup failed with 'unknown vehicle' - an admitted engineering vehicle could not be spawned at all because the initial spawn, the AI slots and the respawn all go through that path; the definitions are now loaded identically for any selection, with load_all keeping its historical-only contract and load_engineering called explicitly. Second, the readiness gate built a fresh VehicleCatalog whose packages dictionary is empty, so its admitted set fell back to the historical ids and every engineering vehicle was ineligible, which made the AI slots take the first historical type - the check showed that as definition id us_m4a3_75w_vvss_1944 on every AI slot while the player slot correctly carried the engineering vehicle's own round. The gate now uses the catalog the match already loaded. No gate is widened and no criterion is relaxed: the check asserts the six items per spawned vehicle plus the refusal of a genuinely unknown id and the training hull's own round" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
