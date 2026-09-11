param([Parameter(Mandatory)][string]$Folder)
$ErrorActionPreference='Stop'
$identity=Get-Content -LiteralPath (Join-Path $Folder 'BENCHMARK_PROFILE.json') -Raw | ConvertFrom-Json
$report=Get-Content -LiteralPath (Join-Path $Folder ('FRAME_PROFILE_'+$identity.map+'_'+$identity.seed+'.json')) -Raw | ConvertFrom-Json
$result=Get-Content -LiteralPath (Join-Path $Folder 'RESULTS.json') -Raw | ConvertFrom-Json
$frames=@($report.samples_ms)
if ($frames.Count -eq 0 -or @($frames | Where-Object { $_ -le 0 -or [double]::IsNaN($_) -or [double]::IsInfinity($_) }).Count -gt 0) { throw 'Invalid raw frame samples' }
$sorted=@($frames | Sort-Object)
$total=($frames | Measure-Object -Sum).Sum
$mean=$total/$frames.Count
$p95=$sorted[[Math]::Ceiling($frames.Count*0.95)-1]
$p99=$sorted[[Math]::Ceiling($frames.Count*0.99)-1]
$rawMatches=$report.frames_from_match_start.count -eq $frames.Count -and [Math]::Abs($report.frames_from_match_start.mean_ms-$mean) -lt 0.000001 -and [Math]::Abs($report.frames_from_match_start.p95_ms-$p95) -lt 0.000001 -and [Math]::Abs($report.frames_from_match_start.p99_ms-$p99) -lt 0.000001
$complete=$result.passed -and $identity.full_requested -and $report.match_finished -and -not $report.incomplete -and $rawMatches -and $report.resolution[0] -eq 1920 -and $report.resolution[1] -eq 1080
$memoryPath=Join-Path $Folder 'PROCESS_MEMORY.json'
$rawMemory=if (Test-Path -LiteralPath $memoryPath) { @(Get-Content -LiteralPath $memoryPath -Raw | ConvertFrom-Json) } else { @() }
$rolesPath=Join-Path $Folder 'PROCESS_ROLES.json'
$memory=@()
if (Test-Path -LiteralPath $rolesPath) {
    $roles=Get-Content -LiteralPath $rolesPath -Raw | ConvertFrom-Json
    $memory=@($rawMemory | Where-Object { $roles.PSObject.Properties[[string]$_.pid].Value -like 'Godot*' })
}
$summary=[ordered]@{
    source_sha=$identity.source_sha;map=$identity.map;seed=$identity.seed;full_match_verified=[bool]$complete;raw_statistics_verified=$rawMatches
    resolution=$report.resolution;cpu=$report.cpu;gpu=$report.gpu;renderer=$report.renderer;render_cap=$report.render_cap;fx_level=$report.fx_level
    ram_bytes=$identity.ram_bytes;physics_tick_hz=$report.physics_tick_hz;time_scale=$report.time_scale;query_metrics=$report.query_metrics
    observer_far_m=$report.observer_far_m;wall_seconds=$report.wall_seconds;sim_seconds=$report.measurement_end_sim_time;termination=$report.termination_reason
    frames=$frames.Count;mean_ms=$mean;fps_from_mean=1000/$mean;p95_ms=$p95;p99_ms=$p99;max_ms=$sorted[-1]
    p95_within_20ms=($complete -and $p95 -le 20);p99_within_33_3ms=($complete -and $p99 -le 33.3)
    raw_memory_samples=$rawMemory.Count;memory_samples=$memory.Count;memory_source_verified=($memory.Count -gt 0);private_bytes_peak=($memory | Measure-Object -Property private_bytes -Maximum).Maximum
    working_set_bytes_peak=($memory | Measure-Object -Property working_set_bytes -Maximum).Maximum
    nodes_peak=($report.snapshots | Measure-Object -Property nodes -Maximum).Maximum
    physics_ms_peak=($report.snapshots | Measure-Object -Property physics_ms -Maximum).Maximum
    process_ms_peak=($report.snapshots | Measure-Object -Property process_ms -Maximum).Maximum
    load_coverage=$report.load_coverage
    limitations=@('single seed and observer camera','instrumented source build','virtual display present','16 and 32 actors not measured','frame intervals do not attribute a specific bottleneck')
}
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Folder 'SUMMARY.json') -Encoding utf8
[pscustomobject]$summary | Select-Object source_sha,map,full_match_verified,raw_statistics_verified,frames,fps_from_mean,p95_ms,p99_ms,max_ms,p95_within_20ms,p99_within_33_3ms | ConvertTo-Json
if (-not $complete) { exit 1 }
