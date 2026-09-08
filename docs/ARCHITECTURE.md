# PixelArmor 架构说明（004 版）

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
- `VehicleActor.submit_command(cmd) -> bool`：唯一命令**提交**入口（003-R2）——
  验证/复制/暂存（`CommandMailbox`），不移动/不射击；暂停拒绝并清空、
  实体无效拒绝、`aim_world_point` 非有限整条拒绝。
- `VehicleActor._physics_process`：每车唯一物理**执行器**（003-R2）——
  消费暂存恰好一次 → `_apply_command_once`（驱动/炮塔/武器走同一套限制：
  冷却/俯仰限位/遮挡由生产逻辑把关）。无输入=零命令静止；
  玩家输入与脚本命令走同一提交入口，不存在第二执行路径。

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

`godot --headless --path <工程根> -s res://tests/run_checks.gd`（205 项，exit=0）：
001/002 全部回归 + T003-01~09（独立状态/输入隔离与统一命令/自身排除与命中 B/
20 次生成销毁/坏配置定位/试射目标真实命中推进/配置驱动真实表现/多车碰撞与坐标/
真实任务闭环与射手-射击编号-轮次-生命周期）。
另有独立验收：`-s res://tests/abort_check.gd`（启动失败受控短路——坏配置下
真实主场景子进程非零退出 + 配置恢复字节一致）。

## 7.5 003-R1 修订（needs_revision → 交付待验收）

GPT 复核提出 RC-001 变更与四组关闭项，003-R1 在同一分支以四个顺序子提交完成：

- **A 配置驱动真实表现（6186d12）**：`VehicleActor` 注入 `VehicleDefinition`/
  `WeaponDefinition` 到 tank/turret/gunner，驾驶速度/炮塔转速/俯仰限位/装填/射程
  全部读配置（GameConfig 常量仅作缺省后备）。T003-07 用两套不同配置实测
  速度/转速/装填/射程差异。`validate()` 硬校验：production 必须 verified、
  verified 必须有实质 source_refs（空/TEST ONLY 拒绝）；测试车显式
  `content_tier="test"` + `source_refs=["TEST ONLY: ..."]` + `verification="unknown"`。
- **B 统一命令与生命周期（d2082ef）**：PlayerController 不再直呼 Gunner——
  只生成 `VehicleCommand`（含 fire 边沿 → fire_requested），经
  `VehicleActor.submit_command` 提交、由车辆唯一 `_physics_process` 消费
  （003-R2 起邮箱化：验证/复制/暂存与执行分离；入口检查暂停/实体有效/
  有限值/输入范围钳制）。脚本控制与玩家控制走同一入口（T003-02）。
  `reset_vehicle` 清瞄点覆盖/待发命令/炮镜请求/瞬态；`set_controller` 统一
  绑定/解绑（相机 current 随控制者走，未控制车辆不抢相机）。
- **C 多车碰撞与坐标（4144be4）**：`tank.collision_mask = WORLD|VEHICLE`——
  A 行驶撞 B 稳定阻挡不互穿、不推移（CharacterBody3D move_and_slide）。
  `apply_drive` 前向改用 `-global_transform.basis.z`（速度是世界量，
  非ZeroY旋转出生时仍沿车头行驶，重置回正确世界出生变换，T003-08）。
  示踪线 `_tracer.top_level = true`——顶点即世界坐标，无双重父变换、
  不随车辆运动拖动。
- **D 真实任务闭环（0c8e6f7）**：命中事件携带 `shooter_id`/`shot_id`
  （gunner 按发递增）；main 记录 射击编号→轮次（`_shot_rounds`，
  整场重开 `_round_id` 递增且不清历史）——任务只接受 A→B 命中、
  同一发重复投递不重复计分、重开后旧编号无效（T003-09）。
  C 射击 B 可命中但不替 A 得分。HUD 车辆标识来自实际状态
  （entity_id + PLAYER/TEST TARGET + content_tier TEST ONLY 提示）。
  autoshot 320-350 为**正常输入完整演示**：自然瞄准 → Input 开火 →
  自然装填 → 3/3 → 真实 R 事件整场重开 → 两车/炮镜/HUD 截图
  （autoshot_9~13；不清零冷却、不直接写任务计数、不绕过命令入口）。
  autoshot_8 保留为构造状态演示并已注明。

## 7.6 003-R2 定向收尾（003-R1 部分保留，四项关闭）

GPT 003-R1 复审：配置驱动/碰撞坐标/射手过滤/自然装填演示**保留**，但"四组全部
关闭"不签收——授权 003-R2 定向收尾（同分支追加提交，基准 dfdcd1a）：

- **命令单一物理消费**：新增 `CommandMailbox`——`submit_command` 只验证/复制/
  暂存（暂停拒绝并清空、实体无效拒绝、`aim_world_point` 非有限整条拒绝），
  每车唯一 `_physics_process` 每步 consume 恰好一次（无输入=零命令），
  `_apply_command_once` 执行（原 apply_command 执行体改名，算法未重写；
  旧 apply_command 双路径删除）。脚本不再传 delta；测试不再关闭生产物理回调
  （断言 `drive_call_count` 增量=提交帧数：每物理步恰好一次）。
  暂停（NOTIFICATION_PAUSED）/重置/解绑清暂存，恢复不补执行旧请求。
- **发射时轮次/生命周期身份**：`try_fire` 通过全部检查后先 `shot_id += 1`
  并冻结 `{round_id(开火时刻, round_provider 注入), shooter_id, shooter_life_id,
  shot_id, target_id, target_life_id}`——空射/打墙同样消耗编号；命中车辆时
  目标身份来自实际碰撞对象。`_on_b_hit(identity)` 校验当前轮次+射手 A+目标 B+
  **双方 life_id 存续**+本回合去重（`_round_shots` 重开清空）。强反例实测：
  旧轮次事件重开后首次送达不计分、旧生命周期事件不计分、同名车重建 life_id 不同
  （`VehicleActor` static 计数器）。
- **启动失败短路**：`_ready` 三处失败点 → `_abort_initialization`（关正常帧/输入、
  清理半建实体、显示错误画面、headless/autoshot 非零退出）；
  `resolve_vehicle` 装配边界再次校验三定义本体（手工注册绕过 load_defaults 也拦截）。
  独立验收 `tests/abort_check.gd`：坏配置 → 子进程真实启动主场景 → 非零退出 +
  ABORT 日志 + 生产配置恢复字节一致（user:// 自愈备份防中断污染）。
- **自然瞄准演示**：autoshot 332 去掉 `turret.snap_to_aim()`，改等待炮塔有限速
  真实追赶（`aim_error_deg()` 只读判据 >0.5° 驻留，900 帧有限超时）——
  实测 6 帧收敛 0.05°。阈值未放宽、历史截图未重拍。

测试 200 → **205**（R1 行为要求全保留 + 5 项 R2 断言）。交付
`docs/DELIVERY_003_R2.md`；证据 `docs/evidence/003-R2/`、`logs/003-R2/`。

## 8. 仍然没有（003/003-R1/003-R2 边界）

B 无 AI/巡逻/反击；无装甲/伤害判定（命中反馈测试，无整车血条）；
无内构/穿甲/科技树/正式菜单/网络/大量美术。历史车型数据核验自 004 起。
见 `docs/DELIVERY_003_R1.md`。

## 9. 004 增量：装甲/内构数据层与检视窗口（不接入命中）

### 9.1 布局 schema（scripts/layout/，004-a）

- `VehicleLayoutDefinition`（schema_version=1）：content_tier / historical_identity_id /
  parts / armor_patches / modules / crew_stations / declared_openings /
  allowed_overlaps / source_catalog_id / field_evidence_id。
- `LayoutPartDefinition`：bind_local 刚体变换（无缩放/镜像/剪切）+ joint_kind
  fixed/yaw/pitch + 限位；`ArmorPatchDefinition`（顶点+三角形，绕向与
  outward_normal_local 一致；厚度 verified/estimated/unknown 三态——
  unknown 必须显示"未知"不得显示 0mm）；`ModuleVolumeDefinition`（oriented box +
  external 标志）；`CrewStationDefinition`（五乘员 role 枚举，无四人模板）。
- `LayoutMath`（GPT 参考实现逐字采纳）：is_rigid / posed_local（绕部件自身
  bind 原点旋转+限位 clamp）/ compose_world / box_world_corners。
- `ArmorPatchMesh`（GPT 参考实现）：几何校验（共面≤0.0001m/单位法线/
  绕向一致/退化拒绝）、build_surface（Godot 渲染序反转索引，**不翻转历史法线**）、
  build_wire（PRIMITIVE_LINES——gl_compatibility 无线框 debug）、weld_patches。
- `LayoutValidator`：三级 errors/warnings/infos + suspicious_overlaps +
  边缘邻接（T004-04 封闭性：每条无向边恰好两个方向各一次）。
- `LayoutCatalog`：evidence key 注册表 + load_layout 校验 + 缓存。

### 9.2 历史研究布局（004-b）

- `configs/layouts/us_m4a3_75w_vvss_1944.tres`（tests/m4a3_builder.gd 生成）：
  hull→turret→gun 层级；根原点=炮塔回转轴接地投影；content_tier=research。
- 依据链：`docs/vehicles/us_m4a3_75w_vvss_1944/`（IDENTITY/SOURCES/FIELD_EVIDENCE/
  GEOMETRY_NOTES/OPEN_QUESTIONS）。字段级 origin 分类（historical_primary /
  test_fixture）与三态 status（verified/estimated/unknown）。
- 诚实边界：装甲厚度**全部 unknown**（TM 9-759 无厚度表；图板未目视核验）；
  几何 estimated（verified 总尺寸拟合）；FM 17-67 五乘员岗位 verified。

### 9.3 检视窗口（004-c）

- `VehiclePreviewModel`：布局→部件层级 Node3D（bind_local）；三模式
  外观/装甲/内构；姿态经 LayoutMath.posed_local（不绕父部件、不改共享定义）；
  选中高亮=实例材质覆盖；厚度分档着色（真实数据映射）。
- `VehicleInspector`（scenes/inspection/vehicle_inspector.tscn）：SubViewport
  own_world_3d 独立世界（不接靶场场景）；布局选择器/部件树/详情面板/姿态滑杆/
  轨道相机；Back 与 Esc 同一 close_requested 信号链。
- 接入：HUD 暂停菜单按钮（inspect_requested）→ Main.open_vehicle_inspector
  （树保持 paused）→ close 返回暂停菜单；检视期间 Esc 路由优先、
  靶场输入（R/F3 等）隔离；**检视窗口不依赖 VehicleActor/Gunner/PlayerController/
  命中信号，不含 005 命中查询**。
- `VehicleDefinition.layout_id`（String，缺省空）为唯一向后兼容改动。

### 9.4 测试与证据（004-d）

- `tests/run_layout_checks.gd`：70 项（T004-02..07 + 004-b 历史布局 +
  004-c 查看器断言）。
- `--inspect-demo`：真实窗口 6 步证据（暂停菜单→窗口→三模式→选中详情→
  返回暂停），必需截图失败退出码非 0；证据归档 docs/evidence/004/<sha>/<resolution>/。
- 边界：不做 005 命中查询；不合并 main；不强推；003 签收内容未重写。

## 10. 006：有限速度炮弹（真实飞行，替换即时命中结算）

### 10.1 运动内核

- `scripts/projectiles/ballistic_math.gd`（纯函数）：plan_times（寿命裁短 + 重力抛物线
  子段规划）与 advance_free（闭式抛物线推进）；非有限输入显式失败。
- `scripts/projectiles/projectile_state.gd`（纯数据）：发射身份冻结
  （round/shooter/life/team/shot/shell）+ 运动量（pos/vel/gravity/age/travelled）+
  寿命上限 + status(pending/flying/terminal)。
- ShellDefinition：muzzle_velocity_mps / gravity_scale / max_flight_time_s / gun_range；
  WeaponDefinition：initial_rounds / gun_range（设计初值，TEST ONLY）。

### 10.2 ProjectileManager（唯一推进执行器）

- try_spawn 只校验/复制/占容量（MAX_ACTIVE=64）/入待推进；出生当步不推进不撞击；
  duplicate_launch 守卫（shooter:shot 键）。
- 每物理步：pending→flying → 取一次全车辆快照（下一步重采样）→ 逐发分段推进：
  剩余寿命裁短 → 子段规划 → advance_free → 按剩余路程裁短 →
  WorldQueryAdapter.query_world_stop（世界整段射线）→ ShotQueryService.query
  （excluded=射手身份，world_stop 前置）→ ExternalContactSelector → vehicle/world
  接触或继续。目标几何按单物理步内固定（不支持单 tick 内高速横穿的检测保证）。
- finish_once：先标 terminal/移出活动集再发 projectile_finished（一次性终止；
  监听者触发重置不会二次结算）。active_count()=_active.size()（pending 同在
  _active，不重复计数）。暂停 PROCESS_MODE_PAUSABLE 冻结；_exit_tree 静默清理。

### 10.3 发射流程（Gunner）

- try_fire：冷却/宽限/弹药/炮根-炮口遮挡 → 冻结炮口/方向/车速/身份 →
  try_spawn → ok 才扣弹/装填/编号/计数；拒绝不改状态。last_shot_result="fired"=在飞。
- 装填时钟 advance_timers(delta) 在车辆 _physics_process 内、发射消费之前
  （车辆 priority 0 < 管理器 100）；暂停随树冻结。

### 10.4 身份分发与计分

- Main._on_projectile_finished：记录 _last_impact（HUD）→ impact_vehicle 经
  find_vehicle(entity+life) → 身份字典 → 命中门（轮次/射手/目标/生命周期/去重）计分。
- 重置：单车 reset_vehicle=cancel_by_shooter；整场 reset=cancel_all；均无命中事件。

### 10.5 训练场景与演示

- scenes/training/ballistics_range.tscn：复用生产车辆/Gunner/ProjectileManager/查询；
  30m/150m 射道 + 背板墙；round_id=0（只反馈）；R 重开（cancel_by_shooter+车辆复位）；
  暂停菜单"返回靶场"（先 cancel_all）。
- --ballistics-demo：物理回调步进机（自增 tick 等待、连续 match 标签、看门狗），
  五时点断言链（刚发射未命中/飞行中/接触后/暂停冻结/重开已清空）+ 双限帧
  （--max-fps 30/144）窗口证据 docs/evidence/006/<sha>/1280x720/{30,144}fps/。

### 10.6 测试

- tests/run_projectile_checks.gd：81 项（弹道专用）；tests/run_checks.gd 214 项
  （即时命中测试迁移真实飞行，见 docs/TEST_MIGRATION_006.md）；
  run_query_checks 140 / run_layout_checks 123 无回归。全部退出码 0。

### 10.7 006-R1 整改增量

- 推进循环内出生 tick 门（now_tick <= born_physics_tick 跳过；管理器前/后提交
  时序均不推进）；路程裁短统一记账（alpha 同比例作用于查询/位置/路程/时间/速度；
  端点接触先于到期；剩余近零立即到期）；active_states 单次枚举。
- 发射去重键 = [round_id, shooter_id, shooter_life_id, shot_id]（完整发射身份；
  训练场 round_id=0 合法）；Gunner/Manager 公开入口在扣弹/占容量前拒绝暂停与
  清理期请求；世界接触先 finish_once 再 register_hit；Main 目标反馈前校验记录轮次。
- ProjectileVisuals 可见显示层（sync/present_terminal/clear_all；只读模拟状态，
  不写回不参与命中）；HUD 按 projectile_id 区分在飞/已终止；训练场近/远射道切换
  （_set_lane，T 键 + 演示）；get_aim_point 意图射线 150→300m（覆盖 gun_range +
  相机偏移，否则远射道不可用）；重开训练闭环（靶板/最近结果/视觉同步复位）。

## 008 路径损伤与功能状态
ProjectileManager从ShotQueryService.volume_intervals选择实际下一内部/外部接触；DamageResolver纯解析阻力和状态增量，VehicleActor验证身份并静默提交VehicleRuntimeState，管理器先记录再通知。VehicleCapabilities是驾驶/炮塔/武器与显示的共同能力来源。DamageRange复用真实命令和射击链。规则及证据见DELIVERY_008.md。

## 009 恢复/库存/终结
AmmoInventory是弹药位置与总量唯一账本；VehicleRecovery由VehicleActor物理命令消费驱动正交火灾/维修/灭火/换位，VehicleRuntimeState.destroy_once幂等保存来源。WreckRegistry只管理已终结真实实体的有界留存。CameraRig在resolve模式用同一几何查询缓存真实炮塔意图点；查询target_generation保护重置后的新状态。规则/测试与可见入口见DELIVERY_009.md。
