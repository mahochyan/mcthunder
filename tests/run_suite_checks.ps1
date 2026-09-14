param(
    [string[]]$Suites = @('run_checks','run_layout_checks','run_query_checks','run_slope_pivot_checks','run_model_binding_checks','run_suspension_checks','run_track_drive_checks','run_powertrain_checks','run_query_cache_checks','run_simulation_phase_checks','run_turret_mechanism_checks','run_loading_checks','run_partial_support_checks','run_landing_contact_checks','run_landing_response_checks','run_moving_contact_checks','run_surface_drive_checks','run_hull_frame_checks','run_chassis_recoil_checks','run_track_damage_checks','run_ammo_compartment_checks','run_fire_control_checks','run_projectile_checks','run_armor_checks','run_damage_checks','run_recovery_checks','run_replay_checks','run_core_checks','run_drive_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks'),
    [int]$TimeoutSeconds = 900,
    [string]$Order = '007',
    [string]$SourceSha = '',
    [string]$EnginePath = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
if('run_art_checks' -in $Suites -and 'run_menu_fire_handoff_checks' -notin $Suites){$Suites += 'run_menu_fire_handoff_checks'}
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = if ($EnginePath) { $EnginePath } else { Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $engine)) { throw "Fixed Godot missing: $engine" }
$sourceSha = if ($SourceSha) { $SourceSha } else { (& git -C $projectRoot rev-parse HEAD).Trim() }
$runPath = Join-Path $projectRoot ("logs/$Order/$sourceSha/" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $runPath | Out-Null
$engineVersion = (& $engine --version).Trim()
$summary = [System.Collections.Generic.List[object]]::new()
$steps = @(@{Name='import'; Args='--headless --path "' + $projectRoot + '" --editor --import'})
foreach ($suite in $Suites) {
    $simulationClock = if ($suite -in @('run_app_flow_checks','run_tutorial_checks','run_settings_checks','run_input_binding_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks')) { ' --fixed-fps 60' } else { '' }
    $steps += @{Name=$suite; Args='--headless --path "' + $projectRoot + '"' + $simulationClock + ' -s "res://tests/' + $suite + '.gd"'}
}
foreach ($step in $steps) {
    $stdout = Join-Path $runPath ($step.Name + '_stdout.log')
    $stderr = Join-Path $runPath ($step.Name + '_stderr.log')
    $command = '"' + $engine + '" ' + $step.Args
    $process = Start-Process -FilePath $engine -ArgumentList $step.Args -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $outputRead = Read-SuiteLog -Path $stdout
    $errorRead = Read-SuiteLog -Path $stderr
    $output = $outputRead.Text
    $errors = $errorRead.Text
    $logReadErrors = @(@($outputRead.Error,$errorRead.Error) | Where-Object { $null -ne $_ })
    $errorLines = @([regex]::Matches($errors, '(?m)^ERROR:.*') | ForEach-Object { $_.Value.Trim() })
    $allowedErrors = @()
    if ($step.Name -eq 'run_layout_checks') {
        $allowedErrors = @(
            'ERROR: ArmorPatchMesh: triangles: winding disagrees with outward normal; triangles: winding disagrees with outward normal',
            'ERROR: LayoutCatalog: layout not found: nonexistent_layout (res://configs/layouts/nonexistent_layout.tres)',
            'ERROR: LayoutCatalog: empty layout_id'
        )
    }
    $unexpected = @($errorLines | Where-Object { $_ -notin $allowedErrors })
    foreach ($expected in $allowedErrors) {
        if (@($errorLines | Where-Object { $_ -eq $expected }).Count -ne 1) { $unexpected += "Expected exactly one negative-fixture error: $expected" }
    }
    $scriptError = ($errors + $output) -match 'SCRIPT ERROR:|Parse Error:'
    $checkMatch = [regex]::Match($output, '=== 结果: (\d+) 项检查, (\d+) 失败 ===')
    $assertionsPass = $step.Name -eq 'import' -or ($checkMatch.Success -and [int]$checkMatch.Groups[2].Value -eq 0 -and $output -match '(?m)^[A-Z_]*CHECKS_PASS\s*$')
    # WT-036-R1: two environment artefacts made verdicts wrong - Start-Process sometimes leaves
    # ExitCode null, and the captured log can arrive with the Chinese result line mojibaked so the
    # regex above misses a suite that actually printed "N checks, 0 failures". The verdict therefore
    # rests on the log evidence: either the parsed result line with zero failures, or the ASCII
    # CHECKS_PASS marker that every suite prints only when its failure count is zero - plus no script
    # error and no unexpected errors. The process exit code is recorded for information only.
    $markerPass = $output -match '(?m)^[A-Z_]*CHECKS_PASS\s*$'
    $evidencePass = ($assertionsPass -or ($step.Name -ne 'import' -and $markerPass))
    $exitCode = $process.ExitCode
    $passed = -not $timedOut -and -not $scriptError -and $unexpected.Count -eq 0 -and $evidencePass -and $logReadErrors.Count -eq 0
    $row = [pscustomobject]@{suite=$step.Name; source_sha=$sourceSha; engine=$engineVersion; command=$command; exit_code=$exitCode; timed_out=$timedOut; checks=if($checkMatch.Success){[int]$checkMatch.Groups[1].Value}else{0}; passed=$passed; script_error=$scriptError; unexpected_errors=$unexpected; expected_error_count=$allowedErrors.Count; marker_pass=$markerPass}
    $summary.Add($row)
    $row | Add-Member -NotePropertyName log_read_errors -NotePropertyValue $logReadErrors
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runPath 'RESULTS.json') -Encoding utf8
    Write-Output ("{0}: checks={1} exit={2} passed={3} unexpected_errors={4}" -f $step.Name,$row.checks,$row.exit_code,$passed,$unexpected.Count)
    if ($step.Name -eq 'import' -and -not $passed) { break }
}
Write-Output ("EVIDENCE=" + $runPath)
if (@($summary | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
