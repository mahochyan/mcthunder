param([Parameter(Mandatory=$true)][string]$Before,[Parameter(Mandatory=$true)][string]$After)
$ErrorActionPreference='Stop'
$baseline=Get-Content -LiteralPath $Before -Raw | ConvertFrom-Json
$candidate=Get-Content -LiteralPath $After -Raw | ConvertFrom-Json
if(-not $baseline.match_finished -or -not $candidate.match_finished) { throw 'Both reports must contain a naturally completed match.' }
$settings=@{}
foreach($field in @('map','seed','resolution','renderer','render_cap','vsync','fx_level','selected_vehicle','physics_tick_hz','cpu','gpu','engine')) {
    $settings[$field]=(($baseline.$field | ConvertTo-Json -Compress -Depth 4) -ceq ($candidate.$field | ConvertTo-Json -Compress -Depth 4))
}
if($settings.Values -contains $false) { throw ('Benchmark configuration mismatch: '+($settings | ConvertTo-Json -Compress)) }
if($baseline.query_metrics.enabled -ne $candidate.query_metrics.enabled) { throw 'Query instrumentation differs.' }
$result=[ordered]@{
    before_report=$Before;after_report=$After;matching_settings=$settings
    before=$baseline.frames_from_match_start;after=$candidate.frames_from_match_start
    query_cpu_ms_before=$baseline.query_metrics.cpu_ms;query_cpu_ms_after=$candidate.query_metrics.cpu_ms
    query_calls_before=$baseline.query_metrics.calls;query_calls_after=$candidate.query_metrics.calls
    simulation_seconds_before=$baseline.measurement_end_sim_time;simulation_seconds_after=$candidate.measurement_end_sim_time
    finished_projectiles_before=$baseline.load_coverage.projectiles_finished;finished_projectiles_after=$candidate.load_coverage.projectiles_finished
    exact_per_tick_equivalence_proven=$false
    target_fps=60;target_p95_ms=20;target_p99_ms=33.3
    frame_time_targets_met=($candidate.frames_from_match_start.p95_ms -le 20 -and $candidate.frames_from_match_start.p99_ms -le 33.3)
}
$path=Join-Path (Split-Path -Parent $After) 'BENCHMARK_COMPARISON.json'
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path
$result | ConvertTo-Json -Depth 6
Write-Output ('EVIDENCE='+$path)
