# CD16 attribution, second target: the R3-A near-target B1 stabiliser-convergence check in tests/run_checks.gd.
# Written to the same rules the village instrument learned the hard way:
#   * the import cache is deleted per step so each commit is imported from its own sources;
#   * the engine runs through a real process handle with redirected streams, so a missing exit status is never
#     mistaken for zero and a NATIVE warning can never become a terminating error;
#   * the script contains ZERO non-ASCII bytes, because a Chinese literal in a BOM-less .ps1 is read as ANSI and
#     broke an earlier revision with a parse error that looked exactly like a verdict;
#   * the verdict is read from the ASCII part of the check label ONLY (the R3-A line names B1), so the Chinese
#     text that follows it is never matched;
#   * every path that cannot produce a real verdict exits 125 so git SKIPS the commit instead of guessing.
# run_checks carries its own 90 second watchdog in every build, including the one judged PASS, so this test does
# NOT judge the suite exit status: it judges whether the R3-A B1 convergence line PASSED or FAILED.
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$Engine,
    [Parameter(Mandatory = $true)][string]$LogDir
)
$ErrorActionPreference = 'Continue'
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$stamp = Get-Date -Format 'HHmmss'
$head = (& git -C $Worktree rev-parse --short HEAD).Trim()
Write-Output ("BISECT_R3A commit=" + $head + " at " + (Get-Date -Format 'HH:mm:ss'))

function Invoke-Native([string]$Exe, [string]$Arguments, [string]$WorkingDirectory, [string]$StdoutPath, [int]$TimeoutSeconds) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
    $timedOut = -not $exited
    if ($timedOut) { try { $proc.Kill() } catch { }; [void]$proc.WaitForExit(15000) }
    $outText = $outTask.GetAwaiter().GetResult()
    $errText = $errTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText($StdoutPath, $outText)
    [IO.File]::WriteAllText($StdoutPath + '.err', $errText)
    $code = $null
    if (-not $timedOut) { try { $code = $proc.ExitCode } catch { $code = $null } }
    $proc.Dispose()
    return @{ exit_code = $code; timed_out = $timedOut; output = $outText + $errText }
}

try {
    $cache = Join-Path $Worktree '.godot'
    if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
} catch {
    Write-Output ("BISECT_R3A cache removal failed at " + $head + " -> skip")
    exit 125
}
$import = Invoke-Native $Engine ('--headless --path "' + $Worktree + '" --editor --import') $Worktree (Join-Path $LogDir ("import-$stamp.log")) 900
if ($null -eq $import.exit_code -or $import.timed_out -or $import.exit_code -ne 0) {
    Write-Output ("BISECT_R3A import unusable at " + $head + " -> skip")
    exit 125
}
# No --fixed-fps: this suite runs with the default clock exactly as every clean build runs it.
$run = Invoke-Native $Engine ('--headless --path "' + $Worktree + '" -s res://tests/run_checks.gd') $Worktree (Join-Path $LogDir ("runchecks-$stamp.log")) 600
$text = $run.output
$lines = $text -split "`r?`n"
$r3aPass = 0
$r3aFail = 0
$failLine = ''
foreach ($l in $lines) {
    if ($l -notmatch 'R3-A') { continue }
    if ($l -notmatch 'B1') { continue }
    if ($l -match '\[FAIL\]') { $r3aFail += 1; if ($failLine -eq '') { $failLine = $l } }
    elseif ($l -match '\[PASS\]') { $r3aPass += 1 }
}
Write-Output ("BISECT_R3A commit=" + $head + " exit=" + $run.exit_code + " r3a_pass=" + $r3aPass + " r3a_fail=" + $r3aFail + " line=" + $failLine)
if ($null -eq $run.exit_code -or $run.timed_out) {
    Write-Output ("BISECT_R3A the run did not finish at " + $head + " -> skip")
    exit 125
}
if ($r3aPass -eq 0 -and $r3aFail -eq 0) {
    Write-Output ("BISECT_R3A the suite never reached the R3-A block at " + $head + " -> skip")
    exit 125
}
if ($r3aFail -gt 0) { exit 1 }
exit 0
