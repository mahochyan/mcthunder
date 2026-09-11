param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
$data=Get-Content -LiteralPath $Report -Raw | ConvertFrom-Json
$stages=@()
foreach($group in ($data.snapshots | Group-Object { [math]::Floor($_.wall_seconds/60) })) {
    $rows=@($group.Group | Sort-Object frame_index)
    if($rows.Count -lt 2) { continue }
    $first=$rows[0]; $last=$rows[-1]
    $frames=@($data.samples_ms[([int]$first.frame_index)..([int]$last.frame_index-1)])
    $sorted=@($frames | Sort-Object)
    $mean=($frames | Measure-Object -Average).Average
    $wall=$last.wall_seconds-$first.wall_seconds
    $queries=$last.query_calls_total-$first.query_calls_total
    $queryMs=$last.query_cpu_ms_total-$first.query_cpu_ms_total
    $stages+= [ordered]@{
        wall_start=$first.wall_seconds;wall_end=$last.wall_seconds;frames=$frames.Count
        fps=1000/$mean;p95_ms=$sorted[[math]::Ceiling($sorted.Count*0.95)-1]
        query_calls=$queries;query_cpu_ms=$queryMs;query_wall_percent=100*$queryMs/($wall*1000)
        nodes_min=($rows.nodes | Measure-Object -Minimum).Minimum;nodes_max=($rows.nodes | Measure-Object -Maximum).Maximum
        projectiles_max=($rows.projectiles | Measure-Object -Maximum).Maximum
        records_max=($rows.records | Measure-Object -Maximum).Maximum
        wrecks_max=($rows.wrecks | Measure-Object -Maximum).Maximum
        orphan_max=($rows.orphans | Measure-Object -Maximum).Maximum
        primitives_max=($rows.primitives | Measure-Object -Maximum).Maximum
        draw_calls_max=($rows.draw_calls | Measure-Object -Maximum).Maximum
        static_memory_max=($rows.static_memory_bytes | Measure-Object -Maximum).Maximum
    }
}
$output=Join-Path (Split-Path -Parent $Report) 'MATCH_STAGES.json'
@{scope='60-second wall buckets bounded by recorded snapshot frame indices; excludes unpaired bucket edges';source_report=$Report;stages=$stages} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $output
$stages | ForEach-Object { [pscustomobject]$_ } | Format-Table wall_start,wall_end,fps,p95_ms,query_wall_percent,nodes_max,projectiles_max,records_max,wrecks_max
Write-Output ('EVIDENCE='+$output)
