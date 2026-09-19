# MCT-COMBAT-DEEPEN-01 / WT-CD-012 delivery: optics, stabilisation, ranging and battle intelligence

Status: **COMPLETE for the six cases, with the machinery CONFIRMED rather than replaced**. All six cases hold BEFORE any implementation, because the policy and support rules the basis described are measured to be in place. The order asks for the observation, sight intent, barrel ability and visible information to be SEPARATED, and the measurement shows they already are.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every precision, expiry, attenuation and blocking value is a declared project design initial value with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-012 |
| base_sha | `9493e2867a03386fabc27d9810b0c71d941b5671` |
| implementation_sha | `239bd843f7fa15744b3bf52ed7a76eaaf507c083` |
| tested_sha | `239bd843f7fa15744b3bf52ed7a76eaaf507c083` |
| final_sha | `239bd843f7fa15744b3bf52ed7a76eaaf507c083` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd12-observation-and-support-wired-v1, existing rules confirmed and nothing replaced |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | no rule was replaced. The observation policy information classes, their per source precision and expiry, the media rules that separate physical blocking from visual attenuation, the per vehicle smoke and recon declarations and the internal field guard are CONFIRMED in place and exercised by six scenes through the production objects. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted scenes over the production policy and support objects, plus eight existing optics, sight, support and fire control suites re-run green. No screenshots are claimed. |
| current limits | thermal imaging and radar stay explicitly UNSUPPORTED rather than being faked; the wiring of the existing machinery onto the command and information interfaces and the committed events remain as the next step; CD13..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING. |
| continuation and rollback | no policy value changed, so there is no rule to roll back; removing the scenes leaves the machinery as it was found; the next dependency is CD13. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| free look and binocular must not command the turret | `scripts/camera_rig.gd` view direction against `turret_rig.gd` and the actor command path | CD12-T01 | `tests/run_cd012_scene_checks.gd` S1 |
| the barrel follows a configured stabiliser, not a camera option | `VehicleCapabilities.stabilizer_available` with the sight profile | CD12-T02 | `tests/run_cd012_scene_checks.gd` S2 |
| ranging, zeroing, muzzle occlusion and the shot share one solve | `scripts/defs/optics_profile.gd` and `fire_control_state.gd` with the occlusion check | CD12-T03 | scene S3 + `run_sight_ballistics_checks.gd` |
| smoke affects both the aids and the AI, and world truth is authority only | `ObservationPolicy.MEDIA_RULES`, `CHANNELS`, `record` and `query` | CD12-T04 | `tests/run_cd012_scene_checks.gd` S4 |
| a mark carries its source and expires, and last seen does not follow | `SupportActions.recon_mark` and `recon_marks_now` with `expiry_for` | CD12-T05 | `tests/run_cd012_scene_checks.gd` S5 |
| an unequipped vehicle is denied and occlusion is not a display setting | `SupportActions.CAPABILITIES` and `ObservationPolicy.visual_blocked` | CD12-T06 | `tests/run_cd012_scene_checks.gd` S6 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: world truth is refused from a client view, and a building blocks a projectile while smoke does not |
| standard fixture | measured: the per source precision and expiry ordering, and the optical against thermal attenuation |
| actual actor integration | measured: the production policy and support objects are driven directly, and the existing sight and fire control suites pass |
| normal player flow and package | measured across eight existing suites at 265 passes with no failures |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD12-T01 | MEASURED | `tests/run_cd012_scene_checks.gd (S1)` | recording an observation leaves the turret yaw at 0.000, so observation does not command the turret |
| CD12-T02 | MEASURED | `tests/run_cd012_scene_checks.gd (S2)` | the stabiliser reads false when absent and true when present, so it is a configured capability rather than a camera option |
| CD12-T03 | MEASURED | `tests/run_cd012_scene_checks.gd (S3)` | a building blocks a projectile while smoke does not, and smoke still occludes the optical channel |
| CD12-T04 | MEASURED | `tests/run_cd012_scene_checks.gd (S4)` | world truth is refused from a client view, and smoke occludes optical 1.000 against thermal 0.600 |
| CD12-T05 | MEASURED | `tests/run_cd012_scene_checks.gd (S5)` | the mark carries its source and expires: one mark at one second and none long after |
| CD12-T06 | MEASURED | `tests/run_cd012_scene_checks.gd (S6)` | an unequipped hull reports no smoke and no recon while an equipped vehicle reports both, and smoke occlusion is a rule |

## 6. What was measured rather than assumed, including my own mistakes
```
1. The basis was confirmed by reading the sources, not by trusting the sentence: all six named files exist and the four
   information classes, the per source precision and expiry, the media rules and the per vehicle smoke and recon
   declarations were already there, so the order needed CONFIRMATION and WIRING rather than a new perception system.
2. Two suite names I used early on DO NOT EXIST and reported zero checks. The real ones were measured - observation
   policy, optics, sight ballistics, support actions, modern support, partial support - and used instead, which is why the
   re-run reports 265 real checks rather than zero.
3. Three device faults of mine in the scenes were found by measurement and fixed, and the expectations were never touched:
   the attenuation figure is OCCLUSION STRENGTH so smoke occludes optical MORE than thermal and my comparison was
   reversed; the support capability table uses its own vehicle keys rather than catalogue ids, so I was testing a vehicle
   that is not in it; the recon mark refused my source string because only declared spawn sources may mark; and the
   recon reply nests the mark under its own key, so a working mark looked like a broken one.
4. NO PRODUCTION CODE WAS CHANGED to make any of this pass, and no delivered expectation was edited at any point.
```
