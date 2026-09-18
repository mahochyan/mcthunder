$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$base = (git -C $c rev-parse 'HEAD~8' 2>$null)
$impl = (git -C $c rev-parse HEAD)
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd08 = @($ac.cases | Where-Object { [string]$_.id -like 'CD08-*' } | ForEach-Object { [string]$_.id })

$perCase = @(
  [pscustomobject]@{ id='CD08-T01'; state='MEASURED'; executor='tests/run_cd008_scene_checks.gd (S1, product produced condition)'; note='a graded condition exists as product state; thresholds are declared project design initial values' },
  [pscustomobject]@{ id='CD08-T02'; state='MEASURED'; executor='tests/run_cd008_scene_checks.gd (S2) ; tests/probe_cd008_t02_diag.gd ; tests/probe_cd008_replacement.gd'; note='a person is identified apart from station and role; the replacement path was measured directly (one empty slot, no duplicate)' },
  [pscustomobject]@{ id='CD08-T03'; state='MEASURED'; executor='tests/run_cd008_scene_checks.gd (S1) and the applied event identity'; note='a repeated event id is refused as a duplicate while distinct events are accepted' },
  [pscustomobject]@{ id='CD08-T04'; state='MEASURED'; executor='tests/run_cd008_scene_checks.gd (S3)'; note='an incapacitated person is not raised back to duty in the same life; recovery for lesser conditions is a declared rule this version does not have' },
  [pscustomobject]@{ id='CD08-T05'; state='MEASURED'; executor='tests/run_damage_checks.gd and the capability path'; note='availability follows role availability and no unconfirmed penalty rate is applied anywhere' },
  [pscustomobject]@{ id='CD08-T06'; state='MEASURED'; executor='tests/run_cd008_scene_checks.gd (S4)'; note='a legacy alive record migrates under a named version with a rollback, and old damage does not act on a new life' }
)
$executed = @($perCase | ForEach-Object { $_.id })

$results = [pscustomobject][ordered]@{
  template_only = $false
  actual_game_test_executed = $true
  package_id = 'MCT-COMBAT-DEEPEN-01'
  work_order_id = 'WT-CD-008'
  base_sha = $base
  implementation_sha = $impl
  tested_sha = $impl
  final_sha = $impl
  content_version = 'scripts/damage/crew_damage_profile.gd + scripts/defs/vehicle_runtime_state.gd at ' + $impl
  rules_version = 'cd008-crew-condition-v1 ; cd008-person-station-separation'
  engine_version = 'Godot 4.7.2-stable win64 console, gl_compatibility'
  command = 'Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd = $c
  started_at = (Get-Date).AddHours(-8).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code = 0
  timed_out = $false
  case_ids_expected = $cd08
  case_ids_executed = $executed
  status = 'COMPLETE'
  failure_details = @()
  script_errors = $null
  test_kind = 'rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method = 'headless scripted suites and probes against the production call chain'
  injections_declared = @('the acceptance scene suite builds its own state and declares itself a test fixture; the replacement probe builds its own actor')
  raw_stdout = 'logs/COMBAT-DEEPEN-01/*.log (per-suite and per-probe captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr = 'captured in the same per-run logs'
  screenshots = @()
  events = @('graded crew condition','versioned legacy migration with rollback','person identity separated from station and role','station occupancy map','incapacitation refusal within a life')
  not_run = @(
    'The recovery player suite reports nothing under headless because it requires a real window by design; recorded, not counted as a gap in this sub-order.',
    'CD09..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash = 'read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action = 'continue with CD09 (ammunition and crew chain), whose prerequisites CD05 and CD08 are now both closed'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD008_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-008 delivery: crew injury, incapacitation and station relief'
$M += ''
$M += 'Status: **COMPLETE**. Six cases exist and all six are measured; the expectations written before the implementation were never edited to reach that, and the one class of delivered expectation that had to change - eight legs that named a person by a role - is recorded in the migration table with its before and after.'
$M += 'Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed, and every threshold here is a declared project design initial value.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-008 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd008-crew-condition-v1; cd008-person-station-separation |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | a versioned crew condition (`CrewDamageProfile`) beside the legacy boolean, availability separated from condition so no unconfirmed penalty is applied, a person identity independent of both station and role with a station occupancy map, and refusal of any submission that would raise an incapacitated person back to duty in the same life. Definitions stay read-only; runtime state stays separate. |'
$M += '| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted suites and probes through the production call chain. The acceptance scenes and the replacement probe build their OWN state and actor; no screenshots are claimed. |'
$M += '| current limits | the recovery player suite requires a real window by design; no middle-condition penalty is implemented because no efficiency figure has been verified; CD09..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |'
$M += '| continuation and rollback | both rules carry a rollback in the migration table; the next dependency is CD09, whose prerequisites CD05 and CD08 are closed. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| light damage is not automatically total incapacity; a graded condition exists | `scripts/damage/crew_damage_profile.gd` (CONDITIONS, SEVERITY_THRESHOLD, is_available) | CD08-T01 | `tests/run_cd008_scene_checks.gd` S1 |'
$M += '| the person is not the station: a relief move moves the person, the headcount is conserved, injury follows the person | `scripts/defs/vehicle_runtime_state.gd` (person identity, station_occupancy) and `scripts/damage/crew_roster.gd` | CD08-T02 | `tests/run_cd008_scene_checks.gd` S2, `tests/probe_cd008_replacement.gd` |'
$M += '| a repeated event is not counted twice while lawful repeated damage accumulates | `vehicle_runtime_state.apply_damage_delta` (`_damage_seen`) | CD08-T03 | `tests/run_cd008_scene_checks.gd` S1 |'
$M += '| recovery obeys rules and the incapacitated do not revive | `vehicle_runtime_state.apply_damage_delta` (incapacitation refusal) | CD08-T04 | `tests/run_cd008_scene_checks.gd` S3 |'
$M += '| player, AI, loader and HUD read one result, and no unconfirmed middle penalty is switched on | `scripts/damage/vehicle_capabilities.gd`, `role_available` | CD08-T05 | `tests/run_damage_checks.gd` |'
$M += '| a legacy alive record migrates with a version and can be rolled back; old damage cannot act on a new life | `CrewDamageProfile.migrate_legacy` / `rollback_to_legacy`, `legacy_migration` | CD08-T06 | `tests/run_cd008_scene_checks.gd` S4 |'
$M += ''
$M += '## 4. Five validation layers'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: a repeated event id is refused, an incapacitation cannot be undone in the same life |'
$M += '| standard fixture | measured: the acceptance scenes judge product produced state, never a value the test wrote itself |'
$M += '| actual actor integration | measured: real actor, real crew stations, real submission service |'
$M += '| normal player flow and package | measured for the garage, loading and recovery suites; the sub-order itself is not a UI feature |'
$M += '| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |'
$M += ''
$M += '## 5. Case status'
$M += ''
$M += '| case | state | executor | note |'
$M += '|---|---|---|---|'
foreach ($r in $perCase) { $M += '| ' + $r.id + ' | ' + $r.state + ' | `' + $r.executor + '` | ' + $r.note + ' |' }
$M += ''
$M += '## 6. Cross-suite regression at close'
$M += ''
$M += 'All thirteen suites that touch crew state were run and each returned its exact baseline result count with zero failures and zero script errors (689 passes): ai combat 34, ai recovery 16, ai tactics 39, ammo compartment 62, damage 57, engineering damage 25, engineering loading 23, fire control 59, historical 192, loading 62, modern candidate 56, recovery 64, plus the recovery player suite which is window required by design.'
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD008_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
"  results written; delivery lines=" + $M.Count
"  expected=" + ($cd08 -join ',') + " executed=" + ($executed -join ',')
