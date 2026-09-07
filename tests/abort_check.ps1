# 003-R2: startup-failure controlled-abort acceptance (isolated-copy mode).
# Usage (repo root): powershell -ExecutionPolicy Bypass -File tests\abort_check.ps1
#
# Flow (original tree is READ-ONLY; never in-place edit / auto-restore):
#   1. Require the candidate commit (clean worktree), take HEAD as tested SHA
#   2. git archive that commit into a single temp dir OUTSIDE the project
#   3. In the copy: --import + --quit-after 10 must boot normally
#   4. Mutate ONLY the copy's configs (verified without source -> validate rejects)
#   5. Launch real main scene via subprocess --path <copy> (timeout, full stdout/stderr, exit code)
#   6. PASS = nonzero exit + "003-R2 ABORT" in output + no unexpected SCRIPT ERROR;
#      timeout / missing engine / unexpected script error are all FAIL
#   7. Original tree read-only check (git status before/after); user:// legacy backup is reported only
# Note: cmdlets and instance methods only, no .NET static calls (constrained-mode safe);
#       config content is pure ASCII; this file is ASCII-only (PowerShell 5.1 ANSI decoding safe).

$ErrorActionPreference = 'Stop'
$testsDir = $PSScriptRoot
$root = Split-Path $testsDir
$godot = Join-Path $root 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$fail = @()

function Note($m) { Write-Host "[abort-check] $m" }
Note "runner-version=RUNNER_D_ascii_20260907"

# 0) engine must exist (missing = FAIL, not skip)
if (-not (Test-Path $godot)) { Note "FAIL: godot exe not found at $godot"; exit 1 }

# 1) candidate must be committed (clean worktree, logs/ exempted as run artifacts)
$stBefore = @(git -C $root status --porcelain | Where-Object { $_ -notlike '*logs/*' })
if ($stBefore.Count -gt 0) { Note "FAIL: worktree not clean (non-log changes); commit the candidate first:"; $stBefore | ForEach-Object { Note "  $_" }; exit 1 }
$sha = (git -C $root rev-parse HEAD).Trim()
Note "testing committed candidate $sha"

# 2) legacy user:// backup from the old in-place test: report only, never auto-restore
$projName = (Select-String -Path (Join-Path $root 'project.godot') -Pattern 'config/name="(.+)"').Matches[0].Groups[1].Value
$legacyBak = Join-Path $env:APPDATA "Godot\app_userdata\$projName\abort_check_backup.tres"
if (Test-Path $legacyBak) { Note "NOTICE: legacy user:// backup found, reported only, NOT auto-restored: $legacyBak" }

# 3) export committed candidate to a temp dir outside the project
Note "TEMP=[$env:TEMP]"
$tmp = "$env:TEMP\mcthunder-abort-" + (Get-Random -Maximum 999999999)
Note "tmp=[$tmp]"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'source.zip'
git -C $root archive --format=zip --output=$zip $sha
if ($LASTEXITCODE -ne 0) { Note "FAIL: git archive failed"; exit 1 }
Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'project') -Force
$proj = Join-Path $tmp 'project'
Note "exported to $proj"

# 4) clean copy must boot normally
& $godot --headless --path $proj --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: import failed on clean copy"; exit 1 }
& $godot --headless --path $proj --quit-after 10 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: clean copy did not boot normally"; exit 1 }
Note "clean copy boots normally (--quit-after 10 exit=0)"

# 5) mutate ONLY the copy config: verified without source -> validate must reject
$cfg = "$proj" + "\configs\player_tank_vehicle.tres"
if ([string]::IsNullOrEmpty($cfg)) { Note "FAIL: cfg path is null (proj=[$proj])"; exit 1 }
if (-not (Test-Path -LiteralPath $cfg)) { Note "FAIL: cfg missing in copy (cfg=[$cfg])"; exit 1 }
Note "cfg=[$cfg]"
$orig = Get-Content -LiteralPath $cfg -Raw
if (-not $orig.Contains('verification = "unknown"')) { Note "FAIL: marker not found in copy config"; exit 1 }
$bad = $orig.Replace('verification = "unknown"', 'verification = "verified"')
Set-Content -LiteralPath $cfg -Value $bad -Encoding ascii -NoNewline
Note "bad config injected into COPY only"

# 6) subprocess: real main scene with the copy as --path (timeout + full output + reliable exit code)
$codeFile = Join-Path $tmp 'exitcode.txt'
$job = Start-Job -ScriptBlock {
	param($g, $prj, $so, $se, $codeFile)
	& $g --headless --path $prj 1> $so 2> $se
	$LASTEXITCODE | Set-Content -LiteralPath $codeFile -Encoding ascii
} -ArgumentList $godot, $proj, $so, $se, $codeFile
if (Wait-Job $job -Timeout 60) { Remove-Job $job -Force } else { Stop-Job $job; Remove-Job $job -Force; Note "FAIL: subprocess TIMEOUT (not a pass)"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
if (-not (Test-Path -LiteralPath $codeFile)) { Note "FAIL: exit code file missing (cannot verify nonzero)"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
$code = (Get-Content -LiteralPath $codeFile -Raw).Trim()
if ([string]::IsNullOrEmpty($code)) { Note "FAIL: exit code unavailable (cannot verify nonzero)"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
$full = ''
if (Test-Path $so) { $full += Get-Content $so -Raw }
if (Test-Path $se) { $full += Get-Content $se -Raw }
$aborted = $full.Contains('003-R2 ABORT')
$scriptErr = $full.Contains('SCRIPT ERROR')
Note "subprocess exit=$code abort_log=$aborted unexpected_script_error=$scriptErr"

# 7) original tree read-only check (before/after identical; report changes, never auto-restore)
$stAfter = @(git -C $root status --porcelain | Where-Object { $_ -notlike '*logs/*' })
if ($stAfter.Count -gt 0) { Note "FAIL: original worktree changed during test (report only, NOT auto-restored):"; $stAfter | ForEach-Object { Note "  $_" }; $fail += 'original tree changed' }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# verdict
if (($code -ne 0) -and $aborted -and (-not $scriptErr) -and ($fail.Count -eq 0)) {
	Note "PASS: copy-only bad config -> real main scene aborts with nonzero exit; original tree untouched"
	exit 0
} else {
	Note "FAIL"
	exit 1
}