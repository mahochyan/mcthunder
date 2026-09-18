$c='E:\AIprogram\mcthunder-cont'
$p="$c\scripts\projectiles\projectile_manager.gd"
$lines = Get-Content $p -Encoding UTF8
"=== raw view of the two anchor lines with whitespace made visible (tab=T, space=.) ==="
foreach ($n in @(567,568,569,447,448,449)) {
  if ($n -lt $lines.Count) {
    $shown = $lines[$n] -replace "`t",'T' -replace ' ','.'
    "  L" + ($n+1) + ": [" + $shown.Substring(0,[Math]::Min(150,$shown.Length)) + "]"
  }
}
"=== match test on the single line that certainly exists ==="
$txt = Get-Content $p -Raw -Encoding UTF8
"  contains_rest_for_fuze=" + $txt.Contains('_rest_for_fuze(st, ev, "armor_"')
foreach ($pat in @('_rest_for_fuze\(st, ev, "armor_"\+str\(result\.result\)\)', 'waiting = _rest_for_fuze', 'if not handle_contact\(st, ev\)')) {
  "  pattern [" + $pat + "] hits=" + ([regex]::Matches($txt,$pat)).Count
}
"=== exact index of the substring, to see its real surroundings ==="
$i = $txt.IndexOf('_rest_for_fuze(st, ev, "armor_"')
if ($i -ge 0) {
  $seg = $txt.Substring([Math]::Max(0,$i-90),180) -replace "`t",'T' -replace "`r",'R' -replace "`n",'N'
  "  around: [" + $seg + "]"
}
$j = $txt.IndexOf('if not handle_contact(st, ev):')
if ($j -ge 0) {
  $seg2 = $txt.Substring([Math]::Max(0,$j-60),150) -replace "`t",'T' -replace "`r",'R' -replace "`n",'N'
  "  around2: [" + $seg2 + "]"
}
