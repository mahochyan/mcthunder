$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\projectiles\fragment_system.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# The previous attempt wrote the comment lines one level too shallow, so the for-block had no indented body. Rebuild the
# whole eligibility loop with explicit tab counts.
$i = $txt.IndexOf('		if (delayed or external_blast) and not directional:')
"  found_loop=" + [int]($i -ge 0)
if ($i -ge 0) {
  $j = $txt.IndexOf('		for iteration in ShellEffectPolicy.FRAGMENT_CONTACTS:')
  "  found_next=" + [int]($j -gt $i)
  if ($j -gt $i) {
    $head = $txt.Substring(0,$i)
    $tail = $txt.Substring($j)
    $loop = '		if (delayed or external_blast) and not directional:' + "`r`n" + `
      '			eligible.clear()' + "`r`n" + `
      '			for snapshot in snapshots:' + "`r`n" + `
      '				# An external blast is NOT inside any target, so an inside test would leave the candidate set empty. For' + "`r`n" + `
      '				# that policy every supplied snapshot is a candidate; what a fragment actually strikes is still decided' + "`r`n" + `
      '				# by its ray and by world occlusion, which is what makes the wall matter.' + "`r`n" + `
      '				if snapshot is Dictionary:' + "`r`n" + `
      '					if external_blast or ShellEffectPolicy.inside(snapshot, point+direction*ShellEffectPolicy.EPS*2):' + "`r`n" + `
      '						eligible[DamageResolver.target_key(snapshot)] = true' + "`r`n"
    $txt = $head + $loop + $tail
  }
}
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  external_candidate=" + $txt.Contains('if external_blast or ShellEffectPolicy.inside(snapshot')
& $g --headless --path $c --check-only --script res://scripts/projectiles/fragment_system.gd *> "$L\parse-fs4.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-fs4.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-fs4.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j2 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-wo4.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j2 -Timeout 420
if (-not $d) { Stop-Job $j2; "  timeout" } else { "  done" }
Remove-Job $j2
Get-Content "$L\cd007-wo4.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl\]|=== 结果|CD07_WALL_OCCLUSION|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
