$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) re-apply DriveProfile.from_packet ==='
$dp="$c\scripts\drive\drive_profile.gd"
$lines = @(Get-Content $dp -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^func validate') { $idx = $i; break } }
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
  ($T+'return p')
)
$out = @()
for ($i=0; $i -lt $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($dp, $out, (New-Object Text.UTF8Encoding($false)))
'  drive_profile lines ' + $n0 + ' -> ' + $out.Count

'=== (b) override AFTER the match, so no indentation surgery is needed and the legacy match is untouched ==='
$vp="$c\scripts\content\vehicle_content_pipeline.gd"
$vl = @(Get-Content $vp -Encoding UTF8)
$v0 = $vl.Count
$vi = -1
for ($i=0; $i -lt $vl.Count; $i++) { if ($vl[$i] -match 'v\.drive_profile=preload\("res://configs/drive/m24_design\.tres"\)') { $vi = $i; break } }
'  the last match arm at ' + $(if ($vi -ge 0) { $vi+1 } else { 'NONE' })
if ($vi -lt 0) { '  ABORT'; git -C $c checkout -- scripts/drive/drive_profile.gd; exit 1 }
# find the next function after that arm: insert just before it, at one tab, inside the same function
$nxt = -1
for ($i=$vi+1; $i -lt $vl.Count; $i++) { if ($vl[$i] -match '^func ') { $nxt = $i; break } }
'  next function at ' + $(if ($nxt -ge 0) { $nxt+1 } else { 'NONE' })
if ($nxt -lt 0) { '  ABORT: no following function'; git -C $c checkout -- scripts/drive/drive_profile.gd; exit 1 }
$vadd = @(
  ($T+'# CD11: a packet may DECLARE its own drive profile, which is how the two engineering vehicles come to differ. The match'),
  ($T+'# above is left exactly as it was, so a packet that declares nothing keeps its hard coded legacy design resource.'),
  ($T+'if packet.has("drive_profile") and packet.drive_profile is Dictionary:'),
  ($T+$T+'v.drive_profile = DriveProfile.from_packet(packet.drive_profile)'),
  ''
)
$vout = @()
for ($i=0; $i -lt $nxt; $i++) { $vout += $vl[$i] }
$vout += $vadd
for ($i=$nxt; $i -lt $vl.Count; $i++) { $vout += $vl[$i] }
[IO.File]::WriteAllLines($vp, $vout, (New-Object Text.UTF8Encoding($false)))
'  pipeline lines ' + $v0 + ' -> ' + $vout.Count

'=== SHAPE FIRST ==='
& $g --headless --path $c --import *> "$L\impQ.log" 2>&1 | Out-Null
$bad = 0
foreach ($f in @('res://scripts/drive/drive_profile.gd','res://scripts/content/vehicle_content_pipeline.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh15.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh15.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { $bad += 1; Get-Content "$L\sh15.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
if ($bad -gt 0) { '  SHAPE WRONG - reverting BOTH'; git -C $c checkout -- scripts/drive/drive_profile.gd scripts/content/vehicle_content_pipeline.gd; exit 1 }
'  shape good for both'
'=== and the admission diagnostic must still pass, which is what tells us the legacy path is intact ==='
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/diag_cd011_admission.gd *> "$L\diagrun3.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 300; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 300
Get-Content "$L\diagrun3.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String '\[diag\] (defs|load_all|load_engineering)|setup ok' | Select-Object -First 8 | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
