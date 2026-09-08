param([Parameter(Mandatory=$true)][string]$Executable,[switch]$Wip)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $projectRoot "logs/019/$identity/player-$stamp"
$shotDir = Join-Path $projectRoot "docs/evidence/019/$identity/player-$stamp"
New-Item -ItemType Directory -Force -Path $logDir,$shotDir | Out-Null
$exe = (Resolve-Path -LiteralPath $Executable).Path
$arguments = '--position 1280,0 --max-fps 60 -- --team-play-check --shot-dir "'+$shotDir+'"'
$process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $exe) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDir/stdout.log" -RedirectStandardError "$logDir/stderr.log"
$timeout = -not $process.WaitForExit(900000)
if ($timeout) { Stop-Process -Id $process.Id -Force }
$process.WaitForExit()
$output = [IO.File]::ReadAllText("$logDir/stdout.log") + [IO.File]::ReadAllText("$logDir/stderr.log")
$passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -match 'TEAM_SLICE_PLAYER_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
@{source_sha=$sourceSha;uncommitted_source=[bool]$Wip;command='"'+$exe+'" '+$arguments;exe_sha256=(Get-FileHash -LiteralPath $exe).Hash;exit_code=$process.ExitCode;timed_out=$timeout;passed=$passed;captures=$shotDir;human='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content "$logDir/RESULTS.json" -Encoding utf8
Get-Content "$logDir/RESULTS.json"
Get-Content "$logDir/stdout.log"
if (-not $passed) { exit 1 }
exit 0
