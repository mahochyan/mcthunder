$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'
$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Show ("restored from HEAD, lines=" + @($good).Count)

$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$old = '	await aim_at(battle,Vector3(0,1.99,-20.28))'
$new = @'
	# WT-040-R1 measured evidence: the dev tree and the package hit the same height (contact y 2.004 vs 1.999) but
	# differ in depth by about 0.45 m, and that alone decides the outcome. The loader sits at turret-local z 0.38
	# (span about 0.21-0.55) and the ammunition rack at z 0.70 (span about 0.525-0.875), so the loader is IN
	# FRONT of the rack: when the line runs too far forward the round is spent on the loader - damage records
	# loader with newly_destroyed false and the rack is never reached - so no ammunition detonation, no death and
	# the flank is not credited. The aim is therefore taken from the target's own live snapshot, as the in-tree
	# fixture does, at an authored interior offset whose depth is inside the rack but BEYOND the loader, so the
	# round clears the loader and still enters the rack. Nothing about armour, damage, cooldown or inventory is
	# written, no game value is changed and no criterion is relaxed - the shot is still a real mouse click.
	var flank_target: VehicleActor = battle.find_actor("B1",battle._spawned.B1)
	var flank_snapshot := QuerySnapshotBuilder.build_from_vehicle(flank_target.tank,flank_target.damage_layout_override)
	var flank_aim: Vector3 = flank_snapshot.part_world_transforms.turret * Vector3(0,0.08,0.85)
	print("[aim] target-derived aim=",flank_aim," (rack centre would be z 0.70; previously the fixed (0,1.99,-20.28))")
	await aim_at(battle,flank_aim)
'@
$n = ([regex]::Matches($t, [regex]::Escape($old))).Count
Show ("aim anchor x" + $n)
if ($n -ne 1) { Show "ANCHOR MISSING"; exit 1 }
[System.IO.File]::WriteAllText($p, $t.Replace($old, $new.TrimEnd("`r","`n").Replace("`n", $nl)), $enc)
Show "patch applied"

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Show ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier7.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier7.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier7.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow9.log'
Show ("dev-tree guard run; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Show ("flow exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '\[aim\] target-derived|\[aim\] barrel|\[normal record\]' | Select-Object -First 5 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(320, $_.Line.Trim().Length))) }
$verdict = @(Get-Content $lg | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration')
Show ("flank pass lines=" + $verdict.Count)
if ($verdict.Count -lt 2) { Show "DEV-TREE GUARD FAILED - not committing, not rebuilding"; exit 1 }

git -C $c add scripts/diagnostics/player_flow_verifier.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Aim the flank shot at the rear of the ammunition rack, beyond the loader that stands in front of it. The dev tree and the package hit the same height but differ in depth by about 0.45 m, and that alone decides the outcome: the loader spans turret-local z 0.21 to 0.55 and the rack spans 0.525 to 0.875, so the loader is in front, and when the line runs too far forward the round is spent on the loader - damage records loader with newly_destroyed false and the rack is never reached, so there is no ammunition detonation, no death and no credited flank. The aim now comes from the target's own live snapshot, as the in-tree fixture does, at an interior offset whose depth is inside the rack but beyond the loader, so the round clears the loader and still enters the rack. The shot is still a real mouse click; no game value is written and no criterion is relaxed. The dev-tree guard passes before this is committed, and a rebuild follows so the package can be measured" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
