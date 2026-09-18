$c='E:\AIprogram\mcthunder-cont'
$p="$c\tests\probe_cd007_he_landed.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$n1 = ([regex]::Matches($txt,'var sources := fixture_asset\(packet,1\.0\)')).Count
$txt = $txt.Replace('var sources := fixture_asset(packet,1.0)','var sources: Variant = packet.get("sources",{})')
$n2 = ([regex]::Matches($txt,'var sources2 := fixture_asset\(packet,1\.0\)')).Count
$txt = $txt.Replace('var sources2 := fixture_asset(packet,1.0)','var sources2: Variant = packet.get("sources",{})')
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  replaced=" + $n1 + "/" + $n2
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_he_landed.gd *> "$L\parse-hel3.log" 2>&1 | Out-Null
$err = @(Get-Content "$L\parse-hel3.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hel3.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_landed.gd *> "$L\cd007-hel3.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hel3.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 HE|=== 结果|CD07_HE_LANDED|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(250,$_.Line.Trim().Length)) }
