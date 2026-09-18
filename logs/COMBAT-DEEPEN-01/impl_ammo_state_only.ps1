$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
'=== confirm the tree is clean at the reverted state ==='
'  tracked changes=' + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }).Count

'=== insert ONLY the state side, whose block already parsed clean ==='
$st="$c\scripts\defs\vehicle_runtime_state.gd"
$lines = @(Get-Content $st -Encoding UTF8)
$before = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'var breech_failure: Dictionary = \{\}') { $idx = $i; break } }
'  anchor at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT'; exit 1 }
$add = @(
  '',
  '## CD10: the committed reaction record for a hit on stored ammunition, and the loss it caused. The loss is reported here',
  '## and moved out of the racks by the single ledger, so the inventory row stays the only book.',
  'var ammo_reactions: Array[Dictionary] = []',
  'var ammo_reaction: Dictionary = {}',
  'var ammo_loss_total := 0',
  '',
  '## The compartment state as the profile needs it: the barrier and the vent are read LIVE from the module map, so a',
  '## perforated partition or a lost vent actually changes the answer instead of being ignored.',
  'func ammo_compartment_view(module_id: String) -> Dictionary:',
  ($T+'var view: Dictionary = (module_states.get(module_id,{}) as Dictionary).duplicate(true)'),
  ($T+'var protection: Dictionary = view.get("ammo_protection",{})'),
  ($T+'if not protection.is_empty():'),
  ($T+$T+'view["barrier_integrity"] = float((module_states.get(str(protection.get("barrier_module_id","")),{}) as Dictionary).get("integrity",1.0))'),
  ($T+$T+'view["vent_integrity"] = float((module_states.get(str(protection.get("vent_module_id","")),{}) as Dictionary).get("integrity",1.0))'),
  ($T+'return view'),
  '',
  '## Judge and record a reaction for one ammunition module at the given stock, deterministically in the seed.',
  'func judge_ammo_reaction(module_id: String, channel: String, stock: int, seed: int) -> Dictionary:',
  ($T+'var plan := AmmoReactionProfile.plan(module_id,ammo_compartment_view(module_id),channel,stock,seed)'),
  ($T+'plan["module_id"] = module_id'),
  ($T+'ammo_reaction = plan'),
  ($T+'ammo_reactions.append(plan.duplicate(true))'),
  ($T+'ammo_loss_total += int(plan.get("loss",0))'),
  ($T+'return plan')
)
$out = @()
for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($st, $out, (New-Object Text.UTF8Encoding($false)))
'  state lines ' + $before + ' -> ' + $out.Count + ' (expect +' + $add.Count + ')'
& $g --headless --path $c --import *> "$L\impH.log" 2>&1 | Out-Null
& $g --headless --path $c --check-only --script res://scripts/defs/vehicle_runtime_state.gd *> "$L\sh12.log" 2>&1 | Out-Null
$e = @(Get-Content "$L\sh12.log" | Select-String 'Parse Error|Compile Error').Count
'  state parse_errors=' + $e
if ($e -gt 0) { Get-Content "$L\sh12.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }; '  REVERTING'; git -C $c checkout -- scripts/defs/vehicle_runtime_state.gd; exit 1 }
'=== run the CD10 scenes ==='
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd010_scene_checks.gd *> "$L\c10y.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 400
$o = Get-Content "$L\c10y.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  errors=' + @($o|Select-String 'SCRIPT ERROR').Count
$o | Select-String 'CD10-T0|not_yet_met=|CD10_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(225,$_.Line.Trim().Length)) }
'=== a slice ==='
$tp=0;$tf=0
foreach ($s in @('run_loading_checks','run_damage_checks','run_ammo_compartment_checks','run_historical_checks','run_shell_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\c10z-$s.log"
  $o2 = Get-Content "$L\c10z-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o2|Select-String '^\[PASS\]').Count; $ff=@($o2|Select-String '^\[FAIL\]').Count
  $tp+=$pp;$tf+=$ff
  '  {0,-30} PASS={1,4} FAIL={2}' -f $s,$pp,$ff
}
'  TOTAL PASS=' + $tp + ' FAIL=' + $tf
