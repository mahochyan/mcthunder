$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'

$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Write-Output ("restored from HEAD, lines=" + @($good).Count)

$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }

# 1) introduce the adaptive aim target next to the tolerance
$old1 = '	var aim_tolerance := 0.03'
$new1 = '	var aim_tolerance := 0.03' + $nl + '	var aim_target: Vector3 = point'
$n1 = ([regex]::Matches($t, [regex]::Escape($old1))).Count
Write-Output ("tolerance anchor x" + $n1)

# 2) feed the barrel's measured miss back into the camera aim, on that same pass
$old2 = '		var aim_delta := point - battle.actor.cam_rig.cam.global_position'
$new2 = @'
		# WT-040-R1: the camera's intent_point is the FIRST surface its ray hits, so aiming it at a point behind
		# armour pins the barrel about 0.13 m high - measured residuals were 0.1396 m from one firing position
		# and 0.1316 m from another, which is why the position was ruled out as the cause. The camera target is
		# therefore shifted each pass by the vector from where the barrel line passes closest to the requested
		# point, so the correction acts on the barrel's own error. No game value is written or relaxed.
		aim_target = aim_target + (point - (muzzle_at + barrel_dir*to_point.dot(barrel_dir)))
		var aim_delta := aim_target - battle.actor.cam_rig.cam.global_position
'@
$n2 = ([regex]::Matches($t, [regex]::Escape($old2))).Count
Write-Output ("delta anchor x" + $n2)

if ($n1 -eq 1 -and $n2 -eq 1) {
    $t = $t.Replace($old1, $new1)
    $t = $t.Replace($old2, $new2.TrimEnd("`r","`n").Replace("`n", $nl))
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output "patch applied"
} else { Write-Output "ANCHOR MISSING - not applied"; exit 1 }

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Write-Output ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier6.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier6.log') | Select-String 'Parse Error|Compile Error').Count
Write-Output ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier6.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Write-Output ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow8.log'
Write-Output ("running dev-tree flow; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Write-Output ("flow exit=" + $LASTEXITCODE)
Write-Output "=== aim and hits ==="
Get-Content $lg | Select-String '\[aim\] barrel|\[normal record\]|\[saved profile\]' | Select-Object -First 6 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(330, $_.Line.Trim().Length))) }
Write-Output "=== verdicts ==="
Get-Content $lg | Select-String '^\[FAIL\]|^\[PASS\] normal keyboard|^\[PASS\] result backed|^\[PASS\] actual personal|^\[PASS\] new store|^\[PASS\] task selection|^\[PASS\] quitting|=== ' | Select-Object -Last 14 | ForEach-Object { Write-Output ("  " + $_.Line.Trim().Substring(0, [Math]::Min(180, $_.Line.Trim().Length))) }
Write-Output '=== done ==='
