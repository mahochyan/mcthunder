# MCT-COMBAT-DEEPEN-01 / WT-CD-008 delivery: crew injury, incapacitation and station relief

Status: **COMPLETE**. Six cases exist and all six are measured; the expectations written before the implementation were never edited to reach that, and the one class of delivered expectation that had to change - eight legs that named a person by a role - is recorded in the migration table with its before and after.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed, and every threshold here is a declared project design initial value.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-008 |
| base_sha | `deb6033f2ef1adde83b584de1e824ba9b7af33f1` |
| implementation_sha | `b29662201933f17a99a46690d962a532cacd3257` |
| tested_sha | `b29662201933f17a99a46690d962a532cacd3257` |
| final_sha | `b29662201933f17a99a46690d962a532cacd3257` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd008-crew-condition-v1; cd008-person-station-separation |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | a versioned crew condition (`CrewDamageProfile`) beside the legacy boolean, availability separated from condition so no unconfirmed penalty is applied, a person identity independent of both station and role with a station occupancy map, and refusal of any submission that would raise an incapacitated person back to duty in the same life. Definitions stay read-only; runtime state stays separate. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted suites and probes through the production call chain. The acceptance scenes and the replacement probe build their OWN state and actor; no screenshots are claimed. |
| current limits | the recovery player suite requires a real window by design; no middle-condition penalty is implemented because no efficiency figure has been verified; CD09..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | both rules carry a rollback in the migration table; the next dependency is CD09, whose prerequisites CD05 and CD08 are closed. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| light damage is not automatically total incapacity; a graded condition exists | `scripts/damage/crew_damage_profile.gd` (CONDITIONS, SEVERITY_THRESHOLD, is_available) | CD08-T01 | `tests/run_cd008_scene_checks.gd` S1 |
| the person is not the station: a relief move moves the person, the headcount is conserved, injury follows the person | `scripts/defs/vehicle_runtime_state.gd` (person identity, station_occupancy) and `scripts/damage/crew_roster.gd` | CD08-T02 | `tests/run_cd008_scene_checks.gd` S2, `tests/probe_cd008_replacement.gd` |
| a repeated event is not counted twice while lawful repeated damage accumulates | `vehicle_runtime_state.apply_damage_delta` (`_damage_seen`) | CD08-T03 | `tests/run_cd008_scene_checks.gd` S1 |
| recovery obeys rules and the incapacitated do not revive | `vehicle_runtime_state.apply_damage_delta` (incapacitation refusal) | CD08-T04 | `tests/run_cd008_scene_checks.gd` S3 |
| player, AI, loader and HUD read one result, and no unconfirmed middle penalty is switched on | `scripts/damage/vehicle_capabilities.gd`, `role_available` | CD08-T05 | `tests/run_damage_checks.gd` |
| a legacy alive record migrates with a version and can be rolled back; old damage cannot act on a new life | `CrewDamageProfile.migrate_legacy` / `rollback_to_legacy`, `legacy_migration` | CD08-T06 | `tests/run_cd008_scene_checks.gd` S4 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: a repeated event id is refused, an incapacitation cannot be undone in the same life |
| standard fixture | measured: the acceptance scenes judge product produced state, never a value the test wrote itself |
| actual actor integration | measured: real actor, real crew stations, real submission service |
| normal player flow and package | measured for the garage, loading and recovery suites; the sub-order itself is not a UI feature |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD08-T01 | MEASURED | `tests/run_cd008_scene_checks.gd (S1, product produced condition)` | a graded condition exists as product state; thresholds are declared project design initial values |
| CD08-T02 | MEASURED | `tests/run_cd008_scene_checks.gd (S2) ; tests/probe_cd008_t02_diag.gd ; tests/probe_cd008_replacement.gd` | a person is identified apart from station and role; the replacement path was measured directly (one empty slot, no duplicate) |
| CD08-T03 | MEASURED | `tests/run_cd008_scene_checks.gd (S1) and the applied event identity` | a repeated event id is refused as a duplicate while distinct events are accepted |
| CD08-T04 | MEASURED | `tests/run_cd008_scene_checks.gd (S3)` | an incapacitated person is not raised back to duty in the same life; recovery for lesser conditions is a declared rule this version does not have |
| CD08-T05 | MEASURED | `tests/run_damage_checks.gd and the capability path` | availability follows role availability and no unconfirmed penalty rate is applied anywhere |
| CD08-T06 | MEASURED | `tests/run_cd008_scene_checks.gd (S4)` | a legacy alive record migrates under a named version with a rollback, and old damage does not act on a new life |

## 6. Cross-suite regression at close

All thirteen suites that touch crew state were run and each returned its exact baseline result count with zero failures and zero script errors (689 passes): ai combat 34, ai recovery 16, ai tactics 39, ammo compartment 62, damage 57, engineering damage 25, engineering loading 23, fire control 59, historical 192, loading 62, modern candidate 56, recovery 64, plus the recovery player suite which is window required by design.
