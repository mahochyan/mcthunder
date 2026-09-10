param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$SourceSha,
    [int]$Width=1280,
    [int]$Height=720
)
$ErrorActionPreference='Stop'
if ($SourceSha -notmatch '^[0-9a-f]{40}$' -or $Width -lt 640 -or $Width -gt 3840 -or $Height -lt 480 -or $Height -gt 2160) { throw 'Invalid source identity or window size' }
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$manifestPath=Join-Path (Split-Path -Parent $Executable) 'BUILD_MANIFEST.json'
if (Test-Path -LiteralPath $manifestPath) {
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.source_sha -ne $SourceSha) { throw 'Requested source differs from actual package manifest' }
}
$projectRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $projectRoot ('logs/034/'+$SourceSha+'/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$stdout=Join-Path $out 'stdout.log'; $stderr=Join-Path $out 'stderr.log'
$arguments="--resolution ${Width}x${Height} -- --verify-player-flow"
$running=Start-Process -FilePath $Executable -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $Executable) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$watch=[Diagnostics.Stopwatch]::StartNew(); $timedOut=$false
while (-not $running.WaitForExit(30000)) {
    Write-Output ('player_flow_wall_seconds='+[int]$watch.Elapsed.TotalSeconds)
    if ($watch.Elapsed.TotalSeconds -gt 2200) { $timedOut=$true; Stop-Process -Id $running.Id -Force; break }
}
$running.WaitForExit()
$output=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
$match=[regex]::Match($output,'(?m)^PLAYER_FLOW_EVIDENCE=(.+)$')
$pictures=@()
if ($match.Success) {
    $directory=$match.Groups[1].Value.Trim()
    $pictures=@(Get-ChildItem -LiteralPath $directory -Filter '*.png')
    New-Item -ItemType Directory -Force (Join-Path $out 'screenshots') | Out-Null
    $pictures | Copy-Item -Destination (Join-Path $out 'screenshots')
}
$required=@('00_garage_main_menu.png','05_real_shot_replay.png','09_battle_0.png','09_battle_1.png','10_settled_0.png','10_settled_1.png')
$missing=@($required | Where-Object { $_ -notin $pictures.Name })
$count=[regex]::Match($output,'=== 结果: (\d+) 项检查, (\d+) 失败 ===')
$passed=-not $timedOut -and $running.ExitCode -eq 0 -and $output -match 'PLAYER_FLOW_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]' -and $missing.Count -eq 0 -and $count.Success -and $count.Groups[2].Value -eq '0'
$result=[ordered]@{source_sha=$SourceSha;exe_sha256=(Get-FileHash -LiteralPath $Executable).Hash;pck_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($Executable,'.pck'))).Hash;command='"'+$Executable+'" '+$arguments;exit_code=$running.ExitCode;timed_out=$timedOut;passed=$passed;checks=if($count.Success){[int]$count.Groups[1].Value}else{0};missing_screenshots=$missing;images=@($pictures | ForEach-Object {@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}});human='PENDING'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'RESULTS.json') -Encoding utf8
Write-Output "EVIDENCE=$out"
if (-not $passed) { exit 1 }
exit 0
