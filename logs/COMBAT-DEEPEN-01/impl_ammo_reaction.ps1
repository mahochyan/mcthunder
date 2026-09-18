$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9

'=== (a) the state records a reaction, reading the LIVE barrier and vent integrity ==='
$st="$c\scripts\defs\vehicle_runtime_state.gd"
$lines = @(Get-Content $st -Encoding UTF8)
$n0 = $lines.Count
$idx = -1
for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'var breech_failure: Dictionary = \{\}') { $idx = $i; break } }
'  anchor at ' + $(if ($idx -ge 0) { $idx+1 } else { 'NONE' })
if ($idx -lt 0) { '  ABORT'; exit 1 }
$add = @(
  ($T+'## CD10: the committed reaction record for a hit on stored ammunition, and the loss it caused. The loss is reported here'),
  ($T+'## and moved out of the racks by the single ledger, so the inventory stays the only book.'),
  ($T+'var ammo_reactions: Array[Dictionary] = []'),
  ($T+'var ammo_reaction: Dictionary = {}'),
  ($T+'var ammo_loss_total := 0'),
  ($T+'## The compartment state as the profile needs to see it: the barrier and the vent are read LIVE from the module map, so'),
  ($T+'## a perforated partition or a lost vent actually changes the answer instead of being ignored.'),
  ($T+'func ammo_compartment_view(module_id: String) -> Dictionary:'),
  ($T+$T+'var view: Dictionary = (module_states.get(module_id,{}) as Dictionary).duplicate(true)'),
  ($T+$T+'var protection: Dictionary = view.get("ammo_protection",{})'),
  ($T+$T+'if not protection.is_empty():'),
  ($T+$T+$T+'view["barrier_integrity"] = float((module_states.get(str(protection.get("barrier_module_id","")),{}) as Dictionary).get("integrity",1.0))'),
  ($T+$T+$T+'view["vent_integrity"] = float((module_states.get(str(protection.get("vent_module_id","")),{}) as Dictionary).get("integrity",1.0))'),
  ($T+$T+'return view'),
  ($T+'## Judge and record a reaction for one ammunition module at the given stock, deterministically in the seed.'),
  ($T+'func judge_ammo_reaction(module_id: String, channel: String, stock: int, seed: int) -> Dictionary:'),
  ($T+$T+'var plan := AmmoReactionProfile.plan(module_id,ammo_compartment_view(module_id),channel,stock,seed)'),
  ($T+$T+'plan["module_id"] = module_id'),
  ($T+$T+'ammo_reaction = plan'),
  ($T+$T+'ammo_reactions.append(plan.duplicate(true))'),
  ($T+$T+'ammo_loss_total += int(plan.get("loss",0))'),
  ($T+$T+'return plan')
)
$out = @()
for ($i=0; $i -le $idx; $i++) { $out += $lines[$i] }
$out += $add
for ($i=$idx+1; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($st, $out, (New-Object Text.UTF8Encoding($false)))
'  state lines ' + $n0 + ' -> ' + $out.Count + ' (expect +' + $add.Count + ')'

'=== (b) the gunner moves the reported loss out of the racks into lost, keeping one ledger ==='
$gu="$c\scripts\gunner.gd"
$gl = @(Get-Content $gu -Encoding UTF8)
$g0 = $gl.Count
$gi = -1
for ($i=0; $i -lt $gl.Count; $i++) { if ($gl[$i] -match '^func supply_racks') { $gi = $i; break } }
'  anchor at ' + $(if ($gi -ge 0) { $gi+1 } else { 'NONE' })
if ($gi -lt 0) { '  ABORT'; exit 1 }
$gadd = @(
  ($T+'## CD10: apply a recorded ammunition reaction to the SINGLE ledger. The loss is taken out of the racks and counted in'),
  ($T+'## lost, so nothing is invented and nothing is duplicated: the book still balances.'),
  ($T+'func apply_ammo_reaction() -> Dictionary:'),
  ($T+$T+'var plan: Dictionary = {}'),
  ($T+$T+'if actor != null and actor.state != null: plan = actor.state.ammo_reaction'),
  ($T+$T+'if plan.is_empty(): return {"ok":false,"reason":"no_reaction_recorded"}'),
  ($T+$T+'var module_id := str(plan.get("module_id",""))'),
  ($T+$T+'var want := int(plan.get("loss",0))'),
  ($T+$T+'if want <= 0 or not inventory.racks.has(module_id): return {"ok":true,"moved":0}'),
  ($T+$T+'var have := int(inventory.racks[module_id])'),
  ($T+$T+'var moved := mini(want,have)'),
  ($T+$T+'inventory.racks[module_id] = have - moved'),
  ($T+$T+'inventory.lost += moved'),
  ($T+$T+'return {"ok":true,"moved":moved,"rack":module_id,"remaining":have-moved}'),
  ($T+$T+''),
  ($T+'')
)
$gout = @()
for ($i=0; $i -lt $gi; $i++) { $gout += $gl[$i] }
$gout += $gadd
for ($i=$gi; $i -lt $gl.Count; $i++) { $gout += $gl[$i] }
[IO.File]::WriteAllLines($gu, $gout, (New-Object Text.UTF8Encoding($false)))
'  gunner lines ' + $g0 + ' -> ' + $gout.Count + ' (expect +' + $gadd.Count + ')'

'=== SHAPE FIRST ==='
& $g --headless --path $c --import *> "$L\impF.log" 2>&1 | Out-Null
foreach ($f in @('res://scripts/damage/ammo_reaction_profile.gd','res://scripts/defs/vehicle_runtime_state.gd','res://scripts/gunner.gd')) {
  & $g --headless --path $c --check-only --script $f *> "$L\sh10.log" 2>&1 | Out-Null
  $e = @(Get-Content "$L\sh10.log" | Select-String 'Parse Error|Compile Error').Count
  '  ' + $f + ' parse_errors=' + $e
  if ($e -gt 0) { Get-Content "$L\sh10.log" | Select-String 'Parse Error|at:' | Select-Object -First 4 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) } }
}
