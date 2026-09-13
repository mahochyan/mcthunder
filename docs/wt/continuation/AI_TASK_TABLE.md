# AI 任务/优先级表（WT-020-R1）

- 依据：`02_首轮10张执行单.md` §08「必须交付：AI任务/优先级表」
- 实现：`scripts/ai/ai_role_allocator.gd`（新增，纯决策层）+ `scripts/ai/ai_tank_controller.gd` 接线
- 权限边界（硬）：分配器只读**公共目标状态**、**本方名单**（位置/朝向/弹药比例/机动性/受损）与自身任务历史；**绝不读取敌方内部真值**（模块/乘员/隐藏位置），因此不可能在本层引入透视。

## 1. 角色与优先级

| 优先级 | 角色 | 触发条件 | 目标选择 | 是否可越过迟滞 |
|---|---|---|---|---|
| 1（最高） | `repair` | 不可机动或 `immobile_damaged` | 原地；由既有恢复流程决定维修/换位/灭火 | **是**（紧急） |
| 2 | `supply` | 弹药比例 ≤ `DRY_AMMO_FRACTION`(0.25) | 本方补给点（与 WT-032-R1 的 `supply_points` 一致） | **是**（紧急） |
| 3 | `defend` | 无可用公共推进目标，或已驻守已占目标 | 当前目标 | 否（受迟滞约束） |
| 4 | `attack` | 机动正常且存在公共目标 | 按 `entity_id` 排序后对 A/B/C **轮转分配** | 否 |
| 5 | `flank` | 同队机动车辆 ≥ 3 时**固定 1 辆** | 目标集合末项（外侧路线） | 否 |

## 2. 迟滞与确定性

| 规则 | 值/做法 | 目的 |
|---|---|---|
| 切换冷却 | `SWITCH_COOLDOWN_S = 12 s` | 防止每步换任务（永久振荡） |
| 越权条件 | 仅紧急触发（repair/supply）可绕过冷却 | 受伤/断弹必须立即响应 |
| 目标身份保持 | 角色与目标**同时**相同才算未切换 | 避免"同角色换目标"逃过迟滞 |
| 确定性 | 名单按 `entity_id` 排序后轮转 | 同输入必得同分配（可复现、可审计） |
| 任务年龄 | `decision_reason().assigned_age_s` | 供审计与后续调参 |

## 3. 有界让行（关键桥口）

| 条件 | 判定 |
|---|---|
| 同队 | 不同队绝不让行（不向敌人让路） |
| 距离 | 6 m 内（`FRIEND_GAP_M`） |
| 朝向 | 对向（前向点积 < `OPPOSING_DOT = -0.3`） |
| 位置 | 任一车处于咽喉点（`chokepoint_test` 回调；由调用方按地图注入） |
| 让行方 | **`entity_id` 较大者让行**（双方无需协商即可一致） |
| 时长 | 上界 `CHOKEPOINT_GIVE_WAY_S = 6 s`；到期自动恢复 |

控制器行为：让行期间 `phase = "yielding"`、油门/转向归零，**优先级低于恢复与撤退**（恢复请求不会被让行吞掉）。咽喉点之外或非同向 → 不让行。

## 4. 决策留痕（decision_reason）

`{"entity_id","task","objective","reason","assigned_age_s","urgent","hold_reason","last_seen_age_s","ammo_state","damage_state"}`

- **合法守点**：驻守已占目标时写入 `hold_reason = "legitimate_objective_hold"`，使"合法驻守"不被交通归因误计为堵车（与 `traffic_telemetry.gd` 的合法桶口径一致）。
- 任务切换会向 `AITankController.events` 追加 `{"reason":"task_assigned","task","objective","detail"}`，可逐车审计"为何换任务"。

## 5. 本轮验证（真实运行）

| 项 | 结果 |
|---|---|
| `tests/run_ai_tactics_checks.gd`（新增） | **39/39 PASS** |
| ├ 8 槽位分配覆盖 A/B/C 且含 1 个侧翼、同输入确定性 | PASS |
| ├ 迟滞：冷却内重分配保持角色与目标 | PASS |
| ├ 紧急越权：不可机动受损 → `repair`；断弹 → `supply`（并解析到本方补给点） | PASS |
| ├ `decision_reason` 九字段齐备且反映实见状态 | PASS |
| ├ 让行：同队对向+咽喉点→高 id 让行；咽喉点外/同向/敌车→不让行；时长有界 | PASS |
| ├ 实验室：隐藏目标 500 tick 全程 `visible=false`，感知不含 `modules/crew` 字段 | PASS |
| └ 控制器接线：真实 AI 被赋予角色/目标、记录 `task_assigned` 事件、让行产生油门归零且 6 s 有界 | PASS |
| 接线回归 `run_ai_drive_checks` / `run_ai_combat_checks` / `run_multi_objective_checks` | **40/40 · 34/34 · 35/35** |

## 6. 未覆盖（如实）

- **河谷 8AI 战术整局**（三点分工 + 会车 + 补给的实际观测量）：`NOT_RUN`；本单只做正确性验证，按范围界限**不跑大型 AI 压力采样**。
- 让行在真实双 AI 桥头对峙中的端到端录像：`NOT_RUN`（本轮为规则级 + 控制器级验证）。
- 网络/真人：`NOT_RUN`；性能 `HOLD_BY_USER`。
