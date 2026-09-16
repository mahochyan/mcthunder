$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

# The check already carries the other two fixes in the working tree; only the watchdog line is wrong, because a
# SceneTree script has no get_tree() - it IS the tree, so create_timer/quit are called on self.
$f = 'tests/check_engineering_wiring.gd'
$p = Join-Path $c $f
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$old = '	get_tree().create_timer(300,true,false,true).timeout.connect(func() -> void: print("ENGINEERING_WIRING_TIMEOUT"); get_tree().quit(2))'
$new = '	create_timer(300,true,false,true).timeout.connect(func() -> void: print("ENGINEERING_WIRING_TIMEOUT"); quit(2))'
$n = ([regex]::Matches($t, [regex]::Escape($old))).Count
Show ("  watchdog fix anchor x" + $n)
if ($n -ne 1) { Show "ANCHOR MISSED - aborting"; exit 1 }
[System.IO.File]::WriteAllText($p, $t.Replace($old, $new), $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
foreach ($pair in @(@('scripts/training/ballistics_range.gd','ballistics_range.gd'), @($f,'check_engineering_wiring.gd'))) {
    & $g --headless --path $c --check-only --script ('res://' + $pair[0]) *> (Join-Path $c 'logs\WT-040-R1\chkW3.log') 2>&1 | Out-Null
    $perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkW3.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $pair[1] + " errors=" + $perr)
    if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkW3.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

Show "=== rerun the wiring check ==="
$lg = Join-Path $c 'logs\WT-040-R1\engineering-wiring4.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '=== wiring|ENGINEERING_WIRING|^\[FAIL\]|unknown vehicle|TIMEOUT' | Select-Object -First 24 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(175, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'ENGINEERING_WIRING_PASS'
Show ("wiring pass=" + $pass)
$mine = @(Get-CimInstance Win32_Process -Filter "Name like '%Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*check_engineering_wiring*' })
foreach ($proc in $mine) { try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop; Show ("  killed pid=" + $proc.ProcessId) } catch {} }
if (-not $pass) { Show "WIRING NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/training/ballistics_range.gd tests/check_engineering_wiring.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Load the match path's definitions for every selection instead of only for historical ones, with the direct wiring check that found it. The catalog load in ballistics_range was gated on the selected vehicle being historical, so choosing an admitted engineering vehicle skipped the whole block - including the engineering admission that had just been added inside it - and actor setup then failed with 'unknown vehicle', which meant an admitted engineering vehicle could never be spawned at all: the initial spawn, the AI slots and the respawn all go through that path. The definitions are now loaded identically for any selection: load_defaults for the fixture, load_all for the curated historical roster which stays historical-only, and load_engineering for the admitted engineering set, each failing loudly. The wiring check compares, for every spawned combat vehicle, the requested id against the real definition id, the round and weapon against its own packet, the layout id, the registered model binding and the drive collision size, and asserts that a genuinely unknown id is refused with an empty id while the training hull keeps its own training round. It also gained a null-definition guard and a watchdog after its own early runs crashed on a failed actor setup; the watchdog uses create_timer and quit on the SceneTree itself, because a SceneTree script has no get_tree()" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
