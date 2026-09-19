$ErrorActionPreference='Stop'
# Verifies the village register entry against the REAL failing line, using the SAME matcher the build runs
# (tests/candidate_register_match.ps1 is dot-sourced, never copied). It also runs the two negative controls the
# matcher exists for: a brand new failure must be refused, and a registered failure plus an extra one must be refused.
$root='E:\AIprogram\mcthunder-cont'
. (Join-Path $root 'tests/candidate_register_match.ps1')
$path=Join-Path $root 'tests/build_release.ps1'
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -gt 0){ throw "build_release.ps1 has $($parseErrors.Count) parse error(s): $($parseErrors[0].Message)" }
Write-Output "PARSE_OK tokens=$($tokens.Count) parseErrors=0"
$assign=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$deviationRegister'},$true)
if($assign.Count -ne 1){ throw "expected exactly one deviationRegister assignment, found $($assign.Count)" }
$register = & ([scriptblock]::Create($assign[0].Right.Extent.Text))
Write-Output "REGISTER_ENTRIES=$($register.Count) suites=$($register.suite -join ',')"
$village=@($register | Where-Object { $_.suite -eq 'run_village_battle_checks' })
if($village.Count -ne 1){ throw "the village register entry is missing" }
$real='[FAIL] all seven autonomous actors leave spawn and reach central approaches: ["A4", "B", "A3", "B4", "B2"]'
$accepted=Test-CandidateFailureSet -Entry $village[0] -FailLines @($real)
Write-Output "REAL_FAIL_ACCEPTED=$($accepted.ok) reason=$($accepted.reason)"
$new=Test-CandidateFailureSet -Entry $village[0] -FailLines @('[FAIL] a brand new failure nobody registered')
Write-Output "NEW_FAILURE_REFUSED=$(-not $new.ok) reason=$($new.reason)"
$extra=Test-CandidateFailureSet -Entry $village[0] -FailLines @($real,'[FAIL] an extra unregistered failure')
Write-Output "EXTRA_FAILURE_REFUSED=$(-not $extra.ok) reason=$($extra.reason)"
Write-Output "VILLAGE_REGISTER_VERIFY_DONE"
