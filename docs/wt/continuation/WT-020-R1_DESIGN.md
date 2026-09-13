# WT-020-R1 设计页（河谷 AI 分工、战术、让行与恢复）

- 对应父项：WT-017 / WT-020 / WT-021；依赖：WT-032-R1（可达网络 + 补给）、WT-012-R1（能力与恢复）、WT-002-R1（权威状态）
- 依据：`02_首轮10张执行单.md` §08

## 1. 现状核查（实测）

| 已有 | 证据 |
|---|---|
| 感知只取可见表面 | `ai_perception.gd`：`# Visible surface samples, never module or crew coordinates.`；memory 6 s |
| 路径/让障 | `ai_path_driver.gd` 已有 `yielding` 相位（`physical_obstacle` / `obstacle_cleared`）+ `StuckDetector` |
| 任务目标不丢失 | 之前的 hop 修复：hop 永不取代 `patrol_goal`，`arrived` 后从新地面重试（C11/C12） |
| 恢复优先于撤退 | `ai_tank_controller.gd:164-171`：无弹且不可机动时保持恢复命令，不被撤退吞掉 |
| 公共目标只读接口 | `battle_objectives.gd`：`configure/step/snapshot` |
| 合法驻留 vs 堵车 | `traffic_telemetry.gd` 桶（`at_objective` 等） |
| **缺失** | **角色/任务分配层**（进攻/守点/侧翼/补给）与其迟滞；**`decision_reason` 留痕**；**同队对向咽喉让行规则** |

## 2. 本单改动（3 个运行文件 + 1 套件）

| 文件 | 改动 |
|---|---|
| `scripts/ai/ai_role_allocator.gd`（新，~150 行） | 纯决策层：角色/目标分配 + 迟滞 + 紧急越权 + `decision_reason` + 有界让行规则；只读公共目标与本方名单 |
| `scripts/ai/ai_tank_controller.gd` | 新增 `allocator/role/task_objective/task_reason/give_way_until`、`bind_allocator()`、`apply_task(context)`；在恢复/撤退之后插入**有界让行保持**（`phase="yielding"`，油门转向归零） |
| `tests/run_ai_tactics_checks.gd`（新，39 项） | 分配/迟滞/越权/留痕/让行/不跟隐藏真值/控制器接线 |

**惰性保证**：未绑定分配器时 `apply_task` 与让行分支都不生效 → 既有单车主循环行为不变（接线回归三套件全绿）。

## 3. 接口与数据结构

- 名单行（本方）：`{entity_id, team, position, forward, ammo_fraction, mobile, immobile_damaged, at_objective, destroyed}`
- 上下文：`{team, objectives:[{id, position, owner_team}], supply:{team:Vector3}, friendly_rows:[…]}`
- 输出：`assignments[entity_id] = {role, objective, reason, since, urgent, hold_reason}`
- 让行：`should_give_way(self_row, other_row) -> bool`（同队 + 对向 + 咽喉 + 高 id 让行）

**兼容性**：纯新增；`apply_task` 为可选调用；无存档/协议/内容迁移。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_ai_tactics_checks`（新） | **39/39 PASS** |
| `run_ai_drive_checks` | **40/40** |
| `run_ai_combat_checks` | **34/34** |
| `run_multi_objective_checks` | **35/35**（`RESULT multi_objective passed=35 failed=0`） |

自纠记录：套件首版两处夹具写错（友好车朝向同向、让行方实体 id 比较方向）导致 1 项失败；修正夹具后通过——规则本身未被放宽（`should_give_way` 的双向判定与"咽喉点外不让行"用例始终为硬断言）。

## 5. 明确不做 / 未运行

- 不跑大型 AI 压力采样；不做 8AI 河谷战术整局的观测量统计（`NOT_RUN`）。
- 不改任何战斗参数、不改导航图数据、不重写感知/路径实现。
- 网络、真人 `NOT_RUN`；性能 `HOLD_BY_USER`（未采集 FPS/p95/p99）。

## 6. 回滚

删除新模块与套件、回退 `ai_tank_controller.gd` 的 3 处新增即可；因默认惰性，回滚不影响任何既有行为。
