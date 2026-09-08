param([switch]$Wip)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$logDir = Join-Path $projectRoot ("logs/019/$identity/profile-"+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$arguments = '--path "'+$projectRoot+'" --position 1280,0 --max-fps 60 -s res://tests/run_frame_profile.gd -- --report-dir "'+$logDir+'"'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDir/stdout.log" -RedirectStandardError "$logDir/stderr.log"
$timeout = -not $process.WaitForExit(90000)
if ($timeout) { Stop-Process -Id $process.Id -Force }
$process.WaitForExit()
$output = [IO.File]::ReadAllText("$logDir/stdout.log") + [IO.File]::ReadAllText("$logDir/stderr.log")
$passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -match 'FRAME_PROFILE_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
@{source_sha=$sourceSha;uncommitted_source=[bool]$Wip;command='"'+$engine+'" '+$arguments;exit_code=$process.ExitCode;timed_out=$timeout;passed=$passed;human='NOT_RUN'} | ConvertTo-Json | Set-Content "$logDir/RESULTS.json" -Encoding utf8
Get-Content "$logDir/RESULTS.json"
Get-Content "$logDir/stdout.log"
if (-not $passed) { exit 1 }
exit 0
