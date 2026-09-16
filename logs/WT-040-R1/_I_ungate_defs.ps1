$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
$ok = $true

# --- 1) ungate the match path's definition loading: the same definitions for any selection -----------------
$f1 = 'scripts/training/ballistics_range.gd'
$p1 = Join-Path $c $f1
$g1 = & git -C $c show ("HEAD:" + $f1)
[System.IO.File]::WriteAllText($p1, (($g1 -join "`r`n") + "`r`n"), $enc)
$t1 = [System.IO.File]::ReadAllText($p1, [System.Text.Encoding]::UTF8)
$nl1 = if ($t1.Contains("`r`n")) { "`r`n" } else { "`n" }
$old1 = @'
	if selected_vehicle_id in VehicleCatalog.IDS:
		historical_catalog = VehicleCatalog.new()
		var loaded := historical_catalog.load_all(defs)
		if not loaded.ok:
			push_error("historical content admission: "+", ".join(loaded.errors))
			return
'@
$new1 = @'
	# WT-040-R1 (2026-09-17 ruling): the catalog load used to be gated on the selected vehicle being HISTORICAL,
	# so selecting an admitted engineering vehicle skipped the whole block and actor setup then failed with
	# "unknown vehicle" - the direct wiring check caught exactly that. The definitions are now loaded the same way
	# for every selection, which is what "one controlled path" means: load_defaults for the fixture, load_all for
	# the curated historical roster (still historical-only) and load_engineering for the admitted engineering set.
	if true:
		historical_catalog = VehicleCatalog.new()
		var loaded := historical_catalog.load_all(defs)
		if not loaded.ok:
			push_error("historical content admission: "+", ".join(loaded.errors))
			return
		var engineering := historical_catalog.load_engineering(defs)
		if not engineering.ok:
			push_error("engineering content admission: "+", ".join(engineering.errors))
			return
'@
$n1 = ([regex]::Matches($t1, [regex]::Escape($old1.TrimEnd("`r","`n").Replace("`n",$nl1)))).Count
Show ("  ballistics ungated anchor x" + $n1)
if ($n1 -eq 1) { [System.IO.File]::WriteAllText($p1, $t1.Replace($old1.TrimEnd("`r","`n").Replace("`n",$nl1), $new1.TrimEnd("`r","`n").Replace("`n",$nl1)), $enc) } else { $ok = $false }

# --- 2) the wiring check: guard a null definition (setup failed) and add a watchdog against a hang ---------
$f2 = 'tests/check_engineering_wiring.gd'
$p2 = Join-Path $c $f2
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$old2 = @'
			if actor == null:
				ok(false, "%s: an actor slot is missing entirely" % vehicle_id)
				continue
			var actual := str(actor.definition.id)
'@
$new2 = @'
			if actor == null:
				ok(false, "%s: an actor slot is missing entirely" % vehicle_id)
				continue
			# WT-040-R1: an actor whose setup FAILED exists but carries no definition, so guard that too instead
			# of dereferencing it - the first run crashed here and hung instead of reporting.
			if actor.definition == null:
				ok(false, "%s: an actor exists without a definition, so its setup was refused" % vehicle_id)
				continue
			var actual := str(actor.definition.id)
'@
$n2 = ([regex]::Matches($t2, [regex]::Escape($old2.TrimEnd("`r","`n").Replace("`n",$nl2)))).Count
Show ("  wiring definition guard x" + $n2)
if ($n2 -eq 1) { $t2 = $t2.Replace($old2.TrimEnd("`r","`n").Replace("`n",$nl2), $new2.TrimEnd("`r","`n").Replace("`n",$nl2)) } else { $ok = $false }

$old3 = 'func _run() -> void:
	root.size = Vector2i(1280, 720)'
$new3 = @'
func _run() -> void:
	root.size = Vector2i(1280, 720)
	# WT-040-R1: a watchdog, because a runtime error in this check previously skipped quit() and left the process
	# alive until the caller timed out. Five minutes is far more than three match setups need.
	get_tree().create_timer(300,true,false,true).timeout.connect(func() -> void: print("ENGINEERING_WIRING_TIMEOUT"); get_tree().quit(2))
'@
$n3 = ([regex]::Matches($t2, [regex]::Escape($old3.Replace("`n",$nl2)))).Count
Show ("  wiring watchdog anchor x" + $n3)
if ($n3 -eq 1) { $t2 = $t2.Replace($old3.Replace("`n",$nl2), $new3.TrimEnd("`r","`n").Replace("`n",$nl2)) } else { $ok = $false }
[System.IO.File]::WriteAllText($p2, $t2, $enc)

if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
foreach ($pair in @(@($p1,'ballistics_range.gd'), @($p2,'check_engineering_wiring.gd'))) {
    & $g --headless --path $c --check-only --script ('res://' + $pair[0].Replace($c + '\','').Replace('\','/')) *> (Join-Path $c 'logs\WT-040-R1\chkW2.log') 2>&1 | Out-Null
    $n = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkW2.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $pair[1] + " errors=" + $n)
    if ($n -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkW2.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

Show "=== rerun the wiring check (watchdog in place) ==="
$lg = Join-Path $c 'logs\WT-040-R1\engineering-wiring3.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '=== wiring|ENGINEERING_WIRING|^\[FAIL\]|unknown vehicle|TIMEOUT' | Select-Object -First 22 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(175, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'ENGINEERING_WIRING_PASS'
Show ("wiring pass=" + $pass)
'=== tidy up any lingering process of mine ==='
$mine = @(Get-CimInstance Win32_Process -Filter "Name like '%Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*check_engineering_wiring*' })
foreach ($p in $mine) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; Show ("  killed pid=" + $p.ProcessId) } catch {} }
if (-not $pass) { Show "WIRING NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/training/ballistics_range.gd tests/check_engineering_wiring.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Load the match path's definitions for every selection instead of only for historical ones, and add the direct wiring check that found it. The catalog load in ballistics_range was gated on the selected vehicle being historical, so choosing an admitted engineering vehicle skipped the whole block - including the engineering admission I had just added inside it - and actor setup then failed with 'unknown vehicle', which meant an admitted engineering vehicle could never be spawned at all: the initial spawn, the AI slots and the respawn all go through that path. The definitions are now loaded identically for any selection: load_defaults for the fixture, load_all for the curated historical roster which stays historical-only, and load_engineering for the admitted engineering set. The wiring check compares, for every spawned combat vehicle, the requested id against the real definition id, the round and weapon against its own packet, the layout id, the registered model binding and the drive collision size, and asserts that a genuinely unknown id is refused with an empty id while the training hull keeps its own training round. It also gained a watchdog and null-definition guard after its own first runs crashed on a failed actor setup and left the process alive instead of reporting" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
