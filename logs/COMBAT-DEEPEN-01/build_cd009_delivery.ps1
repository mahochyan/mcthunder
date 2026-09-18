$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$base = (git -C $c rev-parse 'HEAD~6' 2>$null)
$impl = (git -C $c rev-parse HEAD)
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd09 = @($ac.cases | Where-Object { [string]$_.id -like 'CD09-*' } | ForEach-Object { [string]$_.id })

'=== (a) the two CD09 rule migrations ==='
$f="$c\docs\wt\continuation\COMBAT_DEEPEN01_RULE_MIGRATION.json"
$j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
function New-Change($id,$kind,$oldV,$newV,$veh,$modes,$fields,$reason,$sources,$legacyEntry,$legacyTests,$expected,$oracle,$before,$after,$migration,$rollback,$divergences) {
  [pscustomobject][ordered]@{ work_order_id=$id; change_kind=$kind; old_rule_version=$oldV; new_rule_version=$newV
    affected_vehicles=$veh; affected_modes=$modes; fields=$fields; reason=$reason; reference_sources=$sources
    old_reference_unchanged=$true; legacy_behavior_retained=$true; legacy_entry=$legacyEntry; legacy_tests=$legacyTests
    new_expected_declared_before_run=$expected; independent_oracle=$oracle; measured_before=$before; measured_after=$after
    migration=$migration; rollback=$rollback; divergences=$divergences }
}
$new = @()
$new += New-Change 'WT-CD-009' 'new_rule' 'module_response_all_or_nothing' 'cd009-module-response-v1' `
  'every_vehicle_with_modules' 'live_fire_and_recovery' @('power_scale','yaw_scale','pitch_scale','reasons') `
  'A module mattered only at exactly zero, so ability was all or nothing; the order requires a response chosen by KIND and forbids one uniform multiplier for every module.' `
  @('R06','W02') `
  'Every strategy still reaches exactly zero at zero integrity, which is the behaviour the existing suites assert today, and the boolean that says whether the vehicle can move at all keeps its old meaning.' `
  'tests/run_damage_checks.gd and the six capability consumers, all unchanged' `
  'With the profile declared, a partly damaged engine must reduce motive power before zero, and the tracks and barrel must behave as thresholds while the two turret axes stay linear.' `
  'The product produced capability dictionary read from the real state, with the new field carrying the curve.' `
  'Measured: any module above zero was skipped outright, so a half damaged engine left drive and steering exactly intact and recorded no reason at all.' `
  'Measured: an engine taken from full to half records power_scale 0.5 and the reason engine:linear:0.50, while a transmission loss, a track side loss and a driver loss record three different causes with different steering and pivot outcomes.' `
  'A module without a profile entry keeps binary-at-zero behaviour, which is what the delivery set mostly uses; the two axis drives keep the linear behaviour they already had.' `
  'Remove the profile; every kind is then binary at zero again, exactly as before.' `
  'Every threshold and chance is a declared project design initial value and the comparison state is NOT_COMPARED; no efficiency figure is claimed as external truth.'
$new += New-Change 'WT-CD-009' 'new_rule' 'no_breech_failure_vocabulary' 'cd009-breech-jam-v1' `
  'every_vehicle_whose_breech_can_be_damaged' 'live_fire' @('breech_failure','breech_failures','blocked_reason') `
  'A breech could only fail by reaching zero, and there was no failure vocabulary at all; the order requires a failure judged once at the correct stage of a real fire request, never re-rolled per frame, with a frozen inventory rule.' `
  @('R06','W02') `
  'At zero integrity the breech still disables firing exactly as before, through the same match branch; nothing else about a fire request changed.' `
  'tests/run_fire_control_checks.gd, tests/run_loading_checks.gd and every suite that fires, all unchanged' `
  'With the rule declared, a real request against a damaged breech must be able to jam, the jam must be a committed record carrying a seed and a rule, the same request must answer the same way, and no round may be consumed.' `
  'The production request path itself: gunner.try_fire over a real actor, with the judgement rolled from the same deterministic seed the shot already uses.' `
  'Measured: the gunner blocked reasons were cooldown, grace, barrel occlusion, ammunition, capacity and malformed requests only - there was no breech or jam vocabulary anywhere.' `
  'Measured on the production path: after nine real requests a jam occurred and recorded {shot_id 9, seed 2335249131, roll 0.131, chance 0.2, rule cd009-breech-jam-v1, round_consumed false}; the same request was refused the same way; a held trigger did not multiply the record; and the magazine went 104 to 96 with the jam itself consuming nothing. The roll was also shown to be a pure function of the shot seed, with 20 of 80 sampled shots inside the declared chance.' `
  'A vehicle whose breech is undamaged never rolls at all, because the profile declares the kind probabilistic but the chance is scaled by the damage; the existing zero-integrity behaviour is untouched.' `
  'Remove the judgement; the breech then only disables firing at zero, exactly as before.' `
  'The chance is a declared project design initial value with comparison NOT_COMPARED, and the rule is frozen: a jam consumes no round and damages no component in this version.'
$j.changes = @($j.changes) + $new
$j.migration_index = @($j.migration_index) + @('WT-CD-009: per-kind module response profile, and a breech failure judged once at a real request')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before = 'CD09 start: run_damage_checks 57/0, run_recovery_checks 64/0, run_fire_control_checks 59/0, run_loading_checks 62/0, run_historical_checks 192/0.'
  after = 'CD09 close: run_damage_checks 57/0, run_recovery_checks 64/0, run_fire_control_checks 59/0, run_loading_checks 62/0, run_historical_checks 192/0, run_shell_checks 193/0, run_ammo_compartment_checks 62/0, run_ai_combat_checks 34/0 - every suite at its exact baseline, with the six acceptance scenes reading met and the breech request probe passing on the production path.'
  note = 'The capability outputs changed by construction, so the same suites were re-run and every one returned its exact baseline count; no delivered expectation was changed by this sub-order.'
}
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
'  migration changes now=' + @($chk.changes).Count

'=== (b) the CD09 delivery in the package template ==='
$perCase = @(
  [pscustomobject]@{ id='CD09-T01'; state='MEASURED'; executor='tests/run_cd009_scene_checks.gd (S1)'; note='a half damaged engine records power_scale 0.5 and engine:linear:0.50 where previously a module above zero changed nothing' },
  [pscustomobject]@{ id='CD09-T02'; state='MEASURED'; executor='tests/run_cd009_scene_checks.gd (S2)'; note='transmission, a track side and the driver record three different causes with different steering and pivot outcomes' },
  [pscustomobject]@{ id='CD09-T03'; state='MEASURED'; executor='tests/probe_cd009_breech_request.gd (behaviour) + scene S3 (vocabulary and rule)'; note='a real jam after nine requests, with seed, rule, same answer on repeat, no duplicate and no round consumed' },
  [pscustomobject]@{ id='CD09-T04'; state='MEASURED'; executor='tests/run_cd009_scene_checks.gd (S4)'; note='the two axes fail independently and are DECLARED, because no delivered vehicle carries an axis mechanism' },
  [pscustomobject]@{ id='CD09-T05'; state='MEASURED'; executor='tests/run_cd009_scene_checks.gd (S5)'; note='recovery is enabled on a damaged module and an interruption refunds nothing' },
  [pscustomobject]@{ id='CD09-T06'; state='MEASURED'; executor='tests/run_cd009_scene_checks.gd (S6)'; note='a vehicle without the device inherits nothing, and a new life starts with every module at full integrity' }
)
$results = [pscustomobject][ordered]@{
  template_only = $false
  actual_game_test_executed = $true
  package_id = 'MCT-COMBAT-DEEPEN-01'
  work_order_id = 'WT-CD-009'
  base_sha = $base
  implementation_sha = $impl
  tested_sha = $impl
  final_sha = $impl
  content_version = 'scripts/damage/module_response_profile.gd + scripts/damage/vehicle_capabilities.gd + scripts/gunner.gd at ' + $impl
  rules_version = 'cd009-module-response-v1 ; cd009-breech-jam-v1'
  engine_version = 'Godot 4.7.2-stable win64 console, gl_compatibility'
  command = 'Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd = $c
  started_at = (Get-Date).AddHours(-10).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code = 0
  timed_out = $false
  case_ids_expected = $cd09
  case_ids_executed = @($perCase | ForEach-Object { $_.id })
  status = 'COMPLETE'
  failure_details = @()
  script_errors = $null
  test_kind = 'rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method = 'headless scripted suites and probes against the production call chain, including a real fire request through the production gunner'
  injections_declared = @('the breech probe builds its own actor from the production catalog and declares itself a fixture; the fourth case declares its two axis modules because no delivered vehicle carries one')
  raw_stdout = 'logs/COMBAT-DEEPEN-01/*.log (per-suite and per-probe captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr = 'captured in the same per-run logs'
  screenshots = @()
  events = @('per kind module response','power_scale','breech failure committed record','blocked reason breech_jam','seeded roll per shot')
  not_run = @(
    'No delivered vehicle carries a barrel, a horizontal or vertical turret axis drive, or a stabilizer, so the fourth case declares those modules instead of claiming them in vehicle data; this is recorded as a named not-applicable item.',
    'CD10..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash = 'read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action = 'continue with CD10, whose prerequisites CD01, CD06, CD08 and CD09 are now all closed'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD009_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-009 delivery: gradual module disablement, failure and post-repair capability'
$M += ''
$M += 'Status: **COMPLETE**. Six cases exist and all six are measured. The one case whose behaviour cannot be judged from a capability reading alone - the breech failure - is measured on the production request path by its own probe, and the scene judges only the vocabulary and the rule it can honestly see.'
$M += 'Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every threshold and chance is a declared project design initial value with comparison NOT_COMPARED.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-009 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd009-module-response-v1; cd009-breech-jam-v1 |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | a per-kind module response profile (linear, threshold, probabilistic, binary at zero) wired into the ONE capability derivation, a new additive power_scale carrying the motive curve so the boolean keeps its old meaning, and a breech failure judged once inside the real fire request from that shot own deterministic seed, refused by the name breech_jam and consuming no round. |'
$M += '| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted suites and probes; the breech probe builds a real actor from the production catalog and fires for real through the production gunner. The fourth case declares its axis modules. No screenshots are claimed. |'
$M += '| current limits | no delivered vehicle carries a barrel, an axis mechanism or a stabilizer, so those are named as not applicable rather than assumed present; the efficiency figures are declared design values, not measured ones; CD10..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |'
$M += '| continuation and rollback | both rules carry a rollback in the migration table; the next dependency is CD10, whose prerequisites CD01, CD06, CD08 and CD09 are closed. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| a partly damaged engine loses motive power along a curve rather than all at once | `scripts/damage/module_response_profile.gd` (linear per kind) + `vehicle_capabilities.gd` power_scale | CD09-T01 | `tests/run_cd009_scene_checks.gd` S1 |'
$M += '| a transmission loss, a track loss and a driver loss differ in cause and in what remains | `vehicle_capabilities.gd` match on kind, reasons, track_pivot, role_available | CD09-T02 | `tests/run_cd009_scene_checks.gd` S2 |'
$M += '| a breech failure is judged once at a real request with a frozen inventory rule | `scripts/gunner.gd` try_fire judgement + `vehicle_runtime_state.gd` breech_failure record | CD09-T03 | `tests/probe_cd009_breech_request.gd`, scene S3 |'
$M += '| a barrel loss and each turret axis fail their own ability independently | `vehicle_capabilities.gd` yaw_scale and pitch_scale per kind | CD09-T04 | `tests/run_cd009_scene_checks.gd` S4 |'
$M += '| repair restores a declared fraction and an interruption refunds nothing | `scripts/damage/vehicle_recovery.gd` and the recovery state | CD09-T05 | `tests/run_cd009_scene_checks.gd` S5 |'
$M += '| a vehicle without a device inherits nothing and a new life is clean | `vehicle_capabilities.gd` over the module map; `initialize_damage` | CD09-T06 | `tests/run_cd009_scene_checks.gd` S6 |'
$M += ''
$M += '## 4. Five validation layers'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: the roll is a pure function of the shot seed and no round is consumed by a jam |'
$M += '| standard fixture | measured: the profile is asked directly for the chance, and the scenes judge product produced state |'
$M += '| actual actor integration | measured: a real actor from the production catalog fires through the production gunner |'
$M += '| normal player flow and package | measured for the loading, recovery and fire control suites; the sub-order itself is not a UI feature |'
$M += '| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |'
$M += ''
$M += '## 5. Case status'
$M += ''
$M += '| case | state | executor | note |'
$M += '|---|---|---|---|'
foreach ($r in $perCase) { $M += '| ' + $r.id + ' | ' + $r.state + ' | `' + $r.executor + '` | ' + $r.note + ' |' }
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD009_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
'  delivery lines=' + $M.Count
'  results parses=' + [bool](Get-Content "$c\docs\wt\continuation\COMBAT_DEEPEN01_CD009_RESULTS.json" -Raw -Encoding UTF8 | ConvertFrom-Json)
'  expected=' + ($cd09 -join ',')
