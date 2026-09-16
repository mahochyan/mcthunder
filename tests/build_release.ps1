param(
    [string]$TemplateDirectory = (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'),
    [string[]]$Suites = @('run_checks','run_layout_checks','run_query_checks','run_projectile_checks','run_armor_checks','run_damage_checks','run_recovery_checks','run_replay_checks','run_core_checks','run_drive_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks','run_input_binding_checks','run_app_flow_checks','run_tutorial_checks','run_settings_checks','run_query_cache_checks','run_balance_matrix_checks','run_diagnostic_budget_checks'),
    [switch]$Candidate
)
$ErrorActionPreference = 'Stop'
# WT-040-R1 ④ (user ruling): an INTERNAL development candidate may be produced while the known,
# individually registered failures below are present; a FORMAL release candidate keeps every strict
# gate and is the only artefact allowed to claim release_ready. The register matches a SPECIFIC
# failing check - suite name, how many checks failed, and text that must appear among those failures -
# never a whole suite. A new or different failure inside a registered suite still stops the build.
$deviationRegister = @(
    [pscustomobject]@{ suite='run_industrial_battle_checks'; failures=1; must_match='physically reach central approaches'; reason='registered pre-existing arrival red: only 15/16 reach checks pass (WT-036-R1_INDUSTRIAL_BATTLE_MECHANISM.md)' },
    [pscustomobject]@{ suite='run_challenge_checks';          failures=2; must_match='finite waves with opponent AI untouched'; reason='registered fixture boundary, user ruling B4: the defence-script pilot fails the same check twice' }
)
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
# WT-040-R1 ④: resolve the official export template defensively instead of trusting one default.
# A build launched from a background job reported the template missing even though it exists under
# %APPDATA%, which means the child did not inherit the same environment; the candidates are now
# searched in order and the failure message lists every location that was tried.
$templateCandidates=@()
if ($TemplateDirectory) { $templateCandidates += (Join-Path $TemplateDirectory 'windows_release_x86_64.exe') }
foreach ($root in @($env:APPDATA, (Join-Path $env:USERPROFILE 'AppData\Roaming'), $env:LOCALAPPDATA)) {
    if ($root) { $templateCandidates += (Join-Path $root 'Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe') }
}
try {
    $searchRoot=Join-Path $env:USERPROFILE 'AppData\Roaming\Godot\export_templates'
    if (Test-Path -LiteralPath $searchRoot) {
        $templateCandidates += @(Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter 'windows_release_x86_64.exe' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
} catch { }
$template=$templateCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $template) {
    throw ('Matching official Windows release x64 template is missing; looked in: ' + (($templateCandidates | Where-Object { $_ }) -join ' | ') + '; no candidate created')
}
$TemplateDirectory=Split-Path -Parent $template
Write-Output "TEMPLATE=$template"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runDir = Join-Path $projectRoot "backups/builds/031/$sourceSha/$stamp"
$logs = Join-Path $projectRoot "logs/031/$sourceSha/build-$stamp"
$source = Join-Path $runDir 'clean-source'
$package = Join-Path $runDir 'package'
$outside = Join-Path ([IO.Path]::GetTempPath()) "PixelArmor 独立测试 $stamp"
New-Item -ItemType Directory -Path $source,$package,$logs,$outside -Force | Out-Null
$runs = [System.Collections.Generic.List[object]]::new()
function Run-Checked([string]$Name,[string]$Executable,[string]$Arguments,[string]$WorkingDirectory,[int]$Timeout=300,[string]$Required='',[string]$RequiredArtifact='',[switch]$TolerateNonZeroExit) {
    $stdout=Join-Path $logs "$Name.stdout.log"; $stderr=Join-Path $logs "$Name.stderr.log"
    # WT-040-R1 ④: Start-Process -PassThru handed back an object whose ExitCode was $null even though
    # the child had finished successfully (measured 2026-09-16: the import's own stdout showed two
    # DONE markers and zero errors while RESULTS.json recorded exit_code=null). A real Process handle
    # with redirected streams gives a genuine exit status; a null status is treated as FAILURE, never
    # as zero, and no log marker may substitute for it.
    $psi=[System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$Executable
    $psi.Arguments=$Arguments
    $psi.WorkingDirectory=$WorkingDirectory
    $psi.UseShellExecute=$false
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.CreateNoWindow=$true
    $proc=[System.Diagnostics.Process]::new()
    $proc.StartInfo=$psi
    [void]$proc.Start()
    $outTask=$proc.StandardOutput.ReadToEndAsync()
    $errTask=$proc.StandardError.ReadToEndAsync()
    $exited=$proc.WaitForExit($Timeout*1000)
    $timedOut=-not $exited
    if ($timedOut) { try { $proc.Kill() } catch {}; [void]$proc.WaitForExit(15000) }
    $outText=$outTask.GetAwaiter().GetResult()
    $errText=$errTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText($stdout,$outText)
    [IO.File]::WriteAllText($stderr,$errText)
    $exitCode=$null
    if (-not $timedOut) { try { $exitCode=$proc.ExitCode } catch { $exitCode=$null } }
    $proc.Dispose()
    $output=$outText+$errText
    $exitKnown=($null -ne $exitCode)
    $artifactOk=$true
    if ($RequiredArtifact) { $artifactOk=Test-Path -LiteralPath $RequiredArtifact }
    $passed=(-not $timedOut) -and $exitKnown -and ($exitCode -eq 0) -and ($output -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]') -and $artifactOk
    if ($Required) { $passed=$passed -and ($output -match $Required) }
    $runs.Add([pscustomobject]@{name=$Name;source_sha=$sourceSha;command='"'+$Executable+'" '+$Arguments;exit_code=$exitCode;exit_known=$exitKnown;timed_out=$timedOut;artifact_ok=$artifactOk;passed=$passed})
    $runs | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'RESULTS.json') -Encoding utf8
    Write-Output "$Name passed=$passed exit=$exitCode timeout=$timedOut artifact=$artifactOk"
    if (-not $passed) {
        $why=@()
        if ($timedOut) { $why += 'timed out' }
        if (-not $exitKnown) { $why += 'exit status unreadable (treated as failure)' }
        elseif ($exitCode -ne 0) { $why += "exit=$exitCode" }
        if (-not $artifactOk) { $why += "required artefact missing: $RequiredArtifact" }
        if ($output -match 'SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]') { $why += 'disallowed output marker present' }
        if ($Required -and -not ($output -match $Required)) { $why += "required marker missing: $Required" }
        # WT-040-R1 (user ruling): in a candidate build the regression RUNNER legitimately exits non-zero
        # when a registered suite fails, and the register further down is what judges those failures.
        # ONLY a non-zero exit is tolerated here, and only when the caller asks: a timeout, an unreadable
        # exit status, a missing artefact, a disallowed output marker or a missing required marker still
        # stop the build immediately.
        $tolerable=@()
        if ($TolerateNonZeroExit -and (-not $timedOut) -and $exitKnown -and $artifactOk) {
            $tolerable=@($why | Where-Object { $_ -match '^exit=' })
        }
        $hard=@($why | Where-Object { $tolerable -notcontains $_ })
        if ($hard.Count -eq 0 -and $tolerable.Count -gt 0) {
            Write-Output "$Name kept for register review: $($tolerable -join '; ') (candidate mode; only a registered failure may be accepted)"
        } else {
            throw "Build stopped at $Name ($($why -join '; ')); see recorded output. No verified release ZIP created."
        }
    }
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
Run-Checked 'regression' $shell ('-NoProfile -File "'+$suiteLaunch+'"') $source 7200 'EVIDENCE=' '' -TolerateNonZeroExit:$Candidate
$suiteResults=Get-ChildItem -LiteralPath (Join-Path $source 'logs/031-clean') -Recurse -Filter RESULTS.json | Select-Object -Last 1
$regression=Get-Content -LiteralPath $suiteResults.FullName -Raw | ConvertFrom-Json
$failing=@($regression | Where-Object { -not $_.passed })
$knownFailures=@()
if ($failing.Count -gt 0) {
    if (-not $Candidate) {
        throw "Regression evidence contains a failed suite ($($failing.suite -join ', ')); a formal release candidate requires every gate green. Re-run with -Candidate for an internal development package that is explicitly marked release_ready=false."
    }
    foreach ($f in $failing) {
        $entry=@($deviationRegister | Where-Object { $_.suite -eq $f.suite })
        if ($entry.Count -eq 0) { throw "Candidate build refuses an UNREGISTERED failing suite: $($f.suite) - add it to the register only after the failure is understood and recorded" }
        $suiteLog=Get-ChildItem -LiteralPath $suiteResults.Directory.FullName -Recurse -Filter ($f.suite+'_stdout.log') | Select-Object -Last 1
        $failLines=@()
        if ($suiteLog) { $failLines=@(Select-String -LiteralPath $suiteLog.FullName -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line.Trim() }) }
        if ($failLines.Count -ne [int]$entry[0].failures) { throw "Candidate build: $($f.suite) failed $($failLines.Count) check(s) but the register allows $([int]$entry[0].failures) - a DIFFERENT failure is present" }
        if ($entry[0].must_match -and -not (@($failLines | Where-Object { $_ -match $entry[0].must_match }).Count -gt 0)) { throw "Candidate build: $($f.suite) failures do not carry the registered signature '$($entry[0].must_match)'" }
        $knownFailures += [pscustomobject]@{ suite=$f.suite; checks=$f.checks; failures=$failLines.Count; detail=$failLines; reason=$entry[0].reason }
        Write-Output "KNOWN FAILURE ACCEPTED (candidate only): $($f.suite) - $($failLines.Count) check(s) - $($entry[0].reason)"
    }
}
$releaseReady=(-not $Candidate) -and ($knownFailures.Count -eq 0)
Write-Output "RELEASE_READY=$releaseReady candidate=$([bool]$Candidate) known_failures=$($knownFailures.Count)"
Copy-Item -LiteralPath $suiteResults.Directory.FullName -Destination (Join-Path $logs 'regression') -Recurse
# Explicitly use the already checked template, including when supplied via a different folder.
$preset=Join-Path $source 'export_presets.cfg'
$presetText=[IO.File]::ReadAllText($preset)
$presetText=$presetText.Replace('[preset.2.options]',('[preset.2.options]'+"`n"+'custom_template/release="'+$template.Replace('\','/')+'"'))
[IO.File]::WriteAllText($preset,$presetText,[Text.UTF8Encoding]::new($false))
$exe=Join-Path $package 'PixelArmor.exe'
Run-Checked 'export_release' $engine ('--headless --path "'+$source+'" --export-release "Windows Release" "'+$exe+'"') $source 300 '' $exe
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
$manifest=[ordered]@{source_sha=$sourceSha;version=$versionMatch.Groups[1].Value;engine=$engineVersion;template_sha256=(Get-FileHash -LiteralPath $template).Hash;platform='Windows x64';configuration='release';renderer='gl_compatibility';clean_import=$true;challenge_rules=1;settings_schema=2;profile_schema=3;regression_checks=($regression | Measure-Object -Property checks -Sum).Sum;regression_failed_checks=(@($knownFailures | Measure-Object -Property failures -Sum).Sum);suites=@($regression | Select-Object suite,checks,passed);known_failures=$knownFailures;release_ready=$releaseReady;candidate=[bool]$Candidate;files=$fileHashes;verification=@($runs | Select-Object name,exit_code,exit_known,timed_out,artifact_ok,passed);human='PENDING';public_release=$false}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $package 'BUILD_MANIFEST.json') -Encoding utf8
foreach ($file in $fileHashes) {
    if ((Get-FileHash -LiteralPath (Join-Path $outside $file.name)).Hash -ne $file.sha256) { throw 'Verified extracted package differs from final package' }
}
$kind=$(if ($Candidate) { 'devcandidate' } else { 'release' })
$zip=Join-Path $runDir ('PixelArmor-'+$manifest.version+'-Windows-x64-'+$sourceSha.Substring(0,8)+'-'+$kind+'.zip')
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $zip
@{zip_sha256=(Get-FileHash -LiteralPath $zip).Hash;source_sha=$sourceSha;release_ready=$releaseReady;candidate=[bool]$Candidate;known_failures=$knownFailures;build_manifest_sha256=(Get-FileHash -LiteralPath (Join-Path $package 'BUILD_MANIFEST.json')).Hash;independent_install=$outside;zip=$zip} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'PACKAGE.json') -Encoding utf8
Write-Output "VERIFIED_CANDIDATE=$zip"
Write-Output "PACKAGE_KIND=$kind"
Write-Output "RELEASE_READY=$releaseReady"
Write-Output "INDEPENDENT_INSTALL=$outside"
Write-Output "EVIDENCE=$logs"
