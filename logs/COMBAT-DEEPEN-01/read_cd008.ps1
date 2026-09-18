$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
"=== WT-CD-008 work order definition (07_WORK_ORDERS.json) ==="
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
'  top keys=' + (($wo.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
$list = if ($wo.work_orders) { $wo.work_orders } else { $wo.orders }
'  orders=' + @($list).Count
$w8 = @($list) | Where-Object { [string]$_.id -eq 'WT-CD-008' } | Select-Object -First 1
if ($w8) {
  $w8.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(230,$v.Length))
  }
} else { '  WT-CD-008 NOT FOUND' }
"=== CD08 cases, quoted from the packaged list (08_ACCEPTANCE_CASES.json) ==="
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD08-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.work_order + ' | ' + [string]$_.title
  '      setup    : ' + [string]$_.setup
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
  '      origin=' + [string]$_.origin + ' level=' + [string]$_.evidence_level + ' status=' + [string]$_.status
}
