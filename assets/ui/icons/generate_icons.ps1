# MCT-UI-FIELDWORK-01 / WT-UI-002 icon source.
# Generates the single-colour functional icon set from one definition table: the same 24x24 view box and the same
# 1.75-unit stroke for every icon, no fills except where a shape needs one, no font and no third-party dependency.
# The SVGs are monochrome white so the UI tints them through modulate; the design's own ink colour is text_primary.
# Run:  powershell -ExecutionPolicy Bypass -File assets/ui/icons/generate_icons.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force -Path $root | Out-Null

$stroke = '1.75'
$icons = [ordered]@{
  'nation'            = '<path d="M6 3v18"/><path d="M6 4h11l-1.6 3.2L17 10.4H6"/>'
  'vehicle_medium'    = '<rect x="3" y="12" width="18" height="7" rx="1.5"/><rect x="8" y="7.5" width="8" height="3.5" rx="1"/><path d="M16.5 8.6h5"/><circle cx="7" cy="19.6" r="1.6"/><circle cx="12" cy="19.6" r="1.6"/><circle cx="17" cy="19.6" r="1.6"/>'
  'vehicle_heavy'     = '<rect x="2.5" y="11.5" width="19" height="8" rx="1.5"/><rect x="7.5" y="6.5" width="9" height="4" rx="1"/><path d="M16.5 7.8h5.2"/><path d="M4 14h16"/><circle cx="6.8" cy="20" r="1.7"/><circle cx="12" cy="20" r="1.7"/><circle cx="17.2" cy="20" r="1.7"/>'
  'vehicle_light'     = '<rect x="4.5" y="12.5" width="15" height="6" rx="1.5"/><rect x="9" y="8.5" width="6" height="3" rx="1"/><path d="M15 9.4h4"/><circle cx="8" cy="19.4" r="1.5"/><circle cx="12" cy="19.4" r="1.5"/><circle cx="16" cy="19.4" r="1.5"/>'
  'vehicle_destroyer' = '<path d="M3 15.5h14l3-2.5v-1.5H8"/><path d="M12 11.5H21"/><circle cx="7" cy="19.4" r="1.6"/><circle cx="12" cy="19.4" r="1.6"/><circle cx="17" cy="19.4" r="1.6"/>'
  'vehicle_spaa'      = '<rect x="4" y="13.5" width="16" height="5.5" rx="1.5"/><rect x="9.5" y="9.5" width="5" height="4" rx="1"/><path d="M10.8 9.5V5.2M13.2 9.5V5.2"/><circle cx="7.5" cy="19.6" r="1.5"/><circle cx="12" cy="19.6" r="1.5"/><circle cx="16.5" cy="19.6" r="1.5"/>'
  'ammo'              = '<path d="M9 21V9.5a3 3 0 0 1 6 0V21z"/><path d="M9 13.5h6"/><path d="M12 6.5V4"/>'
  'armor'             = '<path d="M12 3.5 19 6v6.5c0 4-3 6.5-7 8-4-1.5-7-4-7-8V6z"/><path d="M12 3.5v17"/>'
  'crew'              = '<circle cx="12" cy="8" r="3.2"/><path d="M5.5 20.5c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/>'
  'repair'            = '<path d="M14.5 4.5a4.5 4.5 0 0 0-4 6.7L4.5 17.2l2.3 2.3 6-6a4.5 4.5 0 0 0 6.7-4l-2.6 1.7-2.2-.6-.6-2.2z"/>'
  'extinguish'        = '<path d="M12 3.5s4.5 4.2 4.5 7.6a4.5 4.5 0 0 1-9 0C7.5 7.7 12 3.5 12 3.5z"/><path d="M4 20.5 20 3.5"/>'
  'warning'           = '<path d="M12 4.5 21 19.5H3z"/><path d="M12 10v4.2"/><path d="M12 16.6v1.2"/>'
  'spectate'          = '<path d="M3 12s3.8-6 9-6 9 6 9 6-3.8 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/>'
  'back'              = '<path d="M20 12H5"/><path d="M10.5 6.5 5 12l5.5 5.5"/>'
  'settings'          = '<circle cx="12" cy="12" r="2.8"/><path d="M12 3.5v2.6M12 17.9v2.6M3.5 12h2.6M17.9 12h2.6M6 6l1.8 1.8M16.2 16.2 18 18M18 6l-1.8 1.8M7.8 16.2 6 18"/>'
  'search'            = '<circle cx="11" cy="11" r="5.5"/><path d="M15.2 15.2 20 20"/>'
  'lock'              = '<rect x="5" y="10.5" width="14" height="9" rx="1.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/><path d="M12 14v2.5"/>'
}

$manifest = [ordered]@{
  schema_version  = 1
  work_order      = 'WT-UI-002'
  viewbox         = 24
  stroke_units    = 1.75
  fill_policy     = 'no fill except where a shape needs one; every icon is single colour'
  colour_policy   = 'authored monochrome white; the UI tints with modulate, ink colour is the text_primary token'
  size_checks     = @(16, 24, 32)
  font_or_plugin  = 'none: no font binary and no third-party package is added by this set'
  icons           = @()
}

foreach ($name in $icons.Keys) {
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none"
     stroke="#FFFFFF" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">
  $($icons[$name])
</svg>
"@
  $path = Join-Path $root ("icon_{0}.svg" -f $name)
  [System.IO.File]::WriteAllText($path, $svg, [System.Text.UTF8Encoding]::new($false))
  $manifest.icons += [ordered]@{ name = $name; file = ("icon_{0}.svg" -f $name); bytes = (Get-Item $path).Length }
}

$manifestPath = Join-Path $root 'ICON_MANIFEST.json'
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
"ICONS_WRITTEN=" + $icons.Count
"MANIFEST=" + $manifestPath
