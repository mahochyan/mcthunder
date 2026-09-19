$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) DriveProfile gains per vehicle recoil speed and cap, defaulting to the old global values ==='
$dp="$c\scripts\drive\drive_profile.gd"
$lines = @(Get-Content $dp -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'var suspension_enabled') { $idx = $i; break } }
if ($idx -lt 0) { '  ABORT'; exit 1 }
$add = @(
  '## CD11: the recoil response is a per weapon and per vehicle value rather than one global kick. The defaults ARE the values',
  '## the global constants already used, so a profile that declares nothing behaves exactly as before and the previous uniform',
  '## behaviour is retained as the legacy strategy rather than deleted. The damping stays global, exactly as the code reads it.',
  '@export var recoil_speed_mps: float = GameConfig.CHASSIS_RECOIL_SPEED_MPS',
  '@export var recoil_max_mps: float = GameConfig.CHASSIS_RECOIL_MAX_MPS'
)
$out = @()
for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($dp, $out, (New-Object Text.UTF8Encoding($false)))
'  drive_profile lines ' + $n0 + ' -> ' + $out.Count

'=== (b) kick_recoil reads the profile through the member defs, which is the member the local definition is built from ==='
$tk="$c\scripts\tank.gd"
$tl = @(Get-Content $tk -Encoding UTF8)
$t0 = $tl.Count
$ti = -1
for ($i=0; $i -lt $tl.Count; $i++) { if ($tl[$i] -match 'recoil_velocity -= shot_direction') { $ti = $i; break } }
if ($ti -lt 0) { '  ABORT'; exit 1 }
$trep = @(
  ($T+'# CD11: bounded by the profile, which each vehicle may declare. The profile defaults are the old global values, so an'),
  ($T+'# undeclared profile is the legacy behaviour, and the damping stays global exactly as the attenuation below reads it.'),
  ($T+'var cd011_speed := GameConfig.CHASSIS_RECOIL_SPEED_MPS'),
  ($T+'var cd011_max := GameConfig.CHASSIS_RECOIL_MAX_MPS'),
  ($T+'if defs != null and defs.drive_profile != null:'),
  ($T+$T+'cd011_speed = defs.drive_profile.recoil_speed_mps'),
  ($T+$T+'cd011_max = defs.drive_profile.recoil_max_mps'),
  ($T+'recoil_velocity -= shot_direction.normalized().slide(up)*cd011_speed'),
  ($T+'recoil_velocity = recoil_velocity.limit_length(cd011_max)')
)
$tout = @()
for ($i=0; $i -lt $ti; $i++) { $tout += $tl[$i] }
$tout += $trep
for ($i=$ti+2; $i -lt $tl.Count; $i++) { $tout += $tl[$i] }
[IO.File]::WriteAllLines($tk, $tout, (New-Object Text.UTF8Encoding($false)))
'  tank lines ' + $t0 + ' -> ' + $tout.Count

'=== SHAPE FIRST ==='
& $g --headless --path $c --import *> "$L\impN.log" 2>&1 | Out-Null
$bad = 0
foreach ($f in @('res://scripts/drive/drive_profile.gd','res://scripts/tank.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh12b.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh12b.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { $bad += 1; Get-Content "$L\sh12b.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
if ($bad -gt 0) { '  SHAPE WRONG - reverting BOTH'; git -C $c checkout -- scripts/drive/drive_profile.gd scripts/tank.gd; exit 1 }
'  shape good for drive_profile and tank'

'=== (c) give the two engineering vehicles DIFFERENT declared drive profiles (small config change, as the order directs) ==='
foreach ($n2 in @('ussr_t_80b','germ_leopard_2a4')) {
  $fp = "$c\configs\vehicles\engineering\$n2.json"
  $j = Get-Content $fp -Raw -Encoding UTF8 | ConvertFrom-Json
  $turn = if ($n2 -eq 'ussr_t_80b') { 0.30 } else { 0.42 }
  $spacing = if ($n2 -eq 'ussr_t_80b') { 2.72 } else { 2.88 }
  $dmg = if ($n2 -eq 'ussr_t_80b') { 0.22 } else { 0.30 }
  $rec = if ($n2 -eq 'ussr_t_80b') { 0.55 } else { 0.78 }
  $recmax = if ($n2 -eq 'ussr_t_80b') { 1.10 } else { 1.55 }
  $prof = [pscustomobject][ordered]@{
    turn_speed_falloff=$turn
    track_spacing_m=$spacing
    damaged_track_turn_scale=$dmg
    recoil_speed_mps=$rec
    recoil_max_mps=$recmax
  }
  $j | Add-Member -NotePropertyName drive_profile -NotePropertyValue $prof -Force
  [IO.File]::WriteAllText($fp, ($j | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
  '  ' + $n2 + ' drive_profile -> turn=' + $turn + ' spacing=' + $spacing + ' damaged=' + $dmg + ' recoil=' + $rec + '/' + $recmax
}
'  json reparse ok=' + [bool](Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json)
