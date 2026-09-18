$c='E:\AIprogram\mcthunder-cont'
$ac = Get-Content "$c\docs\wt\combat-deepen-01\original\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @($ac.cases)
$probes = @(Get-ChildItem "$c\tests" -File -Filter 'probe_cd0*.gd' | ForEach-Object { $_.Name })

# Two naming forms meet here and must be mapped rather than conflated: a case id is CD01-T01 whose first four characters
# are CD01, while the evidence documents are named with three digits, CD001..CD016. Both earlier attempts got this wrong -
# one compared a null against the empty string and called everything evidenced, the other used the two digit form as a key
# and found nothing - so the mapping is explicit here.
function Doc-Rel($caseTag) {
  $digits = [int]$caseTag.Substring(2,2)
  return 'docs/wt/continuation/COMBAT_DEEPEN01_CD' + $digits.ToString('000') + '_EVIDENCE.md'
}

$rows = @()
foreach ($case in $cases) {
  $id = [string]$case.id
  $tag = $id.Substring(0,4)
  $rel = Doc-Rel $tag
  $exists = Test-Path ($c + '\' + $rel)
  $doc = ''
  if ($exists) { $doc = $rel }
  $mine = @($probes | Where-Object { $_ -like ('probe_' + $tag.ToLower() + '*') })
  $state = 'NOT_RUN'
  if ($doc.Length -gt 0) { $state = 'EVIDENCE_RECORDED' }
  $rows += [pscustomobject][ordered]@{
    case_id = $id; sub_order = $tag; work_order = [string]$case.work_order; title = [string]$case.title
    state = $state; evidence_document = $doc; executors = ($mine -join ' '); original_status = [string]$case.status
  }
}
$summary = @($rows | Group-Object sub_order | Sort-Object Name | ForEach-Object {
  $g = $_.Group
  $doc = [string]$g[0].evidence_document
  [pscustomobject][ordered]@{
    sub_order = $_.Name; cases = $_.Count
    state = $(if ($doc.Length -gt 0) { 'EVIDENCE_RECORDED' } else { 'NOT_RUN' })
    evidence_document = $doc
    executors = ((($g | ForEach-Object { $_.executors }) | Where-Object { $_ -ne '' } | Select-Object -Unique) -join ' ')
  }
})
$out = [pscustomobject][ordered]@{
  package_id = [string]$ac.package_id; case_count = $cases.Count
  note = 'The packaged case list is read-only, so its ninety six ids are mirrored here rather than edited: each row names the sub-order, the evidence document this order keeps, the probes that execute it, and the state. A sub-order with no evidence document is NOT_RUN rather than assumed.'
  naming_note = 'Case ids use two digits after the prefix and the evidence documents use three, so the mapping is stated in the generator rather than guessed.'
  evidence_state = 'engineering self-consistent version only; a publicly comparable version is NOT established'
  summary = $summary; rows = $rows
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CASE_COVERAGE.json", ($out | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$L = @()
$L += '# MCT-COMBAT-DEEPEN-01 case coverage: ninety six ids, mirrored rather than edited'
$L += ''
$L += 'The packaged list at `docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json` is read-only. Its ninety six case ids are mirrored here with the evidence document this order keeps and the state it can actually show; a sub-order with no evidence document is recorded as NOT_RUN rather than assumed to pass.'
$L += ''
$L += '| sub-order | cases | state | evidence document | executors |'
$L += '|---|---|---|---|---|'
foreach ($s in $summary) {
  $d = '-'; if ($s.evidence_document.Length -gt 0) { $d = '`' + $s.evidence_document + '`' }
  $e = '-'; if ($s.executors.Length -gt 0) { $e = '`' + $s.executors + '`' }
  $L += '| ' + $s.sub_order + ' | ' + $s.cases + ' | ' + $s.state + ' | ' + $d + ' | ' + $e + ' |'
}
$L += ''
$L += '| case | sub-order | title | state | executors |'
$L += '|---|---|---|---|---|'
foreach ($r in $rows) {
  $e = '-'; if ($r.executors.Length -gt 0) { $e = '`' + $r.executors + '`' }
  $L += '| ' + $r.case_id + ' | ' + $r.sub_order + ' | ' + ($r.title -replace '\|','/') + ' | ' + $r.state + ' | ' + $e + ' |'
}
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CASE_COVERAGE.md", $L, (New-Object Text.UTF8Encoding($false)))
"  rows=" + $rows.Count + " evidenced=" + @($rows | Where-Object { $_.state -eq 'EVIDENCE_RECORDED' }).Count + " not_run=" + @($rows | Where-Object { $_.state -eq 'NOT_RUN' }).Count
$summary | ForEach-Object { "    " + $_.sub_order + " cases=" + $_.cases + " state=" + $_.state + " exec=" + $(if ($_.executors.Length -gt 0) { $_.executors } else { '-' }) }
