$ErrorActionPreference='Stop'
# Verifies the INDUSTRIAL register entry against the REAL failing line from logs/COMBAT-DEEPEN-01/industrial-budget.log,
# using the gate's own matcher (dot-sourced), plus the two negative controls that matter for THIS entry: a registered
# failure that TIMED OUT must be refused, and one whose log carries a SCRIPT ERROR must be refused.
$root='E:\AIprogram\mcthunder-cont'
. (Join-Path $root 'tests/candidate_register_match.ps1')
$path=Join-Path $root 'tests/build_release.ps1'
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -gt 0){ throw "build_release.ps1 parse errors: $($parseErrors[0].Message)" }
$assign=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$deviationRegister'},$true)
$register = & ([scriptblock]::Create($assign[0].Right.Extent.Text))
$entry=@($register | Where-Object { $_.suite -eq 'run_industrial_battle_checks' })
if($entry.Count -ne 1){ throw 'the industrial register entry is missing' }
$log=Join-Path $root 'logs/COMBAT-DEEPEN-01/industrial-budget.log'
$realFail=@('[FAIL] at least three actual slots from each team physically reach central approaches')
$healthy=[pscustomobject]@{passed=$false;timed_out=$false;unexpected_errors=@();exit_known=$true}
$ok=Test-CandidateFailureSet -Entry $entry[0] -FailLines $realFail -ResultRow $healthy -SuiteLogPath $log
Write-Output "REAL_FAIL_ACCEPTED=$($ok.ok) reason=$($ok.reason)"
$timedOut=[pscustomobject]@{passed=$false;timed_out=$true;unexpected_errors=@();exit_known=$true}
$refused=Test-CandidateFailureSet -Entry $entry[0] -FailLines $realFail -ResultRow $timedOut -SuiteLogPath $log
Write-Output "TIMEOUT_REFUSED=$(-not $refused.ok) reason=$($refused.reason)"
$unexpected=[pscustomobject]@{passed=$false;timed_out=$false;unexpected_errors=@('SCRIPT ERROR: something');exit_known=$true}
$refused2=Test-CandidateFailureSet -Entry $entry[0] -FailLines $realFail -ResultRow $unexpected -SuiteLogPath $log
Write-Output "SCRIPT_ERROR_REFUSED=$(-not $refused2.ok) reason=$($refused2.reason)"
$two=Test-CandidateFailureSet -Entry $entry[0] -FailLines @($realFail[0],'[FAIL] a second different failure') -ResultRow $healthy -SuiteLogPath $log
Write-Output "EXTRA_FAILURE_REFUSED=$(-not $two.ok) reason=$($two.reason)"
Write-Output "INDUSTRIAL_REGISTER_VERIFY_DONE"
