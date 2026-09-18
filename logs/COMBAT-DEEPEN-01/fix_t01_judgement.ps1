$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\tests\run_cd009_scene_checks.gd"
$lines = Get-Content $p -Encoding UTF8
'  lines before=' + $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'met\("CD09-T01"') { $idx = $i; break } }
'  the T01 judgement sits at line ' + ($idx+1)
if ($idx -lt 0) { '  NOT FOUND - aborting rather than guessing'; exit 1 }
# Replace exactly that statement, which spans two lines here, keeping the line count equal and asserting it.
$replacement = @(
  ($T+'met("CD09-T01", float(half.get("power_scale",1.0)) < float(full.get("power_scale",1.0)),'),
  ($T+$T+'"ability must follow a declared curve as integrity falls, not stay identical until zero",'),
  ($T+$T+'"a half damaged engine still gives exactly the intact ability, so ability is all-or-nothing at zero")')
)
$out = @()
for ($i=0; $i -lt $idx; $i++) { $out += $lines[$i] }
$out += $replacement
# the original statement occupied this line and the next two; skip them
$skip = 3
for ($i=$idx+$skip; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($p, $out, (New-Object Text.UTF8Encoding($false)))
'  lines after=' + $out.Count + ' (equal is expected: 3 lines replaced by 3)'
'  t01_now_reads_power=' + ((Get-Content $p -Raw -Encoding UTF8).Contains('float(half.get("power_scale",1.0)) < float(full.get("power_scale",1.0))'))
& $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\pcZ.log" 2>&1 | Out-Null
'  parse_errors=' + @(Get-Content "$L\pcZ.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pcZ.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pcZ.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { '     ' + $_.Line.Trim().Substring(0,[Math]::Min(185,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9z.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9z.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
