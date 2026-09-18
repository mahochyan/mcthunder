$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
'=== WT-CD-010 definition, verbatim ==='
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$w = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-010' } | Select-Object -First 1
if ($w) {
  $w.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(280,$v.Length))
  }
} else { '  WT-CD-010 NOT FOUND' }
'=== its six cases, quoted from the packaged list ==='
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD10-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.title
  '      setup    : ' + [string]$_.setup
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
}
'=== the dependency graph around CD10 (from the same packaged file) ==='
@($wo.items) | Where-Object { [string]$_.id -in @('WT-CD-010','WT-CD-011','WT-CD-012') } | ForEach-Object {
  '  ' + [string]$_.id + ' depends_on=' + (($_.depends_on | Out-String).Trim() -replace "`r?`n",',')
}