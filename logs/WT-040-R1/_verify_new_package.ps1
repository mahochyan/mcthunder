# WT-040-R1 Stage 4 follow-up, prepared while the candidate build runs. Kept UNTRACKED on purpose: the build
# requires a clean tracked tree, and its own check ignores untracked local evidence.
#
# It finds the newest package produced by the running build, reads that package's OWN BUILD_MANIFEST.json, and
# runs the player-flow verification with the manifest's source_sha - so the provenance is the package's own
# statement rather than something inferred here.

$c = 'E:\AIprogram\mcthunder-cont'
$sha = (& git -C $c rev-parse HEAD).Trim()
Write-Output ("source sha = " + $sha)

$runRoot = Join-Path $c ("backups\builds\031\" + $sha)
if (-not (Test-Path -LiteralPath $runRoot)) { throw ("no build run directory yet under " + $runRoot) }
$run = Get-ChildItem -LiteralPath $runRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Output ("run dir    = " + $run.FullName)

# The package may be a directory tree or an extracted zip; look for the executable and its manifest.
$exe = Get-ChildItem -LiteralPath $run.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('PixelArmor.exe','PixelArmorClient.exe') } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) {
    Write-Output "no PixelArmorClient.exe yet; listing what exists:"
    Get-ChildItem -LiteralPath $run.FullName -Recurse -File -Include '*.exe','*.zip','BUILD_MANIFEST.json' -ErrorAction SilentlyContinue |
        Select-Object -First 12 | ForEach-Object { Write-Output ("  " + $_.FullName.Replace($run.FullName, '') + "  " + [math]::Round($_.Length/1KB,0) + " KB") }
    exit 2
}
Write-Output ("executable = " + $exe.FullName)

$manifestPath = Join-Path $exe.Directory.FullName 'BUILD_MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw ("package has no BUILD_MANIFEST.json beside the executable: " + $manifestPath) }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Write-Output "=== BUILD_MANIFEST.json"
$manifest | ConvertTo-Json -Depth 6

if ($manifest.source_sha -ne $sha) { throw ("manifest source_sha " + $manifest.source_sha + " differs from HEAD " + $sha) }
Write-Output ("PACKAGE_KIND=" + $manifest.package_kind + " RELEASE_READY=" + $manifest.release_ready + " KNOWN_FAILURES=" + @($manifest.known_failures).Count)

# The player-flow verification runs the package in its own directory and requires its six real screenshots.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_player_flow_checks.ps1') -Executable $exe.FullName -SourceSha $manifest.source_sha
Write-Output ("player flow exit = " + $LASTEXITCODE)
