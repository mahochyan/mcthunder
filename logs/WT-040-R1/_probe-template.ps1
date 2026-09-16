param([string]$TemplateDirectory = (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'))
"APPDATA=$env:APPDATA"
"TemplateDirectory=$TemplateDirectory"
"dir_exists=" + (Test-Path -LiteralPath $TemplateDirectory)
$t = Join-Path $TemplateDirectory 'windows_release_x86_64.exe'
"template=$t"
"template_exists=" + (Test-Path -LiteralPath $t)
