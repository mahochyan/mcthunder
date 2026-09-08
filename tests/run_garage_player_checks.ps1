param([int]$TimeoutSeconds = 360,[string]$EvidenceTag = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sha = (& git -C $projectRoot rev-parse HEAD).Trim()
$folder = if ($EvidenceTag) { $EvidenceTag } else { $sha }
$stamp = 'player-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$logs = Join-Path $projectRoot "logs/022/$folder/$stamp"
$shots = Join-Path $projectRoot "docs/evidence/022/$folder/$stamp"
New-Item -ItemType Directory -Force -Path $logs,$shots | Out-Null
$argsText = '--path "'+$projectRoot+'" --fixed-fps 60 --disable-vsync -- --garage-play-check --shot-dir "'+$shots+'"'
$out = Join-Path $logs 'garage_stdout.log'
$err = Join-Path $logs 'garage_stderr.log'
$p = Start-Process -FilePath $engine -ArgumentList $argsText -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
$timedOut = -not $p.WaitForExit($TimeoutSeconds*1000)
if ($timedOut) { Stop-Process -Id $p.Id -Force }
$p.WaitForExit()
$output = [IO.File]::ReadAllText($out)
$errors = [IO.File]::ReadAllText($err)
$marker = [regex]::Match($output,'=== 结果: (\d+) 项检查, (\d+) 失败 ===')
$passed = -not $timedOut -and $p.ExitCode -eq 0 -and $marker.Success -and [int]$marker.Groups[1].Value -eq 68 -and [int]$marker.Groups[2].Value -eq 0 -and ($output+$errors) -notmatch '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:'
[pscustomobject]@{source_sha=$sha; uncommitted_candidate=[bool]$EvidenceTag; command=('"'+$engine+'" '+$argsText); engine=(& $engine --version).Trim(); exit_code=$p.ExitCode; timed_out=$timedOut; checks=if($marker.Success){[int]$marker.Groups[1].Value}else{0}; passed=$passed} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs 'RESULTS.json') -Encoding utf8
$images = @(Get-ChildItem -LiteralPath $shots -Filter '*.png' | ForEach-Object { [pscustomobject]@{file=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
[pscustomobject]@{source_sha=$sha; uncommitted_candidate=[bool]$EvidenceTag; images=$images; graphical_review='PENDING'; human='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $shots 'SESSION.json') -Encoding utf8
Write-Output ('PASSED='+$passed)
Write-Output ('EVIDENCE='+$logs)
Write-Output ('SCREENSHOTS='+$shots)
if (-not $passed -or $images.Count -ne 15) { exit 1 }
exit 0
