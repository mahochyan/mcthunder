$c='E:\AIprogram\mcthunder-cont'
foreach ($n in @('ussr_t_80b','germ_leopard_2a4')) {
  $f = "$c\configs\vehicles\engineering\$n.json"
  $v = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
  "=== $n ==="
  "  assembly.gun=" + [string]$v.assembly.gun + " ; caliber=" + [string]$v.assembly.caliber_mm + " ; shell=" + [string]$v.assembly.shell
  "  compatible_shells=" + (($v.compatible_shells) -join ' | ')
  if ($v.PSObject.Properties.Name -contains 'shell_catalog') {
    $sc = $v.shell_catalog
    "  shell_catalog keys=" + (($sc.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
    "  schema_version=" + [string]$sc.schema_version + " ; default=" + [string]$sc.default + " ; shells count=" + @($sc.shells).Count
    @($sc.shells) | ForEach-Object {
      "    entry id=" + [string]$_.id + " family=" + [string]$_.family + " source=" + [string]$_.source_bullet_type + " effect=" + [string]$_.effect_policy + " gun=" + [string]$_.gun + " caliber=" + [string]$_.caliber_mm
      "      entry keys=" + (($_.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
    }
  } else { "  shell_catalog MISSING" }
  foreach ($k in @('shell_counts','counts','loadout','ammo','ammo_counts')) {
    if ($v.PSObject.Properties.Name -contains $k) { "  " + $k + " => " + ($v.$k | ConvertTo-Json -Depth 4 -Compress) }
  }
}
"=== VehicleShellCatalog.install (L123-146) ==="
$lines = Get-Content "$c\scripts\content\vehicle_shell_catalog.gd" -Encoding UTF8
$lines[122..145] | ForEach-Object { "  |" + $_.Substring(0,[Math]::Min(158,$_.Length)) }
