$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== read EVERY @export from DriveProfile, with its declared default ==='
$dp="$c\scripts\drive\drive_profile.gd"
$fields = @{}
$order = @()
foreach ($ln in (Get-Content $dp -Encoding UTF8)) {
  if ($ln -match '^@export var ([a-z_0-9]+):\s*([A-Za-z0-9_]+)\s*=\s*(.+?)\s*$') {
    $name = $Matches[1]; $kind = $Matches[2]; $raw = $Matches[3].Trim()
    $val = $raw
    if ($kind -eq 'bool') { $val = ($raw -eq 'true') }
    elseif ($kind -eq 'int') { $val = [int]$raw }
    else { $val = [double]$raw }
    $fields[$name] = $val
    $order += $name
  }
}
'  DriveProfile declares ' + $order.Count + ' exported fields'
$order | ForEach-Object { '    ' + $_ + ' = ' + $fields[$_] }

'=== rewrite both packets with EVERY field stated explicitly, differing where the case needs it ==='
foreach ($n2 in @('ussr_t_80b','germ_leopard_2a4')) {
  $fp = "$c\configs\vehicles\engineering\$n2.json"
  $j = Get-Content $fp -Raw -Encoding UTF8 | ConvertFrom-Json
  $is_t80 = ($n2 -eq 'ussr_t_80b')
  $vals = [ordered]@{}
  foreach ($f in $order) {
    $v = $fields[$f]
    switch ($f) {
      'turn_speed_falloff'       { $v = $(if ($is_t80) { 0.30 } else { 0.42 }) }
      'turn_drag_per_second'     { $v = $(if ($is_t80) { 0.32 } else { 0.40 }) }
      'track_spacing_m'          { $v = $(if ($is_t80) { 2.72 } else { 2.88 }) }
      'damaged_track_turn_scale' { $v = $(if ($is_t80) { 0.22 } else { 0.30 }) }
      'power_falloff'            { $v = $(if ($is_t80) { 0.42 } else { 0.50 }) }
      'recoil_speed_mps'         { $v = $(if ($is_t80) { 0.55 } else { 0.78 }) }
      'recoil_max_mps'           { $v = $(if ($is_t80) { 1.10 } else { 1.55 }) }
      'brake_scale'              { $v = $(if ($is_t80) { 0.95 } else { 0.88 }) }
      'coast_scale'              { $v = $(if ($is_t80) { 0.92 } else { 0.86 }) }
      'gear_count'               { $v = $(if ($is_t80) { 5 } else { 6 }) }
    }
    $vals[$f] = $v
  }
  $valsObj = [pscustomobject]$vals
  $env = [pscustomobject][ordered]@{
    schema_version = 1
    origin = 'game_rule'
    note = 'Declared project design curve for this vehicle. Every field is stated explicitly because the gate demands it; the two engineering vehicles differ in turning, one sided track loss and recoil. These are game tuning values, not measurements of any real vehicle.'
    values = $valsObj
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
  '  ' + $n2 + ' -> ' + @($valsObj.PSObject.Properties).Count + ' fields ; turn=' + $valsObj.turn_speed_falloff + ' spacing=' + $valsObj.track_spacing_m + ' recoil=' + $valsObj.recoil_speed_mps
}
'=== admission ==='
$j1 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/diag_cd011_admission.gd *> "$L\diagrun8.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j1 -Timeout 300; if (-not $d) { Stop-Job $j1 } ; Remove-Job $j1
Start-Sleep -Milliseconds 300
Get-Content "$L\diagrun8.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'load_engineering ok|setup ok' | Select-Object -First 6 | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
'=== the scenes ==='
$j2 = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd011_scene_checks.gd *> "$L\c11n.log" } -ArgumentList $g,$c,$L
$d2 = Wait-Job $j2 -Timeout 400; if (-not $d2) { Stop-Job $j2 } ; Remove-Job $j2
Start-Sleep -Milliseconds 400
$o2 = Get-Content "$L\c11n.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  errors=' + @($o2|Select-String 'SCRIPT ERROR').Count
$o2 | Select-String 'CD11\] S1|CD11\] S2|CD11\] S4|CD11-T0|not_yet_met=|CD11_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
