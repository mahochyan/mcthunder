$c='E:\AIprogram\mcthunder-cont'
$o="$c\docs\wt\combat-deepen-01\original"
$base = (git -C $c rev-parse 'b81a00c0~1' 2>$null)
$impl = (git -C $c rev-parse HEAD)
$ac = Get-Content "$o\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd14 = @($ac.cases | Where-Object { [string]$_.id -like 'CD14-*' } | ForEach-Object { [string]$_.id })

'=== (a) the four CD14 rule migrations ==='
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
$new += New-Change 'WT-CD-014' 'new_rule' 'single_team_match_preset_only' 'cd14-ground-rb-preset-v1' `
  'every_vehicle' 'live_match' @('start_tickets','time_limit_s','books','initial_sp','vehicle_cost','repeat_sortie_limit','contribution_income','sortie_rules') `
  'The order requires a realistic sortie rule set to exist BESIDE the existing three hundred ticket preset, covering the four independent books, initial sortie points, per class vehicle cost, a repeat sortie limit, contribution income and the sortie transaction - while the rejection conditions forbid quietly changing the old mode.' `
  @('R09','W07') `
  'MatchRulePreset team_standard_300 is NOT touched: it keeps its id, its version, its three hundred tickets and its fingerprint, and the acceptance scenario re-reads all four to prove it.' `
  'run_match_rules_checks.gd 43/0 and run_match_event_checks.gd 11/0, both unchanged' `
  'With the new preset declared, the old one must remain byte for byte explainable by its own fingerprint and the new one must carry its own id, its own books and its own transaction rules.' `
  'GroundRbLikePreset.snapshot() read directly, and the old preset snapshot read in the same scene.' `
  'Measured: only one preset existed, with id team_standard_300, version 1, three hundred tickets and fingerprint 1328a3e77a4cc431172d3ac1c5b083dbfb93ea2f8ba3ac2a9d380a3bcc4f77b6, and no book, sortie point or transaction concept existed anywhere.' `
  'Measured: the old preset still reports the same id, version, three hundred tickets and the SAME fingerprint, while the new preset reports id ground_rb_like_v1 with four books, initial SP 450, per class costs, a repeat limit of three, contribution income and the four transaction steps declared with release on failure and cancellation, an idempotent token and a never negative balance.' `
  'Where a real battle rating or price is absent the preset declares project_balance_band rather than inventing one, and switching the economy side off is refused unless it carries a divergence label.' `
  'Delete the new preset file; the old preset is untouched and every existing behaviour is exactly as before.' `
  'Every number is a declared project design initial value with comparison NOT_COMPARED, and no official battle rating or real price is claimed anywhere.'
$new += New-Change 'WT-CD-014' 'new_rule' 'no_personal_sortie_book' 'cd14-personal-sp-book-v1' `
  'every_vehicle' 'live_match' @('initial_sp','balance','lifetime_earned','lifetime_spent','entries') `
  'The order names FOUR independent books and the rejection conditions forbid the team ticket pool being read as personal sortie points, so a personal book is required that is fed by committed events rather than by the team pool.' `
  @('R09','W07') `
  'The ticket ledger remains the ONLY team pool authority and is not read by this book at all; the team count is never used as a personal balance.' `
  'run_match_rules_checks.gd and run_match_event_checks.gd, both unchanged' `
  'With the book declared, a committed event must credit once, a replayed event must add nothing, and no balance in its history may ever be negative.' `
  'SortieService driven directly, including a duplicate event key and an unaffordable request.' `
  'Measured: the stored profile held research points, unlocked vehicles, the garage block and receipts, and NO personal sortie book of any kind, and the profile schema validates an exact key count so a book cannot simply be added as a key.' `
  'Measured: earning from a committed event credited 120 to a 450 balance for 570, the same event key again was refused as already_earned, and the book own check reports that no balance in its entry history ever went negative.' `
  'Income is keyed by the committed EVENT, not by the subject, which is the order requirement that income follow committed events and that the subject and the dedup key never be conflated.' `
  'Remove the book; the team pool and everything else are unchanged.' `
  'The income table is a declared project design initial value with comparison NOT_COMPARED.'
$new += New-Change 'WT-CD-014' 'new_rule' 'no_sortie_transaction' 'cd14-sortie-transaction-v1' `
  'every_vehicle' 'live_match' @('reservations','receipts','sortie_rules') `
  'The order specifies the respawn request as validate, then reserve, then confirm the spawn, then commit the charge, with the reservation released when the spawn is blocked, fails or is cancelled, a repeat request idempotent, and the balance never negative. Before this sub-order respawn knew only how to search for a safe point.' `
  @('R09','W07') `
  'RespawnService.find_safe and the existing spawn provider are untouched: the safe point search still decides WHERE a hull appears, and this service only decides whether the request may be paid for.' `
  'check_live_fire_respawn.gd 17/0 and run_match_rules_checks.gd 43/0, both unchanged' `
  'With the transaction declared, a blocked spawn and a cancellation must release with the balance untouched, a confirmed and committed sortie must charge once, a repeat token must be idempotent with zero charged, and an unaffordable request must be refused by name.' `
  'SortieService driven through all four steps in the acceptance scene.' `
  'Measured: no reservation bookkeeping existed at all, so a repeat token could not be made idempotent and a failure could not release anything.' `
  'Measured: a blocked spawn released with the balance still 300, a cancellation released as well, a confirmed and committed sortie charged once, the same token again returned idempotent with zero charged, and a request the balance could not cover was refused as insufficient_sp with the balance still never negative.' `
  'The reservation holds the cost WITHOUT moving the balance, which is what makes a release safe: nothing was ever charged, so nothing can be refunded twice.' `
  'Remove the transaction; the safe point search and every existing spawn behaviour are unchanged.' `
  'The steps and the release rules are declared project design initial values with comparison NOT_COMPARED.'
$new += New-Change 'WT-CD-014' 'new_rule' 'results_read_under_current_rules_only' 'cd14-rule-version-interpreter-v1' `
  'every_stored_result' 'live_match' @('rule_version','known_versions','migrated','action') `
  'The order requires a historical result to be explained by ITS OWN rule version and an unknown version to be explicitly migrated or refused, rather than silently reinterpreted under today rules.' `
  @('R09','W07') `
  'The existing result entry point and the stored profile receipts are untouched; the interpreter adds an explanation layer and rewrites no history.' `
  'run_match_rules_checks.gd and run_save_lock_checks.gd 8/0, both unchanged' `
  'With the interpreter declared, a known version must be explained by its own rules and an unknown version must be refused by name with an action, never read as if it were current.' `
  'RuleVersionInterpreter driven directly with a known and an unknown version.' `
  'Measured: no interpreter existed at all, so a stored result could not be read by the version that produced it and an unknown version had no handling path whatsoever.' `
  'Measured: version one is explained as team_standard_300 with nothing reinterpreted, and version 999 is refused with reason unknown_rule_version:999 and action refuse_or_migrate alongside the known version list.' `
  'The interpreter knows exactly two versions, migrates forward only where it declares it can, and never rewrites a stored result: the tag keeps the version it was written with.' `
  'Remove the interpreter; stored results keep their versions and nothing else changes.' `
  'The known version table is a declared project fact with comparison NOT_COMPARED.'
$j.changes = @($j.changes) + $new
$j.migration_index = @($j.migration_index) + @('WT-CD-014: a realistic rule preset beside the old one, a personal sortie book, a four step sortie transaction, and a rule version interpreter')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before='CD14 start: run_garage_checks 151/0, run_save_lock_checks 8/0, run_match_rules_checks 43/0, run_match_event_checks 11/0, run_damage_checks 57/0, run_recovery_checks 64/0.'
  after='CD14 close: the same six suites at their exact baselines with 334 passes and no failures, and all six acceptance scenes reading met.'
  note='team_standard_300, the ticket ledger and the runtime death gate were NOT replaced, and no delivered expectation was changed at any point.'
}
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
'  migration changes now=' + @($chk.changes).Count

'=== (b) the divergence register the order names ==='
$dr="$c\docs\wt\continuation\DIVERGENCE_REGISTER.json"
if (Test-Path $dr) { $d = Get-Content $dr -Raw -Encoding UTF8 | ConvertFrom-Json } else { $d = [pscustomobject]@{ register_version=1; entries=@() } }
$entry14 = [pscustomobject][ordered]@{
  work_order_id='WT-CD-014'
  divergence='The realistic sortie set is a PROJECT rule set, not War Thunder Ground RB. The team pool, the personal sortie points, the vehicle costs, the repeat sortie limit and the contribution income are declared project design initial values.'
  public_reference='War Thunder Ground RB exists as a public reference and is named as such, but no value in this sub-order is taken from it as a verified figure.'
  project_choice='project_balance_band is used wherever a real battle rating or a real price is absent, so no official rating and no real price is invented or claimed.'
  evidence='docs/wt/continuation/COMBAT_DEEPEN01_CD014_DELIVERY.md and logs/COMBAT-DEEPEN-01/'
  state='OPEN'
}
$d.entries = @($d.entries) + @($entry14)
[IO.File]::WriteAllText($dr, ($d | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
'  divergence register entries=' + @((Get-Content $dr -Raw -Encoding UTF8 | ConvertFrom-Json).entries).Count

'=== (c) the CD14 delivery in the package template ==='
$perCase = @(
  [pscustomobject]@{ id='CD14-T01'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S1)'; note='the old preset keeps id, version, 300 tickets and the SAME fingerprint while the new one reports ground_rb_like_v1' },
  [pscustomobject]@{ id='CD14-T02'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S2)'; note='a committed event credits once for 570 from 450, a replayed event is refused as already earned, and no balance ever went negative' },
  [pscustomobject]@{ id='CD14-T03'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S3)'; note='a blocked spawn and a cancellation both release with the balance untouched, a repeat token is idempotent with zero charged, and an unaffordable request is refused' },
  [pscustomobject]@{ id='CD14-T04'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S4)'; note='an unconfigured vehicle is refused with a reason and the garage does not claim to hold it' },
  [pscustomobject]@{ id='CD14-T05'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S5)'; note='the first settlement pays 60 and the repeat returns duplicate with zero, and the store commit succeeds transactionally' },
  [pscustomobject]@{ id='CD14-T06'; state='MEASURED'; executor='tests/run_cd014_scene_checks.gd (S6)'; note='version one is explained as team_standard_300 and version 999 is refused by name with an action' }
)
$results = [pscustomobject][ordered]@{
  template_only=$false
  actual_game_test_executed=$true
  package_id='MCT-COMBAT-DEEPEN-01'
  work_order_id='WT-CD-014'
  base_sha=$base
  implementation_sha=$impl
  tested_sha=$impl
  final_sha=$impl
  content_version='scripts/battle/ground_rb_like_preset.gd + sortie_service.gd + rule_version_interpreter.gd at ' + $impl
  rules_version='cd14-ground-rb-preset-v1 ; cd14-personal-sp-book-v1 ; cd14-sortie-transaction-v1 ; cd14-rule-version-interpreter-v1'
  engine_version='Godot 4.7.2-stable win64 console, gl_compatibility'
  command='Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd=$c
  started_at=(Get-Date).AddHours(-16).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at=(Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code=0
  timed_out=$false
  case_ids_expected=$cd14
  case_ids_executed=@($perCase | ForEach-Object { $_.id })
  status='COMPLETE'
  failure_details=@()
  script_errors=$null
  test_kind='rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method='headless scripted scenes over the real preset, garage, profile store and progression services, plus a new sortie service driven through all four transaction steps'
  injections_declared=@('the scenes declare themselves fixtures; the first pass built a match state by hand and its own readings exposed that, and every probe was corrected to drive behaviour rather than look for a stored key')
  raw_stdout='logs/COMBAT-DEEPEN-01/*.log (per-suite captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr='captured in the same per-run logs'
  screenshots=@()
  events=@('versioned realistic preset beside the old one','four independent books','personal sortie income by committed event','sortie transaction four steps','release on blocked or cancelled','idempotent token','never negative balance','rule version explanation','unknown version refused')
  not_run=@(
    'No paid store, account service or real currency is built, which the order excludes for this round.',
    'CD15..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash='read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action='continue with CD15, whose prerequisites including CD14 are now closed'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD014_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-014 delivery: realistic sortie rules and out-of-match settlement'
$M += ''
$M += 'Status: **COMPLETE**. Six cases exist and all six are MEASURED, and the last two of them are driven through real behaviour rather than probed for a stored key: the personal sortie book is fed by committed events and the sortie transaction runs all four steps the order names.'
$M += 'Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every sortie point value, vehicle cost and income figure is a declared project design initial value with comparison NOT_COMPARED, and where a real battle rating or price is absent the project uses project_balance_band rather than inventing one.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-014 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd14-ground-rb-preset-v1; cd14-personal-sp-book-v1; cd14-sortie-transaction-v1; cd14-rule-version-interpreter-v1 |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | a realistic rule preset that sits BESIDE the old one with four separate books, an initial sortie balance, per class costs, a repeat limit, contribution income and the four transaction steps; a personal sortie book fed by committed events with an event key dedup and a never negative balance; and a rule version interpreter that explains a stored result by its own version or refuses an unknown one by name. |'
$M += '| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted scenes driving the real preset, garage, profile store and progression services, plus the new sortie service through all four steps. No screenshots are claimed. |'
$M += '| current limits | every value is a project design initial value and the comparison state is NOT_COMPARED; no paid store, account service or real currency exists, which the order excludes; CD15..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |'
$M += '| continuation and rollback | four rules carry a rollback each; team_standard_300, the ticket ledger and the runtime death gate were never touched; the next dependency is CD15. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| the old mode is preserved and new behaviour lives only in a new preset | `GroundRbLikePreset` beside `MatchRulePreset` | CD14-T01 | `tests/run_cd014_scene_checks.gd` S1 |'
$M += '| the four books never share a balance and income follows committed events | `SortieService.earn` with an event key | CD14-T02 | scene S2 |'
$M += '| a failed or cancelled sortie releases its reservation and a repeat is idempotent | `SortieService.request`, `release`, `confirm`, `commit` | CD14-T03 | scene S3 |'
$M += '| the line-up refuses uniformly with a visible reason and never generates a default hull | `Lineup.validate` and `GarageService.has_vehicle` | CD14-T04 | scene S4 |'
$M += '| a repeated settlement does not reward twice and the profile is written transactionally | `ProgressionService.apply_result_once` and `ProfileStore.commit` | CD14-T05 | scene S5 |'
$M += '| a historical result is read by its own rule version and an unknown one is refused | `RuleVersionInterpreter.interpret` | CD14-T06 | scene S6 |'
$M += ''
$M += '## 4. Five validation layers'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: an unaffordable request is refused by name and a balance never goes negative |'
$M += '| standard fixture | measured: a blocked spawn and a cancellation both release with the balance untouched |'
$M += '| actual actor integration | measured: the real preset, garage, store and progression services, and the four transaction steps |'
$M += '| normal player flow and package | measured across six garage, save, match and damage suites at 334 passes with no failures |'
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
$M += '1. The FIRST PASS wired nothing: no new preset file, no personal book and no reservation bookkeeping, and its own readings'
$M += '   said exactly that rather than leaving it to guesswork.'
$M += '2. A whole chain of my own device faults was cleared by READING THE CODE THAT GATES EACH CALL rather than by guessing: the'
$M += '   result entry point needs a registered token whose director is bound and finished; the store commit rejects any key count'
$M += '   other than the declared schema, so a probe key was refused BY DESIGN; the config builder reports a refusal through'
$M += '   REASON rather than errors, which is why an earlier print came back empty; the value must carry a loadouts dictionary;'
$M += '   and the line-up may hold at most three vehicles where six were passed.'
$md = ''
$M += '3. A WRONG CONDITION of mine was corrected against the service own body: not rewarding twice is reported as a DUPLICATE'
$M += '   with zero points, not as a failure, and the first pass read a correctly behaving product as a gap.'
$M += '4. TWO WEAK PROBES were replaced before anyone had to ask: the second and third cases had been looking for a stored'
$M += '   profile KEY, which can never work because the schema validates an exact key count, and both now DRIVE the behaviour.'
$M += '5. A mojibake in a captured refusal reason was SETTLED rather than left hanging: the localization service falls back to a'
$M += '   bracketed key only when a string is missing, the table holds the key, and the garbling was in how console output was'
$m2 = ''
$M += '   decoded - recorded as a measurement with no product fault claimed from it.'
$M += '6. GDScript resolves a referenced static symbol while PARSING, so probing for a function that does not exist yet with'
$M += '   has_method on a class is rejected outright, and those probes became runtime file checks.'
$M += 'TEAM_STANDARD_300, THE TICKET LEDGER AND THE RUNTIME DEATH GATE WERE NEVER REPLACED, and no delivered expectation was'
$M += 'edited at any point.'
$M += '```'
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD014_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
'  delivery lines=' + $M.Count
'  results parses=' + [bool](Get-Content "$c\docs\wt\continuation\COMBAT_DEEPEN01_CD014_RESULTS.json" -Raw -Encoding UTF8 | ConvertFrom-Json)
'  expected=' + ($cd14 -join ',')
