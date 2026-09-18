$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$q="$c\tests\probe_cd007_wall_occlusion.gd"
$tv = Get-Content $q -Raw -Encoding UTF8
$a = '	var box := BoxShape3D.new(); box.size = Vector3(1,4,4)   # 1 m thick along X, 4 m tall and wide'
$b = '	# The diagnostic showed every fragment stopping on "world" with one query: the burst happens ON the wall, so a one metre' + "`r`n" + `
  '	# thick slab swallowed even the sideways fragments. A thin wall is what the case means - it blocks what is behind it and' + "`r`n" + `
  '	# lets the rest pass.' + "`r`n" + `
  '	var box := BoxShape3D.new(); box.size = Vector3(0.1,4,4)   # 0.1 m thick along X, 4 m tall and wide'
$n = ([regex]::Matches($tv,[regex]::Escape($a))).Count
$tv = $tv.Replace($a,$b)
[IO.File]::WriteAllText($q, $tv, (New-Object Text.UTF8Encoding($false)))
"  thin_wall_edit=$n"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_wall_occlusion.gd *> "$L\parse-tw.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-tw.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-tw.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-tw.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 occl\] fragments|CD07 occl\]   fragment|CD07 occl\] terminal|CD07 occl\] shielded|CD07 occl\] unshielded|CD07_WALL_OCCLUSION|^\[FAIL\]' | Select-Object -First 14 | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
