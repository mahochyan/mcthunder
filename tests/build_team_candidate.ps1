param([string]$Order = '019', [switch]$Wip)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildDir = Join-Path $projectRoot "backups/builds/$Order/$identity/$stamp"
$logDir = Join-Path $projectRoot "logs/$Order/$identity/export-$stamp"
New-Item -ItemType Directory -Force -Path $buildDir,$logDir | Out-Null
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$exe = Join-Path $buildDir 'PixelArmor.exe'
$templateRoot = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
if (-not (Test-Path -LiteralPath (Join-Path $templateRoot 'windows_debug_x86_64.exe'))) { throw 'Matching official Windows x86_64 export templates are missing' }
$runs = @(
    @{name='export'; executable=$engine; args='--headless --path "'+$projectRoot+'" --export-debug "Windows Team Slice" "'+$exe+'"'; cwd=$projectRoot},
    @{name='default_start'; executable=$exe; args='--headless --quit-after 15'; cwd=$buildDir},
    @{name='resources_and_input'; executable=$exe; args='--headless --fixed-fps 60 -- --export-smoke'; cwd=$buildDir}
)
$results = @()
foreach ($run in $runs) {
    $process = Start-Process -FilePath $run.executable -ArgumentList $run.args -WorkingDirectory $run.cwd -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDir/$($run.name)_stdout.log" -RedirectStandardError "$logDir/$($run.name)_stderr.log"
    $timeout = -not $process.WaitForExit(180000)
    if ($timeout) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $output = [IO.File]::ReadAllText("$logDir/$($run.name)_stdout.log") + [IO.File]::ReadAllText("$logDir/$($run.name)_stderr.log")
    $passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
    if ($run.name -eq 'resources_and_input') { $passed = $passed -and $output -match 'EXPORT_CHECKS_PASS' }
    $results += @{name=$run.name;command='"'+$run.executable+'" '+$run.args;exit_code=$process.ExitCode;timed_out=$timeout;passed=$passed}
    if (-not $passed) { break }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/OFL.txt') -Destination (Join-Path $buildDir 'FONT_OFL.txt')
@"
PixelArmor v0.2 Windows engineering candidate (019)
Source: $sourceSha
Uncommitted source: $([bool]$Wip)
Run PixelArmor.exe. Keep PixelArmor.pck beside it. No Godot editor required.
Choose 4 vs 4 in the garage. WASD drive, mouse aim, left click fire, right click sight.
F extinguish, T repair, C replace crew, Esc pause. Follow the Chinese HUD for availability.
This candidate uses fictional test vehicles. Historical production content is pending.
Human playtesting: NOT_RUN. Performance is not a verified minimum-spec guarantee.
Godot and bundled library notices: GODOT_LICENSES.txt. Font license: FONT_OFL.txt.
"@ | Set-Content -LiteralPath (Join-Path $buildDir 'README.txt') -Encoding utf8
$files = Get-ChildItem -LiteralPath $buildDir -File | ForEach-Object { @{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} }
@{source_sha=$sourceSha;uncommitted_source=[bool]$Wip;engine=(& $engine --version).Trim();type='official Windows x86_64 debug export, independent exe and pck';build=$buildDir;runs=$results;files=@($files);human='NOT_RUN'} | ConvertTo-Json -Depth 6 | Set-Content "$logDir/RESULTS.json" -Encoding utf8
Get-Content "$logDir/RESULTS.json"
Write-Output "BUILD=$buildDir"
Write-Output "EVIDENCE=$logDir"
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
