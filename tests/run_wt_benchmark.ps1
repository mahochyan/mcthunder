param([ValidateSet('village','industrial')][string]$Map='village',[int]$Seed=19001,[switch]$Probe,[ValidateRange(2,45)][int]$ProbeSeconds=5,[switch]$QueryMetrics)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$sourceSha=(& git -C $projectRoot rev-parse HEAD).Trim()
$folder=Join-Path $projectRoot ('logs/wt003-benchmark/'+$sourceSha+'/'+$Map+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$arguments='--path "'+$projectRoot+'" --borderless --resolution 1920x1080 --position 0,0 --max-fps 60 -s res://tests/run_frame_profile.gd -- --report-dir "'+$folder+'" --map '+$Map+' --seed '+$Seed+' --vehicle us_m4a3_75w_vvss_1944'
$arguments+=' --benchmark-1080'
if ($QueryMetrics) { $arguments+=' --query-metrics' }
$arguments += if ($Probe) { ' --seconds '+$ProbeSeconds } else { ' --full --wall-seconds 900' }
$identity=[ordered]@{source_sha=$sourceSha;build='source-worktree';full_requested=(-not $Probe);map=$Map;seed=$Seed;command=($engine+' '+$arguments);engine_sha256=(Get-FileHash -LiteralPath $engine).Hash;profiler_sha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'run_frame_profile.gd')).Hash;cpu=(Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name);ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;capacity=@{'8'='running';'16'='not_run';'32'='not_run'}}
$identity | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $folder 'BENCHMARK_PROFILE.json') -Encoding utf8
$stdout=Join-Path $folder 'stdout.log'; $stderr=Join-Path $folder 'stderr.log'
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Write-Output ('BENCHMARK_PROCESS='+$process.Id+' EVIDENCE='+$folder)
$memory=@()
$processRoles=@{}
while (-not $process.WaitForExit(5000)) {
    # Console engine launches a GUI child; sample that process's actual private memory.
    $children=@(Get-CimInstance Win32_Process -Filter ('ParentProcessId = '+$process.Id))
    foreach ($child in $children) {
        $processRoles[[string]$child.ProcessId]=$child.Name
        if ($child.Name -notlike 'Godot*') { continue }
        $runtime=Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
        if ($null -ne $runtime) { $memory += [ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$runtime.Id;private_bytes=$runtime.PrivateMemorySize64;working_set_bytes=$runtime.WorkingSet64} }
    }
    $processRoles | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'PROCESS_ROLES.json') -Encoding utf8
    $memory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'PROCESS_MEMORY.json') -Encoding utf8
}
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
$out=Read-SuiteLog $stdout; $err=Read-SuiteLog $stderr
$passed=$process.ExitCode -eq 0 -and -not $out.Error -and -not $err.Error -and ($out.Text+$err.Text) -notmatch 'SCRIPT ERROR:|Parse Error:|(?m)^ERROR:|\[FAIL\]' -and $out.Text -match 'FRAME_PROFILE_CHECKS_PASS'
if ($passed) {
    $reportPath=Join-Path $folder ('FRAME_PROFILE_'+$Map+'_'+$Seed+'.json')
    $passed=Test-Path -LiteralPath $reportPath
    if ($passed) {
        $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $passed=$report.resolution[0] -eq 1920 -and $report.resolution[1] -eq 1080 -and $report.selected_vehicle -eq 'us_m4a3_75w_vvss_1944' -and $report.renderer -eq 'gl_compatibility' -and ($Probe -or $report.match_finished)
        $passed=$passed -and $report.query_metrics.enabled -eq [bool]$QueryMetrics
        if ($QueryMetrics) { $passed=$passed -and $report.query_metrics.calls -gt 0 -and $report.query_metrics.cpu_ms -gt 0 }
    }
}
$identity.capacity['8']=if ($passed -and -not $Probe) {'complete_match_measured'} elseif ($passed) {'probe_only'} else {'incomplete_or_invalid'}
$identity | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $folder 'BENCHMARK_PROFILE.json') -Encoding utf8
@{exit_code=$process.ExitCode;passed=$passed;full_requested=(-not $Probe);source_sha=$sourceSha} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'RESULTS.json') -Encoding utf8
Write-Output ('BENCHMARK_COMPLETE='+$passed+' EVIDENCE='+$folder)
if (-not $passed) { exit 1 }
