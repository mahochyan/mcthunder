$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\tests\run_cd009_scene_checks.gd"
$lines = @(Get-Content $p -Encoding UTF8)
'  lines before=' + $lines.Count
$dup = -1
for ($i=1; $i -lt $lines.Count; $i++) {
  if ($lines[$i].Trim() -eq $lines[$i-1].Trim() -and $lines[$i] -match 'all-or-nothing at zero') { $dup = $i; break }
}
'  duplicate line at ' + $(if ($dup -ge 0) { $dup+1 } else { 'none' })
if ($dup -lt 0) { '  NO DUPLICATE FOUND - nothing changed'; exit 1 }
$out = @()
for ($i=0; $i -lt $lines.Count; $i++) { if ($i -ne $dup) { $out += $lines[$i] } }
[IO.File]::WriteAllLines($p, $out, (New-Object Text.UTF8Encoding($false)))
'  lines after=' + $out.Count + ' (exactly one fewer is expected)'
& $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\pcV.log" 2>&1 | Out-Null
'  parse_errors=' + @(Get-Content "$L\pcV.log" | Select-String 'Parse Error|Compile Error').Count
if (@(Get-Content "$L\pcV.log" | Select-String 'Parse Error').Count -gt 0) { Get-Content "$L\pcV.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '     ' + $_.Line.Trim().Substring(0,[Math]::Min(185,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9v.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
$o = Get-Content "$L\c9v.log" -Encoding UTF8 -ErrorAction SilentlyContinue
$o | Select-String 'CD09\] S1|CD09-T0|not_yet_met=|CD09_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(220,$_.Line.Trim().Length)) }
"  crashes=" + @($o|Select-String '^\s*SCRIPT ERROR').Count
'=== commit if the scenes are green ==='
$scFail = @($o|Select-String '^\[FAIL\]').Count
if ($scFail -eq 0) {
  git -C $c add scripts/damage/module_response_profile.gd scripts/damage/vehicle_capabilities.gd tests/run_cd009_scene_checks.gd docs/wt/continuation/COMBAT_DEEPEN01_CD009_EVIDENCE.md logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD09: the per-kind module response is wired into the single capability derivation, and the first acceptance case turns to met without its expectation being touched. The capability file was rewritten whole through the file tool rather than patched by anchor or by line surgery, and the shape was asserted before any run: eighty nine lines against seventy before, and a clean parse for both the capability file and the new profile. The measured outcome is direct - an engine taken from full to half records a motive power of 0.5 and the reason engine:linear:0.50, where previously a module above zero changed nothing at all - and eight suites return their exact baselines with seven hundred and sixteen passes and no failures. A new additive field carries that curve, so the boolean that says whether the vehicle can move at all keeps its old meaning and the existing assertions still hold. Two of my own slips are also recorded: the first wiring attempt used text anchors that matched nothing twice over, and the second left an orphaned duplicate line behind, which the parse check caught both times. The first case now reads met through the field its own declared expectation is about; only the breech failure case remains not yet met" 2>&1 | Select-Object -First 2
} else { '  scenes not green, nothing committed' }
'  commits=' + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { '  push: ' + $_.ToString() }
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
'  remote_synced=' + ($remote -eq (git -C $c rev-parse HEAD))
