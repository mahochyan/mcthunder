$c='E:\AIprogram\mcthunder-cont'
"=== (1) the delivered expectation about the engineering shell count ==="
Select-String -Path "$c\tests\run_historical_checks.gd" -Pattern 'engineering types|admitted engineering|two admitted' -Encoding UTF8 | ForEach-Object { "  L" + $_.LineNumber + ": " + $_.Line.Trim() }
"=== (2) T-80B shell_catalog.shells textual boundary ==="
$p = "$c\configs\vehicles\engineering\ussr_t_80b.json"
Select-String -Path $p -Pattern '"shell_catalog"|"shells"|"compatible_shells"|"default"' -Encoding UTF8 | Select-Object -First 8 | ForEach-Object { "  L" + $_.LineNumber + ": " + $_.Line.Trim().Substring(0,[Math]::Min(110,$_.Line.Trim().Length)) }
$lines = Get-Content $p -Encoding UTF8
"  total lines=" + $lines.Count
$idx = @()
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*"shells"\s*:\s*\[') { $idx += $i } }
"  shells array lines=" + ($idx -join ',')
if ($idx.Count -ge 1) {
  $s = $idx[0]
  "  --- around the shells array start (L$($s+1)) ---"
  $lines[($s-1)..($s+2)] | ForEach-Object { "    [" + $_.Substring(0,[Math]::Min(100,$_.Length)) + "]" }
  $close = -1
  for ($i=$s+1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*\]\s*,?\s*$') { $close = $i; break } }
  "  shells array closes at L$($close+1)"
  if ($close -ge 0) { $lines[($close-6)..($close+2)] | ForEach-Object { "    [" + $_.Substring(0,[Math]::Min(100,$_.Length)) + "]" } }
}
"=== (3) the entry template keys present in the file (indentation reference) ==="
$lines | Where-Object { $_ -match '"effect_policy"|"family"|"source_bullet_type"' } | Select-Object -First 6 | ForEach-Object { "  [" + $_.Substring(0,[Math]::Min(100,$_.Length)) + "]" }
