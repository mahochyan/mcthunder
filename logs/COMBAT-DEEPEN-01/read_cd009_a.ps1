$c='E:\AIprogram\mcthunder-cont'
'=== 1) vehicle_capabilities.gd IN FULL (the single derivation the order requires) ==='
Get-Content "$c\scripts\damage\vehicle_capabilities.gd" -Encoding UTF8 | ForEach-Object { $s = $_ -replace "`t",'T'; '  |' + $s.Substring(0,[Math]::Min(155,$s.Length)) }