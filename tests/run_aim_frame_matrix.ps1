param([string]$Order='WT007-optics',[int]$TimeoutSeconds=90)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$folder=Join-Path $projectRoot ("logs/$Order/aim-matrix-"+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $folder -Force | Out-Null
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
$results=@()
$baseline=$null
foreach($case in @(@{Name='30';Cap=30;Stall=$false},@{Name='60';Cap=60;Stall=$false},@{Name='144';Cap=144;Stall=$false},@{Name='60-stall';Cap=60;Stall=$true})) {
    $reportPath=Join-Path $folder ($case.Name+'.json')
    $stdout=Join-Path $folder ($case.Name+'.stdout.log')
    $stderr=Join-Path $folder ($case.Name+'.stderr.log')
    $arguments='--path "'+$projectRoot+'" --max-fps '+$case.Cap+' -s res://tests/run_turret_tick_checks.gd -- "'+$reportPath+'" --local-intent'
    if($case.Stall){$arguments+=' --stall'}
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
    if($timedOut){Stop-Process -Id $process.Id -Force}
    $process.WaitForExit()
    $out=Read-SuiteLog $stdout; $err=Read-SuiteLog $stderr
    $report=if(Test-Path -LiteralPath $reportPath){Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json}else{$null}
    $valid=-not $timedOut -and $process.ExitCode -eq 0 -and $null -ne $report -and $report.rows.Count -eq 360 -and $report.shots -eq 2 -and $report.render_does_not_turn -and -not $out.Error -and -not $err.Error -and ($out.Text+$err.Text) -notmatch 'SCRIPT ERROR:|(?m)^ERROR:' -and $out.Text -match 'TURRET_TICK_CHECKS_PASS'
    $maximumError=0.0
    $sameEvents=$false
    if($valid){
        if($null -eq $baseline){$baseline=$report}
        for($row=0;$row -lt 360;$row++){
            for($field=0;$field -lt 4;$field++){
                $maximumError=[Math]::Max($maximumError,[Math]::Abs([double]$report.rows[$row][$field]-[double]$baseline.rows[$row][$field]))
            }
        }
        $sameEvents=($report.hits | ConvertTo-Json -Depth 5 -Compress) -ceq ($baseline.hits | ConvertTo-Json -Depth 5 -Compress)
    }
    $passed=$valid -and $sameEvents -and $maximumError -le 0.000001
    $results+=[pscustomobject]@{name=$case.Name;command=$engine+' '+$arguments;exit_code=$process.ExitCode;timed_out=$timedOut;passed=$passed;max_state_error=$maximumError;same_events=$sameEvents}
    Write-Output ($case.Name+': passed='+$passed+' max_state_error='+$maximumError)
}
$hashes=@{}
foreach($file in @('scripts/camera_rig.gd','scripts/turret_rig.gd','scripts/vehicle_actor.gd','tests/run_turret_tick_checks.gd')){$hashes[$file]=(Get-FileHash (Join-Path $projectRoot $file)).Hash}
@{source=(& git -C $projectRoot rev-parse HEAD).Trim();build='source-worktree';engine=(& $engine --version).Trim();hashes=$hashes;cases=$results;human='NOT_RUN'} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $folder 'RESULTS.json')
Write-Output ('EVIDENCE='+$folder)
if(@($results | Where-Object {-not $_.passed}).Count -gt 0){exit 1}
exit 0
