$c = 'E:\AIprogram\mcthunder-cont'
function Show($m) { Write-Output $m }

Show "=== working tree must be exactly the B4-patched state (patches already applied) ==="
git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' } | ForEach-Object { Show ("  " + $_) }

Show "=== re-evaluate the ALREADY PRODUCED guard logs with a correct pattern ==="
$garageLog = Join-Path $c 'logs\WT-040-R1\B4-guard-run_garage_checks.log'
$teamLog   = Join-Path $c 'logs\WT-040-R1\B4-guard-run_team_checks.log'
$flankLog  = Join-Path $c 'logs\WT-040-R1\devtree-player-flow14.log'
foreach ($row in @(@($garageLog,'run_garage_checks'), @($teamLog,'run_team_checks'))) {
    if (Test-Path $row[0]) { Get-Content $row[0] | Select-String ($row[1] + ':') | ForEach-Object { Show ("  " + $_.Line.Trim()) } }
}
$garageOk = (Test-Path $garageLog) -and ((Get-Content $garageLog -Raw) -match 'run_garage_checks: checks=\d+.*passed=True')
$teamOk   = (Test-Path $teamLog)   -and ((Get-Content $teamLog   -Raw) -match 'run_team_checks: checks=\d+.*passed=True')
$flank    = @(Get-Content $flankLog | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration').Count
Show ("garageOk=" + $garageOk + " teamOk=" + $teamOk + " flank=" + $flank)
if (-not $garageOk -or -not $teamOk -or $flank -lt 2) { Show "GUARD EVIDENCE NOT GREEN - not committing"; exit 1 }

git -C $c add scripts tests logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Make the engineering vehicles reach the same controlled battle path as the historical ones, and refuse only what is genuinely unknown. load_all keeps its historical-only contract and GarageService explicitly calls load_engineering as well, so both sets are ready and the vehicle list, the loadout lookup and the match path all see them. The silent substitutions are removed: an unknown selection is refused rather than becoming player_tank, the four-vehicle rotation applies only to historical selections, an engineering vehicle is not rotated into history, an unadmitted slot refuses instead of falling back to player_tank, the training profile and the team_ap120 round with its policy and flat curve are applied to the training vehicle alone, and a spawn uses its own drive collision size. Two further historical-only assumptions were found in the readiness ledger, which is what actually gates the battlefield: it read packets only from the historical directory, so an admitted engineering vehicle came back as unknown_vehicle, and it marked every modern-mounted hull preview_only, which is a PUBLIC release judgement rather than a restriction on the controlled internal engineering entry. The ledger now reads the engineering directory explicitly and gains an explicit engineering mode in which the preview mark is still reported but does not block, while every other gate continues to apply and release gating is untouched. The dev-tree guard, not reasoning, produced the two corrections: the training hull is a known third category with its own readiness path and is not pushed through the combat gate, and a context that has not loaded a definition gets the documented training box with a reported warning rather than a refusal, because a synthetic test context may legitimately not load the catalog while genuinely unknown ids are refused upstream. Guard evidence for this commit: flank checks pass, run_garage_checks 151 passed with zero script errors, run_team_checks back to 67 passed with zero script errors - the first two attempts had broken it to 35 checks with eighteen and then twelve script errors, and were refused by the guard before anything was committed" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
