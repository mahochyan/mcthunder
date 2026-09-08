param([ValidateRange(1,10)][int]$Runs=10,[switch]$Wip)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $projectRoot "logs/019/$identity/batch-$stamp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$arguments = '--headless --fixed-fps 60 --path "'+$projectRoot+'" -s res://tests/run_match_batch_checks.gd -- --runs '+$Runs+' --report-dir "'+$logDir+'"'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDir/stdout.log" -RedirectStandardError "$logDir/stderr.log"
$timeout = -not $process.WaitForExit($Runs*780000)
if ($timeout) { Stop-Process -Id $process.Id -Force }
$process.WaitForExit()
$output = [IO.File]::ReadAllText("$logDir/stdout.log") + [IO.File]::ReadAllText("$logDir/stderr.log")
$passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -match 'MATCH_BATCH_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
@{source_sha=$sourceSha;uncommitted_source=[bool]$Wip;command='"'+$engine+'" '+$arguments;exit_code=$process.ExitCode;timed_out=$timeout;passed=$passed;requested_matches=$Runs;human='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content "$logDir/RESULTS.json" -Encoding utf8
Get-Content "$logDir/RESULTS.json"
if (-not $passed) { exit 1 }
exit 0
