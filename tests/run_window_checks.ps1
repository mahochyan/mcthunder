param(
    [string]$Order = '009',
    [string]$Script = 'run_recovery_player_checks',
    [int]$TimeoutSeconds = 150,
    [switch]$Wip
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$logRoot = Join-Path $projectRoot "logs/$Order/$identity/window-$stamp"
$captureRoot = "res://docs/evidence/$Order/$identity/window-$stamp"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$argsText = '--path "' + $projectRoot + '" --position 1280,0 --max-fps 60 -s "res://tests/' + $Script + '.gd" -- --shot-dir "' + $captureRoot + '"'
$proc = Start-Process -FilePath $engine -ArgumentList $argsText -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logRoot/stdout.log" -RedirectStandardError "$logRoot/stderr.log"
$timer = [Diagnostics.Stopwatch]::StartNew()
while (-not $proc.WaitForExit(1000) -and $timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) { }
$timedOut = -not $proc.HasExited
if ($timedOut) { Stop-Process -Id $proc.Id -Force }
$proc.WaitForExit()
$output = [IO.File]::ReadAllText("$logRoot/stdout.log")
$errors = [IO.File]::ReadAllText("$logRoot/stderr.log")
$passed = -not $timedOut -and $proc.ExitCode -eq 0 -and ($errors + $output) -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]' -and $output -match '(?m)^[A-Z_]*CHECKS_PASS\s*$'
[pscustomobject]@{source_sha=$sourceSha; uncommitted_source=[bool]$Wip; engine=(& $engine --version).Trim(); command='"'+$engine+'" '+$argsText; exit_code=$proc.ExitCode; timed_out=$timedOut; passed=$passed; captures=$captureRoot; human='NOT_RUN'} | ConvertTo-Json | Set-Content "$logRoot/RESULTS.json" -Encoding utf8
Get-Content "$logRoot/RESULTS.json"
Write-Output "EVIDENCE=$logRoot"
if (-not $passed) { exit 1 }
exit 0
