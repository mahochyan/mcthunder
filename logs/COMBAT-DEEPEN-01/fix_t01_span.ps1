$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\tests\run_cd009_scene_checks.gd"
$lines = Get-Content $p -Encoding UTF8
'=== the region as it stands (L62-74) ==='
for ($i=61; $i -le 73 -and $i -lt $lines.Count; $i++) {
  $s = $lines[$i] -replace "`t",'T'
  '  L' + ($i+1) + ': [' + $s.Substring(0,[Math]::Min(135,$s.Length)) + ']'
}
'=== replace the whole T01 statement by index span, found by its closing line ==='
$start = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'met\("CD09-T01"') { $start = $i; break } }
$end = -1
for ($i=$start; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd() -match '\)$') { $end = $i; break } }
'  statement spans lines ' + ($start+1) + ' to ' + ($end+1) + ' (' + ($end-$start+1) + ' lines)'
if ($start -lt 0 -or $end -lt $start) { '  COULD NOT FIND THE SPAN - aborting'; exit 1 }
$replacement = @(
  ($T+'met("CD09-T01", float(half.get("power_scale",1.0)) < float(full.get("power_scale",1.0)),'),
  ($T+$T+'"ability must follow a declared curve as integrity falls, not stay identical until zero",'),
  ($T+$T+'"a half damaged engine still gives exactly the intact ability, so ability is all-or-nothing at zero")')
)
$out = @()
for ($i=0; $i -lt $start; $i++) { $out += $lines[$i] }
$out += $replacement
for ($i=$end+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($p, $out, (New-Object Text.UTF8Encoding($false)))
'  lines before=' + $lines.Count + ' after=' + $out.Count + ' (delta = 3 - old span)'
& $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\pcW.log" 2>&1 | Out-Null
'  parse_errors=' + @(Get-Content "$L\pcW.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pcW.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pcW.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { '     ' + $_.Line.Trim().Substring(0,[Math]::Min(185,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9w.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9w.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09\] S1|CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
