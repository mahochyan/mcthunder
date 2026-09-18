$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== what the previous scene run actually said, in full ==='
$o = Get-Content "$L\c9h.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  log lines=' + $o.Count
@($o | Select-String 'SCRIPT ERROR|Invalid|CD09-T0|not_yet_met|CD09_SCENES') | Select-Object -First 14 | ForEach-Object { '    ' + $_.Line.Trim().Substring(0,[Math]::Min(190,$_.Line.Trim().Length)) }

'=== fix the one bad token: s3 IS the state, so s3.state is wrong ==='
$p="$c\tests\run_cd009_scene_checks.gd"
$t = Get-Content $p -Raw -Encoding UTF8
$n = ([regex]::Matches($t,'s3\.state\.breech_failure')).Count
$t = $t.Replace('s3.state.breech_failure','s3.breech_failure')
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))
'  token fixes=' + $n
& $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\s144b.log" 2>&1 | Out-Null
'  scene parse_errors=' + @(Get-Content "$L\s144b.log" | Select-String 'Parse Error|Compile Error').Count
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9i.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 300
$o2 = Get-Content "$L\c9i.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  log lines=' + $o2.Count + ' ; crashes=' + @($o2|Select-String 'SCRIPT ERROR').Count
$o2 | Select-String 'CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]|CD09\] S3' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(215,$_.Line.Trim().Length)) }
