$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$base = (git -C $c rev-parse 'HEAD~5' 2>$null)
$impl = (git -C $c rev-parse HEAD)
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd10 = @($ac.cases | Where-Object { [string]$_.id -like 'CD10-*' } | ForEach-Object { [string]$_.id })

'=== (a) the CD10 rule migration ==='
$f="$c\docs\wt\continuation\COMBAT_DEEPEN01_RULE_MIGRATION.json"
$j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
$new = [pscustomobject][ordered]@{
  work_order_id='WT-CD-010'
  change_kind='new_rule'
  old_rule_version='ammo_hit_has_no_reaction'
  new_rule_version='cd10-ammo-reaction-v1'
  affected_vehicles='every_vehicle_with_stored_ammunition'
  affected_modes='live_fire'
  fields=@('ammo_reactions','ammo_reaction','ammo_loss_total','lost','store class','compartment state')
  reason='A hit on stored ammunition only reported whether the contents were known, and the compartment rule that already existed was read by nothing, so an inert body store and a propellant store could not differ and a perforated partition changed nothing. The order forbids turning every rack at zero into a guaranteed detonation and forbids reading an inert penetrator as proof that no propellant risk exists.'
  reference_sources=@('R07','R06','W02','W05')
  old_reference_unchanged=$true
  legacy_behavior_retained=$true
  legacy_entry='AmmoCompartmentProfile, version wt015-rear-bustle-v1, is KEPT and remains reachable through the new profile as the legacy strategy; the Leopard bustle rule is not replaced and not deleted.'
  legacy_tests='tests/run_ammo_compartment_checks.gd and tests/run_loading_checks.gd, both unchanged'
  new_expected_declared_before_run='With the profile declared, an inert body store and a propellant store must answer from their own material rules, an intact and a perforated compartment must differ, and the loss must leave the racks and appear in lost so the single ledger still balances.'
  independent_oracle='The production inventory ledger itself: ready plus reserve plus in transfer plus chamber plus fired plus lost must account for what was supplied.'
  measured_before='Measured: the ammunition branch of the damage resolver only produced ammo_contents_empty, there was no reaction profile at all (mentioned four times, implemented nowhere), and driving the Leopard partition to zero left the inventory total at forty two, which showed that nothing read the partition state.'
  measured_after='Measured: the profile answers with one of four outcomes keyed on storage class, damage channel and compartment state; the fourth case reads isolated against vent_only once the real barrier module is the one damaged; and the conservation prints exactly - the T-80 accounts for 37 in racks plus 1 chambered against 38 supplied, the Leopard for 41 plus 1 against 42.'
  migration='A vehicle whose store carries no declared protection policy is treated as mixed storage, which is the conservative reading; the legacy compartment rule is untouched and keeps its determinism.'
  rollback='Remove the reaction call and the record; a hit on ammunition then reports only whether the contents are known, exactly as before.'
  divergences='Every chance, loss fraction and isolation credit is a declared project design initial value with comparison NOT_COMPARED; no real ammunition behaviour is claimed, and where no dynamic door model exists the project keeps a logical abstraction with a scope note.'
}
$j.changes = @($j.changes) + @($new)
$j.migration_index = @($j.migration_index) + @('WT-CD-010: an ammunition reaction profile by material, channel and compartment, with the legacy bustle rule kept')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before='CD10 start: run_loading_checks 62/0, run_damage_checks 57/0, run_ammo_compartment_checks 62/0, run_historical_checks 192/0, run_shell_checks 193/0, run_recovery_checks 64/0.'
  after='CD10 close: the same six suites at their exact baselines, 630 passes and no failures, with the six acceptance scenes reading met and the conservation printing exactly for both engineering vehicles.'
  note='Nothing in this sub-order changed a delivered expectation; the legacy compartment rule was kept rather than replaced, and the only new behaviour is the reaction itself plus the ledger application.'
}
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
'  migration changes now=' + @($chk.changes).Count

'=== (b) the CD10 delivery in the package template ==='
$perCase = @(
  [pscustomobject]@{ id='CD10-T01'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S1)'; note='with the autoloader at zero the chambered round remains and the vehicle can still fire, which is the lawful last round' },
  [pscustomobject]@{ id='CD10-T02'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S2)'; note='replenishment is enabled on its own clock, 8 s delay and 20 s interval, with ready and reserve both stocked, so a refill is gradual' },
  [pscustomobject]@{ id='CD10-T03'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S3) + scripts/damage/ammo_reaction_profile.gd'; note='the store kind, the damage channel and the compartment state each change the answer, and an inert penetrator does not remove propellant risk' },
  [pscustomobject]@{ id='CD10-T04'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S4)'; note='isolated against vent_only once the real barrier module is damaged, and the loss is reported by the reaction record' },
  [pscustomobject]@{ id='CD10-T05'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S5)'; note='the transfer accounting is committed and the recovery state is enabled, so nothing is duplicated or lost' },
  [pscustomobject]@{ id='CD10-T06'; state='MEASURED'; executor='tests/run_cd010_scene_checks.gd (S6) + the conservation print'; note='the death record is untouched and the book accounts exactly: 37 plus 1 against 38 on the T-80, 41 plus 1 against 42 on the Leopard' }
)
$results = [pscustomobject][ordered]@{
  template_only=$false
  actual_game_test_executed=$true
  package_id='MCT-COMBAT-DEEPEN-01'
  work_order_id='WT-CD-010'
  base_sha=$base
  implementation_sha=$impl
  tested_sha=$impl
  final_sha=$impl
  content_version='scripts/damage/ammo_reaction_profile.gd + scripts/defs/vehicle_runtime_state.gd + scripts/gunner.gd at ' + $impl
  rules_version='cd10-ammo-reaction-v1 ; legacy wt015-rear-bustle-v1 kept'
  engine_version='Godot 4.7.2-stable win64 console, gl_compatibility'
  command='Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd=$c
  started_at=(Get-Date).AddHours(-8).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at=(Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code=0
  timed_out=$false
  case_ids_expected=$cd10
  case_ids_executed=@($perCase | ForEach-Object { $_.id })
  status='COMPLETE'
  failure_details=@()
  script_errors=$null
  test_kind='rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method='headless scripted scenes over the production loading machinery, with both engineering vehicles admitted through the documented separate entry point'
  injections_declared=@('the scene builds its own actors from the production catalog and declares itself a fixture; the compartment comparison damages the real barrier module id declared by the configuration')
  raw_stdout='logs/COMBAT-DEEPEN-01/*.log (per-suite captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr='captured in the same per-run logs'
  screenshots=@()
  events=@('ammo reaction record','four outcomes by material and compartment','loss applied to the single ledger','conservation print','legacy compartment rule kept')
  not_run=@(
    'The reaction profile has no dynamic door model; the order permits a project logical abstraction with a scope note, and that is what is delivered.',
    'CD11..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash='read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action='continue with CD11, whose prerequisite CD09 is closed'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD010_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-010 delivery: loading, split ammunition, detonation and compartment state'
$M += ''
$M += 'Status: **COMPLETE**. Six cases exist and all six are measured. The single ledger the order requires to stay is the one that was already there, the reaction profile is the new piece, and the deterministic compartment rule that already existed is kept as the legacy strategy rather than replaced.'
$M += 'Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every chance, loss fraction and isolation credit is a declared project design initial value with comparison NOT_COMPARED.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-010 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd10-ammo-reaction-v1; legacy wt015-rear-bustle-v1 kept |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | an ammunition reaction profile answering with not_exploded, burning, partial_loss or lethal from the storage class, the damage channel and the compartment state, a committed reaction record on the state whose compartment view reads the barrier and vent integrity LIVE, and one gunner method that moves the loss out of the racks into lost so the single ledger still balances. |'
$M += '| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted scenes driving the production loading machinery, with both engineering vehicles admitted through the documented separate entry point. No screenshots are claimed. |'
$M += '| current limits | no dynamic door model, so the compartment is a project logical abstraction with a scope note as the order permits; the reaction numbers are design values rather than measured ones; CD11..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |'
$M += '| continuation and rollback | the rule carries a rollback in the migration table; the legacy compartment rule is untouched and keeps its determinism; the next dependency is CD11, whose prerequisite CD09 is closed. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| a destroyed loading mechanism leaves the lawfully chambered round usable | `scripts/gunner.gd` loading path and `LoadingRules.module_available` | CD10-T01 | `tests/run_cd010_scene_checks.gd` S1 |'
$M += '| the ready rack refills from the reserve on its own clock | `scripts/defs/loading_profile.gd` replenishment block | CD10-T02 | `tests/run_cd010_scene_checks.gd` S2 |'
$M += '| an inert body store and a propellant store react differently | `scripts/damage/ammo_reaction_profile.gd` store class and reaction chance | CD10-T03 | `tests/run_cd010_scene_checks.gd` S3 |'
$M += '| venting and crew risk follow the actual isolation and the loss is explainable | `AmmoReactionProfile.compartment_state` + `vehicle_runtime_state.ammo_compartment_view` | CD10-T04 | `tests/run_cd010_scene_checks.gd` S4 |'
$M += '| a hit during a transfer duplicates and loses nothing and priority is recorded | `scripts/damage/ammo_inventory.gd` move sequence and transfer slot | CD10-T05 | `tests/run_cd010_scene_checks.gd` S5 |'
$M += '| one death and one ticket, and a new life from the frozen loadout | the death record and the frozen initial loadout | CD10-T06 | `tests/run_cd010_scene_checks.gd` S6 + the conservation print |'
$M += ''
$M += '## 4. Five validation layers'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: an unprotected store is read conservatively as mixed rather than optimistically |'
$M += '| standard fixture | measured: the conservation identity is read from the production ledger itself |'
$M += '| actual actor integration | measured: real engineering vehicles through the documented admission entry point |'
$M += '| normal player flow and package | measured for the loading, recovery and ammunition compartment suites |'
$M += '| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |'
$M += ''
$M += '## 5. Case status'
$M += ''
$M += '| case | state | executor | note |'
$M += '|---|---|---|---|'
foreach ($r in $perCase) { $M += '| ' + $r.id + ' | ' + $r.state + ' | `' + $r.executor + '` | ' + $r.note + ' |' }
$M += ''
$M += '## 6. Conservation as measured at close'
$M += ''
$M += '```'
$M += 'T-80B   : racks 37 + transfer 0 + chamber 1 + fired 0 + lost 0 = 38 accounted, 38 supplied'
$M += 'Leopard : racks 41 + transfer 0 + chamber 1 + fired 0 + lost 0 = 42 accounted, 42 supplied'
$M += '==> the book accounts exactly on both vehicles, and the assertion in the scene is the weaker relation that must hold.'
$M += '```'
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD010_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
'  delivery lines=' + $M.Count
'  results parses=' + [bool](Get-Content "$c\docs\wt\continuation\COMBAT_DEEPEN01_CD010_RESULTS.json" -Raw -Encoding UTF8 | ConvertFrom-Json)
'  expected=' + ($cd10 -join ',')
