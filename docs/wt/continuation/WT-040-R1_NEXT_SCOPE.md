# 后续内容明确书（阶段：河谷现代团队战 · 依工作单 014/020/021）

> 用户指令：**恢复目标 → 检查工作单 → 明确后续内容 → 做完再人工审核**。
> 工作单依据：`docs/planning/ALL_WORK_ORDERS.md` 中 **014（电脑感知、瞄准与交战状态）**、以及 020/021（任务分配与协调，代码在 `AIRoleAllocator` / `TeamCoordinator`）。
> 目标状态：goal **active**（上限已提至 320，revision 6）✓

## 0. 当前**实测**事实（不是推断）
| 观测 | 值 | 来源 |
|---|---|---|
| 河谷对局 | 8 AI（4v4）初始化、`phase=playing`、stderr 空 | `logs/WT-040-R1/river-match-run9.log` |
| 任务推进 | `to_goal` **523→509→472→241 m**（修复前 608→594→608 振荡） | 同上 |
| 任务字段 | `task=""` `role=""` `task_reason=""` **全程为空** | `[river-chain]` |
| 观察/瞄准/发射 | `first_seen_s=-1` · `aim=""` · `shots=0` **全程** | 同上 |
| 票数/存活 | 300/300 · 4/4 不变（≠零交火：三项独立指标一致指向未接敌） | 同上 |

## 1. **根因（本轮新查清，两层"实现了但没接进去"）**
| # | 缺口 | 证据 | 影响 |
|---|---|---|---|
| **A** | **`TeamCoordinator` 全库从未实例化** ✗（无 `configure` / 无 `bind_allocator`） | `git grep TeamCoordinator` 只有类定义 | 角色/任务分配层**完全未接入** ⇒ `task=""` 必然 |
| **B** | **`director.begin()` 未传 objectives** ✗ | `TeamMatchDirector.begin(team_size, objectives)` vs `TeamRange` 内 `director.begin()` | `state.objectives == null` ⇒ **占点永不发生**（任何地图） |

⇒ **链条最先未通过的一环＝任务** ✓（其根因即 A+B）✓ —— 与用户"任务→路径→移动→观察→瞄准→发射"的定位一致 ✓。

## 2. **本轮修复范围（一次只修该环）**
**只做"目标/任务源接入"** ✓，不动其它环：
1. **场景提供目标**：新增场景钩子 `match_objectives()` ✓
   - 默认实现放 `TeamRange` ✓：从地图定义取（乡村/工业按其**既有**占点来源；河谷用 `RiverJunctionDefinition.capture_definitions()` ✓）；
   - 形状对齐分配器要求 ✓：`[{id, position:Vector3, owner_team}]`（`ai_role_allocator.gd:33`）。
2. **接进导演**：`director.begin(<team_size>, match_objectives())` ✓ ⇒ 占点集生效 ✓（`BattleObjectives.configure` ✓）。
3. **接进协调器（每队一个）**：
   - `TeamCoordinator.new()` ✓ → `configure(team, match_objectives(), supply, chokepoint)` ✓ → `set_roster(rows)` ✓ → **每物理帧 `step(now, delta)`** ✓；
   - 把 `coordinator.allocator` **绑定到该队每辆 AI**：`ai.bind_allocator(...)` ✓（`ai_tank_controller.gd:86` ✓）；
   - roster 行形状按其自身契约 ✓：`{entity_id, position, destroyed, mobile, speed_mps, blocked, at_objective, engaging, repairing}` ✓（`team_coordinator.classify` ✓）。
4. **再出击**：`spawn_slot` 已覆盖 ✓（复用同一 `objective_goal` ✓）—— 本轮同时**让新生成的车也 `bind_allocator`** ✓（否则再出击仍无任务 ✗）。

**不动**：速度/地图/传送/冷却/命中/伤害/平衡 ✗ · 性能专项继续 **HOLD** ✓ · 不新增外部依赖 ✓。

## 3. 验收（工作单 014 的口径 + 我的六环记录）
| 编号 | 验收 | 命令 |
|---|---|---|
| **验收-1** | 角色/任务**非空**：`task_objective`/`role` 在河谷出现 ✓ | `-s res://tests/record_river_ai_match.gd` → `[river-chain]` |
| **验收-2** | 占点集生效：`director.state.objectives != null` ✓ | 同上 + `director.state.result.objectives` |
| **验收-3** | 目标映射回归仍全绿 ✓（不回退 TeamArena、8/8 可达 ✓） | `-s res://tests/check_river_task_mapping.gd` |
| **验收-4** | **首次观察**出现（`first_seen_s >= 0` ✓），且**未看见时不开火** ✓（工作单 T014-01 ✓） | `[river-chain]` + 现有 T014 套件 |
| **验收-5** | 已有回归不被破坏：`run_ai_drive_checks` 40/0 ✓ · `run_ai_tactics_checks` ✓ · `run_team_checks` 67/0 ✓ · `run_map_checks` 48/0 ✓ | 逐套件复跑 |
| **验收-6** | 交火若出现：`shots>0` ✓ 且票池/击毁随之变化 ✓；若未出现 ⇒ 记录**最先失败的一环**并停在该环 ✓ | 同上 |

**交付物**：`docs/DELIVERY_014.md`（工作单 014 §5 要求 ✓）· 独立修复提交 ✓ · 版本绑定时间线+JSON ✓ · 修复前后对照 ✓。

## 4. 与用户主交付的衔接（不跳步）
```
本环（任务接入）→ 观察 → 瞄准 → 发射 → 河谷正常团队战
  → ③ 两辆现代样车战斗包（实测字段工具生成 + 参考字段标出处 + 设计项逐条列）
  → ④ 实际操作接通（观瞄/射击/受损/结算 + 烟幕或辅助武器之一）
  → ⑤ 完整流程（科技树选车→配弹→河谷交火→阵亡再出击→结算→下一局→重启保存）+ 独立可运行包
```
