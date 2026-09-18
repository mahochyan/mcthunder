# MCT-COMBAT-DEEPEN-01 / WT-CD-009 delivery: gradual module disablement, failure and post-repair capability

Status: **COMPLETE**. Six cases exist and all six are measured. The one case whose behaviour cannot be judged from a capability reading alone - the breech failure - is measured on the production request path by its own probe, and the scene judges only the vocabulary and the rule it can honestly see.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every threshold and chance is a declared project design initial value with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-009 |
| base_sha | `c0b7b9c6741ee96b8ff6fb447ac9bfdbff3e5b18` |
| implementation_sha | `03d36f8c5cefdd411d4ac164357238f6f38fae63` |
| tested_sha | `03d36f8c5cefdd411d4ac164357238f6f38fae63` |
| final_sha | `03d36f8c5cefdd411d4ac164357238f6f38fae63` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd009-module-response-v1; cd009-breech-jam-v1 |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | a per-kind module response profile (linear, threshold, probabilistic, binary at zero) wired into the ONE capability derivation, a new additive power_scale carrying the motive curve so the boolean keeps its old meaning, and a breech failure judged once inside the real fire request from that shot own deterministic seed, refused by the name breech_jam and consuming no round. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted suites and probes; the breech probe builds a real actor from the production catalog and fires for real through the production gunner. The fourth case declares its axis modules. No screenshots are claimed. |
| current limits | no delivered vehicle carries a barrel, an axis mechanism or a stabilizer, so those are named as not applicable rather than assumed present; the efficiency figures are declared design values, not measured ones; CD10..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | both rules carry a rollback in the migration table; the next dependency is CD10, whose prerequisites CD01, CD06, CD08 and CD09 are closed. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| a partly damaged engine loses motive power along a curve rather than all at once | `scripts/damage/module_response_profile.gd` (linear per kind) + `vehicle_capabilities.gd` power_scale | CD09-T01 | `tests/run_cd009_scene_checks.gd` S1 |
| a transmission loss, a track loss and a driver loss differ in cause and in what remains | `vehicle_capabilities.gd` match on kind, reasons, track_pivot, role_available | CD09-T02 | `tests/run_cd009_scene_checks.gd` S2 |
| a breech failure is judged once at a real request with a frozen inventory rule | `scripts/gunner.gd` try_fire judgement + `vehicle_runtime_state.gd` breech_failure record | CD09-T03 | `tests/probe_cd009_breech_request.gd`, scene S3 |
| a barrel loss and each turret axis fail their own ability independently | `vehicle_capabilities.gd` yaw_scale and pitch_scale per kind | CD09-T04 | `tests/run_cd009_scene_checks.gd` S4 |
| repair restores a declared fraction and an interruption refunds nothing | `scripts/damage/vehicle_recovery.gd` and the recovery state | CD09-T05 | `tests/run_cd009_scene_checks.gd` S5 |
| a vehicle without a device inherits nothing and a new life is clean | `vehicle_capabilities.gd` over the module map; `initialize_damage` | CD09-T06 | `tests/run_cd009_scene_checks.gd` S6 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: the roll is a pure function of the shot seed and no round is consumed by a jam |
| standard fixture | measured: the profile is asked directly for the chance, and the scenes judge product produced state |
| actual actor integration | measured: a real actor from the production catalog fires through the production gunner |
| normal player flow and package | measured for the loading, recovery and fire control suites; the sub-order itself is not a UI feature |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD09-T01 | MEASURED | `tests/run_cd009_scene_checks.gd (S1)` | a half damaged engine records power_scale 0.5 and engine:linear:0.50 where previously a module above zero changed nothing |
| CD09-T02 | MEASURED | `tests/run_cd009_scene_checks.gd (S2)` | transmission, a track side and the driver record three different causes with different steering and pivot outcomes |
| CD09-T03 | MEASURED | `tests/probe_cd009_breech_request.gd (behaviour) + scene S3 (vocabulary and rule)` | a real jam after nine requests, with seed, rule, same answer on repeat, no duplicate and no round consumed |
| CD09-T04 | MEASURED | `tests/run_cd009_scene_checks.gd (S4)` | the two axes fail independently and are DECLARED, because no delivered vehicle carries an axis mechanism |
| CD09-T05 | MEASURED | `tests/run_cd009_scene_checks.gd (S5)` | recovery is enabled on a damaged module and an interruption refunds nothing |
| CD09-T06 | MEASURED | `tests/run_cd009_scene_checks.gd (S6)` | a vehicle without the device inherits nothing, and a new life starts with every module at full integrity |
