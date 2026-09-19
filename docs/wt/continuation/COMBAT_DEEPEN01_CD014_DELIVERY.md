# MCT-COMBAT-DEEPEN-01 / WT-CD-014 delivery: realistic sortie rules and out-of-match settlement

Status: **COMPLETE**. Six cases exist and all six are MEASURED, and the last two of them are driven through real behaviour rather than probed for a stored key: the personal sortie book is fed by committed events and the sortie transaction runs all four steps the order names.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every sortie point value, vehicle cost and income figure is a declared project design initial value with comparison NOT_COMPARED, and where a real battle rating or price is absent the project uses project_balance_band rather than inventing one.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-014 |
| base_sha | `399ae69c7cf9bc466e0478aaf990f96a8bbb24ad` |
| implementation_sha | `736e06980f75384ad89977bcea2155906cd6ad69` |
| tested_sha | `736e06980f75384ad89977bcea2155906cd6ad69` |
| final_sha | `736e06980f75384ad89977bcea2155906cd6ad69` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd14-ground-rb-preset-v1; cd14-personal-sp-book-v1; cd14-sortie-transaction-v1; cd14-rule-version-interpreter-v1 |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | a realistic rule preset that sits BESIDE the old one with four separate books, an initial sortie balance, per class costs, a repeat limit, contribution income and the four transaction steps; a personal sortie book fed by committed events with an event key dedup and a never negative balance; and a rule version interpreter that explains a stored result by its own version or refuses an unknown one by name. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted scenes driving the real preset, garage, profile store and progression services, plus the new sortie service through all four steps. No screenshots are claimed. |
| current limits | every value is a project design initial value and the comparison state is NOT_COMPARED; no paid store, account service or real currency exists, which the order excludes; CD15..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | four rules carry a rollback each; team_standard_300, the ticket ledger and the runtime death gate were never touched; the next dependency is CD15. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| the old mode is preserved and new behaviour lives only in a new preset | `GroundRbLikePreset` beside `MatchRulePreset` | CD14-T01 | `tests/run_cd014_scene_checks.gd` S1 |
| the four books never share a balance and income follows committed events | `SortieService.earn` with an event key | CD14-T02 | scene S2 |
| a failed or cancelled sortie releases its reservation and a repeat is idempotent | `SortieService.request`, `release`, `confirm`, `commit` | CD14-T03 | scene S3 |
| the line-up refuses uniformly with a visible reason and never generates a default hull | `Lineup.validate` and `GarageService.has_vehicle` | CD14-T04 | scene S4 |
| a repeated settlement does not reward twice and the profile is written transactionally | `ProgressionService.apply_result_once` and `ProfileStore.commit` | CD14-T05 | scene S5 |
| a historical result is read by its own rule version and an unknown one is refused | `RuleVersionInterpreter.interpret` | CD14-T06 | scene S6 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: an unaffordable request is refused by name and a balance never goes negative |
| standard fixture | measured: a blocked spawn and a cancellation both release with the balance untouched |
| actual actor integration | measured: the real preset, garage, store and progression services, and the four transaction steps |
| normal player flow and package | measured across six garage, save, match and damage suites at 334 passes with no failures |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD14-T01 | MEASURED | `tests/run_cd014_scene_checks.gd (S1)` | the old preset keeps id, version, 300 tickets and the SAME fingerprint while the new one reports ground_rb_like_v1 |
| CD14-T02 | MEASURED | `tests/run_cd014_scene_checks.gd (S2)` | a committed event credits once for 570 from 450, a replayed event is refused as already earned, and no balance ever went negative |
| CD14-T03 | MEASURED | `tests/run_cd014_scene_checks.gd (S3)` | a blocked spawn and a cancellation both release with the balance untouched, a repeat token is idempotent with zero charged, and an unaffordable request is refused |
| CD14-T04 | MEASURED | `tests/run_cd014_scene_checks.gd (S4)` | an unconfigured vehicle is refused with a reason and the garage does not claim to hold it |
| CD14-T05 | MEASURED | `tests/run_cd014_scene_checks.gd (S5)` | the first settlement pays 60 and the repeat returns duplicate with zero, and the store commit succeeds transactionally |
| CD14-T06 | MEASURED | `tests/run_cd014_scene_checks.gd (S6)` | version one is explained as team_standard_300 and version 999 is refused by name with an action |

## 6. The honest history of this sub-order, recorded because it matters
```
1. The FIRST PASS wired nothing: no new preset file, no personal book and no reservation bookkeeping, and its own readings
   said exactly that rather than leaving it to guesswork.
2. A whole chain of my own device faults was cleared by READING THE CODE THAT GATES EACH CALL rather than by guessing: the
   result entry point needs a registered token whose director is bound and finished; the store commit rejects any key count
   other than the declared schema, so a probe key was refused BY DESIGN; the config builder reports a refusal through
   REASON rather than errors, which is why an earlier print came back empty; the value must carry a loadouts dictionary;
   and the line-up may hold at most three vehicles where six were passed.
3. A WRONG CONDITION of mine was corrected against the service own body: not rewarding twice is reported as a DUPLICATE
   with zero points, not as a failure, and the first pass read a correctly behaving product as a gap.
4. TWO WEAK PROBES were replaced before anyone had to ask: the second and third cases had been looking for a stored
   profile KEY, which can never work because the schema validates an exact key count, and both now DRIVE the behaviour.
5. A mojibake in a captured refusal reason was SETTLED rather than left hanging: the localization service falls back to a
   bracketed key only when a string is missing, the table holds the key, and the garbling was in how console output was
   decoded - recorded as a measurement with no product fault claimed from it.
6. GDScript resolves a referenced static symbol while PARSING, so probing for a function that does not exist yet with
   has_method on a class is rejected outright, and those probes became runtime file checks.
TEAM_STANDARD_300, THE TICKET LEDGER AND THE RUNTIME DEATH GATE WERE NEVER REPLACED, and no delivered expectation was
edited at any point.
```
