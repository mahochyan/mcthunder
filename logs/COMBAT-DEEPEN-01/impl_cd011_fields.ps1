$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== complete every DriveProfile field explicitly, differing on turning, track and recoil ==='
foreach ($n2 in @('ussr_t_80b','germ_leopard_2a4')) {
  $fp = "$c\configs\vehicles\engineering\$n2.json"
  $j = Get-Content $fp -Raw -Encoding UTF8 | ConvertFrom-Json
  $is_t80 = ($n2 -eq 'ussr_t_80b')
  $vals = [pscustomobject][ordered]@{
    power_falloff                = $(if ($is_t80) { 0.42 } else { 0.50 })
    shift_seconds                = $(if ($is_t80) { 0.20 } else { 0.24 })
    shift_power                  = $(if ($is_t80) { 0.16 } else { 0.20 })
    gear_count                   = $(if ($is_t80) { 5 } else { 6 })
    downshift_hysteresis         = 0.08
    grade_acceleration           = 9.81
    brake_scale                  = $(if ($is_t80) { 0.95 } else { 0.88 })
    coast_scale                  = $(if ($is_t80) { 0.92 } else { 0.86 })
    turn_speed_falloff           = $(if ($is_t80) { 0.30 } else { 0.42 })
    turn_drag_per_second         = $(if ($is_t80) { 0.32 } else { 0.40 })
    track_spacing_m              = $(if ($is_t80) { 2.72 } else { 2.88 })
    neutral_turn                 = $true
    damaged_track_turn_scale     = $(if ($is_t80) { 0.22 } else { 0.30 })
    pitch_degrees_per_acceleration = 0.18
    pitch_limit_degrees          = 1.5
    pitch_response_rate          = 8.0
    landing_min_speed            = 2.0
    landing_restitution          = 0.12
    landing_max_rebound          = 1.0
    suspension_enabled           = $false
    recoil_speed_mps             = $(if ($is_t80) { 0.55 } else { 0.78 })
    recoil_max_mps               = $(if ($is_t80) { 1.10 } else { 1.55 })
  }
  $env = [pscustomobject][ordered]@{
    schema_version = 1
    origin = 'game_rule'
    note = 'Declared project design curve for this vehicle. The two engineering vehicles must differ in turning, in one sided track loss and in recoil; every field is stated explicitly and these are game tuning values, not measurements of any real vehicle.'
    values = $vals
  }
  $j.drive_profile = $env
  $claim = [pscustomobject][ordered]@{
    location = $n2 + ': drive.profile'
    note = 'Declared project design curve for this vehicle, matching the drive_profile content above field for field.'
    origin = 'game_rule'
    source_refs = @('mcthunder_pipeline')
    status = 'design'
    unit = 'structured'
    value = $env
  }
  $j.facts | Add-Member -NotePropertyName 'drive.profile' -NotePropertyValue $claim -Force
  [IO.File]::WriteAllText($fp, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
  '  ' + $n2 + ' : ' + @($vals.PSObject.Properties).Count + ' declared fields ; turn=' + $vals.turn_speed_falloff + ' spacing=' + $vals.track_spacing_m + ' damaged=' + $vals.damaged_track_turn_scale + ' recoil=' + $vals.recoil_speed_mps + '/' + $vals.recoil_max_mps
}
'=== admission ==='
$j1 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/diag_cd011_admission.gd *> "$L\diagrun7.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j1 -Timeout 300; if (-not $d) { Stop-Job $j1 } ; Remove-Job $j1
Start-Sleep -Milliseconds 300
Get-Content "$L\diagrun7.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'load_engineering ok|setup ok' | Select-Object -First 8 | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(215,$_.Line.Trim().Length)) }
'=== the scenes ==='
$j2 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd011_scene_checks.gd *> "$L\c11m.log" } -ArgumentList $g,$c,$L
$d2 = Wait-Job $j2 -Timeout 400; if (-not $d2) { Stop-Job $j2 } ; Remove-Job $j2
Start-Sleep -Milliseconds 400
$o2 = Get-Content "$L\c11m.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  errors=' + @($o2|Select-String 'SCRIPT ERROR').Count
$o2 | Select-String 'CD11\] S1|CD11\] S2|CD11\] S4|CD11-T0|not_yet_met=|CD11_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
