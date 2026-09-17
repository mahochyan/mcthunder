param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$SourceSha
)
$ErrorActionPreference='Stop'
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$package=Split-Path -Parent $Executable
$manifest=Get-Content -LiteralPath (Join-Path $package 'BUILD_MANIFEST.json') -Raw | ConvertFrom-Json
if($SourceSha -notmatch '^[0-9a-f]{40}$' -or $manifest.source_sha -ne $SourceSha -or -not $manifest.modern_river_required){throw 'Actual modern package identity is required'}
$pck=[IO.Path]::ChangeExtension($Executable,'.pck')
$before=@(Get-FileHash -LiteralPath $Executable,$pck)
foreach($actual in $before){
    $entry=@($manifest.files | Where-Object {$_.name -eq (Split-Path -Leaf $actual.Path)})
    if($entry.Count -ne 1 -or $entry[0].sha256 -ne $actual.Hash){throw 'Actual package hash differs from manifest'}
}
$root=Split-Path -Parent $PSScriptRoot
$stamp=Get-Date -Format yyyyMMdd-HHmmss-fff
$run=Join-Path $root "logs/WT040-modern-player/$SourceSha/$stamp"
# Keep versioned evidence separate from engine user data. An existing GLES3
# cache below the long SHA/timestamp path fails directory reopening on Windows;
# copying those same bytes to a short path reproduced a clean restart. Do not
# disable caches, suppress renderer errors, or change the game's normal paths.
$userData=Join-Path $root "logs/WT040-runtime/$stamp"
if((Join-Path $userData ('Godot/app_userdata/PixelArmor/shader_cache/CanvasOcclusionShaderGLES3/'+('0'*64))).Length -gt 240){throw 'Diagnostic user-data path is too long for the fixed Windows renderer; use a shorter workspace path'}
New-Item -ItemType Directory -Force -Path "$run/workdir",$userData | Out-Null
function Run-Phase([string]$Name,[string]$Extra,[int]$Limit){
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$Executable
    $psi.Arguments='--resolution 1280x720 -- --verify-modern-match '+$Extra
    $psi.WorkingDirectory="$run/workdir"
    $psi.EnvironmentVariables['APPDATA']=$userData
    $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $child=[Diagnostics.Process]::new(); $child.StartInfo=$psi
    [void]$child.Start()
    $stdout=$child.StandardOutput.ReadToEndAsync(); $stderr=$child.StandardError.ReadToEndAsync()
    $clock=[Diagnostics.Stopwatch]::StartNew(); $timedOut=$false
    while(-not $child.WaitForExit(30000)){
        Write-Host ("modern_${Name}_wall_seconds="+[int]$clock.Elapsed.TotalSeconds)
        if($clock.Elapsed.TotalSeconds -gt $Limit){$timedOut=$true; $child.Kill(); break}
    }
    $child.WaitForExit()
    $out=$stdout.GetAwaiter().GetResult(); $err=$stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText("$run/$Name.stdout.log",$out)
    [IO.File]::WriteAllText("$run/$Name.stderr.log",$err)
    return [ordered]@{name=$Name;command=$psi.Arguments;exit_code=$child.ExitCode;timed_out=$timedOut;passed=(-not $timedOut -and $child.ExitCode -eq 0 -and $out -match 'MODERN_MATCH_PASS' -and $out -match 'MODERN_MATCH_RUNTIME release=true' -and ($out+$err) -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]')}
}
$match=Run-Phase 'match' '' 1800
$restore=$null; $unchangedSave=$false
$saveDir="$userData/Godot/app_userdata/PixelArmor/tests/modern_match_current"
if($match.passed){
    $saves=@(Get-ChildItem -LiteralPath $saveDir -Filter 'commander.*.json' | Sort-Object Name | Get-FileHash)
    if($saves.Count -eq 0){throw 'Successful flow did not produce a disk profile'}
    $restore=Run-Phase 'restart' '--resume-proof' 90
    $afterSaves=@(Get-ChildItem -LiteralPath $saveDir -Filter 'commander.*.json' | Sort-Object Name | Get-FileHash)
    $unchangedSave=($saves.Hash -join ',') -eq ($afterSaves.Hash -join ',')
}
$shots="$userData/Godot/app_userdata/PixelArmor/tests/modern_match_shots"
$required=@('00_prepared.png','01_deployed.png','04_result.png','05_next_match.png','06_fresh_process.png','events.json')
$missing=@($required | Where-Object {-not (Test-Path -LiteralPath (Join-Path $shots $_))})
$after=@(Get-FileHash -LiteralPath $Executable,$pck)
$unchanged=($before.Hash -join ',') -eq ($after.Hash -join ',')
$passed=$match.passed -and $null -ne $restore -and $restore.passed -and $unchangedSave -and $unchanged -and $missing.Count -eq 0
$result=[ordered]@{source_sha=$SourceSha;scope='normal keyboard/mouse modern river player flow and separate fresh-process save reload';userdata=$userData;shots=$shots;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;match=$match;restart=$restore;passed=$passed;package_unchanged=$unchanged;save_unchanged_by_restart=$unchangedSave;exe_sha256=$before[0].Hash;pck_sha256=$before[1].Hash;missing=$missing;human='PENDING';release_ready=$false;public_release=$false}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$run/RESULTS.json" -Encoding utf8
Write-Output "EVIDENCE=$run"
if(-not $passed){exit 1}
exit 0
