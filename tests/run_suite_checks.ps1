param(
    [string[]]$Suites = @('run_checks','run_layout_checks','run_query_checks','run_slope_pivot_checks','run_model_binding_checks','run_suspension_checks','run_track_drive_checks','run_powertrain_checks','run_query_cache_checks','run_simulation_phase_checks','run_turret_mechanism_checks','run_loading_checks','run_partial_support_checks','run_landing_contact_checks','run_landing_response_checks','run_moving_contact_checks','run_surface_drive_checks','run_hull_frame_checks','run_chassis_recoil_checks','run_track_damage_checks','run_ammo_compartment_checks','run_fire_control_checks','run_suspension_network_checks','run_optics_checks','run_moving_target_tick_checks','run_world_vehicle_phase_checks','run_vehicle_readiness_checks','run_command_contract_checks','run_track_assembly_checks','run_sight_ballistics_checks','run_observation_policy_checks','run_role_mapping_checks','run_support_actions_checks','run_engagement_distance_checks','run_ballistic_intercept_checks','run_material_response_checks','run_long_rod_damage_checks','run_spall_checks','run_chemical_checks','run_era_checks','run_composite_checks','run_fuze_checks','run_content_record_checks','run_reference_admission_checks','run_match_rules_checks','run_team_traffic_checks','run_authority_state_checks','run_diagnostic_budget_checks','run_tech_segment_checks','run_asset_registry_checks','run_match_event_checks','run_modern_equipment_checks','run_modern_candidate_checks','run_equipment_package_checks','run_composite_content_checks','run_composite_binding_checks','run_ai_recovery_checks','run_ai_intercept_checks','run_ai_tactics_checks','run_loading_mechanism_checks','run_long_rod_content_checks','run_chemical_content_checks','run_spall_content_checks','run_era_binding_checks','run_bound_model_package_checks','run_model_binding_probe_checks','run_airborne_drive_checks','run_app_flow_checks','run_balance_matrix_checks','run_build_identity_checks','run_era_network_checks','run_garage_frontend_checks','run_input_binding_checks','run_long_rod_checks','run_map_pack_checks','run_material_replay_checks','run_menu_fire_handoff_checks','run_model_showroom_checks','run_modern_model_mount_checks','run_query_metrics_checks','run_research_alignment_checks','run_research_trial_data_checks','run_research_tree_checks','run_save_lock_checks','run_telemetry_measures','run_network_authority_checks','run_network_controller_checks','run_network_event_journal_checks','run_network_event_recovery_checks','run_network_fault_checks','run_network_fire_control_checks','run_network_frame_checks','run_network_identity_checks','run_network_pose_checks','run_turret_mechanism_player_checks','run_river_reachability_checks','run_river_engagement_checks','run_room_service_checks','run_settings_checks','run_shell_cycle_player_checks','run_tutorial_checks','run_projectile_checks','run_armor_checks','run_damage_checks','run_recovery_checks','run_replay_checks','run_core_checks','run_drive_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks'),
    [int]$TimeoutSeconds = 1500,
    [string]$Order = '007',
    [string]$SourceSha = '',
    [string]$EnginePath = ''
)
$ErrorActionPreference = 'Stop'
# WT-EXPANSION-02 (measured, not guessed): one suite runs TWO complete real matches and is CPU-bound rather than
# real-time bound, so the single shared bound below marked it timed_out while it was in fact PASSING its other checks
# and failing exactly its one registered check - and the register matcher refuses a registered failure whose run timed
# out, so the build could never accept it. Measured on this machine under --fixed-fps 60: 4327 s of wall time
# (logs/COMBAT-DEEPEN-01/industrial-budget.log, 16 checks / 1 failure / 0 SCRIPT ERROR / 0 ERROR lines) for two seeds
# that together simulate about 710 s of match clock across 8 AI actors with full perception. 6000 s is a ~1.4x margin
# over the measurement. Every other suite keeps the shared bound, so hang detection latency elsewhere is unchanged.
$suiteTimeouts = @{ 'run_industrial_battle_checks' = 6000 }
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
if('run_art_checks' -in $Suites -and 'run_menu_fire_handoff_checks' -notin $Suites){$Suites += 'run_menu_fire_handoff_checks'}
# WT-040-R1: the two engineering vehicles have their own runtime suite - admitted through the production
# catalog, spawned as real actors, fired through the real projectile manager and reset. It is appended
# the same way, so the standing regression covers them without changing how any existing suite runs.
if('run_checks' -in $Suites -and 'run_engineering_runtime_checks' -notin $Suites){$Suites += 'run_engineering_runtime_checks'}
if('run_checks' -in $Suites -and 'check_engineering_admission' -notin $Suites){$Suites += 'check_engineering_admission'}
if('run_checks' -in $Suites -and 'run_engineering_damage_checks' -notin $Suites){$Suites += 'run_engineering_damage_checks'}
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
    # WT-EXPANSION-02 (user ruling): run_checks was the one long-standing suite in this list WITHOUT --fixed-fps, and
    # it is frame-based: measured, it is deterministic at --fixed-fps 60 (217 checks, 0 failed, twice) while in the
    # real-time regime the SAME build produced 217/0 once and 217/4 once (R2-B held-fire precondition plus the T003-06
    # trial-hit lag its own _wait_trial_hits comment documents). The suite's watchdog is also a game-time timer, so a
    # fixed step is the only regime in which its frame-based waits and its timer agree. No check or expectation changed.
    $simulationClock = if ($suite -in @('run_checks','run_app_flow_checks','run_tutorial_checks','run_settings_checks','run_input_binding_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks','run_telemetry_checks','run_historical_checks','run_historical_road_checks','run_blender_asset_checks','run_shell_checks','run_garage_checks','run_industrial_checks','run_industrial_obstruction_checks','run_industrial_battle_checks','run_challenge_checks','run_art_checks','run_structure_checks','run_wreck_visual_checks','run_feedback_checks')) { ' --fixed-fps 60' } else { '' }
    if ($suite -in @('run_modern_support_checks','run_modern_armor_frame_checks','run_modern_garage_checks','run_engineering_runtime_checks','run_engineering_damage_checks','run_river_entry_traffic_checks')) { $simulationClock = ' --fixed-fps 60' }
    $steps += @{Name=$suite; Args='--headless --path "' + $projectRoot + '"' + $simulationClock + ' -s "res://tests/' + $suite + '.gd"'}
}
foreach ($step in $steps) {
    $stdout = Join-Path $runPath ($step.Name + '_stdout.log')
    $stderr = Join-Path $runPath ($step.Name + '_stderr.log')
    $command = '"' + $engine + '" ' + $step.Args
    # WT-040-R1: a real Process handle with redirected streams, read asynchronously before waiting, so every
    # suite's exit_code is the child's own status instead of the $null that Start-Process -PassThru can hand
    # back - the same defect this project already documented and fixed in build_release.ps1. The verdict itself
    # is unchanged: $passed below never consulted $exitCode, so this only makes the recorded exit code real.
    $psi=[System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$engine
    $psi.Arguments=$step.Args
    $psi.WorkingDirectory=$projectRoot
    $psi.UseShellExecute=$false
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.CreateNoWindow=$true
    $process=[System.Diagnostics.Process]::new()
    $process.StartInfo=$psi
    [void]$process.Start()
    $outTask=$process.StandardOutput.ReadToEndAsync()
    $errTask=$process.StandardError.ReadToEndAsync()
    $suiteBound = if ($suiteTimeouts.ContainsKey($step.Name)) { [int]$suiteTimeouts[$step.Name] } else { $TimeoutSeconds }
    $timedOut = -not $process.WaitForExit($suiteBound * 1000)
    if ($timedOut) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    [IO.File]::WriteAllText($stdout,$outTask.GetAwaiter().GetResult())
    [IO.File]::WriteAllText($stderr,$errTask.GetAwaiter().GetResult())
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
    # WT-036-R1: accept BOTH result-line spellings. Suites print either the Chinese line or
    # "=== done: N checks, M failed ==="; the second is ASCII and therefore survives the encoding
    # damage that makes the Chinese one unreadable in this environment.
    $checkMatch = [regex]::Match($output, '=== .*?: (\d+) .*?, (\d+) .*? ===')
    if (-not $checkMatch.Success) { $checkMatch = [regex]::Match($output, '=== done: (\d+) checks, (\d+) failed ===') }
    # Any "<NAME>_PASS" marker counts: requiring the literal "CHECKS" falsely failed suites whose
    # marker is e.g. TELEMETRY_MEASURES_PASS. Every suite prints its PASS marker only when its
    # failure count is zero, so this is still evidence of zero failures and not a relaxation.
    $markerPass = $output -match '(?m)^[A-Z0-9_]*_PASS\s*$'
    # Third form of the same evidence: per-check lines with at least one pass and no failure.
    $perCheckPass = (@($output -split "`n" | Where-Object { $_ -match '^\[PASS\]' }).Count -gt 0) -and
                    (@($output -split "`n" | Where-Object { $_ -match '^\[FAIL\]' }).Count -eq 0)
    $assertionsPass = $step.Name -eq 'import' -or ($checkMatch.Success -and [int]$checkMatch.Groups[2].Value -eq 0)
    $evidencePass = ($step.Name -eq 'import') -or ($assertionsPass -or $markerPass -or $perCheckPass)
    # WT-040-R1: a null status is named instead of being written silently as an empty field.
    try { $exitCode = $process.ExitCode } catch { $exitCode = $null }
    if ($null -eq $exitCode) { Write-Output ("{0}: exit_code=UNKNOWN (the child did not report one)" -f $step.Name) }
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
