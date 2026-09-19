# WT-EXPANSION-02 diagnostic runner: the SAME in-game verifier the package runs, but launched from the SOURCE TREE so a
# failing check can be diagnosed without rebuilding the 77-minute package. It mirrors run_modern_player_flow.ps1's
# environment handling exactly - a separate APPDATA so the player's own profile and saves are never touched - and it
# changes nothing about the game's normal paths.
param(
    [string]$Tree = 'E:\AIprogram\mcthunder-cont',
    [string]$Engine = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe',
    [int]$Limit = 900
)
$ErrorActionPreference='Stop'
$stamp=Get-Date -Format yyyyMMdd-HHmmss-fff
$run=Join-Path $Tree "logs/COMBAT-DEEPEN-01/modern-srcflow/$stamp"
$userData=Join-Path $Tree "logs/COMBAT-DEEPEN-01/modern-srcflow-runtime/$stamp"
New-Item -ItemType Directory -Force -Path "$run/workdir",$userData | Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new()
$psi.FileName=$Engine
$psi.Arguments='--path "'+$Tree+'" --resolution 1280x720 -- --verify-modern-match'
$psi.WorkingDirectory="$run/workdir"
$psi.EnvironmentVariables['APPDATA']=$userData
$psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
$psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
$child=[Diagnostics.Process]::new(); $child.StartInfo=$psi
[void]$child.Start()
$stdout=$child.StandardOutput.ReadToEndAsync(); $stderr=$child.StandardError.ReadToEndAsync()
$clock=[Diagnostics.Stopwatch]::StartNew(); $timedOut=$false
while(-not $child.WaitForExit(30000)){
    Write-Output ("modern_srcflow_wall_seconds="+[int]$clock.Elapsed.TotalSeconds)
    if($clock.Elapsed.TotalSeconds -gt $Limit){$timedOut=$true; $child.Kill(); break}
}
$child.WaitForExit()
$out=$stdout.GetAwaiter().GetResult(); $err=$stderr.GetAwaiter().GetResult()
[IO.File]::WriteAllText("$run/match.stdout.log",$out)
[IO.File]::WriteAllText("$run/match.stderr.log",$err)
Write-Output ("exit="+$child.ExitCode+" timed_out="+$timedOut+" evidence="+$run)
