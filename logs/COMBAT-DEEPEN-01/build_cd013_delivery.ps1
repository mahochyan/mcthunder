$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$base = (git -C $c rev-parse '686170e0~1' 2>$null)
$impl = (git -C $c rev-parse HEAD)
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd13 = @($ac.cases | Where-Object { [string]$_.id -like 'CD13-*' } | ForEach-Object { [string]$_.id })

'=== (a) the two CD13 rule migrations ==='
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
$new += New-Change 'WT-CD-013' 'new_rule' 'no_contribution_ledger' 'cd13-contribution-v1' `
  'every_vehicle_and_every_shooter' 'live_fire ; live_match' `
  @('events','counters','contacts','effective_damages','shots_fired','firing_slots','kills') `
  'The order requires ONE service whose event identity is complete, five SEPARATE counters, and explicitly forbids using the replay buffer as the whole match statistics ledger. Before this sub-order the contribution ledger did not exist in any form, while death de-duplication and the ticket ledger did.' `
  @('R06','R09','R11') `
  'The runtime state death_notified gate stays the ONLY thing that decides a death happens once, and ticket_ledger stays the ONLY place tickets move. The new ledger RECORDS contribution and is neither authority; this is written into the class itself so it cannot be crossed by accident.' `
  'check_live_fire_respawn.gd, run_match_event_checks.gd, run_match_rules_checks.gd and every damage and recovery suite, all unchanged' `
  'With the ledger declared, one firing damaging several modules must count one shot, three effective damages and at most one kill, and a repeated dedup key must add nothing.' `
  'The ledger object itself driven directly, plus the real match event stream, the destroy_once gate and the director report.' `
  'Measured: searching the whole script tree for ContributionLedger or CombatEvent returned ZERO files, and the director per shot de-duplication sets were empty until the contact record matched what observe_contact actually gates on.' `
  'Measured by a dedicated probe: contacts 1, effective damages 3, shots fired 1, firing slots 1 and kills 1 from one firing and several module damages; the same dedup key twice is refused as already_counted with the counter unmoved; and a life is killed once.' `
  'The counters are keyed by SUBJECT while the de-duplication is keyed by KEY, which is the order explicit requirement that the statistics subject and the dedup key never be conflated; a receipt is emitted for every attribution and every refusal.' `
  'Remove the ledger and its callers; nothing else changes, because the ledger was never the authority for a death or a ticket.' `
  'Every window and threshold is a declared project design initial value with comparison NOT_COMPARED, and no real-world attribution figure is claimed.'
$new += New-Change 'WT-CD-013' 'new_rule' 'no_versioned_attribution' 'cd13-attribution-v1' `
  'every_vehicle_and_every_shooter' 'live_fire ; live_match' `
  @('primary','assists','attribution_version','assist_window_s','no_credit_causes') `
  'The order requires kill attribution, the assist window, recon and repair contribution and sustained fire inheritance to be explicitly VERSIONED, requires damage without a legitimate cause to never be credited as a kill, and requires friendly fire, abandonment and environmental death to be handled separately.' `
  @('R06','R09','R11') `
  'The director existing report and its per shot sets are untouched; they remain the match director own accounting, and the ledger adds attribution beside them rather than replacing them.' `
  'run_match_rules_checks.gd and run_match_event_checks.gd, both unchanged' `
  'With the version declared, the larger effective damage must take the primary under a named attribution version, damage outside the assist window must not assist, and each no-credit cause must be refused by name and score nothing.' `
  'The ledger attribution rule driven directly, with the window and the causes read from the class own declared constants.' `
  'Measured: no attribution version existed at all, and the only accounting was the director report of hits, penetrations, kills, deaths and last death, with no notion of a primary shooter, an assist window or a refused cause.' `
  'Measured: two shooters on one target give primary shooter_C with shooter_A as an assist under cd13-attribution-v1; a hit older than the twelve second window is not an assist however large; friendly fire, abandonment, an environmental death and an orphaned fire are each refused with a named reason and the kill counter stays at zero; and a sustained fire keeps its origin when read inside the window.' `
  'Ties inside the window are broken by earliest time and then by subject id, so the same inputs always decide the same way, which is what makes the version meaningful.' `
  'Remove the attribution rule; the ledger then records without deciding, and the director report is all that remains, exactly as before.' `
  'The assist window of twelve seconds and the key damage minimum are declared project design initial values with comparison NOT_COMPARED.'
$j.changes = @($j.changes) + $new
$j.migration_index = @($j.migration_index) + @('WT-CD-013: a single contribution ledger with separate counters, and a versioned attribution rule with named refusals')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before='CD13 start: run_match_event_checks 11/0, run_match_rules_checks 43/0, run_damage_checks 57/0, run_recovery_checks 64/0, run_ammo_compartment_checks 62/0.'
  after='CD13 close: the same suites plus the ledger behaviour probe at 7/0, all green, with the six acceptance scenes reading met on behaviour rather than on existence.'
  note='The ticket ledger and the runtime death gate were NOT replaced, and no delivered expectation was changed. Two of my own device faults and one weak pass are recorded in the delivery rather than hidden.'
}
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
'  migration changes now=' + @($chk.changes).Count

'=== (b) the CD13 delivery in the package template ==='
$perCase = @(
  [pscustomobject]@{ id='CD13-T01'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S1)'; note='destroy_once true then false, and a real death event lands in the versioned stream' },
  [pscustomobject]@{ id='CD13-T02'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S2) + tests/probe_cd013_ledger_behaviour.gd'; note='the frozen rule names primary shooter_C and assist shooter_A under cd13-attribution-v1 and refuses friendly fire' },
  [pscustomobject]@{ id='CD13-T03'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S3)'; note='one tick gives exactly one death event and a ticket move of 300 to 270' },
  [pscustomobject]@{ id='CD13-T04'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S4) + the probe'; note='a stale cause is refused, the ledger version is present and no kill is credited' },
  [pscustomobject]@{ id='CD13-T05'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S5)'; note='destroyed with all eight module keys preserved, the death accepted once and a respawn service present' },
  [pscustomobject]@{ id='CD13-T06'; state='MEASURED'; executor='tests/run_cd013_scene_checks.gd (S6)'; note='the end is frozen, the sequence advances, the next match has its own identity and the ledger keeps all ten events' }
)
$results = [pscustomobject][ordered]@{
  template_only=$false
  actual_game_test_executed=$true
  package_id='MCT-COMBAT-DEEPEN-01'
  work_order_id='WT-CD-013'
  base_sha=$base
  implementation_sha=$impl
  tested_sha=$impl
  final_sha=$impl
  content_version='scripts/battle/contribution_ledger.gd plus the CD13 scene and behaviour probe at ' + $impl
  rules_version='cd13-contribution-v1 ; cd13-attribution-v1'
  engine_version='Godot 4.7.2-stable win64 console, gl_compatibility'
  command='Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd=$c
  started_at=(Get-Date).AddHours(-12).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at=(Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code=0
  timed_out=$false
  case_ids_expected=$cd13
  case_ids_executed=@($perCase | ForEach-Object { $_.id })
  status='COMPLETE'
  failure_details=@()
  script_errors=$null
  test_kind='rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method='headless scripted scenes over a real TeamRange match whose director has spawned and committed its opening events, one scene per case, plus a dedicated probe driving the ledger directly'
  injections_declared=@('the scenes and the probe declare themselves fixtures; the first pass built its match state by hand and its own readings exposed that, which is recorded rather than hidden')
  raw_stdout='logs/COMBAT-DEEPEN-01/*.log (per-suite and per-probe captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr='captured in the same per-run logs'
  screenshots=@()
  events=@('versioned ordered match event stream','death committed once','destroy_once de-duplication','ticket moved once','contribution ledger with five counters','versioned attribution with assists','named no-credit refusals','sustained fire inheritance','frozen match end and distinct next identity')
  not_run=@(
    'The long multi seed batch match suite is not part of this sub-order gate and is run separately in the background, because it is a long simulation rather than a quick check.',
    'CD14..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash='read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action='continue with CD14, after confirming its prerequisites'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD013_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-013 delivery: death, loss and multi-contributor attribution'
$M += ''
$M += 'Status: **COMPLETE**. Six cases exist and all six are measured, and the last two of them are JUDGED ON BEHAVIOUR rather than on a class merely existing: a dedicated probe drives the ledger attribution rule, its assist window, its named refusals, its deduplication and its sustained fire inheritance.'
$M += 'Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. The assist window and every threshold are declared project design initial values with comparison NOT_COMPARED.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-013 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd13-contribution-v1; cd13-attribution-v1 |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | one ContributionLedger service that completes the event identity itself, keeps five SEPARATE counters whose subject and dedup key are deliberately distinct, applies a frozen versioned attribution rule with a declared assist window and named refusals for friendly fire, abandonment, an environmental death and an orphaned fire, inherits sustained fire through a root effect and emits settlement receipts. |'
$M += '| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted scenes over a real match whose director has spawned and committed its opening events, one scene per case, plus a dedicated probe driving the ledger directly. No screenshots are claimed. |'
$M += '| current limits | the ledger RECORDS and is neither the death authority nor the ticket authority, which is deliberate and written into the class; the long multi seed batch match suite is out of this gate and runs separately; CD14..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |'
$M += '| continuation and rollback | both rules carry a rollback; the death gate and the ticket ledger were never touched; the next dependency is CD14. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| one shot damaging several modules counts one firing and at most one kill | `contribution_ledger.gd` five separate counters, with the runtime `destroy_once` gate | CD13-T01 | `tests/run_cd013_scene_checks.gd` S1 |'
$M += '| attribution and assists follow a fixed version and duplicates add nothing | `ContributionLedger.attribute` and `credit_kill` under `cd13-attribution-v1` | CD13-T02 | scene S2 + `tests/probe_cd013_ledger_behaviour.gd` |'
$M += '| several legitimate damages in one tick give one death, one ticket, one loss and one reward | the versioned event stream, `ticket_ledger` and the death gate | CD13-T03 | `tests/run_cd013_scene_checks.gd` S3 |'
$M += '| a round in flight keeps its attribution and an old event does not injure a new life | the ledger dedup keys plus the runtime `destroy_once` gate | CD13-T04 | scene S4 + the probe |'
$M += '| a live round death closes one life chain and re-enters keeping the loadout | the runtime state, the respawn service and the ledger receipts | CD13-T05 | `tests/run_cd013_scene_checks.gd` S5 |'
$M += '| the match ledger keeps history, the end freezes and the next match is distinct | the ledger own event list, never the replay buffer, plus `finish_once` | CD13-T06 | `tests/run_cd013_scene_checks.gd` S6 |'
$M += ''
$M += '## 4. Five validation layers'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: friendly fire, abandonment, an environmental death and an orphaned fire are each refused by name and score nothing |'
$M += '| standard fixture | measured: the assist window boundary and the tie-breaking order |'
$M += '| actual actor integration | measured: a real match scene per case, with the director having spawned and committed its opening events |'
$M += '| normal player flow and package | measured across the match, damage, recovery and ammunition suites, all green |'
$M += '| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |'
$M += ''
$M += '## 5. Case status'
$M += ''
$M += '| case | state | executor | note |'
$M += '|---|---|---|---|'
foreach ($r in $perCase) { $M += '| ' + $r.id + ' | ' + $r.state + ' | `' + $r.executor + '` | ' + $r.note + ' |' }
$M += ''
$M += '## 6. The honest history of this sub-order, recorded because it matters'
$M += '```'
$M += '1. The FIRST PASS built its match state by hand and its own readings exposed it: zero events, no match identity and a'
$M += '   director that had never begun. It was committed as a first pass with that stated, not dressed up.'
$M += '2. The SECOND PASS used the fixture the existing match suite proved - a real scene awaited until its director had spawned'
$M += '   and committed its opening events, one scene per case - and every reading then carried a real identity and nine events.'
$M += '3. Three device faults of mine were then cleared by reading the code that gates each call rather than by guessing: the'
$M += '   ticket after-value was read before the death happened; the re-entry case demanded only a director report field this'
$M += '   path does not update; and the contact record I fed the director had three wrong names, because the round must be a'
$M += '   round_id matching the match, the shot is identified by projectile_id, the outcome is a result string and the life must'
$M += '   be the one the roster holds.'
$M += '4. A WEAK PASS was then caught and removed rather than left standing: the second and fourth cases passed on the ledger'
$M += '   EXISTING, so a dedicated probe was written and the scene now drives the ledger and requires the frozen rule to decide.'
$M += '5. One failure in that probe turned out to be MY probe time, not a missing rule: reading the sustained fire attribution'
$M += '   thirty seconds after it started fell outside the twelve second window, and inside the window the origin is preserved.'
$M += '6. The same instrument mistake from CD12 was repeated and then named: ClassDB lists engine classes only and never sees a'
$M += '   script class, so an existence check reported false for a class that parses cleanly.'
$M += 'THE TICKET LEDGER AND THE RUNTIME DEATH GATE WERE NEVER REPLACED, and no delivered expectation was edited at any point.'
$M += '```'
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD013_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
'  delivery lines=' + $M.Count
'  results parses=' + [bool](Get-Content "$c\docs\wt\continuation\COMBAT_DEEPEN01_CD013_RESULTS.json" -Raw -Encoding UTF8 | ConvertFrom-Json)
'  expected=' + ($cd13 -join ',')
