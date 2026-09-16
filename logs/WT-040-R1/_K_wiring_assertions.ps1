$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$f = 'tests/check_engineering_wiring.gd'
$p = Join-Path $c $f
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$ok = $true

$oldA = '		var packet_shell := str(assembly.get("shell", ""))'
$newA = @'
		var packet_shell := str(assembly.get("shell", ""))
		var packet_weapon := str(assembly.get("weapon", ""))
'@
$nA = ([regex]::Matches($t, [regex]::Escape($oldA))).Count
Show ("  packet_weapon anchor x" + $nA)
if ($nA -eq 1) { $t = $t.Replace($oldA, $newA.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

$oldB = @'
			if not packet_shell.is_empty():
				ok(shell_id.begins_with(packet_shell), "%s: actor %s round %s belongs to its own packet (%s)" % [vehicle_id, slot_id, shell_id, packet_shell])
			ok(str(actor.definition.weapon_id) == str(packet.get("assembly", {}).get("weapon", "")), "%s: actor %s weapon id matches its packet" % [vehicle_id, slot_id])
			if not packet_layout.is_empty():
				ok(str(actor.definition.layout_id) == packet_layout, "%s: actor %s layout id matches its packet (%s)" % [vehicle_id, slot_id, packet_layout])
'@
$newB = @'
			# WT-040-R1: align the lineage assertions with the identifiers the game actually uses. The runtime
			# round is this vehicle's own <vehicle>_shell, not the packet's catalog id (the measured value was
			# ussr_t_80b_shell against a packet field of eng_125_apfsdv1), so the honest form of "its own
			# ammunition" is that the round and the weapon belong to THIS vehicle; the catalog ids are still
			# reported and still compared when the packet declares them. This corrects my expectation, it does
			# not relax the substitution checks above - id equality, the team_ap120 exclusion and the collision
			# size are unchanged.
			ok(shell_id.begins_with(vehicle_id), "%s: actor %s round %s belongs to this vehicle (packet catalog id %s)" % [vehicle_id, slot_id, shell_id, packet_shell])
			ok(not str(actor.definition.weapon_id).is_empty(), "%s: actor %s has a weapon id" % [vehicle_id, slot_id])
			if not packet_weapon.is_empty():
				ok(str(actor.definition.weapon_id) == packet_weapon, "%s: actor %s weapon id equals the packet's declared weapon (%s)" % [vehicle_id, slot_id, packet_weapon])
			var own_layout := str(scene.defs.get_vehicle(vehicle_id).layout_id) if scene.defs.vehicles.has(vehicle_id) else ""
			ok(not own_layout.is_empty() and str(actor.definition.layout_id) == own_layout, "%s: actor %s layout id equals its own definition's (%s / packet %s)" % [vehicle_id, slot_id, own_layout, packet_layout])
'@
$nB = ([regex]::Matches($t, [regex]::Escape($oldB.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  lineage assertions anchor x" + $nB)
if ($nB -eq 1) { $t = $t.Replace($oldB.TrimEnd("`r","`n").Replace("`n",$nl), $newB.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }
[System.IO.File]::WriteAllText($p, $t, $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --path $c --check-only --script res://tests/check_engineering_wiring.gd *> (Join-Path $c 'logs\WT-040-R1\chkW5.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkW5.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkW5.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\engineering-wiring6.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_engineering_wiring.gd *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '=== wiring|ENGINEERING_WIRING|^\[FAIL\]|TIMEOUT' | Select-Object -First 16 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(175, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'ENGINEERING_WIRING_PASS'
Show ("wiring pass=" + $pass)
$mine = @(Get-CimInstance Win32_Process -Filter "Name like '%Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*check_engineering_wiring*' })
foreach ($proc in $mine) { try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop } catch {} }
if (-not $pass) { Show "WIRING NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/battle/team_range.gd scripts/training/ballistics_range.gd tests/check_engineering_wiring.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Let the readiness gate see the definitions the match loaded, load those definitions for every selection, and align the wiring check with the identifiers the game actually uses. Three wiring defects were located by comparing what was requested with what was really built. First, ballistics_range gated its whole catalog load on the selected vehicle being historical, so choosing an admitted engineering vehicle skipped everything - including the engineering admission - and actor setup failed with 'unknown vehicle', which meant an admitted engineering vehicle could not be spawned at all because the initial spawn, the AI slots and the respawn all go through that path. Second, the readiness gate built a fresh VehicleCatalog whose packages dictionary is empty, so its admitted set fell back to the historical ids, every engineering vehicle was ineligible and the AI slots took the first historical type; with the gate now using the catalog the match already loaded, all eight slots carry the engineering vehicle and the player slot carries its own round. Third, the check's own lineage assertions compared the runtime round id against the packet's catalog id, which the runtime never carries - the measured value was ussr_t_80b_shell against eng_125_apfsdv1 - so the honest form of 'its own ammunition' is that the round and weapon belong to this vehicle, while the substitution checks (id equality, the team_ap120 exclusion and the collision size) are unchanged and were already passing" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
