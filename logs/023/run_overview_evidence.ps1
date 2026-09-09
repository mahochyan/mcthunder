$ErrorActionPreference = 'Stop'
$projectRoot = 'E:/AIprogram/mcthunder-development'
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sha = (& git -C $projectRoot rev-parse HEAD).Trim()
$stamp = 'overview-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$logs = Join-Path $projectRoot "logs/023/$sha/$stamp"
$shots = Join-Path $projectRoot "docs/evidence/023/$sha/$stamp"
New-Item -ItemType Directory -Force -Path $logs,$shots | Out-Null
$argsText = '--path "'+$projectRoot+'" -s res://tests/run_industrial_overview.gd -- --shot-dir "'+$shots+'"'
$out = Join-Path $logs 'overview_stdout.log'; $err = Join-Path $logs 'overview_stderr.log'
$p = Start-Process -FilePath $engine -ArgumentList $argsText -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
$timedOut = -not $p.WaitForExit(60000)
if ($timedOut) { Stop-Process -Id $p.Id -Force }
$p.WaitForExit()
$output = [IO.File]::ReadAllText($out)+[IO.File]::ReadAllText($err)
$passed = -not $timedOut -and $p.ExitCode -eq 0 -and $output -match 'MAP_OVERVIEW_PASS' -and $output -notmatch '(?m)^ERROR:|SCRIPT ERROR:|\[FAIL\]'
[pscustomobject]@{source_sha=$sha; command=('"'+$engine+'" '+$argsText); engine=(& $engine --version).Trim(); exit_code=$p.ExitCode; timed_out=$timedOut; checks=2; passed=$passed; fixture='authored-map renderer, not player viewpoint'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs 'RESULTS.json') -Encoding utf8
$images = @(Get-ChildItem -LiteralPath $shots -Filter '*.png' | ForEach-Object { [pscustomobject]@{file=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
[pscustomobject]@{source_sha=$sha; images=$images; graphical_review='PENDING'; human='NOT_RUN'; fixture='authored-map renderer, not player viewpoint'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $shots 'SESSION.json') -Encoding utf8
Write-Output ('PASSED='+$passed)
Write-Output ('EVIDENCE='+$logs)
Write-Output ('SCREENSHOTS='+$shots)
if (-not $passed -or $images.Count -ne 2) { exit 1 }
exit 0
