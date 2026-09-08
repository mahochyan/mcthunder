# DELIVERY 006 — 有限速度炮弹、重力与连续路径检测

状态：待复核（提交后由 GPT 裁决签收）
基准：3aa26da0（005 accepted_sha）；分支 work/006-projectile-flight（追加提交，未合并 main，无 force-push）
本单 tested sha：370242e4c593dd002f0c03bc8f9ffbac7418e38d（证据目录 docs/evidence/006/<sha>/ 与日志 logs/006/<sha>/ 与之对应）
工作单：docs/planning/work_orders/WO006_authorized.md（682 行，GPT 授权实施）

---

## 0. 交付总览

006 将 001-005 的"射线即时命中结算"替换为**有限速度炮弹真实飞行**：
发射时冻结炮口/方向/速度/身份 → `ProjectileManager` 接收 → 每物理步固定步长逐段推进
（重力 + 分段子步规划）→ 每步对世界与车辆几何做**整段连续路径查询** → 一次性终止 →
身份分发（轮次/射手/生命周期门）。装填时钟迁入物理消费序列；暂停冻结在飞弹道；
训练场（30m/150m 射道）提供弹道演示与 `--ballistics-demo` 双限帧证据。

四套检查全绿（退出码均 0，脚本错误 0）：
- `tests/run_projectile_checks.gd`：**81 项**，`PROJECTILE_CHECKS_PASS`（本单新增，专测弹道）
- `tests/run_checks.gd`：**214 项**，`CHECKS_PASS`（即时命中测试迁移真实飞行，见 TEST_MIGRATION_006.md）
- `tests/run_query_checks.gd`：**140 项**，`QUERY_CHECKS_PASS`（无回归）
- `tests/run_layout_checks.gd`：**123 项**，`LAYOUT_CHECKS_PASS`（无回归）

## 1. 006-a：弹种/弹药配置与运动内核

- **`ShellDefinition`**（configs/shells/ap_75.tres）：`muzzle_velocity_mps=300`、`gravity_scale=1.0`、
  `max_flight_time_s=8.0`、`gun_range=200`（均为游戏设计初值，TEST ONLY 来源声明）；
  **`WeaponDefinition.initial_rounds`**（弹匣，默认 30）+ `gun_range`。
- **`scripts/projectiles/ballistic_math.gd`**（纯函数，不访问场景树）：
  `plan_times`（按剩余寿命裁短 → 重力抛物线子段规划：转折点/落点细分），
  `advance_free`（闭式抛物线推进：位置+速度），非有限输入显式失败。
- **`scripts/projectiles/projectile_state.gd`**：纯数据状态（身份冻结：round_id/shooter_id/
  shooter_life_id/shooter_team_id/shot_id/shell_id；运动：position/velocity/gravity/age/travelled；
  寿命：max_age_s/max_distance_m；status pending/flying/terminal + terminal_reason）。
- **`scripts/projectiles/projectile_manager.gd`**：`try_spawn`（只校验/复制/占容量/入待推进——
  出生当步不推进不撞击）；`MAX_ACTIVE=64` 容量；`_accepted_launches` duplicate_launch 守卫；
  **`active_count()` = `_active.size()`**（pending 的 id 同时在 _active 中，不重复计数——
  测试 FAIL[21]/[45] 反例修正）。

## 2. 006-b：固定物理步推进 + 005 查询接入 + 一次性终止

- 每物理步：pending→flying 转换（出生当步不推进）→ 取**一次**当前车辆快照（下一步重采样，
  不用开火瞬间快照算到落点）→ 逐发 `advance_projectile`：剩余寿命裁短 → plan_times 子段 →
  `advance_free` 候选点 → 按剩余路程裁短线段 → `WorldQueryAdapter.query_world_stop`
  （LAYER_WORLD 整段射线；发射者 RID 排除）→ `ShotQueryService.query`
 （excluded=射手实体身份，include_modules=true, include_crew=false，world_stop 前置）→
  `ExternalContactSelector` 选外部接触 → vehicle/world 接触或继续下一段。
- **一次性终止**：`finish_once` 先标 terminal、移出活动集合，再发 `projectile_finished` 记录
  （reason：impact_vehicle/impact_world/expired_time/expired_distance/unresolved_query/
  cancelled_reset/cancelled_scene_exit）；监听者触发重置不会二次结算。
- **Gunner 发射流程重写**（即时结算移除）：冷却/宽限/弹药/炮根-炮口遮挡检查 →
  冻结真实炮口/炮管方向/车体速度/身份 → `projectile_manager.try_spawn` → **ok 才一次性**
  扣弹/装填/编号/计数；拒绝路径不改任何状态。`last_shot_result="fired"` 表示在飞。
- **Main 装配**：`snapshot_provider`（每物理步一次全车辆快照）+ `exclude_provider`
  （发射者 RID）+ `projectile_finished` 身份分发（`_on_projectile_finished` →
  impact_vehicle 经 find_vehicle(entity+life) → `_on_b_hit` 身份字典 → gate 校验计分）。

## 3. 006-c：暂停/重置/销毁 + 装填时钟迁移 + HUD + 训练入口

- **装填时钟迁移**：`Gunner.advance_timers(delta)`（冷却/特效）从 `_process` 迁到
  **车辆 `_physics_process` 内、发射消费之前**（`process_physics_priority` 车辆 0 < 管理器 100）；
  暂停时随树冻结，恢复宽限语义不变（run_checks R1-B/R2-B 回归过）。
- **管理器 `_exit_tree` 静默清理**：场景销毁/初始化失败时清空活动集，不发信号（旧回调不访问已释放对象）。
- **HUD 扩展**：AMMO n/N、PROJECTILES n（在飞计数）、LAST IMPACT（shot_id/终止类型/飞行时间/路程）、
  炮线标注；暂停菜单新增弹道训练入口。
- **训练场景 `scenes/training/ballistics_range.tscn` + `scripts/training/ballistics_range.gd`**：
  复用生产车辆/Gunner/ProjectileManager/查询系统（不复制一套训练专用射击代码）；
  近射道 30m/远射道 150m + 背板墙挡未中弹；`get_round_id()=0`（命中只反馈不推进试射）；
  暂停菜单"返回靶场"（切换先 `cancel_all("cancelled_scene_exit")`，按新局处理）；
  **R 整场重开**（与主靶场语义一致：`cancel_by_shooter("cancelled_reset")` + 车辆复位）。
- **重置语义**：单车重置取消该车飞弹（cancel_by_shooter）；整场重开取消全部（cancel_all）；
  均不产生命中事件。

## 4. 006-d：旧测试迁移 + 弹道回归 + 双分辨率演示 + 交付

### 4.1 旧即时命中测试迁移（docs/TEST_MIGRATION_006.md）

`tests/run_checks.gd` 18 处旧即时命中断言迁移为等待真实飞行
（`_wait_flight_done`：物理帧轮询活动飞弹归零，480 帧上限 = max_flight_time 8s）；
"墙挡结果=miss"（同步 last_shot_result）改为飞弹终止记录
`main._last_impact.reason_upper=="WORLD"`（世界接触优先语义的飞行时代载体）；
遮挡段先等被墙拦截的弹终止再移墙（防旧弹继续飞造成双计）。
迁移后 run_checks 213→214 项全过（逐项旧编号/旧断言/新断言/迁移原因见该文档）。

### 4.2 弹道验收套件 run_projectile_checks.gd（81 项）

覆盖：BallisticMath 手算基准（抛物线/自由推进/分段规划）、ShellDefinition 校验、
管理器接收（容量 64/重复发射/无效规范/出生当步不推进）、free-flight 与重力下坠（150m 弧线 y 精确）、
世界撞击（靶板接触面/穿墙拦截/墙后不命中）、车辆撞击与身份分发（A→B、自身排除、
hits_taken/试射计数联动）、寿命终止（时间/路程）、暂停冻结精确对比、
暂停期发射拒绝、重置取消、场景销毁清理、集成原子性（撞击+计分+反馈一次完成）。
信号时序关键修正：`process_frame` 信号在节点 `_process` 之前发出——瞄准稳定轮询前
空等 2 process 帧防"假收敛"（测试文件内注释说明）。

### 4.3 --ballistics-demo 双限帧窗口演示

`scripts/training/ballistics_range.gd` 内 `--ballistics-demo` 步进机（跑在**物理回调**、
自增 tick 等待、连续 match 标签、看门狗 6000 tick 上限；渲染限帧不影响时序）。
同一训练装配 + 生产发射路径，记录五个时间点并逐项断言：

| 时间点 | 断言链（演示日志逐项打印） |
|---|---|
| 刚发射未命中 | shot1 越板（瞄点 y=3.6>板顶 2.8）→ `impact_world travelled=28.369m point=(0,3.56,-31.5)` 背板 |
| 实际飞行中 | active=1；物理采样 15.000m@age0.0500s → 25.000m（5m/步@60Hz） |
| 接触后 | shot2/shot3 `impact_world 26.600m t=0.0887s point=(0,1.375,-29.8)`（HUD LAST IMPACT 同步） |
| 暂停冻结 | 暂停采样 pos/age/travelled 与 30 tick 后**精确相等**；暂停菜单可见 |
| 重开已清空 | 在飞 1 发（15.000m）→ 生产 `_reset_range()` → `cancelled_reset` → active 1→0 |

证据：`docs/evidence/006/370242e4…/1280x720/{30fps,144fps}/`（各 5 张真实抓帧 70–81KB）+
`logs/006/370242e4…/`（stdout/stderr/退出码/元数据）。双跑物理帧数同为 950、
四次撞击记录逐字节一致——**渲染限帧不影响弹道确定性**；实际渲染帧率 ~24-26（vsync/合成器
决定，低于请求上限不违反限帧语义；请求与实际均已记录）。
运行元数据：完整 SHA/引擎版本/实际命令/物理频率/请求与实际帧率/种子/退出码/无超时——见
`logs/006/<sha>/RUN_METADATA.md`。

### 4.4 退出码采集

全部运行以 `cmd /c` 批处理等待真实进程结束取 `%ERRORLEVEL%`（不补造 005 旧值）；
PASS 文本、退出码、脚本错误三项分别检查（见 RUN_METADATA 表格）。

## 5. 明确不做（006 边界外，未实现）

- 不做穿透/跳弹/损伤/装甲结算（007 范围）；本单"命中"= 停在装甲接触点 + 事件反馈。
- 不做目标移动连续碰撞保证（目标几何按单物理步内固定；文档已注明该边界）。
- 不做随机散布（ShellDefinition.seed 预留，006 不启用）。
- 不做网络、AI、多人。

## 6. NOT_RUN / 保留项

- **截图人工目视**：10 张演示截图为真实抓帧（70–81KB 非空）+ 程序化断言链全过，
  但模型无法读图——人工目视并入 011 前人工验收（不代签）。
- **真人体验验收**：最迟 011 前（既有保留项）。
- 历史装甲厚度保持 UNKNOWN（既有保留项）；史料原页目视 7 张 PNG 待人工转送（既有保留项）。
- `--max-fps 144` 实际渲染帧率 ~24：桌面 vsync/合成器所限，已如实记录（限帧语义为上限）。