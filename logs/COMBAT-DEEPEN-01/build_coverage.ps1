$c='E:\AIprogram\mcthunder-cont'
$ac = Get-Content "$c\docs\wt\combat-deepen-01\original\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @($ac.cases)
"  cases=" + $cases.Count

# What exists on disk, per sub-order: the evidence document I keep, and the probes/suites named after that order.
$probes = @(Get-ChildItem "$c\tests" -File -Filter 'probe_cd0*.gd' | ForEach-Object { $_.Name })
$evidence = @{}
foreach ($n in 1..16) {
  # The case ids are like CD01-T01 and the first four characters are CD01, so the map keys must be CD01..CD16 as well:
  # a five character key left every lookup null, and a null is not the empty string, so the first table reported all
  # ninety six as evidenced.
  $tag = 'CD' + $n.ToString('00')
  # Test-Path is used rather than a filtered listing, because the filtered form returned truthy for documents that do not
  # exist and the first table claimed ninety six of ninety six evidenced, which is exactly the empty pass to avoid.
  $rel = 'docs/wt/continuation/COMBAT_DEEPEN01_' + $tag + '_EVIDENCE.md'
  $evidence[$tag] = if (Test-Path ("$c\" + $rel)) { $rel } else { '' }
}
$rows = @()
foreach ($case in $cases) {
  $id = [string]$case.id
  $tag = $id.Substring(0,4)
  $mine = @($probes | Where-Object { $_ -like ('probe_' + $tag.ToLower() + '*') })
  $row = [pscustomobject][ordered]@{
    case_id = $id
    work_order = [string]$case.work_order
    title = [string]$case.title
    expected = [string]$case.expected
    sub_order = $tag
    evidence_document = [string]$evidence[$tag]
    executors = ($mine -join ' ')
    state = if ($evidence[$tag] -ne '' -and $evidence[$tag] -ne $null) { 'EVIDENCE_RECORDED' } else { 'NOT_RUN' }
    original_status = [string]$case.status
  }
  $rows += $row
}
$summary = @($rows | Group-Object sub_order | Sort-Object Name | ForEach-Object {
  [pscustomobject][ordered]@{
    sub_order = $_.Name
    cases = $_.Count
    state = if ($evidence[$_.Name] -ne '') { 'EVIDENCE_RECORDED' } else { 'NOT_RUN' }
    evidence_document = [string]$evidence[$_.Name]
    executors = (($_.Group | ForEach-Object { $_.executors } | Where-Object { $_ -ne '' } | Select-Object -Unique) -join ' ')
  }
})
$out = [pscustomobject][ordered]@{
  package_id = [string]$ac.package_id
  case_count = $cases.Count
  note = 'The original case list is read-only, so this table mirrors its ninety six ids rather than editing it: each row names the sub-order, the evidence document this order keeps, the probes that execute it, and the state. A sub-order with no evidence document is honestly NOT_RUN rather than assumed.'
  evidence_state = 'engineering self-consistent version only; a publicly comparable version is NOT established'
  summary = $summary
  rows = $rows
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CASE_COVERAGE.json", ($out | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$lines = @()
$lines += '# MCT-COMBAT-DEEPEN-01 case coverage: ninety six cases, mirrored rather than edited'
$lines += ''
$lines += 'The packaged list at `docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json` is read-only, so its ninety six ids are mirrored here with the executor and the state this order can actually show. A sub-order with no evidence document is recorded as NOT_RUN rather than assumed to pass.'
$lines += ''
$lines += '| sub-order | cases | state | evidence document | executors |'
$lines += '|---|---|---|---|---|'
foreach ($s in $summary) {
  $lines += '| ' + $s.sub_order + ' | ' + $s.cases + ' | ' + $s.state + ' | ' + $(if ($s.evidence_document -ne '') { '`' + $s.evidence_document + '`' } else { '-' }) + ' | ' + $(if ($s.executors -ne '') { '`' + $s.executors + '`' } else { '-' }) + ' |'
}
$lines += ''
$lines += '| case | sub-order | title | state | executors |'
$lines += '|---|---|---|---|---|'
foreach ($r in $rows) {
  $lines += '| ' + $r.case_id + ' | ' + $r.sub_order + ' | ' + ($r.title -replace '\|','/') + ' | ' + $r.state + ' | ' + $(if ($r.executors -ne '') { '`' + $r.executors + '`' } else { '-' }) + ' |'
}
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CASE_COVERAGE.md", $lines, (New-Object Text.UTF8Encoding($false)))
"  rows=" + $rows.Count + " ; evidenced=" + @($rows | Where-Object { $_.state -eq 'EVIDENCE_RECORDED' }).Count + " ; not_run=" + @($rows | Where-Object { $_.state -eq 'NOT_RUN' }).Count
"  per_sub_order:"
$summary | ForEach-Object { "    " + $_.sub_order + " cases=" + $_.cases + " state=" + $_.state }
