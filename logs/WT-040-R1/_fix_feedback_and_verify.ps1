$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'

$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Write-Output ("restored from HEAD, lines=" + @($good).Count)

$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$anchor = '	check(await drive_to(battle,Vector3(-16,0,-20)),"WASD reaches side of the static armoured target")'
$n = ([regex]::Matches($t, [regex]::Escape($anchor.Replace("`n", $nl)))).Count
Write-Output ("anchor x" + $n)
if ($n -ne 1) { Write-Output "ANCHOR MISSING"; exit 1 }
# keep the driven position as it was, but mark why it is not the variable that matters
$t = $t.Replace($anchor.Replace("`n", $nl), ('	# WT-040-R1: measured - moving this driven position by two metres changed the barrel''s residual miss' + $nl + '	# by only 0.008 m (0.1396 -> 0.1316 m), so the firing position is not what decides the shot.' + $nl + $anchor))

# The aim helper now feeds the BARREL's measured error back into the camera aim. The camera''s intent point is
# the first surface its ray hits, so aiming it at a point behind armour pins the barrel about 0.13 m high.
$old = '	await frames(240)' + $nl + '	print("[aim] camera="'
$ins = @'
	# WT-040-R1: the camera's intent_point is the FIRST surface its ray hits, so aiming it at a point behind
	# armour leaves the barrel about 0.13 m high - the residual measured on the barrel line was 0.1396 m from one
	# firing position and 0.1316 m from another, which shows the position is not what decides the shot. The aim
	# is therefore driven by the BARREL's own measured miss: each pass shifts the camera's target by the vector
	# from where the barrel line passes closest to the requested point, so the residual is corrected directly.
	# Nothing about armour, damage, cooldown or inventory is written and no game value is changed.
	var aim_tolerance := 0.03
	var aim_target: Vector3 = point
	var aim_settled := false
	for pass_index in 60:
		var muzzle_at: Vector3 = battle.actor.turret.muzzle.global_position
		var barrel_dir: Vector3 = battle.actor.turret.barrel_direction()
		var to_point: Vector3 = point - muzzle_at
		var closest: Vector3 = muzzle_at + barrel_dir*to_point.dot(barrel_dir)
		var miss := (point - closest).length()
		if miss <= aim_tolerance:
			aim_settled = true
			print("[aim] barrel converged miss=%.4f m on pass %d" % [miss, pass_index])
			break
		aim_target = aim_target + (point - closest)
		var aim_delta := aim_target - battle.actor.cam_rig.cam.global_position
		var aim_yaw := atan2(-aim_delta.x,-aim_delta.z)
		var aim_pitch := atan2(aim_delta.y,Vector2(aim_delta.x,aim_delta.z).length())
		var aim_motion := InputEventMouseMotion.new()
		aim_motion.relative = Vector2(-wrapf(aim_yaw-battle.actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(aim_pitch-battle.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(aim_motion); await frames(20)
	if not aim_settled:
		var muzzle_now: Vector3 = battle.actor.turret.muzzle.global_position
		var dir_now: Vector3 = battle.actor.turret.barrel_direction()
		var to_now: Vector3 = point - muzzle_now
		print("[aim] barrel NOT converged miss=%.4f m" % [(point - (muzzle_now + dir_now*to_now.dot(dir_now))).length()])
'@
$n2 = ([regex]::Matches($t, [regex]::Escape($old))).Count
Write-Output ("aim anchor x" + $n2)
if ($n2 -eq 1) {
    $t = $t.Replace($old, $ins.TrimEnd("`r","`n").Replace("`n", $nl) + $nl + $old)
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output "patch applied"
} else { Write-Output "AIM ANCHOR MISSING"; exit 1 }

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Write-Output ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier5.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier5.log') | Select-String 'Parse Error|Compile Error').Count
Write-Output ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier5.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Write-Output ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow7.log'
Write-Output ("running dev-tree flow; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Write-Output ("flow exit=" + $LASTEXITCODE)
Write-Output "=== aim and hits ==="
Get-Content $lg | Select-String '\[aim\] barrel|\[normal record\]|\[saved profile\]' | Select-Object -First 6 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(330, $_.Line.Trim().Length))) }
Write-Output "=== verdicts ==="
Get-Content $lg | Select-String '^\[FAIL\]|^\[PASS\] normal keyboard|^\[PASS\] result backed|^\[PASS\] actual personal|^\[PASS\] new store|^\[PASS\] task selection|^\[PASS\] quitting|=== ' | Select-Object -Last 14 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(180, $_.Line.Trim().Length))) }
Write-Output '=== done ==='
