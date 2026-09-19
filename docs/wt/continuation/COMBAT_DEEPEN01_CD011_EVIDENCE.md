
# MCT-COMBAT-DEEPEN-01 / WT-CD-011 evidence: driving, tracks, suspension and recoil calibration

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[10] (WT-CD-011):
  id=WT-CD-011 ; title=驾驶、履带、悬挂与后坐标定 ; priority=P2 ; phase=G3 ; scope=core ; status=planned
  depends_on = **WT-CD-009**  ⇒ closed, so CD11 may proceed.
  related_parent_orders = WT-004 / WT-005 / WT-006
  basis = 已有运动学驾驶、等效动力、四点悬挂、侧向履带失能等；不是要求改用另一引擎或逐履带板刚体。
  player_outcome = 两车抢位、制动、倒车回掩体、坡顶急停和受损撤退有可信差异。
  read_first = scripts/tank.gd / scripts/drive/drive_powertrain.gd / scripts/drive/suspension_response.gd /
               scripts/drive/track_drive.gd（按实际路径确认） / scripts/drive/landing_response.gd（按实际路径确认）
  source_ids = R08 / R11 ; acceptance_case_ids = CD11-T01 .. CD11-T06
```

### 0.1 The six cases, quoted
| case | title | action | expected |
|---|---|---|---|
| **CD11-T01** | 起步/制动/倒车 | 两车同一平地正常输入 | **测得曲线符合各自冻结配置，反向先制动再倒车** |
| **CD11-T02** | 转向损速与单侧履带 | 直行转弯、原地转向、单侧失能 | **各车型能力与地形条件真实影响结果** |
| **CD11-T03** | 坡顶与侧坡 | 同速度越障后停车再起步 | **支撑收敛、无穿地异常弹起，炮口与装甲跟随** |
| **CD11-T04** | 后坐对比 | 不同武器/车型在平地与坡地开火 | **响应来自各自profile且有界，不累积漂移** |
| **CD11-T05** | 碰撞和脱困 | 车车/残骸/路肩接触后正常倒车 | **不穿透或靠取消碰撞通过；不支持推挤时如实标明** |
| **CD11-T06** | 玩家/AI和显示率 | 同条件不同控制者/渲染fps | **物理时间一致，AI不绕过损伤/坡度限制** |

### 0.2 Rejection conditions carried forward verbatim
```
换引擎或整套推倒作为本单交付 ✗ · 逐帧改测试输入绕过真实通行 ✗ ·
为静止修复直接传送 ✗ · 借本单恢复性能专项 ✗
```

## 1. Stage 2 — the sources located by ACTUAL path, and the design table measured

The order itself asks for the two last paths to be confirmed rather than assumed, so they were listed rather than guessed.

### 1.1 The driving scripts, confirmed
```
scripts/drive/ : drive_powertrain.gd, suspension_response.gd, track_drive.gd, landing_response.gd   (all four named exist)
                 chassis_response.gd, drive_profile.gd, drive_surface.gd, ground_probe.gd, track_assembly.gd,
                 vehicle_frame_pose.gd, vehicle_pose.gd, terrain_fixtures.gd, turret_mechanism_state.gd
scripts/       : tank.gd
also relevant  : battle/vehicle_simulation_driver.gd, ai/ai_path_driver.gd, ai/drive_navigator.gd
```
So the two paths the order flagged for confirmation are real, and there is a separate `vehicle_frame_pose.gd` alongside
`chassis_response.gd`, which is very likely the single pose authority the design requirement names. That has to be measured
before anything is changed.

### 1.2 The existing driving design table (all values are project game-rule tuning, as the order requires them to be split)
| quantity | value | note |
|---|---|---|
| forward max speed | **8.0 m/s** | |
| reverse max speed | **3.0 m/s** | |
| forward accel / reverse accel | **6.0 / 4.0 m/s²** | |
| **brake decel** | **10.0 m/s²** | so "reverse brakes first, then reverses" is expressible numerically - CD11-T01 |
| hull turn speed | **75.0 deg/s** | explicitly allows a neutral turn with no translation |
| max slope | **28.0 deg** | |
| support reach | **0.55 m** | "effective track support reach; game tuning" |
| chassis recoil speed / damping / max | **0.65 / 5.0 / 1.3** | its own comment: "simplified chassis reaction, game tuning rather than historical mass data" |
| AI reverse / turn recovery | **1.2 s / 0.7 s** | the AI side of CD11-T06 |

One comment is directly relevant to T03, in the code itself: `min(left,right) support could zero it entirely when one probe
lost contact (crest, slope...)`, so the crest support case has been worked on before and must not be re-broken.

### 1.3 The two vehicles carry what the cases need
Both the T-80B and the Leopard 2A4 declare `engine`, `transmission`, `track_left` and `track_right` modules, so a one-sided
track loss and damaged driving are both drivable through production damage rather than through a fixture.

### 1.4 What the design requirements imply for the work
```
1. the design table above is the "existing speed/accel/reverse/turn-loss/slope table" the order asks to state first, with
   reference and design values separated - here they are all design values, and no historical gear ratio is invented;
2. there is exactly one pose authority to find and respect, and suspension may update only inside it;
3. RECOIL IS THE REAL WORK: today one chassis recoil value serves every gun, while the order requires a bounded per weapon
   and per vehicle response that does not accumulate drift and is not one uniform kick for every gun;
4. collision must keep stable blocking, never trap a spawn and allow escape, and pushing or towing is to be DECLARED out of
   scope rather than claimed;
5. performance stays on HOLD; only behaviour calibration is in scope.
```

## 2. Next steps
1. write the **acceptance scenes first** for all six cases: the start/brake/reverse curves of both vehicles, turning with a
   one-sided track loss, a crest and side slope, recoil per weapon and per vehicle on flat and on a slope, collision and
   escape, and the player against AI consistency under a changed render rate;
2. then make recoil configuration-driven and bounded, without touching the single pose authority;
3. record the rule in the migration table with before and after, and keep the old uniform behaviour as the legacy strategy.

## 3. The six scenes, and two readings that are honestly under determined

### 3.1 What ran
```
tests/run_cd011_scene_checks.gd drives the REAL machinery: DrivePowertrain.step is the same pure advance the tank uses
every tick, each vehicle brings its own frozen DriveProfile from the production catalog, and the recoil entry is the real
TankVehicle.kick_recoil. Four scenes hold and three do not, and the three that do not are stated rather than dressed up.
```
### 3.2 A vacuous pass was caught and removed, not left standing
```
The recoil scene first passed on `0 == 0`: kick_recoil moved neither vehicle (moved a=0.00000, moved b=0.00000, and
drive_call_count stayed 0), and a judgement that two identical zero responses are equal is trivially true. The condition
now requires a NON ZERO move from the real entry, so the case reads NOT YET MET and the label says exactly why: the
response is identical for both vehicles, which is either because it needs a physics tick this harness does not give it or
because it genuinely is one uniform kick. Both readings name the same gap the order asks to close.
```
### 3.3 An under determined pass, recorded rather than claimed
```
T01 reads met because both vehicles reach forward and reverse speed under their own frozen configuration, but the two
measured curves are IDENTICAL (forward top 10.498, reverse top -2.778 for both), so the phrase "each vehicle own frozen
configuration" is not yet differentiated by this measurement. Note also that 10.498 exceeds the global forward maximum of
8.0 in the game config, which means the curve comes from the per vehicle definition rather than from the global constant.
This is recorded as an open point for T01 and T02 together: the two vehicles currently share their turn falloff and their
track spacing as well, which is why T02 can only read not yet met.
```
### 3.4 The one genuinely discriminating result
```
T06 is the only case whose reading discriminates by construction: one second of simulated time gives a top speed of 3.9786
at sixty steps and 3.9791 at thirty, a difference of five ten thousandths, so the advance is rate independent and the
physics time does not follow the render rate.
```

## 4. The implementation attempt, and the mechanism it measured instead of guessed

### 4.1 What was landed in code and what was reverted
```
KEPT: DriveProfile gained recoil_speed_mps and recoil_max_mps, both DEFAULTING to the global constants that the uniform
kick already used, and TankVehicle.kick_recoil now reads them through the member defs, which is the member the local
definition is built from. A profile that declares nothing therefore behaves exactly as before, so the previous uniform
behaviour is retained as the legacy strategy rather than deleted. The damping stays global, because that is where the
attenuation reads it.
REVERTED: the two engineering packets were given a drive_profile block directly. That broke their admission, and the
diagnostic says exactly why rather than leaving it a mystery: the packet field is an ENVELOPE, it must carry a schema, an
explicit game_rule origin with an explanation, and its numbers under values - and the correct key is not drive_profile at
all but drive.profile, which is a REFERENCE CLAIM. The loader shows the established pattern for every other vehicle:
   v.drive_profile = preload("res://configs/drive/m4a3_design.tres")
so a per vehicle curve belongs in its own .tres resource referenced from the packet, not inlined into it.
```
### 4.2 The device fault that the earlier zero reading was
```
The recoil scene read forward_speed, but the recoil goes to a SEPARATE recoil_velocity vector that is applied into the
velocity later. That is why the first measurement read zero for both vehicles: a wrong field, not a missing response. The
scene now reads recoil_velocity, so the next run will distinguish a real per vehicle response from a uniform one.
```
### 4.3 Next step, now fully specified
```
Write one DriveProfile .tres per engineering vehicle with different, declared design values for turn falloff, track
spacing, damaged track scale and recoil, and reference each from its packet as drive.profile with the schema, the
game_rule origin and the explanation the gate demands. Then the two curves differ by construction, which is what T01 and
T02 need, and the recoil differs by vehicle, which is what T04 needs.
```

## 5. The data path measured, and the insertion that was abandoned rather than forced
```
DriveProfile.from_packet now exists, mirroring the idiom the loading profile already uses, so a per vehicle curve can be
declared in data instead of being hard coded per vehicle id. It parses clean and nothing calls it yet, so it changes no
existing behaviour.
The pipeline edit was attempted five times and each attempt was reverted by its own shape guard. The reason is now known
rather than guessed: the hard coded per id preloads are MATCH ARMS, and the block continues past the arm that was used as
the insertion anchor, so an injected statement lands inside the match and the parser refuses it. Indenting the tail was
tried and was worse, because it swallowed the rest of the file including the function return. The next attempt must
REWRITE THE WHOLE FUNCTION through the file tool, the way the capability file was rewritten when the same class of
problem appeared there, rather than continue to insert.
```

## 6. T05 measured for the first time, and it found a real gap rather than confirming the expectation
```
The collision and escape case was previously not measured at all, so it read not yet met for the honest reason that it
had not been tried. It is now driven for real: a StaticBody3D wall on the world layer, the real hull advanced through its
own apply_drive for three hundred physics frames, and then three hundred frames of reverse.
BLOCKING HOLDS: the hull stopped at z -4.979 against a wall at z -9.000 and never passed through it, so stable blocking
is measured and the hull is not relying on a disabled collision to pass.
ESCAPE FAILS: after stopping against the face, three hundred frames of reverse moved the hull 0.002 metres, which is
nothing. The order expects a hull in contact to reverse out normally, and this is exactly the situation the code already
comments on in tank.gd, where it notes that a non-walkable face can hold the hull and that restoring engine speed every
tick kept pushing it into the face even after the player asked for reverse. That comment describes a repair, and the
measurement says the repair does not cover this case: the hull is stopped by a vertical wall rather than held on a slope.
So T05 stays NOT YET MET, now on a measured gap instead of an untried one, and the next step is to find why reverse
produces no motion against a vertical face - whether the throttle sign reaching the powertrain, the slope block check, or
the engine speed being restored each tick.
```

## 7. Why the reverse produced no motion: traced to the throttle path, with the trace left in place
```
The reverse phase was instrumented with the internals printed every sixty frames, and the reading is unambiguous:
   reverse t=0..240 speed=0.0000 throttle=-1.00 blocked=false on_floor=true velocity=(0,0,0)
So the hull is on the floor, the slope block is NOT the cause, the throttle reaches apply_drive, and the speed stays at
zero for the whole three hundred frames. Reading the producers of forward_speed explains it: the grounded branch advances
the speed through TrackDrive.step, which computes yaw and turn drag only and has no throttle parameter at all, while the
only call that passes the throttle to DrivePowertrain sits in the ELSE branch, which is the airborne case. The powertrain
itself implements throttle fully, including braking to zero before reversing, which is exactly the behaviour the first
acceptance case expects.
This is left as an open measured question rather than a claim: the game is described as drivable, so either the throttle
reaches the powertrain through a path not yet read, or the grounded longitudinal drive really is absent in this file and
setting the speed directly is the only reason this harness moved the hull at all. Either way the honest position for T05
is unchanged: BLOCKING IS MEASURED AND HOLDS, the hull stopped 4.02 m short of the wall and never passed through it, and
the ESCAPE LEG CANNOT YET BE JUDGED because the harness drives the hull by writing its speed rather than through the real
throttle path. The next measurement is therefore narrow and named: find how a grounded throttle becomes forward speed.
```

## 8. The trace resolved: the grounded throttle never reaches the powertrain, which is a real gap in this file
```
Every use of the powertrain in the whole script tree was listed rather than sampled:
   tank.gd:8    var powertrain := DrivePowertrain.new()
   tank.gd:147  powertrain.traction_acceleration=0        # airborne branch
   tank.gd:148  powertrain.braking=false                  # airborne branch
   tank.gd:151  if track_pivot: powertrain.reset()        # airborne branch
   tank.gd:152  else: forward_speed=powertrain.step(...)   # the ELSE of a grounded test => AIRBORNE
   tank.gd:233  powertrain.reset()
So DrivePowertrain.step, which implements throttle completely - including braking to zero before reversing, the exact
behaviour the first acceptance case expects - is called ONLY when the hull is not grounded. The grounded branch advances
the speed through TrackDrive.step, whose signature takes yaw and turn drag and NO throttle, and it returns the speed it
was given times a decay factor. With a speed of zero it returns zero, for ever.
That is the whole reason the reverse produced no motion: not the wall, not the slope block, and not the collision solver.
And it is a real gap rather than a harness artefact, because the only entry the game itself uses is the same one:
   vehicle_actor.gd:407  tank.apply_drive(step.throttle,step.steer,delta)
which is exactly what this test calls. A grounded hull therefore has no longitudinal drive in this file at all, and the
only reason the collision leg moved is that the test wrote the speed directly.
OPEN QUESTION FOR THE USER, recorded rather than assumed: the project instructions describe the tank as drivable, and this
reading says a grounded hull cannot accelerate from rest through its own command path. Either the description refers to an
earlier state of the code, or a production path outside these scripts writes the speed. It is NOT claimed here as a
regression and NOT fixed by guessing: the next step is to run the real game loop once with its own command and read the
speed trace, which settles it in one measurement.
```

## 9. CORRECTION: section 8 is WRONG, and the measurement that refutes it
```
Section 8 above states that "the grounded throttle never reaches the powertrain, which is a real gap in this file". THAT
STATEMENT IS WRONG and it is left in place only so the correction is visible next to it. It was reached by reading the
call graph and then running a harness that had NO FLOOR, and a hull with no ground support cannot accelerate whatever
the throttle does - the powertrain scales its traction by the support the ground probe reports.
The settling measurement, with a floor added and the production entry used exactly as the game uses it:
   on_floor=true  support=1.000  drive_calls=120
   t=  0 speed=0.0000 traction=0.0000
   t= 30 speed=1.9976 traction=3.9856
   t= 60 speed=3.9800 traction=3.9407
   t= 90 speed=5.3280 traction=3.8928
   after 2 s speed=7.1882
So a grounded hull DOES accelerate from rest through VehicleActor.advance_simulation_drive, which is the same entry the
game itself calls. The probe now prints REFUTED in that case, and it is the probe own verdict rather than my reading.
What survives from the investigation, and what does not:
   DOES NOT SURVIVE: "the grounded branch never hands the throttle to the powertrain". The grounded branch calls
   TrackDrive.step, which handles yaw and turn drag, and the throttle reaches the powertrain through the shared
   DrivePowertrain state the same tank owns - the direct powertrain call in the probe returning a smaller value after
   the shared state had been advanced is the evidence that the two are one object, not two paths.
   SURVIVES: the collision case blocking measurement, the hull stopping 4.02 m short of the wall and never passing
   through it, and the escape reading of 0.002 m of motion, which is still unexplained and still needs a measurement.
The remaining measurement is now narrow and named: print ground_state.traction_support during the collision scene own
reverse phase. If it reads zero there, the scene actor is standing on ground that gives no support, the escape failure is
a harness fault like the first one, and T05 must be re-judged. If it reads one, the hull really cannot reverse out of a
vertical face and that is a genuine product gap for this order to close.
```

## 10. T05 closed for this round: blocking is measured, the escape leg is not measurable in this harness, and that is stated
```
The one number that was supposed to decide it is now in, and it decided something else: DURING THE REVERSE PHASE THE GROUND
SUPPORT IS ZERO. The powertrain scales its traction by that support, so grip is zero, so no throttle can move the hull
whatever the collision does - which is exactly the same harness fault that produced the wrong conclusion in section 8, found
a second time in a different scene.
Three attempts were made to give this scene its own floor so the support would be real, and all three failed to make the
hull grounded in this SceneTree harness, while the settle probe - which places its floor before the actor is used and awaits
process frames rather than physics frames - does get support 1.000 and does accelerate. Rather than keep burning rounds on a
fixture detail, the position is recorded as it stands:
   BLOCKING: MEASURED AND HOLDS. The hull was driven at a wall on the world layer and stopped 4.02 m short of it, never
   passing through, so the stable blocking the order asks for is measured and it is not achieved by disabling collision.
   ESCAPE: NOT MEASURED, and the reason is a harness limitation with a number behind it, not an opinion. The hull has no
   ground support in this harness, so its traction is zero and it cannot move for any reason - the 0.002 m reading is a
   fixture artefact and is NOT evidence of a product gap either way.
   PUSHING AND TOWING: DECLARED OUT OF SCOPE, which is what the order itself asks for when no reliable constraint exists.
The escape leg needs an integrated harness - the game own scene, where ground support demonstrably works - rather than a
SceneTree script that has to fabricate the ground. That is named here as the next measurement for this case.
```
