$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engine=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$folder=Join-Path $projectRoot ('logs/wt009-view/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$serverArgs='--headless --path "'+$projectRoot+'" --max-fps 60 --quit-after 1200 -s res://scripts/network/server_main.gd -- 19111'
$viewArgs='--path "'+$projectRoot+'" --max-fps 60 -s res://tests/run_network_view_checks.gd -- "'+(Join-Path $folder 'client.png')+'"'
$server=Start-Process -FilePath $engine -ArgumentList $serverArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $folder 'server.log') -RedirectStandardError (Join-Path $folder 'server.err.log')
$view=Start-Process -FilePath $engine -ArgumentList $viewArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $folder 'view.log') -RedirectStandardError (Join-Path $folder 'view.err.log')
$view.WaitForExit(); $server.WaitForExit()
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
$logs=@('view.log','view.err.log','server.log','server.err.log') | ForEach-Object { Read-SuiteLog (Join-Path $folder $_) }
$text=($logs.Text -join "`n")
$passed=$view.ExitCode -eq 0 -and $server.ExitCode -eq 0 -and @($logs | Where-Object Error).Count -eq 0 -and $text -match 'NETWORK_VIEW_CHECKS_PASS' -and $text -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
$hashes=@{}
foreach ($file in @('scripts/network/network_battle_client.gd','scripts/network/network_client_view.gd','scripts/network/network_battle_server.gd','tests/run_network_view_checks.gd')) { $hashes[$file]=(Get-FileHash (Join-Path $projectRoot $file)).Hash }
@{passed=$passed;source=(& git -C $projectRoot rev-parse HEAD).Trim();build='source-worktree';engine_sha256=(Get-FileHash $engine).Hash;file_hashes=$hashes;server_command=$serverArgs;view_command=$viewArgs;server_exit=$server.ExitCode;view_exit=$view.ExitCode} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $folder 'RESULTS.json')
Write-Output $text
Write-Output ('EVIDENCE='+$folder)
if (-not $passed) { exit 1 }
