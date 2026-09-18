$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\projectiles\fragment_system.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

$a = '			for snapshot in snapshots:' + "`r`n" + '				if snapshot is Dictionary and ShellEffectPolicy.inside(snapshot, point+direction*ShellEffectPolicy.EPS*2):' + "`r`n" + '					eligible[DamageResolver.target_key(snapshot)] = true'
$b = '			for snapshot in snapshots:' + "`r`n" + `
  $T+$T+$T + '# An external blast is NOT inside any target, so the inside test would leave the candidate set empty. For that policy' + "`r`n" + `
  $T+$T+$T + '# every supplied snapshot is a candidate, and what the fragment actually strikes is still decided by its ray and by' + "`r`n" + `
  $T+$T+$T + '# world occlusion, which is what makes the wall matter.' + "`r`n" + `
  $T+$T+$T + 'if snapshot is Dictionary:' + "`r`n" + `
  $T+$T+$T+$T + 'if external_blast or ShellEffectPolicy.inside(snapshot, point+direction*ShellEffectPolicy.EPS*2):' + "`r`n" + `
  $T+$T+$T+$T+$T + 'eligible[DamageResolver.target_key(snapshot)] = true'
$n = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  eligibility_edit=$n ; external_candidate=" + $txt.Contains('if external_blast or ShellEffectPolicy.inside(snapshot')

& $g --headless --path $c --check-only --script res://scripts/projectiles/fragment_system.gd *> "$L\parse-fs3.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-fs3.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-fs3.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-wo3.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-wo3.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl\]|=== 结果|CD07_WALL_OCCLUSION|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
