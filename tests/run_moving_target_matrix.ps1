$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$runPath=Join-Path $projectRoot ('logs/wt002-moving/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$results=@()
$reference=$null
foreach ($case in @(@{Name='30';Cap=30;Stall=$false},@{Name='60';Cap=60;Stall=$false},@{Name='144';Cap=144;Stall=$false},@{Name='60-stall';Cap=60;Stall=$true})) {
    $dataPath=Join-Path $runPath ($case.Name+'.json')
    $stdout=Join-Path $runPath ($case.Name+'.stdout.log')
    $stderr=Join-Path $runPath ($case.Name+'.stderr.log')
    $arguments='--path "'+$projectRoot+'" --resolution 1280x720 --max-fps '+$case.Cap+' -s res://tests/run_moving_target_tick_checks.gd -- "'+$dataPath+'"'
    if ($case.Stall) { $arguments+=' --stall' }
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $process.WaitForExit()
    $output=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
    $valid=$process.ExitCode -eq 0 -and $output -notmatch 'SCRIPT ERROR:|Parse Error:|(?m)^ERROR:' -and (Test-Path -LiteralPath $dataPath)
    $same=$false
    if ($valid) {
        $data=Get-Content -LiteralPath $dataPath -Raw | ConvertFrom-Json
        $valid=$data.ok -and $data.display -eq 'Windows' -and $data.render_cap -eq $case.Cap -and $data.physics_hz -eq 60
        $sample=[ordered]@{rows=$data.rows;contacts=$data.contacts;terminals=$data.terminals}|ConvertTo-Json -Depth 12 -Compress
        if ($null -eq $reference) { $reference=$sample }
        $same=$sample -ceq $reference
    }
    $results += [pscustomobject]@{case=$case.Name;exit_code=$process.ExitCode;valid=$valid;exact_match=$same;passed=($valid -and $same);command=($engine+' '+$arguments)}
    Write-Output ($case.Name+': valid='+$valid+' exact_match='+$same)
}
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runPath 'RESULTS.json') -Encoding utf8
Write-Output ('EVIDENCE='+$runPath)
if ($results.passed -contains $false) { exit 1 }
