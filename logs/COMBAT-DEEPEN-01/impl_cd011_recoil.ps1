$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) DriveProfile gains a bounded, per vehicle recoil, DEFAULTING to exactly the old global values ==='
$dp="$c\scripts\drive\drive_profile.gd"
$lines = @(Get-Content $dp -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'var suspension_enabled') { $idx = $i; break } }
'  anchor at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT'; exit 1 }
$add = @(
  '## CD11: the recoil response is a per weapon and per vehicle value rather than one global kick. The defaults are the',
  '## values the global constants already used, so a profile that does not declare anything behaves EXACTLY as before and the',
  '## previous uniform behaviour is retained as the legacy strategy rather than deleted.',
  '@export var recoil_speed_mps: float = GameConfig.CHASSIS_RECOIL_SPEED_MPS',
  '@export var recoil_damping: float = GameConfig.CHASSIS_RECOIL_DAMPING',
  '@export var recoil_max_mps: float = GameConfig.CHASSIS_RECOIL_MAX_MPS'
)
$out = @()
for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($dp, $out, (New-Object Text.UTF8Encoding($false)))
'  drive_profile lines ' + $n0 + ' -> ' + $out.Count

'=== (b) kick_recoil reads the profile, falling back to the global only when no definition is present ==='
$tk="$c\scripts\tank.gd"
$tl = @(Get-Content $tk -Encoding UTF8)
$t0 = $tl.Count
$ti = -1
for ($i=0; $i -lt $tl.Count; $i++) { if ($tl[$i] -match 'recoil_velocity -= shot_direction') { $ti = $i; break } }
'  recoil line at ' + $(if ($ti -ge 0) { $ti+1 } else { 'NONE' })
if ($ti -lt 0) { '  ABORT'; exit 1 }
$trep = @(
  ($T+'# CD11: the response is bounded by the profile, which each vehicle and weapon may declare; the profile defaults are the'),
  ($T+'# old global values, so an undeclared profile is byte for byte the legacy behaviour.'),
  ($T+'var cd011_profile: DriveProfile = null'),
  ($T+'if definition != null: cd011_profile = definition.drive_profile'),
  ($T+'var cd011_speed := GameConfig.CHASSIS_RECOIL_SPEED_MPS'),
  ($T+'var cd011_max := GameConfig.CHASSIS_RECOIL_MAX_MPS'),
  ($T+'var cd011_damp := GameConfig.CHASSIS_RECOIL_DAMPING'),
  ($T+'if cd011_profile != null:'),
  ($T+$T+'cd011_speed = cd011_profile.recoil_speed_mps'),
  ($T+$T+'cd011_max = cd011_profile.recoil_max_mps'),
  ($T+$T+'cd011_damp = cd011_profile.recoil_damping'),
  ($T+'recoil_damping = cd011_damp'),
  ($T+'recoil_velocity -= shot_direction.normalized().slide(up)*cd011_speed'),
  ($T+'recoil_velocity = recoil_velocity.limit_length(cd011_max)')
)
$tout = @()
for ($i=0; $i -lt $ti; $i++) { $tout += $tl[$i] }
$tout += $trep
for ($i=$ti+2; $i -lt $tl.Count; $i++) { $tout += $tl[$i] }
[IO.File]::WriteAllLines($tk, $tout, (New-Object Text.UTF8Encoding($false)))
'  tank lines ' + $t0 + ' -> ' + $tout.Count
'  does tank have a definition member and a recoil_damping member:'
@(Select-String -Path $tk -Pattern 'var definition|recoil_damping' -Encoding UTF8 | Select-Object -First 6) | ForEach-Object { '    L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(120,$_.Line.Trim().Length)) }

'=== SHAPE FIRST ==='
& $g --headless --path $c --import *> "$L\impM.log" 2>&1 | Out-Null
$bad = 0
foreach ($f in @('res://scripts/drive/drive_profile.gd','res://scripts/tank.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh11b.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh11b.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { $bad += 1; Get-Content "$L\sh11b.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
if ($bad -gt 0) { '  SHAPE WRONG - reverting both'; git -C $c checkout -- scripts/drive/drive_profile.gd scripts/tank.gd; exit 1 }
'  shape good'
