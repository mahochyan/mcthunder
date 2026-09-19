# MCT-COMBAT-DEEPEN-01 / WT-CD-013 delivery: death, loss and multi-contributor attribution

Status: **COMPLETE**. Six cases exist and all six are measured, and the last two of them are JUDGED ON BEHAVIOUR rather than on a class merely existing: a dedicated probe drives the ledger attribution rule, its assist window, its named refusals, its deduplication and its sustained fire inheritance.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. The assist window and every threshold are declared project design initial values with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-013 |
| base_sha | `6132bcfa8c25d466a3c3dda7482c50965c38eccb` |
| implementation_sha | `12c2c2aa2eb8d12bb5bf69b2d1510b1ae2395e94` |
| tested_sha | `12c2c2aa2eb8d12bb5bf69b2d1510b1ae2395e94` |
| final_sha | `12c2c2aa2eb8d12bb5bf69b2d1510b1ae2395e94` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd13-contribution-v1; cd13-attribution-v1 |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | one ContributionLedger service that completes the event identity itself, keeps five SEPARATE counters whose subject and dedup key are deliberately distinct, applies a frozen versioned attribution rule with a declared assist window and named refusals for friendly fire, abandonment, an environmental death and an orphaned fire, inherits sustained fire through a root effect and emits settlement receipts. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted scenes over a real match whose director has spawned and committed its opening events, one scene per case, plus a dedicated probe driving the ledger directly. No screenshots are claimed. |
| current limits | the ledger RECORDS and is neither the death authority nor the ticket authority, which is deliberate and written into the class; the long multi seed batch match suite is out of this gate and runs separately; CD14..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | both rules carry a rollback; the death gate and the ticket ledger were never touched; the next dependency is CD14. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| one shot damaging several modules counts one firing and at most one kill | `contribution_ledger.gd` five separate counters, with the runtime `destroy_once` gate | CD13-T01 | `tests/run_cd013_scene_checks.gd` S1 |
| attribution and assists follow a fixed version and duplicates add nothing | `ContributionLedger.attribute` and `credit_kill` under `cd13-attribution-v1` | CD13-T02 | scene S2 + `tests/probe_cd013_ledger_behaviour.gd` |
| several legitimate damages in one tick give one death, one ticket, one loss and one reward | the versioned event stream, `ticket_ledger` and the death gate | CD13-T03 | `tests/run_cd013_scene_checks.gd` S3 |
| a round in flight keeps its attribution and an old event does not injure a new life | the ledger dedup keys plus the runtime `destroy_once` gate | CD13-T04 | scene S4 + the probe |
| a live round death closes one life chain and re-enters keeping the loadout | the runtime state, the respawn service and the ledger receipts | CD13-T05 | `tests/run_cd013_scene_checks.gd` S5 |
| the match ledger keeps history, the end freezes and the next match is distinct | the ledger own event list, never the replay buffer, plus `finish_once` | CD13-T06 | `tests/run_cd013_scene_checks.gd` S6 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: friendly fire, abandonment, an environmental death and an orphaned fire are each refused by name and score nothing |
| standard fixture | measured: the assist window boundary and the tie-breaking order |
| actual actor integration | measured: a real match scene per case, with the director having spawned and committed its opening events |
| normal player flow and package | measured across the match, damage, recovery and ammunition suites, all green |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD13-T01 | MEASURED | `tests/run_cd013_scene_checks.gd (S1)` | destroy_once true then false, and a real death event lands in the versioned stream |
| CD13-T02 | MEASURED | `tests/run_cd013_scene_checks.gd (S2) + tests/probe_cd013_ledger_behaviour.gd` | the frozen rule names primary shooter_C and assist shooter_A under cd13-attribution-v1 and refuses friendly fire |
| CD13-T03 | MEASURED | `tests/run_cd013_scene_checks.gd (S3)` | one tick gives exactly one death event and a ticket move of 300 to 270 |
| CD13-T04 | MEASURED | `tests/run_cd013_scene_checks.gd (S4) + the probe` | a stale cause is refused, the ledger version is present and no kill is credited |
| CD13-T05 | MEASURED | `tests/run_cd013_scene_checks.gd (S5)` | destroyed with all eight module keys preserved, the death accepted once and a respawn service present |
| CD13-T06 | MEASURED | `tests/run_cd013_scene_checks.gd (S6)` | the end is frozen, the sequence advances, the next match has its own identity and the ledger keeps all ten events |

## 6. The honest history of this sub-order, recorded because it matters
```
1. The FIRST PASS built its match state by hand and its own readings exposed it: zero events, no match identity and a
   director that had never begun. It was committed as a first pass with that stated, not dressed up.
2. The SECOND PASS used the fixture the existing match suite proved - a real scene awaited until its director had spawned
   and committed its opening events, one scene per case - and every reading then carried a real identity and nine events.
3. Three device faults of mine were then cleared by reading the code that gates each call rather than by guessing: the
   ticket after-value was read before the death happened; the re-entry case demanded only a director report field this
   path does not update; and the contact record I fed the director had three wrong names, because the round must be a
   round_id matching the match, the shot is identified by projectile_id, the outcome is a result string and the life must
   be the one the roster holds.
4. A WEAK PASS was then caught and removed rather than left standing: the second and fourth cases passed on the ledger
   EXISTING, so a dedicated probe was written and the scene now drives the ledger and requires the frozen rule to decide.
5. One failure in that probe turned out to be MY probe time, not a missing rule: reading the sustained fire attribution
   thirty seconds after it started fell outside the twelve second window, and inside the window the origin is preserved.
6. The same instrument mistake from CD12 was repeated and then named: ClassDB lists engine classes only and never sees a
   script class, so an existence check reported false for a class that parses cleanly.
THE TICKET LEDGER AND THE RUNTIME DEATH GATE WERE NEVER REPLACED, and no delivered expectation was edited at any point.
```
