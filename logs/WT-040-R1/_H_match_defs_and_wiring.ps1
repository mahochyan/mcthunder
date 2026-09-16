$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$ok = $true

# --- 1) the match path's own definitions must see the admitted engineering vehicles ------------------------
$f1 = 'scripts/training/ballistics_range.gd'
$p1 = Join-Path $c $f1
$g1 = & git -C $c show ("HEAD:" + $f1)
[System.IO.File]::WriteAllText($p1, (($g1 -join "`r`n") + "`r`n"), $enc)
$t1 = [System.IO.File]::ReadAllText($p1, [System.Text.Encoding]::UTF8)
$nl1 = if ($t1.Contains("`r`n")) { "`r`n" } else { "`n" }
$old1 = @'
		var loaded := historical_catalog.load_all(defs)
		if not loaded.ok:
			push_error("historical content admission: "+", ".join(loaded.errors))
			return
'@
$new1 = @'
		var loaded := historical_catalog.load_all(defs)
		if not loaded.ok:
			push_error("historical content admission: "+", ".join(loaded.errors))
			return
		# WT-040-R1 (2026-09-17 ruling): the match path had its own definition set and admitted only the
		# historical packets, so an admitted engineering vehicle failed actor setup with "unknown vehicle" and
		# could never be spawned - the direct wiring check caught exactly that. load_all stays historical-only;
		# the engineering vehicles are admitted here through the same explicit entry point, so the garage, the
		# loadouts, the initial spawn, the AI slots and the respawn all see the same definitions.
		var engineering := historical_catalog.load_engineering(defs)
		if not engineering.ok:
			push_error("engineering content admission: "+", ".join(engineering.errors))
			return
'@
$n1 = ([regex]::Matches($t1, [regex]::Escape($old1.TrimEnd("`r","`n").Replace("`n",$nl1)))).Count
Show ("  ballistics_range defs anchor x" + $n1)
if ($n1 -eq 1) { [System.IO.File]::WriteAllText($p1, $t1.Replace($old1.TrimEnd("`r","`n").Replace("`n",$nl1), $new1.TrimEnd("`r","`n").Replace("`n",$nl1)), $enc) } else { $ok = $false }

# --- 2) make the wiring check null-safe (my own crash: a Nil actor was dereferenced) -----------------------
$f2 = 'tests/check_engineering_wiring.gd'
$p2 = Join-Path $c $f2
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$old2 = @'
		for actor in actors:
			var actual := str(actor.definition.id)
'@
$new2 = @'
		for actor in actors:
			# WT-040-R1: stay null-safe. The first run spawned only one actor and this loop dereferenced the
			# missing ones, which crashed the check instead of reporting; a missing actor is now named and
			# counted as a failure rather than taking the whole run down.
			if actor == null:
				ok(false, "%s: an actor slot is missing entirely" % vehicle_id)
				continue
			var actual := str(actor.definition.id)
'@
$n2 = ([regex]::Matches($t2, [regex]::Escape($old2.TrimEnd("`r","`n").Replace("`n",$nl2)))).Count
Show ("  wiring null-safety anchor x" + $n2)
if ($n2 -eq 1) { [System.IO.File]::WriteAllText($p2, $t2.Replace($old2.TrimEnd("`r","`n").Replace("`n",$nl2), $new2.TrimEnd("`r","`n").Replace("`n",$nl2)), $enc) } else { $ok = $false }

if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
foreach ($pair in @(@($p1,'ballistics_range.gd'), @($p2,'check_engineering_wiring.gd'))) {
    $rel = 'res://' + $pair[0].Replace($c + '\','').Replace('\','/')
    & $g --headless --path $c --check-only --script $rel *> (Join-Path $c 'logs\WT-040-R1\chkW.log') 2>&1 | Out-Null
    $n = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkW.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $pair[1] + " errors=" + $n)
    if ($n -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkW.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

Show "=== rerun the wiring check ==="
$lg = Join-Path $c 'logs\WT-040-R1\engineering-wiring2.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $lg
$exit = $LASTEXITCODE
Show ("run exit=" + $exit)
Get-Content $lg | Select-String '^\[FAIL\]|=== wiring|ENGINEERING_WIRING|unknown vehicle' | Select-Object -First 24 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(180, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'ENGINEERING_WIRING_PASS'
$fails = @(Get-Content $lg | Select-String '=== wiring:').Line
Show ("summary line: " + $fails)
Show ("wiring pass=" + $pass)
if (-not $pass) { Show "WIRING NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/training/ballistics_range.gd tests/check_engineering_wiring.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Let the match path admit the engineering vehicles, which a direct wiring check proved it could not, and add that check. The check compares, for every spawned combat vehicle, the requested id against the real definition id, the round and weapon against the vehicle's own packet, the layout id, the registered model binding and the drive collision size - and it asserts that a genuinely unknown id is refused with an empty id while the training hull keeps its own training round. Its first run failed immediately: ballistics_range built its own VehicleDefs, admitted only the historical packets through load_all, and actor setup rejected ussr_t_80b with 'unknown vehicle', so an admitted engineering vehicle could not be spawned at all - the initial spawn, the AI slots and the respawn all go through that path. load_all keeps its historical-only contract and the same explicit load_engineering entry is now called there too, with a refusal that names the errors. The check itself was also made null-safe: its first run crashed on a missing actor instead of reporting it, which is my bug and is fixed by naming the missing slot as a failure" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
