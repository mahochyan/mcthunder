param([ValidateSet('player','battle')][string]$Mode='player',[string]$EvidenceTag='',[int]$TimeoutSeconds=180)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$sha=(& git -C $projectRoot rev-parse HEAD).Trim()
$identity=if($EvidenceTag){$EvidenceTag}else{$sha}
$stamp=$Mode+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
$logs=Join-Path $projectRoot "logs/026/$identity/$stamp"
$shots=Join-Path $projectRoot "docs/evidence/026/$identity/$stamp"
New-Item -ItemType Directory -Force -Path $logs,$shots | Out-Null
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$suffix=if($Mode -eq 'player'){'-- --feedback-play-check'}else{'-s res://tests/run_feedback_battle_render.gd --'}
$arguments='--path "'+$projectRoot+'" --position 1280,0 --max-fps 60 '+$suffix+' --shot-dir "'+$shots+'"'
$p=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'stdout.log') -RedirectStandardError (Join-Path $logs 'stderr.log')
$timeout=-not $p.WaitForExit($TimeoutSeconds*1000)
if($timeout){Stop-Process -Id $p.Id -Force}
$p.WaitForExit()
$output=[IO.File]::ReadAllText((Join-Path $logs 'stdout.log'))+[IO.File]::ReadAllText((Join-Path $logs 'stderr.log'))
$marker=[regex]::Match($output,'=== 结果: (\d+) 项检查, (\d+) 失败 ===')
$images=@(Get-ChildItem -LiteralPath $shots -Filter '*.png' | ForEach-Object { @{file=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })
$passed=-not $timeout -and $p.ExitCode -eq 0 -and $marker.Success -and [int]$marker.Groups[2].Value -eq 0 -and $output -notmatch '(?m)^ERROR:|SCRIPT ERROR:'
@{source_sha=$sha;uncommitted_candidate=[bool]$EvidenceTag;command=$arguments;exit_code=$p.ExitCode;timed_out=$timeout;passed=$passed;checks=if($marker.Success){[int]$marker.Groups[1].Value}else{0}} | ConvertTo-Json | Set-Content (Join-Path $logs 'RESULTS.json')
@{source_sha=$sha;uncommitted_candidate=[bool]$EvidenceTag;images=$images;graphical_review='PENDING';human='NOT_RUN';listening='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $shots 'SESSION.json')
Write-Output "PASSED=$passed"
Write-Output "EVIDENCE=$logs"
Write-Output "SCREENSHOTS=$shots"
if(-not $passed){exit 1}
