$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\scripts\projectiles\fragment_system.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$a = '			if not delayed and DamageResolver.target_key(event) != DamageResolver.target_key(st.burst_target): fragment.reason = "other_target"; break'
$b = '			# CD07: the same "a non-delayed effect happened inside its target" assumption again - an external blast has no burst' + "`r`n" + `
  '			# target, so this test would reject every other target outright. Gated on the external blast policy.' + "`r`n" + `
  '			if not delayed and not external_blast and DamageResolver.target_key(event) != DamageResolver.target_key(st.burst_target): fragment.reason = "other_target"; break'
$n = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  other_target_gate=$n ; gated=" + $txt.Contains('if not delayed and not external_blast and DamageResolver.target_key(event)')
& $g --headless --path $c --check-only --script res://scripts/projectiles/fragment_system.gd *> "$L\parse-fs5.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-fs5.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-fs5.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-wo5.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-wo5.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl\]|=== 结果|CD07_WALL_OCCLUSION|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
