$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) DriveProfile gains a from_packet path, mirroring the loading profile idiom ==='
$dp="$c\scripts\drive\drive_profile.gd"
$lines = @(Get-Content $dp -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'func validate') { $idx = $i; break } }
'  anchor (validate) at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT'; exit 1 }
$add = @(
  '## CD11: build a profile from a packet row, the same idiom the loading profile already uses, so a per vehicle curve can be',
  '## DECLARED IN DATA rather than hard coded per vehicle id. Any key the row omits keeps the declared default, which is the',
  '## behaviour every vehicle had before this existed.',
  'static func from_packet(row: Dictionary) -> DriveProfile:',
  ($T+'var p := DriveProfile.new()'),
  ($T+'for key in row.keys():'),
  ($T+$T+'var k := str(key)'),
  ($T+$T+'if not (k in p): continue'),
  ($T+$T+'p.set(k,row[key])'),
  ($T+'return p'),
  '',
  '## The declared default profile, used when a packet declares nothing: this is the legacy behaviour, unchanged.',
  'static func legacy_default() -> DriveProfile:',
  ($T+'return DriveProfile.new()')
)
$out = @()
for ($i=0; $i -lt $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($dp, $out, (New-Object Text.UTF8Encoding($false)))
'  drive_profile lines ' + $n0 + ' -> ' + $out.Count

'=== (b) the pipeline builds the drive profile from the packet, keeping the hard coded preloads as the legacy path ==='
$vp="$c\scripts\content\vehicle_content_pipeline.gd"
$vl = @(Get-Content $vp -Encoding UTF8)
$v0 = $vl.Count
$vi = -1
for ($i=0; $i -lt $vl.Count; $i++) { if ($vl[$i] -match 'v\.drive_profile=preload\("res://configs/drive/m4a3_design\.tres"\)') { $vi = $i; break } }
'  anchor (m4a3 preload) at ' + $(if ($vi -ge 0) { $vi+1 } else { 'NONE' })
if ($vi -lt 0) { '  ABORT'; exit 1 }
$vadd = @(
  ($T+'# CD11: a packet may DECLARE its own drive profile, which is how the two engineering vehicles differ. A packet that'),
  ($T+'# declares nothing keeps falling through to the hard coded design resource below, so the legacy path is untouched.'),
  ($T+'if packet.has("drive_profile") and packet.drive_profile is Dictionary:'),
  ($T+$T+'v.drive_profile = DriveProfile.from_packet(packet.drive_profile)')
)
$vout = @()
for ($i=0; $i -lt $vi; $i++) { $vout += $vl[$i] }
$vout += $vadd
for ($i=$vi; $i -lt $vl.Count; $i++) { $vout += $vl[$i] }
[IO.File]::WriteAllLines($vp, $vout, (New-Object Text.UTF8Encoding($false)))
'  pipeline lines ' + $v0 + ' -> ' + $vout.Count

'=== SHAPE FIRST ==='
& $g --headless --path $c --import *> "$L\impO.log" 2>&1 | Out-Null
$bad = 0
foreach ($f in @('res://scripts/drive/drive_profile.gd','res://scripts/content/vehicle_content_pipeline.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh13.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh13.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { $bad += 1; Get-Content "$L\sh13.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
if ($bad -gt 0) { '  SHAPE WRONG - reverting'; git -C $c checkout -- scripts/drive/drive_profile.gd scripts/content/vehicle_content_pipeline.gd; exit 1 }
'  shape good'
