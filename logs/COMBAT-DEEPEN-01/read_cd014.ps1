$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
'=== WT-CD-014 definition, verbatim ==='
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$w = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-014' } | Select-Object -First 1
if ($w) {
  $w.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(380,$v.Length))
  }
} else { '  WT-CD-014 NOT FOUND' }
'=== its six cases, quoted from the packaged list ==='
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD14-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.title
  '      setup    : ' + [string]$_.setup
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
}
'=== dependency check against what is closed ==='
@($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-014' } | ForEach-Object {
  '  ' + [string]$_.id + ' depends_on=' + (($_.depends_on | Out-String).Trim() -replace "`r?`n",',')
}
'  closed by my ledger so far: CD001..CD013 (13 of 16)'
'=== the remaining three orders, for the dependency graph ==='
@($wo.items) | Where-Object { [string]$_.id -in @('WT-CD-014','WT-CD-015','WT-CD-016') } | ForEach-Object {
  '  ' + [string]$_.id + ' | ' + [string]$_.title + ' | depends_on=' + (($_.depends_on | Out-String).Trim() -replace "`r?`n",',')
}