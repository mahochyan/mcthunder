param([string]$Archive)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Archive) { $Archive = Join-Path $projectRoot 'backups/downloads/Godot_v4.7.2-stable_export_templates.tpz' }
$expected = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
$actual = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'Archive does not match the official 4.7.2 standard export template digest' }
$installRoot = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'))
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Archive)
$files = @()
try {
    foreach ($name in @('version.txt','windows_debug_x86_64.exe','windows_debug_x86_64_console.exe','windows_release_x86_64.exe','windows_release_x86_64_console.exe')) {
        $entry = $zip.GetEntry('templates/'+$name)
        if ($null -eq $entry) { throw "Template missing in verified archive: $name" }
        $target = [IO.Path]::GetFullPath((Join-Path $installRoot $name))
        if (-not $target.StartsWith($installRoot+[IO.Path]::DirectorySeparatorChar)) { throw 'Destination escaped template directory' }
        if (-not (Test-Path -LiteralPath $target)) { [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false) }
        $stream = $entry.Open()
        try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) } finally { $stream.Dispose() }
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw "Installed template differs from verified archive: $name" }
        $files += @{name=$name; bytes=$entry.Length; sha256=$hash}
    }
} finally { $zip.Dispose() }
if ((Get-Content -LiteralPath (Join-Path $installRoot 'version.txt') -Raw).Trim() -ne '4.7.2.stable') { throw 'Installed template version mismatch' }
$logRoot = Join-Path $projectRoot 'logs/019'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
@{source='https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable'; archive_sha256=$actual; installed=$installRoot; files=$files; date=(Get-Date).ToString('o'); scope='Windows x86_64 only, original official standard templates'} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $logRoot 'template_install.json') -Encoding utf8
Write-Output "VERIFIED_TEMPLATES=$installRoot"
exit 0
