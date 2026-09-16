$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'

# Restore from HEAD first, so this patch always applies to the committed text.
$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Write-Output ("restored from HEAD, lines=" + @($good).Count)

$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$anchor = "`tawait frames(240)" + $nl + "`tprint(`"[aim] camera=`""
$n = ([regex]::Matches($t, [regex]::Escape($anchor))).Count
Write-Output ("anchor x" + $n)

$ins = @'
	# WT-040-R1 measured evidence and the correction it forces. The camera's intent_point() is the FIRST surface
	# its ray hits, so for a point behind armour it can never equal that point: a run with forty correction
	# passes ended with the intent still 0.90 m away, which is why waiting for the intent to converge cannot
	# work. What actually decides the shot is the BARREL's own line, so convergence is measured there - as the
	# perpendicular distance from that line to the requested point - and the tolerance is geometric rather than a
	# dot product, because dot > 0.9995 still allows about 1.8 degrees, roughly 0.4 m at thirteen metres, which
	# is more than the target's 0.06 m half-height ammunition rack. The camera keeps being corrected toward the
	# requested point (the barrel follows it), and the barrel is given a bounded number of passes to settle.
	# Nothing about armour, damage, cooldown or inventory is written, and no game criterion is relaxed.
	var aim_tolerance := 0.03
	var aim_settled := false
	for pass_index in 60:
		var muzzle_at: Vector3 = battle.actor.turret.muzzle.global_position
		var barrel_dir: Vector3 = battle.actor.turret.barrel_direction()
		var to_point: Vector3 = point - muzzle_at
		var miss: float = (to_point - barrel_dir*to_point.dot(barrel_dir)).length()
		if miss <= aim_tolerance:
			aim_settled = true
			print("[aim] barrel converged miss=%.4f m on pass %d" % [miss, pass_index])
			break
		var aim_delta := point - battle.actor.cam_rig.cam.global_position
		var aim_yaw := atan2(-aim_delta.x,-aim_delta.z)
		var aim_pitch := atan2(aim_delta.y,Vector2(aim_delta.x,aim_delta.z).length())
		var aim_motion := InputEventMouseMotion.new()
		aim_motion.relative = Vector2(-wrapf(aim_yaw-battle.actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(aim_pitch-battle.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(aim_motion); await frames(20)
	if not aim_settled:
		var muzzle_now: Vector3 = battle.actor.turret.muzzle.global_position
		var dir_now: Vector3 = battle.actor.turret.barrel_direction()
		var to_now: Vector3 = point - muzzle_now
		print("[aim] barrel NOT converged miss=%.4f m" % [(to_now - dir_now*to_now.dot(dir_now)).length()])
'@
if ($n -eq 1) {
    $t = $t.Replace($anchor, $ins.TrimEnd("`r","`n").Replace("`n", $nl) + $nl + $anchor)
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output "patch applied"
} else {
    Write-Output "PATCH ANCHOR MISSING - not applied"
}

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Write-Output ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier3.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier3.log') | Select-String 'Parse Error|Compile Error').Count
Write-Output ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier3.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Write-Output ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow5.log'
Write-Output ("running dev-tree flow; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Write-Output ("flow exit=" + $LASTEXITCODE)
Write-Output "=== aim and hits ==="
Get-Content $lg | Select-String '\[aim\] barrel|\[normal record\]' | Select-Object -First 5 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(320, $_.Line.Trim().Length))) }
Write-Output "=== verdicts ==="
Get-Content $lg | Select-String '^\[FAIL\]|^\[PASS\] normal keyboard|^\[PASS\] result backed|^\[PASS\] actual personal|^\[PASS\] new store|^\[PASS\] task selection|^\[PASS\] quitting|=== ' | Select-Object -Last 14 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(180, $_.Line.Trim().Length))) }
Write-Output '=== done ==='
