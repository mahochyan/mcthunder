$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\tests\probe_cd007_segmented_plates.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$a = '	check(actor.setup(defs,packet.id,"cd007_t03",1,Transform3D.IDENTITY,2,layout).ok,"CD07 T03 the two-plate actor installs")'
$b = '	check(actor.setup(defs,packet.id,"cd007_t03",1,Transform3D.IDENTITY,2,null).ok,"CD07 T03 the actor installs")' + "`r`n" + `
  '	# The convention every probe here uses: setup takes null and the layout is installed by set_damage_layout.' + "`r`n" + `
  '	actor.set_damage_layout(layout)'
$n = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  layout_fix=$n"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_segmented_plates.gd *> "$L\parse-t03b.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-t03b.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-t03b.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_segmented_plates.gd *> "$L\cd007-t03b.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-t03b.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 T03|=== 结果|CD07_SEGMENTED_PLATES|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(250,$_.Line.Trim().Length)) }
