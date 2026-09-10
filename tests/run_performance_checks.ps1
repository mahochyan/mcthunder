param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$SourceSha,
    [int]$Seconds=1800,
    [int]$Cycles=20
)
$ErrorActionPreference='Stop'
if ($Seconds -lt 10 -or $Seconds -gt 3600 -or $Cycles -lt 2 -or $Cycles -gt 40) { throw 'Invalid bounded performance request' }
if ($SourceSha -notmatch '^[0-9a-f]{40}$') { throw 'Provide the exact exported source SHA' }
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$manifestPath=Join-Path (Split-Path -Parent $Executable) 'BUILD_MANIFEST.json'
if (Test-Path -LiteralPath $manifestPath) {
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.source_sha -ne $SourceSha) { throw 'Requested source differs from actual package manifest' }
}
$projectRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $projectRoot ('logs/033/'+$SourceSha+'/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$stdout=Join-Path $out 'stdout.log'; $stderr=Join-Path $out 'stderr.log'
$arguments="--resolution 1280x720 -- --verify-performance --performance-seconds $Seconds --performance-cycles $Cycles"
$hardware=[ordered]@{os=(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,TotalVisibleMemorySize);cpu=(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);gpu=(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)}
$hardware | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'hardware.json') -Encoding utf8
$running=Start-Process -FilePath $Executable -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $Executable) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$memory=[System.Collections.Generic.List[object]]::new()
$watch=[Diagnostics.Stopwatch]::StartNew()
$timedOut=$false
while (-not $running.WaitForExit(2000)) {
    $running.Refresh()
    $memory.Add([pscustomobject]@{wall_seconds=$watch.Elapsed.TotalSeconds;working_set_bytes=$running.WorkingSet64;private_bytes=$running.PrivateMemorySize64;cpu_seconds=$running.TotalProcessorTime.TotalSeconds;handles=$running.HandleCount})
    if ($memory.Count%30 -eq 0) { $memory | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'process-memory.json') -Encoding utf8; Write-Output ('sampled_wall_seconds='+[int]$watch.Elapsed.TotalSeconds) }
    if ($watch.Elapsed.TotalSeconds -gt $Seconds+600) { $timedOut=$true; Stop-Process -Id $running.Id -Force; break }
}
$running.WaitForExit()
$memory | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'process-memory.json') -Encoding utf8
$output=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
$match=[regex]::Match($output,'(?m)^PERFORMANCE_REPORT=(.+)$')
$report=$null
if ($match.Success) {
    $reportPath=$match.Groups[1].Value.Trim()
    if (Test-Path -LiteralPath $reportPath) {
        Copy-Item -LiteralPath $reportPath -Destination (Join-Path $out 'performance.json')
        $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        Get-ChildItem -LiteralPath (Split-Path -Parent $reportPath) -Filter '*.png' | Copy-Item -Destination $out
    }
}
$passed=-not $timedOut -and $running.ExitCode -eq 0 -and $output -match 'PERFORMANCE_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]' -and $null -ne $report -and $report.complete -and $memory.Count -gt 0
$result=[ordered]@{source_sha=$SourceSha;exe_sha256=(Get-FileHash -LiteralPath $Executable).Hash;pck_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($Executable,'.pck'))).Hash;command='"'+$Executable+'" '+$arguments;exit_code=$running.ExitCode;timed_out=$timedOut;passed=$passed;wall_seconds=$watch.Elapsed.TotalSeconds;requested_seconds=$Seconds;requested_cycles=$Cycles;process_memory_samples=$memory.Count;peak_private_bytes=($memory | Measure-Object private_bytes -Maximum).Maximum;peak_working_set_bytes=($memory | Measure-Object working_set_bytes -Maximum).Maximum;memory_trend_review='REQUIRES_REVIEW_OF_SAMPLES';human='PENDING'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'RESULTS.json') -Encoding utf8
Write-Output "EVIDENCE=$out"
if (-not $passed) { exit 1 }
exit 0
