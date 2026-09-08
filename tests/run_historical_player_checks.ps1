param([int]$TimeoutSeconds = 180)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sha = (& git -C $projectRoot rev-parse HEAD).Trim()
$stamp = 'player-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$logs = Join-Path $projectRoot "logs/020/$sha/$stamp"
$shots = Join-Path $projectRoot "docs/evidence/020/$sha/$stamp"
New-Item -ItemType Directory -Force -Path $logs,$shots | Out-Null
$steps = @(
    @{Name='garage'; Count=80; Args='--path "' + $projectRoot + '" --fixed-fps 60 -- --historical-play-check --shot-dir "' + $shots + '"'},
    @{Name='arc_fixture'; Count=4; Args='--path "' + $projectRoot + '" --fixed-fps 60 -s res://tests/run_limited_arc_window.gd'}
)
$results = [System.Collections.Generic.List[object]]::new()
foreach ($step in $steps) {
    $out = Join-Path $logs ($step.Name+'_stdout.log')
    $err = Join-Path $logs ($step.Name+'_stderr.log')
    $p = Start-Process -FilePath $engine -ArgumentList $step.Args -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $timedOut = -not $p.WaitForExit($TimeoutSeconds*1000)
    if ($timedOut) { Stop-Process -Id $p.Id -Force }
    $p.WaitForExit()
    $text = [IO.File]::ReadAllText($out)
    $errors = [IO.File]::ReadAllText($err)
    $marker = [regex]::Match($text,'=== 结果: (\d+) 项检查, (\d+) 失败 ===')
    $passed = -not $timedOut -and $p.ExitCode -eq 0 -and $marker.Success -and [int]$marker.Groups[1].Value -eq $step.Count -and [int]$marker.Groups[2].Value -eq 0 -and ($text+$errors) -notmatch '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:'
    $row = [pscustomobject]@{step=$step.Name; source_sha=$sha; command=('"'+$engine+'" '+$step.Args); engine=(& $engine --version).Trim(); exit_code=$p.ExitCode; timed_out=$timedOut; checks=if($marker.Success){[int]$marker.Groups[1].Value}else{0}; passed=$passed}
    $results.Add($row)
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs 'RESULTS.json') -Encoding utf8
    Write-Output ($step.Name+': passed='+$passed+' exit='+$p.ExitCode)
}
$images = @(Get-ChildItem -LiteralPath $shots -Filter '*.png' | ForEach-Object { [pscustomobject]@{file=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
[pscustomobject]@{source_sha=$sha; images=$images; graphical_review='PENDING'; human='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $shots 'SESSION.json') -Encoding utf8
Write-Output ('EVIDENCE='+$logs)
Write-Output ('SCREENSHOTS='+$shots)
if (@($results | Where-Object { -not $_.passed }).Count -gt 0 -or $images.Count -ne 28) { exit 1 }
exit 0
