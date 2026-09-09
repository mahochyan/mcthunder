param([ValidateSet('player','wreck','showcase','battle')][string]$Mode='player',[int]$TimeoutSeconds=300,[string]$EvidenceTag='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sha=(& git -C $projectRoot rev-parse HEAD).Trim()
$identity=if($EvidenceTag){$EvidenceTag}else{$sha}
$stamp=$Mode+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
$logs=Join-Path $projectRoot "logs/025/$identity/$stamp"
$shots=Join-Path $projectRoot "docs/evidence/025/$identity/$stamp"
New-Item -ItemType Directory -Force -Path $logs,$shots | Out-Null
$suffix=switch($Mode){
    'player' {'-- --art-play-check'}
    'wreck' {'-s res://tests/run_wreck_visual_checks.gd -- --capture'}
    'showcase' {'-s res://tests/run_art_showcase.gd --'}
    'battle' {'-s res://tests/run_art_battle_render_checks.gd --'}
}
$cap=if($Mode -eq 'battle'){120}else{60}
$argsText='--path "'+$projectRoot+'" --position 1280,0 --max-fps '+$cap+' '+$suffix+' --shot-dir "'+$shots+'"'
$out=Join-Path $logs 'stdout.log'; $err=Join-Path $logs 'stderr.log'
$p=Start-Process -FilePath $engine -ArgumentList $argsText -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
$timedOut=-not $p.WaitForExit($TimeoutSeconds*1000)
if($timedOut){Stop-Process -Id $p.Id -Force}
$p.WaitForExit()
$output=[IO.File]::ReadAllText($out); $errors=[IO.File]::ReadAllText($err)
$marker=[regex]::Match($output,'=== 结果: (\d+) 项检查, (\d+) 失败 ===')
$passMarker=switch($Mode){'player' {'ART_PLAYER_CHECKS_PASS'} 'wreck' {'WRECK_VISUAL_CHECKS_PASS'} 'showcase' {'ART_SHOWCASE_CHECKS_PASS'} 'battle' {'ART_BATTLE_RENDER_CHECKS_PASS'}}
$images=@(Get-ChildItem -LiteralPath $shots -Filter '*.png' | ForEach-Object { [pscustomobject]@{file=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })
$expected=switch($Mode){'player' {7} 'wreck' {8} 'showcase' {4} 'battle' {4}}
$passed=-not $timedOut -and $p.ExitCode -eq 0 -and $marker.Success -and [int]$marker.Groups[2].Value -eq 0 -and $output.Contains($passMarker) -and ($output+$errors) -notmatch '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:' -and $images.Count -eq $expected
[pscustomobject]@{source_sha=$sha;uncommitted_candidate=[bool]$EvidenceTag;command=('"'+$engine+'" '+$argsText);engine=(& $engine --version).Trim();exit_code=$p.ExitCode;timed_out=$timedOut;checks=if($marker.Success){[int]$marker.Groups[1].Value}else{0};image_count=$images.Count;passed=$passed} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $logs 'RESULTS.json') -Encoding utf8
[pscustomobject]@{source_sha=$sha;uncommitted_candidate=[bool]$EvidenceTag;images=$images;graphical_review='PENDING';human='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $shots 'SESSION.json') -Encoding utf8
Write-Output "PASSED=$passed"
Write-Output "EVIDENCE=$logs"
Write-Output "SCREENSHOTS=$shots"
if(-not $passed){exit 1}
exit 0
