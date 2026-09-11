param([int]$Port=19109)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$folder=Join-Path $projectRoot ('logs/wt009/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$processes=@{}
$launches=@{}
function Start-Slice([string]$Role,[string]$Name) {
    $arguments='--headless --path "'+$projectRoot+'" --max-fps 120 -s res://tests/run_network_slice.gd -- '+$Role+' '+$Port+' "'+(Join-Path $folder ($Name+'.json'))+'"'
    $child=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $folder ($Name+'.stdout.log')) -RedirectStandardError (Join-Path $folder ($Name+'.stderr.log'))
    $launches[$Name]=@{pid=$child.Id;command=($engine+' '+$arguments)}
    $child
}
$processes.server=Start-Slice 'server' 'server'
$deadline=[DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path (Join-Path $folder 'server.json.ready')) -and -not $processes.server.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
if (Test-Path (Join-Path $folder 'server.json.ready')) {
    $processes.client1=Start-Slice 'client' 'client1'
    $processes.client2=Start-Slice 'client' 'client2'
}
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
$results=@(foreach ($name in $processes.Keys) {
    $process=$processes[$name]
    $process.WaitForExit() # Each process owns a bounded internal deadline.
    $out=Read-SuiteLog (Join-Path $folder ($name+'.stdout.log'))
    $err=Read-SuiteLog (Join-Path $folder ($name+'.stderr.log'))
    $reportPath=Join-Path $folder ($name+'.json')
    $report=if (Test-Path $reportPath) { Get-Content $reportPath -Raw | ConvertFrom-Json } else { $null }
    [pscustomobject]@{role=$name;exit_code=$process.ExitCode;passed=($process.ExitCode -eq 0 -and $report.passed -and -not $out.Error -and -not $err.Error -and ($out.Text+$err.Text) -notmatch 'SCRIPT ERROR:|(?m)^ERROR:');digest=$report.digest}
})
$passed=$results.Count -eq 3 -and @($results | Where-Object { -not $_.passed }).Count -eq 0 -and @($results.digest | Select-Object -Unique).Count -eq 1
$hashes=@{}
foreach ($relative in @('scripts/network/network_controller.gd','scripts/network/network_battle_world.gd','scripts/network/network_battle_server.gd','scripts/vehicle_actor.gd','scripts/tank.gd','scripts/camera_rig.gd','scripts/projectiles/projectile_manager.gd','tests/run_network_slice.gd')) { $hashes[$relative]=(Get-FileHash (Join-Path $projectRoot $relative)).Hash }
@{passed=$passed;results=$results;source=(& git -C $projectRoot rev-parse HEAD).Trim();build='source-worktree';file_hashes=$hashes;launches=$launches;engine_sha256=(Get-FileHash $engine).Hash} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $folder 'RESULTS.json')
$results | Format-Table
Write-Output ('EVIDENCE='+$folder)
if (-not $passed) { exit 1 }
