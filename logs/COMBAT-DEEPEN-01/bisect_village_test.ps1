# CD16 attribution: the bisect TEST, second revision. The first revision produced a VACUOUS verdict and this
# header records exactly why, because the same trap would otherwise be repeated:
#   1. it reused whatever import cache the worktree happened to hold, so the suite produced a one-line log that
#      contained no verdict at all - and a run that produces no verdict must never be read as one;
#   2. it ran under $ErrorActionPreference='Stop' with Godot's stderr redirected through the pipeline, which made
#      PowerShell turn a native warning into a TERMINATING error; the script therefore died BEFORE printing its
#      verdict and exited 1, and `git bisect` read exit 1 as "this commit is bad" for EVERY step. The bisect
#      consequently named a DOCUMENTATION-ONLY commit as the first bad one - a verdict that cannot be true.
# This revision uses a real process handle with redirected streams (the same idiom the release build uses, so a
# missing exit status is never mistaken for zero), deletes the import cache so each commit is imported from its
# own sources, and refuses to return a verdict unless the natural battle actually ran. Every other path exits 125
# so git bisect skips the commit instead of guessing.
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$Engine,
    [Parameter(Mandatory = $true)][string]$LogDir
)
$ErrorActionPreference = 'Continue'
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$stamp = Get-Date -Format 'HHmmss'
$head = (& git -C $Worktree rev-parse --short HEAD).Trim()
Write-Output ("BISECT_STEP commit=" + $head + " at " + (Get-Date -Format 'HH:mm:ss'))

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

# --- import this commit from its own sources ---
try {
    $cache = Join-Path $Worktree '.godot'
    if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
} catch {
    Write-Output ("BISECT_STEP cache removal failed at " + $head + " -> skip")
    exit 125
}
$import = Invoke-Native $Engine ('--headless --path "' + $Worktree + '" --editor --import') $Worktree (Join-Path $LogDir ("import-$stamp.log")) 900
if ($null -eq $import.exit_code -or $import.timed_out -or $import.exit_code -ne 0) {
    Write-Output ("BISECT_STEP import unusable at " + $head + " exit=" + $import.exit_code + " timeout=" + $import.timed_out + " -> skip")
    exit 125
}

# --- run the village suite ---
$villagePath = Join-Path $LogDir ("village-$stamp.log")
$run = Invoke-Native $Engine ('--headless --path "' + $Worktree + '" --fixed-fps 60 -s res://tests/run_village_battle_checks.gd') $Worktree $villagePath 1200
$text = $run.output
$pass = $text -match 'VILLAGE_BATTLE_CHECKS_PASS'
$fail = $text -match 'VILLAGE_BATTLE_CHECKS_FAIL'
$traced = $text -match '\[natural battle '
# The check count is read from the ASCII PASS and FAIL markers rather than from the suite's Chinese result line.
# A Chinese literal in a BOM-less .ps1 is read as ANSI by Windows PowerShell and mangles the file - which is
# recorded in tests/package_doc_names.json and which broke THIS script's first revision with a parse error, so the
# script now contains no non-ASCII character at all.
$checks = ([regex]::Matches($text, '\[PASS\]')).Count + ([regex]::Matches($text, '\[FAIL\]')).Count
$failLine = ''
$m = [regex]::Match($text, '\[FAIL\][^\r\n]*')
if ($m.Success) { $failLine = $m.Value }
Write-Output ("BISECT_STEP commit=" + $head + " exit=" + $run.exit_code + " checks=" + $checks + " traced=" + $traced + " pass=" + $pass + " fail=" + $fail + " line=" + $failLine)

# --- a verdict is only a verdict if the battle really ran ---
if ($null -eq $run.exit_code -or $run.timed_out) {
    Write-Output ("BISECT_STEP the run did not finish cleanly at " + $head + " -> skip")
    exit 125
}
if (-not $traced -or $checks -lt 21) {
    Write-Output ("BISECT_STEP the battle did not actually run at " + $head + " -> skip rather than guess")
    exit 125
}
if ($pass) { exit 0 }
if ($fail) { exit 1 }
Write-Output ("BISECT_STEP no verdict at " + $head + " -> skip")
exit 125
