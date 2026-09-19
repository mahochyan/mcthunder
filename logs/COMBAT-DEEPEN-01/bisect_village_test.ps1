# CD16 attribution: the bisect TEST. Given a worktree checked out at some commit, import it and run the village
# battle suite, then report whether the arrival check passed. `git bisect run` reads the exit code:
#   0   = the suite passed at this commit (good)
#   1   = the suite ran and the arrival check FAILED (bad)
#   125 = this commit cannot be tested (import failed, suite did not run) and git should skip it
# The suite is deterministic here: both AI clocks accumulate the physics delta and the run uses --fixed-fps 60,
# so one simulated second is sixty physics steps regardless of machine speed.
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$Engine,
    [Parameter(Mandatory = $true)][string]$LogDir
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$stamp = Get-Date -Format 'HHmmss'
$import = Join-Path $LogDir ("import-$stamp.log")
$village = Join-Path $LogDir ("village-$stamp.log")
$head = (& git -C $Worktree rev-parse --short HEAD).Trim()
Write-Output ("BISECT_STEP commit=" + $head + " at " + (Get-Date -Format 'HH:mm:ss'))
& $Engine --headless --path $Worktree --editor --import *> $import
$importExit = $LASTEXITCODE
if ($importExit -ne 0) {
    Write-Output ("BISECT_STEP import failed exit=" + $importExit + " -> skip")
    exit 125
}
& $Engine --headless --path $Worktree --fixed-fps 60 -s res://tests/run_village_battle_checks.gd *> $village
$exit = $LASTEXITCODE
$text = Get-Content -LiteralPath $village -Raw
$pass = $text -match 'VILLAGE_BATTLE_CHECKS_PASS'
$fail = $text -match 'VILLAGE_BATTLE_CHECKS_FAIL'
$failLine = ''
$m = [regex]::Match($text, '\[FAIL\][^\r\n]*')
if ($m.Success) { $failLine = $m.Value }
Write-Output ("BISECT_STEP commit=" + $head + " exit=" + $exit + " pass=" + $pass + " fail=" + $fail + " line=" + $failLine)
if ($pass) { exit 0 }
if ($fail) { exit 1 }
Write-Output ("BISECT_STEP no verdict at " + $head + " -> skip")
exit 125
