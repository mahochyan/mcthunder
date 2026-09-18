$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$wo = Get-Content "$o\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
'  items=' + @($wo.items).Count
$w8 = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-008' } | Select-Object -First 1
if ($w8) {
  '=== WT-CD-008 definition (verbatim) ==='
  $w8.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(26) + ' = ' + $v.Substring(0,[Math]::Min(260,$v.Length))
  }
} else { '  NOT FOUND in items; ids present: ' + ((@($wo.items) | ForEach-Object { [string]$_.id }) -join ',') }
'=== dependency fields across all items (to place CD08) ==='
@($wo.items) | ForEach-Object {
  $dep = ''
  foreach ($k in @('depends_on','dependencies','prerequisites','requires','after')) { if ($_.PSObject.Properties.Name -contains $k) { $dep += $k + '=' + (($_.$k | Out-String).Trim() -replace "`r?`n",',') + ' ' } }
  '  ' + [string]$_.id + '  ' + $dep
}
'=== interface contracts mentioning CD08 / crew / person / injury ==='
$ic = Get-Content "$o\09_INTERFACE_CONTRACTS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
'  top keys=' + (($ic.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
$txt = Get-Content "$o\09_INTERFACE_CONTRACTS.json" -Raw -Encoding UTF8
foreach ($kw in @('WT-CD-008','person_id','crew','injur','wound','岗位')) {
  $n = ([regex]::Matches($txt,[regex]::Escape($kw))).Count
  '  keyword ' + $kw + ' hits=' + $n
}
