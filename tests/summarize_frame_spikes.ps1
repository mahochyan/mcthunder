param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
$data=Get-Content -LiteralPath $Report -Raw | ConvertFrom-Json
if(-not $data.query_metrics.enabled -or $data.frame_queries.Count -ne $data.samples_ms.Count) { throw 'Requires per-frame query attribution with one row per drawn frame.' }
$rows=[System.Collections.Generic.List[object]]::new(); $queryCalls=0L; $queryMs=0.0
for($index=0;$index -lt $data.samples_ms.Count;$index++) {
    $row=$data.frame_queries[$index]
    if($row[0] -ne $index+1 -or $row[1] -lt 0 -or $row[2] -lt 0 -or $row[3] -lt 0) { throw 'Invalid frame attribution sequence.' }
    $queryCalls+=$row[1]; $queryMs+=$row[2]
    $rows.Add([pscustomobject]@{frame=$row[0];frame_ms=$data.samples_ms[$index];query_calls=$row[1];query_ms=$row[2];physics_ticks=$row[3]})
}
if($queryCalls -ne $data.query_metrics.calls -or [math]::Abs($queryMs-$data.query_metrics.cpu_ms) -gt 0.05) { throw 'Per-frame counters do not reconcile with whole-run query totals.' }
$sourcesCalls=0L; $sourcesUsec=0L
foreach($source in $data.query_sources.PSObject.Properties) { $sourcesCalls+=$source.Value.calls; $sourcesUsec+=$source.Value.cpu_usec }
if($sourcesCalls -ne $queryCalls -or [math]::Abs($sourcesUsec/1000.0-$queryMs) -gt 0.05) { throw 'Source counters do not reconcile.' }
$long=@($rows | Where-Object frame_ms -gt 33.3)
$summary=@{frames=$rows.Count;long_frames=$long.Count;multiple_tick_long_frames=@($long | Where-Object physics_ticks -gt 1).Count;query_sources=$data.query_sources;worst_frames=@($rows | Sort-Object frame_ms -Descending | Select-Object -First 20);scope='Drawn-frame interval counters; query time excludes snapshot construction and other simulation. Source other is not automatically equivalent to AI.'}
$summary.query_majority_long_frames=@($long | Where-Object { $_.query_ms -gt $_.frame_ms*0.5 }).Count
$summary.single_tick_long_frames=@($long | Where-Object physics_ticks -eq 1).Count
$output=Join-Path (Split-Path -Parent $Report) 'FRAME_SPIKES.json'
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $output
$summary.worst_frames | Format-Table
Write-Output ('EVIDENCE='+$output)
