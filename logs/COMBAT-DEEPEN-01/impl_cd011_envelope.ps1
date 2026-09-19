$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== (a) the top level drive_profile becomes the ENVELOPE the validator demands ==='
foreach ($n2 in @('ussr_t_80b','germ_leopard_2a4')) {
  $fp = "$c\configs\vehicles\engineering\$n2.json"
  $j = Get-Content $fp -Raw -Encoding UTF8 | ConvertFrom-Json
  $is_t80 = ($n2 -eq 'ussr_t_80b')
  $vals = [pscustomobject][ordered]@{
    turn_speed_falloff       = $(if ($is_t80) { 0.30 } else { 0.42 })
    turn_drag_per_second     = $(if ($is_t80) { 0.32 } else { 0.40 })
    track_spacing_m          = $(if ($is_t80) { 2.72 } else { 2.88 })
    damaged_track_turn_scale = $(if ($is_t80) { 0.22 } else { 0.30 })
    neutral_turn             = $true
    power_falloff            = $(if ($is_t80) { 0.42 } else { 0.50 })
    grade_acceleration       = 9.81
    brake_scale              = $(if ($is_t80) { 0.95 } else { 0.88 })
    recoil_speed_mps         = $(if ($is_t80) { 0.55 } else { 0.78 })
    recoil_max_mps           = $(if ($is_t80) { 1.10 } else { 1.55 })
    suspension_enabled       = $false
  }
  $env = [pscustomobject][ordered]@{
    schema_version = 1
    origin = 'game_rule'
    note = 'Declared project design curve for this vehicle. The two engineering vehicles must differ in turning, in one sided track loss and in recoil; these are game tuning values, not measurements of any real vehicle.'
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
  '  ' + $n2 + ' envelope values: turn=' + $vals.turn_speed_falloff + ' spacing=' + $vals.track_spacing_m + ' damaged=' + $vals.damaged_track_turn_scale + ' recoil=' + $vals.recoil_speed_mps + '/' + $vals.recoil_max_mps
}
'=== (b) the pipeline reads the envelope values, and still accepts a bare dictionary ==='
$vp="$c\scripts\content\vehicle_content_pipeline.gd"
$t = Get-Content $vp -Raw -Encoding UTF8
$a = '		v.drive_profile = DriveProfile.from_packet(packet.drive_profile)'
$b = '		var cd011_row: Variant = packet.drive_profile.get("values",packet.drive_profile)' + "`r`n" + `
  '		if cd011_row is Dictionary: v.drive_profile = DriveProfile.from_packet(cd011_row)'
$n = ([regex]::Matches($t,[regex]::Escape($a))).Count
$t = $t.Replace($a,$b)
[IO.File]::WriteAllText($vp, $t, (New-Object Text.UTF8Encoding($false)))
"  pipeline_reads_values=$n"
& $g --headless --path $c --import *> "$L\impU.log" 2>&1 | Out-Null
& $g --headless --path $c --check-only --script res://scripts/content/vehicle_content_pipeline.gd *> "$L\sh19.log" 2>&1 | Out-Null
'  pipeline parse_errors=' + @(Get-Content "$L\sh19.log" | Select-String 'Parse Error|Compile Error').Count
@(Get-Content "$L\sh19.log" | Select-String 'Parse Error|at:') | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
'=== admission ==='
$j1 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/diag_cd011_admission.gd *> "$L\diagrun6.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j1 -Timeout 300; if (-not $d) { Stop-Job $j1 } ; Remove-Job $j1
Start-Sleep -Milliseconds 300
Get-Content "$L\diagrun6.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'load_engineering ok|setup ok' | Select-Object -First 8 | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(215,$_.Line.Trim().Length)) }
'=== the scenes ==='
$j2 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd011_scene_checks.gd *> "$L\c11k.log" } -ArgumentList $g,$c,$L
$d2 = Wait-Job $j2 -Timeout 400; if (-not $d2) { Stop-Job $j2 } ; Remove-Job $j2
Start-Sleep -Milliseconds 400
$o2 = Get-Content "$L\c11k.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  errors=' + @($o2|Select-String 'SCRIPT ERROR').Count
$o2 | Select-String 'CD11\] S1|CD11\] S2|CD11\] S4|CD11-T0|not_yet_met=|CD11_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
