$c='E:\AIprogram\mcthunder-cont'
"=== locate the two failing labels ==="
git -C $c grep -rn 'first spawn consumes' -- tests 2>&1 | ForEach-Object { "  " + $_.Substring(0,[Math]::Min(185,$_.Length)) }
git -C $c grep -rn 'restart retains' -- tests 2>&1 | ForEach-Object { "  " + $_.Substring(0,[Math]::Min(185,$_.Length)) }
"=== context of the loadout assertions in the modern garage suite ==="
$hit = @(git -C $c grep -rln 'first spawn consumes' -- tests 2>&1)
foreach ($h in $hit) {
  "  file=$h"
  $lines = Get-Content "$c\$h" -Encoding UTF8
  $n = (@(Select-String -Path "$c\$h" -Pattern 'first spawn consumes' -Encoding UTF8 | Select-Object -First 1)).LineNumber
  if ($n) { $lines[([Math]::Max(0,$n-16))..([Math]::Min($lines.Count-1,$n+6))] | ForEach-Object { "    |" + $_.Substring(0,[Math]::Min(152,$_.Length)) } }
  "  --- any hard-coded round counts in that file ---"
  Select-String -Path "$c\$h" -Pattern 'counts\[|initial_rounds|== 2\b|ammo_ready|shell_spins' -Encoding UTF8 | Select-Object -First 12 | ForEach-Object { "    L" + $_.LineNumber + ": " + $_.Line.Trim().Substring(0,[Math]::Min(140,$_.Line.Trim().Length)) }
}
