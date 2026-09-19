$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
'=== WT-CD-011 definition, verbatim ==='
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$w = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-011' } | Select-Object -First 1
if ($w) {
  $w.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(300,$v.Length))
  }
} else { '  WT-CD-011 NOT FOUND' }
'=== its six cases, quoted from the packaged list ==='
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD11-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.title
  '      setup    : ' + [string]$_.setup
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
}
'=== dependency check ==='
@($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-011' } | ForEach-Object {
  '  ' + [string]$_.id + ' depends_on=' + (($_.depends_on | Out-String).Trim() -replace "`r?`n",',')
}