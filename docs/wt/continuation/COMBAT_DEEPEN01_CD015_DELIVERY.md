# MCT-COMBAT-DEEPEN-01 / WT-CD-015 delivery: feedback, replay and the existing authoritative network on one chain

Status: **COMPLETE**. Six cases exist and all six are MEASURED, and the three cases whose first pass was weak are now driven on the real objects rather than read for a file name: the presentation layer is stopped on the range own projectile manager, the shell family gate is driven with all four declared families, and the authority surface is driven by three real processes.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every sound gain, event point, attenuation and version table value is a declared project design initial value with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-015 |
| base_sha | `39762ec96040f03a43117a6c269bbbec5d1ef1eb` |
| implementation_sha | `38a6b4b3cb15fba2b8477fca9e93c8d2826bc882` |
| tested_sha | `38a6b4b3cb15fba2b8477fca9e93c8d2826bc882` |
| final_sha | `38a6b4b3cb15fba2b8477fca9e93c8d2826bc882` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd15-presentation-consumer-v1; cd15-shell-family-effects-v1; cd15-record-interpretation-v1; cd15-local-authority-v1; cd15-information-permission-v1 |

`base_sha` is the commit after the user ruling and the CD07-T04 close, so the base is the state in which the user allowed CD15 to open. The evidence commit (this delivery) is separate from the tested commit, and the tested commit is where the two CD15 runners stand.

**The whole sub-order changed no production code.** `git diff --name-only 39762ec9..38a6b4b3` returns only `docs/`, `logs/` and `tests/` paths; nothing under `scripts/`, `configs/`, `scenes/` or `assets/` was touched. That is a checked fact, not a claim, and it is what the five migration entries mean when they say CONFIRMED rather than replaced.

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | five rules CONFIRMED on the existing chain instead of a second system: the presentation layer consumes committed events only and can be stopped without touching settlement; the shell family gate admits four declared families each with its own impact profile and refuses an undeclared one by name; a stored record is explained by its own rule version or refused; the local authority refuses a spoofed identity, a stale sequence, an unknown message and a client claimed hit across three real processes; and the information permission is driven with its internal field guard and a real spectator projection. |
| source identity | the table above, with the evidence commit separated from the tested commit and the zero production change verified by path. |
| run evidence | real command lines, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; thirteen headless suites at 879 checks with no failures, two CD15 runners, and the three-process authority harness under `logs/wt009/20260919-121531/`. |
| operational evidence | headless scripted scenes driving the real match range, the real spawn gate, the interpreter and the policy; the presentation mapping table below is the operational contract. No screenshot and no recording is claimed, and the interactive runners that need a window or an argument are recorded as NOT RUN rather than counted green. |
| current limits | every value is a project design initial value with comparison NOT_COMPARED; the presentation mapping discriminates by committed event kind and priority and NOT yet by shell family, caliber band or hit material; `run_ammo_compartment_checks` carries a pre-existing test-suite script error and is not counted green; CD16 NOT_RUN; performance HOLD_BY_USER; human PENDING; release_ready=false; public_release=false. |
| continuation and rollback | five migration entries with a rollback each; the feedback layer, the replay chain, the authority server and the information policy were NOT replaced; the next dependency is CD16. |

## 3. Deliverable one: the presentation event and resource mapping

The mapping is the presentation half of the order, and it is a table rather than an opinion. The event kind is produced by the committed path, the resource is resolved by name, and a missing resource degrades to silence instead of a fault or a borrowed asset.

| committed event kind | audio clip (`assets/audio/`) | caption key | particle channel | priority |
|---|---|---|---|---|
| `shot` | `shot.wav` | `ui_eefc14db1d25` | - | 3 |
| `flyby` | `flyby.wav` | `ui_31f64f460df5` | - | 1 |
| `reload` | `reload.wav` | `ui_f75e3b3c92c9` | - | 3 |
| `non_penetration` | `non_penetration.wav` | `ui_45c77ca87652` | bounded burst | 2 |
| `ricochet` | `ricochet.wav` | `ui_ccc03fd96808` | bounded burst | 2 |
| `penetrated` | `penetrated.wav` | `ui_3a2fddbbba86` | bounded burst | 2 |
| `world` | `world.wav` | `ui_e5138fa0d11b` | bounded burst, dust colour `c6b58d` | 1 |
| `explosion` | `explosion.wav` | `ui_421ca87ebbdb` | - | 4 |
| `destroyed` | `destroyed.wav` | `ui_633312c90ed3` | - | 4 |
| `engine` / `tracks` / `turret` / `fire` | the matching loop clip | - | - | 0 |

| requirement the order names | code location | state |
|---|---|---|
| only committed events are consumed | `CombatFeedback.on_combat_event`, `on_shot`, `on_contact`, `on_finished` | measured: stopping the layer leaves nine committed events and tickets 300/300 |
| the mapping resolves a resource by name | `CombatAudioPool.stream(kind)` reading `res://assets/audio/<kind>.wav` | measured by `run_feedback_checks` (40/0), which checks thirteen clips |
| the asset source is declared, not borrowed | `assets/audio/manifest.json` with `source: Original mathematical synthesis by this project; no recorded samples`, `redistribute_source_allowed: true`, a generator and a sha256 per clip | measured by the same suite at its own check |
| a missing resource degrades and never crashes | `CombatAudioPool.stream` returns null and `play_voice` returns false; the particle pool needs no asset at all | measured by reading the branch; the FX meshes are built procedurally in `CombatFXPool._ready` |
| turning presentation off changes nothing settled | `CombatFeedback.stop_all`, `fx_level`, `audio_volume` | measured by case one |
| selection by shell family, caliber band and hit material | NOT delivered as such | named limit: the mapping discriminates by event kind and priority, and the only material distinction today is the world against vehicle particle colour |

## 4. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| sound, particles and hit prompts only consume committed events and never decide settlement | `CombatFeedback` on the range own `ProjectileManager`, `stop_all` | CD15-T01 | `tests/run_cd015_scene_checks.gd` S1 prints REACHED AND STOPPED=true; probe P1 proves 9 -> 9 events and tickets 300/300 -> 300/300 |
| each shell family produces its own effect from a real event and an unexploded round is never given a lethal burst | `ProjectileManager.try_spawn` effect policy gate, `ArmorImpactProfile` per family profile | CD15-T02 | scene S2 and probe P2: four families accepted, `refusals=[]`, undeclared refused as `invalid_effect_policy`, lone burst `none` |
| an old and a new rule record are explained or explicitly unsupported and never re-settled | `RuleVersionInterpreter.interpret` with `ShotRecordCodec` and `ShotRecordBuilder` | CD15-T03 | scene S3 and probe P3: v1 explained as `team_standard_300`, v999 refused as `unknown_rule_version:999` with `refuse_or_migrate` |
| one server and two clients agree on the authority result and identity, and a client adds no kill or reward | `NetworkBattleServer.reject`, `_freeze_finish`, and the three-process `tests/run_network_slice.gd` | CD15-T04 | three real processes, identical digest `b7a1c492...`, `not_owner:2`, `unsupported_message:2` for a client `claim_hit`, `unsupported_version:4` |
| replayed, duplicated and expired input does not double charge and a reconnect returns to the right rule and content version | `NetworkIdentityPolicy` stale sequence refusal, event journal retention, baseline queueing | CD15-T05 | `run_network_event_recovery_checks` 58/0 drives the initial baseline, a duplicate batch, a malformed suffix, a tick regression, the retention window and an overlapping resync |
| an observer gets only permitted information and enemy live internals do not leak through extended fields | `ObservationPolicy.INFO_CLASSES`, `is_internal_field`, `project` | CD15-T06 | scene S6: four classes read, internal guard true, spectator projection source `observer_visible` |

## 5. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: an undeclared effect is refused by name, an unknown rule version is refused with an action, and a spoofed identity, a stale sequence, an unknown message and a claimed hit are each refused with a counter |
| standard fixture | measured: all four declared families are driven through the real spawn gate with their own complete impact profiles, and a round that reaches nothing produces no burst |
| actual actor integration | measured: the real begun match range, its own projectile manager and feedback layer, the real interpreter, the real server through three processes, and the CD12 policy |
| normal player flow and package | NOT_RUN for this sub-order: the interactive runners that need a window or an argument refuse headless by their own guard, so they are recorded rather than counted; thirteen headless suites stand at 879 checks with no failures |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 6. Case status

| case | state | executor | note |
|---|---|---|---|
| CD15-T01 | MEASURED | `tests/run_cd015_scene_checks.gd (S1)`, `tests/probe_cd015_feedback_behaviour.gd (P1)` | with the presentation layer stopped, the same match keeps nine committed events and tickets 300/300 |
| CD15-T02 | MEASURED | scene S2, probe P2 | all four declared families accepted with zero refusals, an undeclared effect refused by name, no burst for a lone round |
| CD15-T03 | MEASURED | scene S3, probe P3 | version one explained as `team_standard_300`, version 999 refused with reason and action, codec and builder present |
| CD15-T04 | MEASURED | `tests/run_network_slice.ps1` (three processes) and scene S4 | one authority and two production clients on the same final digest, with four named refusals; the clients report `passed=true` |
| CD15-T05 | MEASURED | `run_network_event_recovery_checks.gd` 58/0 and scene S5 | baseline, duplicate batch, malformed suffix, tick regression, retention window and overlapping resync all driven |
| CD15-T06 | MEASURED | scene S6 | four information classes, the internal field guard, and a spectator projection from `observer_visible` rather than world truth |

## 7. The honest history of this sub-order, recorded because it matters

```
1. STAGE ZERO STOPPED AT A REAL PICKUP GAP and asked rather than worked around: of the eight prerequisites,
   CD003, CD004 and CD006 had no result file, and CD007 declared COMPLETE_WITH_GAPS at five of six cases with
   CD07-T04 never run. The user ruled that CD07-T04 be BUILT AND MEASURED FIRST and that the evidence-document
   form of the other three be ACCEPTED with the difference stated. Both were done in that order.
2. THE FIRST PASS ADMITTED TWO WEAK PASSES INSTEAD OF DRESSING THEM UP: the presentation half of case one was
   never exercised - the probe looked for a projectile manager as a CHILD of the match scene, found none, and
   said so - and several conditions rested on FILE EXISTENCE rather than behaviour.
3. BOTH WEAKNESSES WERE THEN REMOVED BY MEASUREMENT, NOT BY REWORDING, and the removal is recorded commit by
   commit: the layer was reached through the range OWN projectiles member, the four families were driven through
   the real gate, the interpreter was driven, and the authority surface was driven by three real processes.
4. TWO DEVICE FAULTS OF MINE closed the last gap and both were mine rather than the product: the long-rod family
   is validated by its own rule set, which FORBIDS the full-caliber normalization and overmatch fields and
   demands an explicit bounded angle curve, so it needed its own profile; and two probes shared identifiers with
   the indexed family loop and were refused as duplicate_launch, which is the manager correctly refusing a
   relaunch of the same round.
5. THE AUTHORITY HALF WAS RAISED ABOVE SOURCE-STRING READING rather than left as it was: the three-process
   harness is now measured, and its own aggregate flag reads FALSE because it reads a NULL process exit code
   while each process printed its PASS line, both clients report passed=true and all three digests are identical.
   That instrument fault is stated here rather than smoothed over.
6. ONE OUT-OF-SCOPE DEFECT IS NAMED RATHER THAN ABSORBED: run_ammo_compartment_checks prints 62 checks with no
   failures but carries a pre-existing SCRIPT ERROR in its own line 104, recorded in this package since the CD07
   and CD10 rounds. It is a test-suite fault outside this change set and it is NOT counted green.
7. THE PRESENTATION MAPPING IS DELIVERED WITH ITS LIMIT VISIBLE: the mapping, the thirteen project-synthesised
   clips with their hashes and the missing-resource degradation are measured; selection by shell family, caliber
   band and hit material is NOT delivered, and it is named in the current limits instead of being implied.
THE FEEDBACK LAYER, THE REPLAY CHAIN, THE AUTHORITY SERVER AND THE INFORMATION POLICY WERE NOT REPLACED, no
delivered expectation was edited at any point, and NO PRODUCTION CODE WAS CHANGED for this sub-order.
```
