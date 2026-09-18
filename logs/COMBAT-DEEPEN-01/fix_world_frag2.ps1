$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\projectiles\fragment_system.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

$a1 = '	var delayed := not st.fuze_policy.is_empty() or directional'
$b1 = '	var delayed := not st.fuze_policy.is_empty() or directional' + "`r`n" + `
  $T + '# CD07: an external HE bursts OUTSIDE a target, which breaks the assumption that a non-delayed effect happened inside' + "`r`n" + `
  $T + '# one. Such a burst therefore takes the same multi-target eligibility path as a delayed one, gated on the policy.' + "`r`n" + `
  $T + 'var external_blast := st.effect_policy == "he_blast"'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

$a2 = '	if delayed and not directional:'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,'	if (delayed or external_blast) and not directional:')

$a3 = '			if not delayed and not ShellEffectPolicy.inside(target,point+direction*ShellEffectPolicy.EPS*2):'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,'			if not delayed and not external_blast and not ShellEffectPolicy.inside(target,point+direction*ShellEffectPolicy.EPS*2):')

$a4 = '			var leave := INF if delayed else ShellEffectPolicy.exit_distance(target,point,direction,remaining)'
$n4 = ([regex]::Matches($txt,[regex]::Escape($a4))).Count
$txt = $txt.Replace($a4,'			var leave := INF if (delayed or external_blast) else ShellEffectPolicy.exit_distance(target,point,direction,remaining)')
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  gate_var=$n1 eligibility=$n2 guard=$n3 leave=$n4 ; external_gate=" + $txt.Contains('var external_blast := st.effect_policy == "he_blast"')

& $g --headless --path $c --check-only --script res://scripts/projectiles/fragment_system.gd *> "$L\parse-fs2.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-fs2.log" | Select-String 'Parse Error|Compile Error').Count
"  fragment_parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-fs2.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-wo2.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-wo2.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl\]|=== 结果|CD07_WALL_OCCLUSION|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
