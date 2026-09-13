# WT-039-D 转向探针结论（H-A 否证；D 场景冻结仍未解释）

- 目的：判定"油门 0 时车体不转"是**产品缺陷（H-A）**还是**我的测试台假象（H-B）**
- 结论：**H-A 被否证**；且**H-B（通用驱动路径）也被否证** → D 场景的冻结另有其因，**在解释清楚前不得作为产品缺陷对外表述**

## 1. 实验一：直接驱动模型（绕开 actor 流程）
```
actor.tank.apply_drive(0.0, -1.0, 1/60) × 120
→ yaw 变化 = -74.07°   yaw_rate = -0.768   （M4A3：hull_turn 44°/s ✓）
```
→ 驱动/转向模型在**零油门**下能原地转向 ✓

## 2. 实验二：穿过 actor 的生产驱动路径
```
控制器 poll() 恒返回 throttle=0.0, steer=-1.0
actor.advance_standalone_tick(1/60) × 120
→ yaw 变化 = -74.07°   yaw_rate = -0.768   speed = 0.000
```
→ **与实验一逐位一致** ✓ → **actor 命令施加路径同样正确**（`begin_simulation_command` 无 throttle 门控；`advance_simulation_drive` 直接把 steer 传给 `apply_drive`）

## 3. 因此被排除的解释
| 假设 | 状态 |
|---|---|
| 无中立转向导致零速不转 | **否证**：四台历史车 `neutral_turn=true`（实测），实验也证明零速可转 |
| 地面支撑把 steer 缩放为 0 | **不是本次冻结的主因**：轨迹显示 `grounded=true, support_l=1.00, support_r=1.00`（我仍保留了支撑下限，见下） |
| 支撑缺失导致 `ground_state.grounded=false` → `yaw_rate=0` | **否证**：轨迹中 `grounded=true` 且 `yaw_rate=-0.768`（非零） |
| actor 命令路径丢失 steer | **否证**：实验二 |

## 4. 仍未解释的核心矛盾（下一步取证点）
在 D 场景中同时观测到：
```
yaw_rate = -0.768（非零，说明模型已算出转向）
grounded = true, support = 1.00
bearing 150+ tick 仅变化 0.02°（车体几乎未转）
driver.last_command = {throttle 0.00, steer -1.00}
```
而同样的 yaw_rate 在实验一/二中**确实让车体转过 74°**。差异只可能来自**D 场景与实验二的其余差异**，候选：
1. **被消费的命令 ≠ 驱动器意图**：`collect_simulation_command` 仅在 generation/epoch/controller 校验通过时才提交；若提交被拒，邮箱返回空命令 → 车体收到 0/0（而 `last_command` 仍是 −1.00）。**下一步**：在 D 套件里打开 `actor.debug_command_trace = true`，直接对照"execute 的 steer"与"driver 的 steer"。
2. **恢复/供给状态门控**：`VehicleRecovery.step(...)`、`supply_motion_active` 或 `died_now` 在 D 场景的特定时刻影响了本 tick 的驱动。
3. **姿态写入被后续步骤覆盖**：`tank.gd:155` 的 `VehiclePose.approach(terrain_basis, compose(forward,up), delta)` 与 `chassis.pitch` 组合在同一 tick 内相互抵消（实验二未复现，可能因场景/坡度差异）。

## 5. 诚实口径（重要）
- **不将 D 电池的"停滞"表述为已确立的产品缺陷**（已有一次"蠕行修复"被回归证据否证的前例）；
- 已保留的产品改动仅一处：`tank.apply_drive` 的**转向支撑下限** `DRIVE_MIN_STEER_SUPPORT=0.35`（物理上合理：单侧失支撑不应把转向清零），且**回归中立**（地图 46/3、历史 29/4 未变）——**但不宣称它修好了任何问题**。

## 6. 下一步
1. 在 D 套件中打开命令追踪，对比**被消费的 steer** 与**驱动器意图**；
2. 若确为提交被拒 → 定位拒绝原因（generation/epoch/邮箱），修正测试台或暴露真实缺陷；
3. 若为姿态写入问题 → 在 D 场景复现实测（含坡度/姿态参数），再决定修 `tank.gd` 还是别处。
