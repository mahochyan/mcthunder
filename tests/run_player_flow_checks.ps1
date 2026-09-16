param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$SourceSha,
    [int]$Width=1280,
    [int]$Height=720
)
$ErrorActionPreference='Stop'
if ($SourceSha -notmatch '^[0-9a-f]{40}$' -or $Width -lt 640 -or $Width -gt 3840 -or $Height -lt 480 -or $Height -gt 2160) { throw 'Invalid source identity or window size' }
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$manifestPath=Join-Path (Split-Path -Parent $Executable) 'BUILD_MANIFEST.json'
if (Test-Path -LiteralPath $manifestPath) {
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.source_sha -ne $SourceSha) { throw 'Requested source differs from actual package manifest' }
}
$projectRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $projectRoot ('logs/034/'+$SourceSha+'/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$stdout=Join-Path $out 'stdout.log'; $stderr=Join-Path $out 'stderr.log'
$arguments="--resolution ${Width}x${Height} -- --verify-player-flow"
# WT-040-R1: this script had the same Start-Process -PassThru defect that build_release.ps1 already fixed and
# documented on 2026-09-16 - a null ExitCode for a child that had finished successfully - which made it report a
# failure for a genuine pass: with all checks green, stderr empty and PLAYER_FLOW_CHECKS_PASS printed, the recorded
# exit code was still $null and the run was judged failed. A real Process handle with redirected streams, read
# asynchronously BEFORE waiting (so neither pipe can fill and deadlock), gives a genuine exit status; a null status
# stays a failure and is named rather than silently passing. The wall-clock ticker and the 2200 s cap are kept.
$psi=[System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName=$Executable
$psi.Arguments=$arguments
$psi.WorkingDirectory=(Split-Path -Parent $Executable)
$psi.UseShellExecute=$false
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$psi.CreateNoWindow=$true
$running=[System.Diagnostics.Process]::new()
$running.StartInfo=$psi
[void]$running.Start()
$outTask=$running.StandardOutput.ReadToEndAsync()
$errTask=$running.StandardError.ReadToEndAsync()
$watch=[Diagnostics.Stopwatch]::StartNew(); $timedOut=$false
while (-not $running.WaitForExit(30000)) {
    Write-Output ('player_flow_wall_seconds='+[int]$watch.Elapsed.TotalSeconds)
    if ($watch.Elapsed.TotalSeconds -gt 2200) { $timedOut=$true; try { $running.Kill() } catch {}; [void]$running.WaitForExit(15000); break }
}
$outText=$outTask.GetAwaiter().GetResult()
$errText=$errTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText($stdout,$outText)
[IO.File]::WriteAllText($stderr,$errText)
$output=$outText+$errText
$match=[regex]::Match($output,'(?m)^PLAYER_FLOW_EVIDENCE=(.+)$')
$pictures=@()
if ($match.Success) {
    $directory=$match.Groups[1].Value.Trim()
    $pictures=@(Get-ChildItem -LiteralPath $directory -Filter '*.png')
    New-Item -ItemType Directory -Force (Join-Path $out 'screenshots') | Out-Null
    $pictures | Copy-Item -Destination (Join-Path $out 'screenshots')
}
$required=@('00_garage_main_menu.png','05_real_shot_replay.png','09_battle_0.png','09_battle_1.png','10_settled_0.png','10_settled_1.png')
$missing=@($required | Where-Object { $_ -notin $pictures.Name })
$count=[regex]::Match($output,'=== .*: (\d+) .* (\d+) .* ===')
# WT-040-R1: read the exit code only after the process has actually exited. Start-Process -PassThru can hand back
# an object whose ExitCode is still $null, and `$null -eq 0` is false, so a genuine pass was reported as a failure
# even though all 96 checks passed, stderr was empty and PLAYER_FLOW_CHECKS_PASS was printed. An unknown exit code
# is now named instead of silently becoming a failure.
if (-not $running.HasExited) { $running.WaitForExit(60000) | Out-Null }
$exitCode=$running.ExitCode
$exitKnown=$null -ne $exitCode
if (-not $exitKnown) { Write-Output 'player_flow_exit_code=UNKNOWN' }
$passed=-not $timedOut -and $exitKnown -and $exitCode -eq 0 -and $output -match 'PLAYER_FLOW_CHECKS_PASS' -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]' -and $missing.Count -eq 0
$result=[ordered]@{source_sha=$SourceSha;exe_sha256=(Get-FileHash -LiteralPath $Executable).Hash;pck_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($Executable,'.pck'))).Hash;command='"'+$Executable+'" '+$arguments;exit_code=$running.ExitCode;timed_out=$timedOut;passed=$passed;checks=if($count.Success){[int]$count.Groups[1].Value}else{0};missing_screenshots=$missing;images=@($pictures | ForEach-Object {@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}});human='PENDING'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'RESULTS.json') -Encoding utf8
Write-Output "EVIDENCE=$out"
if (-not $passed) { exit 1 }
exit 0
