$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
'=== WT-CD-015 definition, verbatim ==='
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$w = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-015' } | Select-Object -First 1
if ($w) {
  $w.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(400,$v.Length))
  }
} else { '  WT-CD-015 NOT FOUND' }
'=== its six cases, quoted from the packaged list ==='
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD15-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.title
  '      setup    : ' + [string]$_.setup
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
}
'=== the eight prerequisites, VERIFIED against the delivered result files rather than assumed ==='
'  depends_on:'
@($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-015' } | ForEach-Object {
  '    ' + (($_.depends_on | Out-String).Trim() -replace "`r?`n",',')
}
$deps = @('WT-CD-003','WT-CD-004','WT-CD-006','WT-CD-007','WT-CD-010','WT-CD-012','WT-CD-013','WT-CD-014')
foreach ($dep in $deps) {
  $num = $dep.Replace('WT-CD-0','CD0').Replace('WT-CD-','CD0')
  $hit = @(Get-ChildItem "$c\docs\wt\continuation" -File -Filter ("COMBAT_DEEPEN01_" + $num + "_RESULTS.json") -ErrorAction SilentlyContinue)
  $status = 'MISSING'
  $cases = 0
  if ($hit.Count -gt 0) {
    try { $rj = Get-Content $hit[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json; $status = [string]$rj.status; $cases = @($rj.case_ids_executed).Count } catch { $status = 'UNREADABLE' }
  }
  '  {0,-12} result_file={1,-6} status={2,-10} cases={3}' -f $dep,$(if ($hit.Count -gt 0) { 'yes' } else { 'NO' }),$status,$cases
}
'=== and the coverage ledger ==='
$cov = "$c\docs\wt\continuation\COMBAT_DEEPEN01_CASE_COVERAGE.md"
'  coverage doc exists=' + (Test-Path $cov)
if (Test-Path $cov) { (Get-Content $cov -Encoding UTF8 | Select-Object -First 6) | ForEach-Object { '    |' + $_.Substring(0,[Math]::Min(120,$_.Length)) } }