param([string]$Order = '011')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$candidateBase = [IO.Path]::GetFullPath((Join-Path $projectRoot 'backups/candidates'))
$candidateRoot = [IO.Path]::GetFullPath((Join-Path $candidateBase "$Order/$sourceSha/PixelArmor"))
if (-not $candidateRoot.StartsWith($candidateBase + [IO.Path]::DirectorySeparatorChar)) { throw 'Candidate path escaped workspace' }
if (Test-Path -LiteralPath $candidateRoot) { throw "Candidate already exists: $candidateRoot" }
New-Item -ItemType Directory -Force -Path $candidateRoot | Out-Null
foreach ($entry in @('scripts','scenes','configs','assets','project.godot','icon.svg','START_GAME.bat','开始试玩.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $entry) -Destination $candidateRoot -Recurse
}
$engineDir = Join-Path $candidateRoot 'tools/godot'
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null
foreach ($entry in @('Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','.gdignore')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "tools/godot/$entry") -Destination $engineDir
}
$logRoot = Join-Path $projectRoot "logs/$Order/$sourceSha/candidate"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$engine = Join-Path $engineDir 'Godot_v4.7.2-stable_win64_console.exe'
$runs = @(@{name='import';args='--headless --path "'+$candidateRoot+'" --editor --import'},@{name='startup';args='--headless --path "'+$candidateRoot+'" --quit-after 8'})
$results = @()
foreach ($run in $runs) {
    $process = Start-Process -FilePath $engine -ArgumentList $run.args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logRoot/$($run.name)_stdout.log" -RedirectStandardError "$logRoot/$($run.name)_stderr.log"
    $timeout = -not $process.WaitForExit(120000)
    if ($timeout) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $output = [IO.File]::ReadAllText("$logRoot/$($run.name)_stdout.log") + [IO.File]::ReadAllText("$logRoot/$($run.name)_stderr.log")
    $passed = -not $timeout -and $process.ExitCode -eq 0 -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:'
    $results += @{name=$run.name;command='"'+$engine+'" '+$run.args;exit_code=$process.ExitCode;timed_out=$timeout;passed=$passed}
    if (-not $passed) { break }
}
$manifest = @{source_sha=$sourceSha;candidate=$candidateRoot;engine=(& $engine --version).Trim();type='local source-and-engine candidate, not exported executable';runs=$results;human='NOT_RUN';font_sha256=(Get-FileHash -LiteralPath (Join-Path $candidateRoot 'assets/fonts/NotoSansCJKsc-Regular.otf')).Hash}
$manifest | ConvertTo-Json -Depth 6 | Set-Content "$logRoot/RESULTS.json" -Encoding utf8
$manifest | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $candidateRoot 'CANDIDATE.json') -Encoding utf8
Write-Output "CANDIDATE=$candidateRoot"
Write-Output "EVIDENCE=$logRoot"
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
