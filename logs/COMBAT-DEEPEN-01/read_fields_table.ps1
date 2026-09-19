$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
'=== (a) the allowed field table for the drive profile kind ==='
$ep="$c\scripts\content\vehicle_equipment_profiles.gd"
$lines = Get-Content $ep -Encoding UTF8
$fi = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^const FIELDS') { $fi = $i; break } }
'  FIELDS at ' + $(if ($fi -ge 0) { $fi+1 } else { 'NONE' })
if ($fi -ge 0) { for ($i=$fi; $i -le [Math]::Min($lines.Count-1,$fi+26); $i++) { $s = $lines[$i] -replace "`t",'T'; '  L' + ($i+1) + ': ' + $s.Substring(0,[Math]::Min(150,$s.Length)) } }
