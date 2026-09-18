$c='E:\AIprogram\mcthunder-cont'
"=== M4A3(75)W 的弹行结构（决定历史安装点名谁 ✓）==="
$v = Get-Content "$c\configs\vehicles\historical\us_m4a3_75w_vvss_1944.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  顶层键=" + (($v.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
foreach ($k in @('shells','shell_catalog','compatible_shells','shell_rows','loadout')) {
  if ($v.PSObject.Properties.Name -contains $k) {
    $val = $v.$k
    "  " + $k + " => " + $(if ($val -is [System.Array]) { "数组(" + @($val).Count + "): " + (($val | ForEach-Object { if ($_ -is [string]) { $_ } else { ($_.PSObject.Properties | ForEach-Object { $_.Name }) -join '/' } }) -join ' | ') } elseif ($val -is [System.Management.Automation.PSCustomObject]) { "对象键=" + (($val.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') } else { "标量=" + [string]$val })
  }
}
"=== historical_shell_catalog 的 row 来源（L14-40 ✓）==="
$lines = Get-Content "$c\scripts\content\historical_shell_catalog.gd" -Encoding UTF8
$lines[13..40] | ForEach-Object { "  |" + $_.Substring(0,[Math]::Min(155,$_.Length)) }
