$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'
$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Show ("restored from HEAD, lines=" + @($good).Count)
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$applied = 0

# 1) keep driving while the goal is still more than 0.6 m away, instead of only beyond 2 m
$old1 = '		var desired := {KEY_W:distance>2 and absf(difference)<0.18 and speed<7.0,KEY_S:distance<=2 and speed>0.2,KEY_A:distance>2 and difference>0.06,KEY_D:distance>2'
if ($t.Contains($old1)) {
    $new1 = '		# WT-040-R1: keep closing until the goal is genuinely reached. The measured stop error was 0.66 m in the' + $nl + '		# package and 0.80 m in the source tree, and that drift alone moved the burst point 0.45 m - enough to' + $nl + '		# credit the loader instead of the ammunition rack - so the tolerance is tightened here. The value stays' + $nl + '		# bounded and the loop can still time out.' + $nl + '		var desired := {KEY_W:distance>0.6 and absf(difference)<0.18 and speed<7.0,KEY_S:distance<=1.2 and speed>0.2,KEY_A:distance>0.6 and difference>0.06,KEY_D:distance>0.6'
    $t = $t.Replace($old1, $new1); $applied++
    Show "desired-dict patch applied"
} else { Show "DESIRED ANCHOR MISSING" }

# 2) break only when actually stopped near the goal
$old2 = '		if distance<=2 and absf(speed)<0.2: break'
if ($t.Contains($old2)) {
    $t = $t.Replace($old2, '		if distance<=0.6 and absf(speed)<0.15: break')
    $applied++
    Show "break-condition patch applied"
} else { Show "BREAK ANCHOR MISSING" }

# 3) accept only a genuinely reached goal (was 4 m)
$old3 = '	return ((battle.actor.tank.global_position-goal)*Vector3(1,0,1)).length()<4'
if ($t.Contains($old3)) {
    $t = $t.Replace($old3, '	return ((battle.actor.tank.global_position-goal)*Vector3(1,0,1)).length()<1.0')
    $applied++
    Show "accept-condition patch applied"
} else { Show "ACCEPT ANCHOR MISSING" }

if ($applied -ne 3) { Show ("only " + $applied + " of 3 patches applied - aborting"); exit 1 }
[System.IO.File]::WriteAllText($p, $t, $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Show ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier8.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier8.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier8.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow10.log'
Show ("dev-tree guard run; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Show ("flow exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String '\[drive\]|\[aim\] barrel|\[normal record\]' | Select-Object -First 6 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(310, $_.Line.Trim().Length))) }
$verdict = @(Get-Content $lg | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration')
Show ("flank pass lines=" + $verdict.Count)
if ($verdict.Count -lt 2) { Show "DEV-TREE GUARD FAILED - not committing, not rebuilding"; exit 1 }

git -C $c add scripts/diagnostics/player_flow_verifier.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Tighten the driven approach so the firing position is reproducible, which is what the measured divergence came down to. The package stopped 0.66 m from the goal and the source tree 0.80 m, because drive_to broke out as soon as it was within two metres and accepted anything within four; that drift moved the burst point by 0.45 m, and the burst point is what decides which interior item is credited - the rack at world z -20.28 or the loader at -19.96 - so the same code credited ammo_ready in one run and loader in the other. The helper now keeps closing while the goal is more than 0.6 m away, only breaks when it is stopped within 0.6 m, and only reports success within 1.0 m. No game value is written and no criterion is relaxed; the loop stays bounded and can still time out. The dev-tree guard passes before this is committed, and a rebuild follows so the package can be measured" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
