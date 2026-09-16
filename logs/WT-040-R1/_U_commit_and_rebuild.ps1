$c = 'E:\AIprogram\mcthunder-cont'
function Show($m) { Write-Output $m }
$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'

Show "=== parse self-check on every file about to be committed ==="
$tot = 0
foreach ($f in @('scripts/battle/team_range.gd','scripts/garage/garage_service.gd','scripts/training/ballistics_range.gd','tests/check_live_fire_respawn.gd')) {
    & $g --headless --path $c --check-only --script ('res://' + $f) *> (Join-Path $c 'logs\WT-040-R1\commit-parse.log') 2>&1 | Out-Null
    $n = @(Get-Content (Join-Path $c 'logs\WT-040-R1\commit-parse.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  " + $f + " errors=" + $n); $tot += $n
}
if ($tot -gt 0) { Show "PARSE ERRORS - aborting"; exit 1 }

Show "=== guard: the two official suites plus the direct wiring check ==="
$ok = $true
foreach ($suite in @('run_checks','run_team_checks')) {
    $sl = Join-Path $c ('logs\WT-040-R1\commit-guard-' + $suite + '.log')
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites $suite *> $sl
    $own = Get-ChildItem (Join-Path $c 'logs') -Recurse -File -Filter ($suite + '_stdout.log') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $res = if ($own) { (Get-Content $own.FullName | Select-String '=== ' | Select-Object -Last 1).Line.Trim() } else { '(no log)' }
    $bad = if ($own) { @(Get-Content $own.FullName | Select-String '^\[FAIL\]').Count } else { 99 }
    Show ("  " + $suite + " : " + $res + " ; FAIL=" + $bad)
    if ($bad -ne 0) { $ok = $false }
}
$wg = Join-Path $c 'logs\WT-040-R1\commit-guard-wiring.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $wg
$wp = (Get-Content $wg -Raw) -match 'ENGINEERING_WIRING_PASS'
$wonly = @(Get-Content $wg | Select-String 'preview_only').Count
Show ("  wiring pass=" + $wp + " preview_only=" + $wonly)
if (-not $wp -or $wonly -ne 0) { $ok = $false }
Show ("  all guards green=" + $ok)
if (-not $ok) { Show "GUARD FAILED - not committing"; exit 1 }

git -C $c add scripts tests logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Make the engineering admission non-fatal when its candidate assets are absent, match the readiness mode to the vehicle being checked, and add the special live-fire respawn fixture. The independent package check caught a real regression I had introduced: the engineering hulls are candidates whose model artefacts are deliberately not shipped, so calling load_engineering unconditionally and treating its failure as fatal made the whole match refuse to start inside the package - garage map 0, three authored challenges and the tutorial all failed with 'model.path: artifact missing'. The historical admission stays mandatory and its failure stays fatal; the engineering admission is now reported loudly as a warning and is not fatal, so in a package the engineering vehicles are simply unavailable, which is what a candidate should be, while the working tree still loads them and the roster, the loadouts, the spawn path, the AI slots and the respawn all see them - re-verified at 141 checks and zero failures with no preview_only warning. The readiness gate also used the training mode for its primary check while only the fallback used the engineering mode, so every engineering request was judged preview_only and then rescued; both now use the same mode and no gate is widened. The special fixture drives slot A through the real move_forward action - three earlier versions never moved it at all, two of them because they pressed an action name this project does not have - lets the real AI shoot it, and then respawns it by CLICKING battle.respawn_button through the window input driver, never by calling request_respawn" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build (the package verification that caught the regression) ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
