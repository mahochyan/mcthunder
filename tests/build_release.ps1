param(
    [string]$TemplateDirectory = (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'),
    [string[]]$Suites = @('run_checks','run_layout_checks','run_query_checks','run_projectile_checks','run_armor_checks','run_damage_checks','run_recovery_checks','run_replay_checks','run_core_checks','run_drive_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks','run_input_binding_checks','run_app_flow_checks','run_tutorial_checks','run_settings_checks')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
if ($sourceSha -notmatch '^[0-9a-f]{40}$') { throw 'Cannot resolve committed source identity' }
# Build only the committed tree. Ignore untracked local evidence; reject tracked edits.
& git -C $projectRoot diff --quiet HEAD
if ($LASTEXITCODE -ne 0) { throw 'Commit tracked source changes before building a release candidate' }
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Fixed Godot engine is missing' }
$engineVersion = (& $engine --version).Trim()
if ($engineVersion -ne '4.7.2.stable.official.ed1daf0bf') { throw 'Unexpected Godot build; release requires the fixed engine' }
$template = Join-Path $TemplateDirectory 'windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $template)) { throw 'Matching official Windows release x64 template is missing; no candidate created' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runDir = Join-Path $projectRoot "backups/builds/031/$sourceSha/$stamp"
$logs = Join-Path $projectRoot "logs/031/$sourceSha/build-$stamp"
$source = Join-Path $runDir 'clean-source'
$package = Join-Path $runDir 'package'
$outside = Join-Path ([IO.Path]::GetTempPath()) "PixelArmor 独立测试 $stamp"
New-Item -ItemType Directory -Path $source,$package,$logs,$outside -Force | Out-Null
$runs = [System.Collections.Generic.List[object]]::new()
function Run-Checked([string]$Name,[string]$Executable,[string]$Arguments,[string]$WorkingDirectory,[int]$Timeout=300,[string]$Required='') {
    $stdout=Join-Path $logs "$Name.stdout.log"; $stderr=Join-Path $logs "$Name.stderr.log"
    $process=Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut=-not $process.WaitForExit($Timeout*1000)
    if ($timedOut) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $output=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
    $passed=-not $timedOut -and $process.ExitCode -eq 0 -and $output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'
    if ($Required) { $passed=$passed -and $output -match $Required }
    $runs.Add([pscustomobject]@{name=$Name;source_sha=$sourceSha;command='"'+$Executable+'" '+$Arguments;exit_code=$process.ExitCode;timed_out=$timedOut;passed=$passed})
    $runs | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'RESULTS.json') -Encoding utf8
    Write-Output "$Name passed=$passed"
    if (-not $passed) { throw "Build stopped at $Name; see recorded output. No verified release ZIP created." }
}
$archive=Join-Path $runDir 'committed-source.zip'
& git -C $projectRoot archive --format=zip "--output=$archive" $sourceSha assets configs scripts scenes tests authoring docs project.godot export_presets.cfg icon.svg START_GAME.bat .gitignore
if ($LASTEXITCODE -ne 0) { throw 'Committed source extraction failed' }
Expand-Archive -LiteralPath $archive -DestinationPath $source
if (Test-Path -LiteralPath (Join-Path $source '.godot')) { throw 'Clean source unexpectedly contains an import cache' }
# This fresh checkout proves imports are reproducible without deleting the user cache.
Run-Checked 'fresh_import' $engine ('--headless --path "'+$source+'" --editor --import') $source 300
$shell = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $shell)) { $shell=Join-Path $PSHOME 'powershell.exe' }
$suiteLiteral = ($Suites | ForEach-Object { if ($_ -notmatch '^run_[a-z0-9_]+$') { throw 'Invalid suite identifier' }; "'$_'" }) -join ','
# Invoke a generated script rather than embedding executable text in -Command.
$suiteLaunch=Join-Path $runDir 'run-regression.ps1'
@"
& '$($source.Replace("'","''"))/tests/run_suite_checks.ps1' -SourceSha '$sourceSha' -EnginePath '$($engine.Replace("'","''"))' -Order '031-clean' -Suites @($suiteLiteral)
exit `$LASTEXITCODE
"@ | Set-Content -LiteralPath $suiteLaunch -Encoding utf8
Run-Checked 'regression' $shell ('-NoProfile -File "'+$suiteLaunch+'"') $source 7200 'EVIDENCE='
$suiteResults=Get-ChildItem -LiteralPath (Join-Path $source 'logs/031-clean') -Recurse -Filter RESULTS.json | Select-Object -Last 1
$regression=Get-Content -LiteralPath $suiteResults.FullName -Raw | ConvertFrom-Json
if (@($regression | Where-Object { -not $_.passed }).Count -gt 0) { throw 'Regression evidence contains a failed suite' }
Copy-Item -LiteralPath $suiteResults.Directory.FullName -Destination (Join-Path $logs 'regression') -Recurse
# Explicitly use the already checked template, including when supplied via a different folder.
$preset=Join-Path $source 'export_presets.cfg'
$presetText=[IO.File]::ReadAllText($preset)
$presetText=$presetText.Replace('[preset.2.options]',('[preset.2.options]'+"`n"+'custom_template/release="'+$template.Replace('\','/')+'"'))
[IO.File]::WriteAllText($preset,$presetText,[Text.UTF8Encoding]::new($false))
$exe=Join-Path $package 'PixelArmor.exe'
Run-Checked 'export_release' $engine ('--headless --path "'+$source+'" --export-release "Windows Release" "'+$exe+'"') $source 300
Run-Checked 'engine_notices' $engine ('--headless --path "'+$source+'" -s res://tests/write_engine_notices.gd -- "'+(Join-Path $package 'GODOT_LICENSES.txt')+'"') $source
Copy-Item -LiteralPath (Join-Path $source 'assets/fonts/OFL.txt') -Destination (Join-Path $package 'FONT_OFL.txt')
Copy-Item -LiteralPath (Join-Path $source 'docs/DATA_RECOVERY_029.md') -Destination (Join-Path $package '数据与恢复说明.md')
Copy-Item -LiteralPath (Join-Path $source 'docs/RELEASE_README_031.txt') -Destination (Join-Path $package '开始游戏.txt')
Copy-Item -LiteralPath (Join-Path $source 'docs/RELEASE_LICENSES_031.md') -Destination (Join-Path $package '素材与许可.md')
$trialZip=Join-Path $runDir 'unverified-candidate.zip'
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $trialZip
Expand-Archive -LiteralPath $trialZip -DestinationPath $outside
$independentExe=Join-Path $outside 'PixelArmor.exe'
Run-Checked 'independent_default_start' $independentExe '--headless --quit-after 30' $outside
Run-Checked 'independent_content' $independentExe '--headless --fixed-fps 60 -- --verify-installation' $outside 240 'RELEASE_CHECKS_PASS'
Run-Checked 'independent_window' $independentExe '--resolution 1280x720 -- --verify-installation' $outside 240 'RELEASE_CHECKS_PASS'
$captureLine=Select-String -LiteralPath (Join-Path $logs 'independent_window.stdout.log') -Pattern '^RELEASE_CAPTURE=(.+)$' | Select-Object -Last 1
if (-not $captureLine) { throw 'Release window did not capture an actual frame' }
Copy-Item -LiteralPath $captureLine.Matches[0].Groups[1].Value -Destination (Join-Path $logs 'release_battle.png')
$versionMatch=[regex]::Match([IO.File]::ReadAllText((Join-Path $source 'project.godot')),'config/version="([^"]+)"')
$fileHashes=@(Get-ChildItem -LiteralPath $package -File | ForEach-Object { [ordered]@{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
$manifest=[ordered]@{source_sha=$sourceSha;version=$versionMatch.Groups[1].Value;engine=$engineVersion;template_sha256=(Get-FileHash -LiteralPath $template).Hash;platform='Windows x64';configuration='release';renderer='gl_compatibility';clean_import=$true;challenge_rules=1;settings_schema=2;profile_schema=3;regression_checks=($regression | Measure-Object -Property checks -Sum).Sum;suites=@($regression | Select-Object suite,checks,passed);files=$fileHashes;verification=@($runs | Select-Object name,exit_code,passed);human='PENDING';public_release=$false}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $package 'BUILD_MANIFEST.json') -Encoding utf8
foreach ($file in $fileHashes) {
    if ((Get-FileHash -LiteralPath (Join-Path $outside $file.name)).Hash -ne $file.sha256) { throw 'Verified extracted package differs from final package' }
}
$zip=Join-Path $runDir ('PixelArmor-'+$manifest.version+'-Windows-x64-'+$sourceSha.Substring(0,8)+'.zip')
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $zip
@{zip_sha256=(Get-FileHash -LiteralPath $zip).Hash;source_sha=$sourceSha;build_manifest_sha256=(Get-FileHash -LiteralPath (Join-Path $package 'BUILD_MANIFEST.json')).Hash;independent_install=$outside;zip=$zip} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'PACKAGE.json') -Encoding utf8
Write-Output "VERIFIED_CANDIDATE=$zip"
Write-Output "INDEPENDENT_INSTALL=$outside"
Write-Output "EVIDENCE=$logs"
