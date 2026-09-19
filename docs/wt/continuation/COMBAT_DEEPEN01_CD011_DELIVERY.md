# MCT-COMBAT-DEEPEN-01 / WT-CD-011 delivery: driving, tracks, suspension and recoil calibration

Status: **COMPLETE**. Six cases exist and all six are measured. The driving curves are now declared in data per vehicle instead of being hard coded per vehicle id, and the recoil is a bounded per vehicle response instead of one global kick. Both changes keep the legacy path intact: a packet that declares nothing behaves exactly as before.
Evidence state: the engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed. Every curve value and both recoil values are declared project design initial values with comparison NOT_COMPARED.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-011 |
| base_sha | `fa9d93b860d3ed86bcfbd7ce52d3f00ff4106418` |
| implementation_sha | `8b58f3f7addd0fad2931f11242fcfc33b0118a31` |
| tested_sha | `8b58f3f7addd0fad2931f11242fcfc33b0118a31` |
| final_sha | `8b58f3f7addd0fad2931f11242fcfc33b0118a31` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd11-drive-profiles-v1; cd11-recoil-v1 |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | each engineering packet declares its own drive curve, the content pipeline reads it from data while the hard coded per id resource remains as the legacy path, and the recoil is read from the vehicle profile with the two new fields defaulting to the global constants so an undeclared profile is unchanged. |
| source identity | the table above; evidence and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted scenes over the production drive machinery plus a real fire request and a real wall collision, with both engineering vehicles admitted through the documented entry point. No screenshots are claimed. |
| current limits | performance remains HOLD_BY_USER as the order requires; the curves and both recoil values are declared design values rather than measured ones; CD12..CD016 NOT_RUN; human playtest PENDING. |
| continuation and rollback | both rules carry a rollback in the migration table; the legacy hard coded resource and the global recoil constants remain reachable; the next dependency is CD12, whose prerequisites are closed. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| start, brake and reverse follow each vehicle own frozen configuration, braking before reversing | `DrivePowertrain.step` with the declared profile, `brake_decel` and the reverse branch | CD11-T01 | `tests/run_cd011_scene_checks.gd` S1 and the escape probe trace |
| a turn, a neutral turn and a one-sided track loss follow ability and terrain | `TrackDrive.step` with `turn_speed_falloff`, `turn_drag_per_second`, `track_spacing_m`, `damaged_track_turn_scale` | CD11-T02 | `tests/run_cd011_scene_checks.gd` S2 |
| a crest and a side slope converge without punch-through and the gun follows | `GroundProbe`, `ChassisResponse` and the pitch limits in the profile | CD11-T03 | `tests/run_cd011_scene_checks.gd` S3 |
| recoil comes from each profile, is bounded and does not drift | `TankVehicle.kick_recoil` with `recoil_speed_mps` and `recoil_max_mps` | CD11-T04 | `tests/run_cd011_scene_checks.gd` S4 |
| collision blocks stably and a hull reverses out of a face | the collision layers, the slide solver and the escape handling in `tank.gd` | CD11-T05 | scene blocking leg + `tests/probe_cd011_t05_escape.gd` |
| physics time is the same under a changed display rate and the AI does not bypass limits | the fixed delta advance in `apply_drive` and the AI drive suites | CD11-T06 | `tests/run_cd011_scene_checks.gd` S6 |

## 4. Five validation layers

| layer | state |
|---|---|
| rule and negative | measured: a packet declaring nothing keeps the legacy curve, and an undeclared recoil profile keeps the global kick |
| standard fixture | measured: both engineering vehicles admitted through the documented separate entry point, with their declared values read back |
| actual actor integration | measured: the real drive entry and the real fire request on real vehicles |
| normal player flow and package | measured across the six driving suites and the loading, damage and recovery suites |
| external behaviour and human | NOT_COMPARED and PENDING; nothing is signed on the user behalf |

## 5. Case status

| case | state | executor | note |
|---|---|---|---|
| CD11-T01 | MEASURED | `tests/run_cd011_scene_checks.gd (S1)` | the two declared curves differ and the trace converges; reverse brakes to -0.303 before reversing |
| CD11-T02 | MEASURED | `tests/run_cd011_scene_checks.gd (S2)` | turn falloff, turn drag, track spacing and damaged track scale each differ by vehicle |
| CD11-T03 | MEASURED | `tests/run_cd011_scene_checks.gd (S3)` | the pitch response is bounded and the profile carries the landing and suspension limits |
| CD11-T04 | MEASURED | `tests/run_cd011_scene_checks.gd (S4)` | the real recoil entry moves 0.780 against 0.550, so the response is per vehicle and bounded |
| CD11-T05 | MEASURED | `tests/run_cd011_scene_checks.gd (blocking) + tests/probe_cd011_t05_escape.gd (escape)` | blocked and never through, then reverses 7.067 m out after braking; pushing and towing declared out of scope |
| CD11-T06 | MEASURED | `tests/run_cd011_scene_checks.gd (S6)` | one second of simulated time gives 3.9786 at sixty steps and 3.9791 at thirty, so physics time does not follow the render rate |

## 6. The honest history of this sub-order, recorded because it matters
```
1. The pipeline edit was attempted five times by insertion and each attempt was reverted by its own shape guard, because the hard
   coded per id preloads are MATCH ARMS; the function was finally rewritten whole through the file tool.
2. Extending the allowed field table with the two recoil names made them MANDATORY for every envelope already written and broke
   a suite that builds its own packet in memory. The repair was an explicit OPTIONAL set, not a weakened gate and not an edited
   test, and the two names were withdrawn from the packets for one round rather than left in a broken state.
3. A conclusion of mine was WRONG and was corrected in place rather than removed: I claimed a grounded hull could not
   accelerate, because the harness I used had no floor, and a hull with no ground support cannot accelerate whatever the
   throttle does. With a floor the same entry takes the hull from rest to 7.1882 m/s in two seconds.
4. The collision case first read a two millimetre escape, which looked like a product gap. The number that settled it was the
   ground support, which read zero: another fixture fault, found by measurement rather than by argument.
5. In a harness with real support the product satisfies both halves of the expectation: blocked at z -8.325 against a wall
   at z -12.000 without passing through, then reversing 7.067 m out, after braking to -0.303 m/s first.
NO PRODUCTION CODE WAS CHANGED TO MAKE ANY OF THIS PASS, and no delivered expectation was edited at any point.
```
