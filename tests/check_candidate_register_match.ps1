# WT-040-R1 Stage 4 negative proof: the candidate register match must refuse a NEW failure that merely fits
# the same total, and must refuse a registered failure travelling with an unhealthy run. Both counter-examples
# the ruling named are asserted here against the SAME function the build uses.
#
# NOTE FOR POWERSHELL 5.1: this file avoids the inline "a" if $x else "b" expression form, which Windows
# PowerShell does not parse at all - a mistake that made this test unrunnable on the first attempt.
. (Join-Path $PSScriptRoot 'candidate_register_match.ps1')

$checks = 0
$failed = 0
function Check([bool]$Value, [string]$Label) {
    $script:checks++
    if (-not $Value) { $script:failed++ }
    if ($Value) { Write-Output ("[PASS] " + $Label) } else { Write-Output ("[FAIL] " + $Label) }
}

$old  = '  [FAIL] at least three actual slots from each team physically reach central approaches'
$wave = '  [FAIL] real defense script pilot completes finite waves with opponent AI untouched'   # exact measured wording (singular 'pilot')

$entryBattle = [pscustomobject]@{ suite='run_industrial_battle_checks'; failures=1; reason='registered pre-existing failure'
    signatures=@([pscustomobject]@{match='at least three actual slots from each team physically reach central approaches';count=1}) }
$entryChallenge = [pscustomobject]@{ suite='run_challenge_checks'; failures=2; reason='registered pre-existing failure'
    signatures=@([pscustomobject]@{match='real defense script pilot completes finite waves with opponent AI untouched';count=2}) }

$healthy = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=0; timed_out=$false; exit_known=$true; passed=$false }

# --- positive: the actually registered sets are accepted --------------------------------------
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy
Check $v.ok "the registered single failure is accepted (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryChallenge -FailLines @($wave,$wave) -ResultRow $healthy
Check $v.ok "the registered pair of identical failures is accepted (reason: $($v.reason))"

# --- counter-example 1: one OLD plus one NEW failure, same total ------------------------------
$v = Test-CandidateFailureSet -Entry $entryChallenge -FailLines @($wave,'  [FAIL] something brand new and unregistered') -ResultRow $healthy
Check (-not $v.ok) "COUNTER-EXAMPLE 1 refused: an old failure plus a new one with the same total (reason: $($v.reason))"

# --- counter-example 2: a registered failure with an unhealthy run ----------------------------
# The real field is an ARRAY of lines; both shapes are asserted so the test cannot pass on a shape that never
# occurs. The numeric form is kept because an empty result may legitimately serialise as 0.
$sickRow = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=@('SCRIPT ERROR: sample diagnostic'); timed_out=$false; exit_known=$true; passed=$false }
$sickRowNumeric = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=3; timed_out=$false; exit_known=$true; passed=$false }
$cleanArray = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=@(); timed_out=$false; exit_known=$true; passed=$false }
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $sickRow
Check (-not $v.ok) "COUNTER-EXAMPLE 2a refused: a registered failure whose run also reported script errors, ARRAY shape (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $sickRowNumeric
Check (-not $v.ok) "COUNTER-EXAMPLE 2a' refused: the same, numeric shape (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $cleanArray
Check $v.ok "an EMPTY array of diagnostics still accepts a registered failure (reason: $($v.reason))"
$timeoutRow = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=0; timed_out=$true; exit_known=$true; passed=$false }
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $timeoutRow
Check (-not $v.ok) "COUNTER-EXAMPLE 2b refused: a registered failure whose run timed out (reason: $($v.reason))"
$unknownRow = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=0; timed_out=$false; exit_known=$false; passed=$false }
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $unknownRow
Check (-not $v.ok) "COUNTER-EXAMPLE 2c refused: a registered failure whose exit code was never observed (reason: $($v.reason))"

# --- further refusals --------------------------------------------------------------------------
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @() -ResultRow $healthy
Check (-not $v.ok) "an empty failure set does not satisfy a register expecting one failure (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old,$old) -ResultRow $healthy
Check (-not $v.ok) "a doubled failure is refused when the register expects one (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryChallenge -FailLines @($wave) -ResultRow $healthy
Check (-not $v.ok) "a single occurrence is refused where the register expects two (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry ([pscustomobject]@{ suite='x'; signatures=@() }) -FailLines @($old) -ResultRow $healthy
Check (-not $v.ok) "a register entry without signatures cannot accept anything (reason: $($v.reason))"

# --- the SUITE LOG clause, using real temporary files -------------------------------------------
$cleanLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_clean.log'
$dirtyLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_dirty.log'
$missingLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_absent.log'
Set-Content -LiteralPath $cleanLog -Value @('=== result: 16 checks, 1 failed ===','[FAIL] at least three actual slots from each team physically reach central approaches') -Encoding utf8
Set-Content -LiteralPath $dirtyLog -Value @('=== result: 16 checks, 1 failed ===','SCRIPT ERROR: Invalid access to property or key x on a base object') -Encoding utf8
if (Test-Path -LiteralPath $missingLog) { Remove-Item -LiteralPath $missingLog -Force }
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $cleanLog
Check $v.ok "a CLEAN suite log still accepts the registered failure (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $dirtyLog
Check (-not $v.ok) "COUNTER-EXAMPLE 2d refused: a registered failure whose SUITE LOG carries a script error (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $missingLog
Check (-not $v.ok) "a MISSING suite log refuses the registered failure instead of assuming health (reason: $($v.reason))"

Write-Output ("=== result: " + $checks + " checks, " + $failed + " failed ===")
if ($failed -eq 0) { Write-Output 'CANDIDATE_REGISTER_MATCH_PASS' } else { Write-Output 'CANDIDATE_REGISTER_MATCH_FAIL' }
if ($failed -ne 0) { exit 1 }
