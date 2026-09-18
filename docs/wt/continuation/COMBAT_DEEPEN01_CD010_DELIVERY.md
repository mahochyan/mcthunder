# MCT-COMBAT-DEEPEN-01 / WT-CD-010 delivery: loading, split ammunition, detonation and compartment state

Status: **COMPLETE**. Six cases exist and all six are measured. The single ledger the order requires to stay is the one that was already there, the reaction profile is the new piece, and the deterministic compartment rule that already existed is kept as the legacy strategy rather than replaced.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every chance, loss fraction and isolation credit is a declared project design initial value with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-010 |
| base_sha | `03d36f8c5cefdd411d4ac164357238f6f38fae63` |
| implementation_sha | `1df67a216396dccc87bd3ce31deb19af9275905a` |
| tested_sha | `1df67a216396dccc87bd3ce31deb19af9275905a` |
| final_sha | `1df67a216396dccc87bd3ce31deb19af9275905a` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd10-ammo-reaction-v1; legacy wt015-rear-bustle-v1 kept |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | an ammunition reaction profile answering with not_exploded, burning, partial_loss or lethal from the storage class, the damage channel and the compartment state, a committed reaction record on the state whose compartment view reads the barrier and vent integrity LIVE, and one gunner method that moves the loss out of the racks into lost so the single ledger still balances. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted scenes driving the production loading machinery, with both engineering vehicles admitted through the documented separate entry point. No screenshots are claimed. |
| current limits | no dynamic door model, so the compartment is a project logical abstraction with a scope note as the order permits; the reaction numbers are design values rather than measured ones; CD11..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | the rule carries a rollback in the migration table; the legacy compartment rule is untouched and keeps its determinism; the next dependency is CD11, whose prerequisite CD09 is closed. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| a destroyed loading mechanism leaves the lawfully chambered round usable | `scripts/gunner.gd` loading path and `LoadingRules.module_available` | CD10-T01 | `tests/run_cd010_scene_checks.gd` S1 |
| the ready rack refills from the reserve on its own clock | `scripts/defs/loading_profile.gd` replenishment block | CD10-T02 | `tests/run_cd010_scene_checks.gd` S2 |
| an inert body store and a propellant store react differently | `scripts/damage/ammo_reaction_profile.gd` store class and reaction chance | CD10-T03 | `tests/run_cd010_scene_checks.gd` S3 |
| venting and crew risk follow the actual isolation and the loss is explainable | `AmmoReactionProfile.compartment_state` + `vehicle_runtime_state.ammo_compartment_view` | CD10-T04 | `tests/run_cd010_scene_checks.gd` S4 |
| a hit during a transfer duplicates and loses nothing and priority is recorded | `scripts/damage/ammo_inventory.gd` move sequence and transfer slot | CD10-T05 | `tests/run_cd010_scene_checks.gd` S5 |
| one death and one ticket, and a new life from the frozen loadout | the death record and the frozen initial loadout | CD10-T06 | `tests/run_cd010_scene_checks.gd` S6 + the conservation print |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: an unprotected store is read conservatively as mixed rather than optimistically |
| standard fixture | measured: the conservation identity is read from the production ledger itself |
| actual actor integration | measured: real engineering vehicles through the documented admission entry point |
| normal player flow and package | measured for the loading, recovery and ammunition compartment suites |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD10-T01 | MEASURED | `tests/run_cd010_scene_checks.gd (S1)` | with the autoloader at zero the chambered round remains and the vehicle can still fire, which is the lawful last round |
| CD10-T02 | MEASURED | `tests/run_cd010_scene_checks.gd (S2)` | replenishment is enabled on its own clock, 8 s delay and 20 s interval, with ready and reserve both stocked, so a refill is gradual |
| CD10-T03 | MEASURED | `tests/run_cd010_scene_checks.gd (S3) + scripts/damage/ammo_reaction_profile.gd` | the store kind, the damage channel and the compartment state each change the answer, and an inert penetrator does not remove propellant risk |
| CD10-T04 | MEASURED | `tests/run_cd010_scene_checks.gd (S4)` | isolated against vent_only once the real barrier module is damaged, and the loss is reported by the reaction record |
| CD10-T05 | MEASURED | `tests/run_cd010_scene_checks.gd (S5)` | the transfer accounting is committed and the recovery state is enabled, so nothing is duplicated or lost |
| CD10-T06 | MEASURED | `tests/run_cd010_scene_checks.gd (S6) + the conservation print` | the death record is untouched and the book accounts exactly: 37 plus 1 against 38 on the T-80, 41 plus 1 against 42 on the Leopard |

## 6. Conservation as measured at close

```
T-80B   : racks 37 + transfer 0 + chamber 1 + fired 0 + lost 0 = 38 accounted, 38 supplied
Leopard : racks 41 + transfer 0 + chamber 1 + fired 0 + lost 0 = 42 accounted, 42 supplied
==> the book accounts exactly on both vehicles, and the assertion in the scene is the weaker relation that must hold.
```
