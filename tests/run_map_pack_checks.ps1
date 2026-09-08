param([string]$Order = '018', [switch]$Wip)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$identity = if ($Wip) { 'wip-uncommitted' } else { $sourceSha }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "backups/packs/$Order/$identity/$stamp"
$logs = Join-Path $projectRoot "logs/$Order/$identity/pack-$stamp"
New-Item -ItemType Directory -Force -Path $outDir,$logs | Out-Null
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$pack = Join-Path $outDir 'village.pck'
$runs = @(
    @{name='export_pack'; args='--headless --path "'+$projectRoot+'" --export-pack "Village Resource Check" "'+$pack+'"'; cwd=$projectRoot},
    @{name='load_pack'; args='--headless --path "'+$outDir+'" --main-pack "'+$pack+'" --fixed-fps 60 -s res://tests/run_map_pack_checks.gd'; cwd=$outDir}
)
$results = @()
foreach ($run in $runs) {
    $process = Start-Process -FilePath $engine -ArgumentList $run.args -WorkingDirectory $run.cwd -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$($run.name)_stdout.log" -RedirectStandardError "$logs/$($run.name)_stderr.log"
    $timeout = -not $process.WaitForExit(120000)
    if ($timeout) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $output = [IO.File]::ReadAllText("$logs/$($run.name)_stdout.log") + [IO.File]::ReadAllText("$logs/$($run.name)_stderr.log")
    $passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
    if ($run.name -eq 'load_pack') { $passed = $passed -and $output -match 'MAP_PACK_CHECKS_PASS' }
    $results += @{name=$run.name; command='"'+$engine+'" '+$run.args; exit_code=$process.ExitCode; timed_out=$timeout; passed=$passed}
    if (-not $passed) { break }
}
$manifest = @{source_sha=$sourceSha; uncommitted_source=[bool]$Wip; engine=(& $engine --version).Trim(); pack=$pack; pck_only=$true; source_fallback_available=$false; runs=$results}
if (Test-Path -LiteralPath $pack) { $manifest.sha256=(Get-FileHash -LiteralPath $pack).Hash }
$manifest | ConvertTo-Json -Depth 6 | Set-Content "$logs/RESULTS.json" -Encoding utf8
Get-Content "$logs/RESULTS.json"
Write-Output "EVIDENCE=$logs"
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
