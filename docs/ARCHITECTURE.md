# PixelArmor 架构说明（003 版）

> 本文档描述当前获批工作单（003 多车辆基础、数据配置与控制接口）落地后的工程架构。
> 前序基线见 `docs/DELIVERY_002_R3.md` 与 `docs/QA_BASELINE_002.md`。

## 1. 总览

```
main.gd (Main, ALWAYS)
 ├─ world (WorldBuilder)         靶场：地面/围墙/箱子/三块靶板
 ├─ defs (VehicleDefs)           配置注册表：Vehicle/Weapon/Shell 定义（.tres）
 ├─ controller (PlayerController) 唯一读取全局键鼠的节点（本地玩家）
 ├─ actor_a (VehicleActor)       A：玩家控制（team 1，视觉层 2）
 │   └─ tank (TankVehicle)        驾驶物理 + 车体网格/碰撞
 │       ├─ turret_rig (TurretRig) 炮塔/炮管（有限转速、俯仰限位、后坐/炮口闪光）
 │       └─ camera_rig (CameraRig) 第三人称/炮镜相机（防穿墙、cull_mask 剔除本车层）
 │   └─ gunner (Gunner)           射击结算（冷却/宽限/遮挡/真实炮口射线）
 ├─ actor_b (VehicleActor)       B：测试目标（team 2，视觉层 4，零命令静态）
 └─ hud (HUD)                    控制车/装填/射击结果/试射目标显示
```

## 2. 数据定义与校验（003-a）

- `scripts/defs/vehicle_definition.gd` / `weapon_definition.gd` / `shell_definition.gd`：
  纯数据 Resource，`validate()` 返回 `{ok, errors}`，错误信息以字段名开头（坏配置可定位字段）。
- `configs/player_tank_vehicle.tres` / `player_tank_weapon.tres` / `ap_75_shell.tres`：
  默认配置（设计初值，非真实车辆性能）。
- `scripts/defs/vehicle_defs.gd`：注册表；`resolve_vehicle(id)` 一次解析
  车辆→武器→弹链，任一环节缺失即报错（T003-05 覆盖）。

## 3. 状态与命令（003-a/b）

- `VehicleRuntimeState`：每实体独立运行时状态（速度/炮塔角/冷却/命中数等）。
  A/B 共享同一份配置定义，但状态实例完全独立（T003-01）。
- `VehicleCommand`：统一控制命令（throttle/steer/aim_world_point/aim_held/fire_requested）。
  003-b 增加显式 `has_aim_point`/`clear_aim` 标志：零命令不覆盖脚本瞄点，
  本地玩家每帧清除脚本瞄点回到相机意图。
- `PlayerController`：唯一输入入口。鼠标 → `cam_rig.set_aim`；键鼠 → `poll()` 生成命令。
  fire 边沿用 `Input.is_action_just_pressed`（Input 系统内部跟踪按下边沿，
  跨帧 release→press 不会被 `_process` 轮询间隔吞掉）。
- `VehicleActor.apply_command(cmd, delta)`：统一命令入口——驱动/炮塔/武器
  走同一套限制（冷却/俯仰限位/遮挡由生产逻辑把关）。B 无控制器时每帧零命令。

## 4. 实体生命周期（003-b）

- `main.spawn_vehicle(vehicle_id, entity_id, pos, ctrl)` / `despawn_vehicle(actor)`：
  统一生成/销毁入口；信号随对象释放自动断开；相机 current 由本地控制者设置管理
  （只有被控制的车拥有有效本地游戏相机，B 不抢相机/鼠标）。
- `reset_vehicle(actor)`（单车）与 `reset_range()`（整场：两车+靶板+试射目标）分离。

## 5. 命中与试射目标（003-b）

- 自身命中排除按实体：炮口射线 mask = WORLD|VEHICLE，排除本车 RID——
  A 可命中 B，墙挡不可命中，A 不会被自己命中（T003-03）。
- 意图射线（`camera_rig.intent_point`/`get_aim_point`）同样查 WORLD|VEHICLE（排除本车）：
  炮塔可瞄准 B，不会越过车辆对准其后方世界点。
- 炮镜 cull_mask 只剔除本车视觉层（A=2 剔除 2，保留 B=4）——炮镜不隐藏 B。
- 试射目标：B 的 `hit_registered` 信号（真实生产命中事件，每发只触发一次）推进
  `trial_hits`，0/3 → 3/3 → TRIAL COMPLETE；空射/墙挡/冷却拒绝不推进；
  整场重置可重复；单车重置不污染（T003-06）。

## 6. 保留的 002 行为（回归保障）

稳定瞄准（有限转速/俯仰限位）、真实炮口结算、炮管穿墙阻止开火、自然装填、
暂停（失焦自动暂停/装填冻结/恢复宽限）、重置、相机防穿墙、瞄点标记前后过滤。

## 7. 测试

`godot --headless --path <工程根> -s res://tests/run_checks.gd`（155 项，exit=0）：
001/002 全部回归 + T003-01~06（独立状态/输入隔离与统一命令/自身排除与命中 B/
20 次生成销毁/坏配置定位/试射目标真实命中推进）。

## 8. 仍然没有（003 边界）

B 无 AI/巡逻/反击；无装甲/伤害判定（命中反馈测试，无整车血条）；
无内构/穿甲/科技树/正式菜单/网络/大量美术。见 `docs/DELIVERY_003.md`。
