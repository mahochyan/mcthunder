$c='E:\AIprogram\mcthunder-cont'
$v = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$e = $v.shell_catalog.shells | Where-Object { [string]$_.id -eq 'eng_125_apfsds_v1' } | Select-Object -First 1
"=== APFSDS entry (full) ==="
($e | ConvertTo-Json -Depth 9) -split "`r?`n" | ForEach-Object { "  " + $_.Substring(0,[Math]::Min(150,$_.Length)) }
