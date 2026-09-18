$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== revert the two bad insertions, keep the profile (it parses clean) ==='
git -C $c checkout -- scripts/defs/vehicle_runtime_state.gd scripts/gunner.gd
'  state lines=' + @(Get-Content "$c\scripts\defs\vehicle_runtime_state.gd" -Encoding UTF8).Count + ' ; gunner lines=' + @(Get-Content "$c\scripts\gunner.gd" -Encoding UTF8).Count

function Insert-At($file, $pattern, $newLines, $expectTag) {
  $lines = @(Get-Content $file -Encoding UTF8)
  $before = $lines.Count
  $idx = -1
  for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $pattern) { $idx = $i; break } }
  if ($idx -lt 0) { '  ' + $expectTag + ': ABORT, anchor not found'; return $false }
  $out = @()
  for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
  $out += $newLines
  for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
  [IO.File]::WriteAllLines($file, $out, (New-Object Text.UTF8Encoding($false)))
  '  ' + $expectTag + ': lines ' + $before + ' -> ' + $out.Count + ' (expect +' + $newLines.Count + ')'
  return $true
}

'=== (a) the state: CLASS BODY lines with NO leading tab, method bodies with tabs ==='
$stateAdd = @(
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
$okA = Insert-At "$c\scripts\defs\vehicle_runtime_state.gd" 'var breech_failure: Dictionary = \{\}' $stateAdd 'state'

'=== (b) the gunner: apply the recorded loss to the single ledger ==='
$gunnerAdd = @(
  '## CD10: apply a recorded ammunition reaction to the SINGLE ledger. The loss leaves the racks and is counted in lost, so',
  '## nothing is invented and nothing is duplicated and the book still balances.',
  'func apply_ammo_reaction() -> Dictionary:',
  ($T+'var plan: Dictionary = {}'),
  ($T+'if actor != null and actor.state != null: plan = actor.state.ammo_reaction'),
  ($T+'if plan.is_empty(): return {"ok":false,"reason":"no_reaction_recorded"}'),
  ($T+'var module_id := str(plan.get("module_id",""))'),
  ($T+'var want := int(plan.get("loss",0))'),
  ($T+'if want <= 0 or not inventory.racks.has(module_id): return {"ok":true,"moved":0}'),
  ($T+'var have := int(inventory.racks[module_id])'),
  ($T+'var moved := mini(want,have)'),
  ($T+'inventory.racks[module_id] = have - moved'),
  ($T+'inventory.lost += moved'),
  ($T+'return {"ok":true,"moved":moved,"rack":module_id,"remaining":have-moved}'),
  ''
)
$okB = Insert-At "$c\scripts\gunner.gd" '^func supply_racks' $gunnerAdd 'gunner'

'=== SHAPE FIRST, WITH A HARD GUARD ==='
& $g --headless --path $c --import *> "$L\impG.log" 2>&1 | Out-Null
$bad = 0
foreach ($f in @('res://scripts/damage/ammo_reaction_profile.gd','res://scripts/defs/vehicle_runtime_state.gd','res://scripts/gunner.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh11.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh11.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { $bad += 1; Get-Content "$L\sh11.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
if ($bad -gt 0) { '  SHAPE IS WRONG - reverting the two insertions'; git -C $c checkout -- scripts/defs/vehicle_runtime_state.gd scripts/gunner.gd; exit 1 }
'  shape is good; running the CD10 scenes'
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd010_scene_checks.gd *> "$L\c10x.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 400
$o = Get-Content "$L\c10x.log" -Encoding UTF8 -ErrorAction SilentlyContinue
"  errors=" + @($o|Select-String 'SCRIPT ERROR').Count
$o | Select-String 'CD10-T0|not_yet_met=|CD10\] S3|CD10\] S4|CD10_SCENES|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(230,$_.Line.Trim().Length)) }
