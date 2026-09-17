param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$SourceSha,
    [ValidateSet('garage','life')][string]$Case='garage'
)
$ErrorActionPreference='Stop'
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$package=Split-Path -Parent $Executable
$manifestPath=Join-Path $package 'BUILD_MANIFEST.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if($SourceSha -notmatch '^[0-9a-f]{40}$' -or $manifest.source_sha -ne $SourceSha -or -not $manifest.modern_river_required){throw 'The actual package must match the specified modern candidate identity'}
$projectRoot=Split-Path -Parent $PSScriptRoot
$stamp=Get-Date -Format yyyyMMdd-HHmmss-fff
$run=Join-Path $projectRoot "logs/WT040-package/$SourceSha/$Case-$stamp"
# Separate the versioned evidence from Windows renderer/user-data paths, as in
# run_modern_player_flow.ps1. Do not recurse through shader caches for evidence.
$userData=Join-Path $projectRoot "logs/WT040-runtime/$stamp"
if((Join-Path $userData ('Godot/app_userdata/PixelArmor/shader_cache/CanvasOcclusionShaderGLES3/'+('0'*64))).Length -gt 240){throw 'Diagnostic user-data path is too long; use a shorter workspace path'}
New-Item -ItemType Directory -Path "$run/workdir",$userData,"$run/shots" -Force | Out-Null
$pck=[IO.Path]::ChangeExtension($Executable,'.pck')
$before=@(Get-FileHash -LiteralPath $Executable,$pck -Algorithm SHA256)
foreach($actual in $before){
    $name=Split-Path -Leaf $actual.Path
    $declared=@($manifest.files | Where-Object {$_.name -eq $name})
    if($declared.Count -ne 1 -or $declared[0].sha256 -ne $actual.Hash){throw "Package bytes differ from BUILD_MANIFEST: $name"}
}
$marker=if($Case -eq 'garage'){'MODERN_GARAGE_CHECKS_PASS'}else{'PLAYER_LIVE_ROUND_PASS'}
$psi=[Diagnostics.ProcessStartInfo]::new()
$psi.FileName=$Executable
$psi.Arguments='--resolution 1280x720 --fixed-fps 60 -- --verify-modern-'+$Case+' --shot-dir "'+$run+'/shots"'
$psi.WorkingDirectory="$run/workdir"
$psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
$psi.EnvironmentVariables['APPDATA']=$userData
$psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
$child=[Diagnostics.Process]::new(); $child.StartInfo=$psi
[void]$child.Start()
$outTask=$child.StandardOutput.ReadToEndAsync(); $errTask=$child.StandardError.ReadToEndAsync()
$clock=[Diagnostics.Stopwatch]::StartNew(); $timeout=$false
while(-not $child.WaitForExit(30000)){
    Write-Output ("modern_${Case}_wall_seconds="+[int]$clock.Elapsed.TotalSeconds)
    if($clock.Elapsed.TotalSeconds -gt 240){$timeout=$true; $child.Kill(); break}
}
$child.WaitForExit()
$stdout=$outTask.GetAwaiter().GetResult(); $stderr=$errTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText("$run/stdout.log",$stdout)
[IO.File]::WriteAllText("$run/stderr.log",$stderr)
$after=@(Get-FileHash -LiteralPath $Executable,$pck -Algorithm SHA256)
$unchanged=$before[0].Hash -eq $after[0].Hash -and $before[1].Hash -eq $after[1].Hash
$pictures=@(Get-ChildItem -LiteralPath "$run/shots" -Filter '*.png')
$eventFile=$null
if($Case -eq 'life'){
    $lifeEvidence=Join-Path $userData 'Godot/app_userdata/PixelArmor/tests/modern_live_round'
    if(Test-Path -LiteralPath $lifeEvidence){
        $eventFile=Get-ChildItem -LiteralPath $lifeEvidence -Filter 'evidence.json' -Recurse | Select-Object -First 1
    }
    if($eventFile){
        Copy-Item -LiteralPath $eventFile.FullName -Destination "$run/evidence.json"
        $pictures=@(Get-ChildItem -LiteralPath $eventFile.DirectoryName -Filter '*.png')
        foreach($picture in $pictures){Copy-Item -LiteralPath $picture.FullName -Destination "$run/shots"}
    }
}
$required=if($Case -eq 'garage'){@('ussr_t_80b_garage.png','ussr_t_80b_river.png','germ_leopard_2a4_garage.png','germ_leopard_2a4_river.png')}else{@('waiting.png','respawned.png')}
$missing=@($required | Where-Object {$_ -notin $pictures.Name})
$count=[regex]::Match($stdout,'=== .*: (\d+) .* (\d+) .* ===')
$passed=$child.ExitCode -eq 0 -and -not $timeout -and $unchanged -and $stdout.Contains($marker) -and $missing.Count -eq 0 -and ($Case -ne 'life' -or $null -ne $eventFile) -and ($stdout+"`n"+$stderr) -notmatch '(?m)SCRIPT ERROR|^ERROR:|^\[FAIL\]'
$result=[ordered]@{case=$Case;source_sha=$SourceSha;scope='packaged production diagnostic; separate component proof, not a complete natural player match';command='"'+$Executable+'" '+$psi.Arguments;working_directory=$psi.WorkingDirectory;exit_code=$child.ExitCode;timed_out=$timeout;passed=$passed;checks=if($count.Success){[int]$count.Groups[1].Value}else{0};exe_sha256=$before[0].Hash;pck_sha256=$before[1].Hash;manifest_sha256=(Get-FileHash -LiteralPath $manifestPath).Hash;package_unchanged=$unchanged;missing_screenshots=$missing;human='PENDING'}
$result.userdata=$userData
$result.runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$run/RESULTS.json" -Encoding utf8
Write-Output "EVIDENCE=$run"
$stdout -split "`n" | Select-Object -Last 8
if($stderr){Write-Output $stderr}
if(-not $passed){exit 1}
exit 0
