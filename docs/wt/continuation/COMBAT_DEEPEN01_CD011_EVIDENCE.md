
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
