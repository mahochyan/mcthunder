# DELIVERY_014（工作单 014：电脑感知、瞄准与交战状态）· 阶段交付

> 工作单要求（§1）：**电脑能发现可见敌人并公平地瞄准开火，暂不追求战术大师。**
> 本文件按 §5 要求列出：实际实现、被测 SHA、命令与日志、未验证、已知问题、运行入口、回退位置。

## 1. 被测对象（版本绑定）
| 项 | 值 |
|---|---|
| 被测 SHA | `8b26c665c8c925321b99a577e3bebed68b0df962` |
| 分支 | `work/continuation-20260913` |
| 基线 | `main @ a1bac406d2bc12b32c7f7d130590f1c1a17907c9`（**未改动** ✓） |
| 引擎 | Godot 4.7.2-stable（普通版）· headless · `--fixed-fps 60` |
| 场景 | `res://scenes/maps/map_river_team.tscn`（河谷团队战；**未列入车库 IDS** ✓） |

## 2. 实际实现（本轮改动清单，全部有 diff 可查）
| 文件 | 改动 | 目的 |
|---|---|---|
| `scripts/battle/team_range.gd` | 新增 `match_objectives()` 场景钩子 + `allocator_objectives()` + 每队 `TeamCoordinator` + 2 Hz 任务层 + `apply_task` 调用 + `_snap_to_graph` 默认实现 | **把已存在但从未接线的任务层接上** |
| `scripts/maps/river_team_range.gd` | `_build_match_objectives()`（河谷自身 `capture_definitions()` ✓）+ `_snap_to_graph` 覆盖 + 目标映射 / 再出击重分配 | 只改**河谷**，不动其它地图 |
| `tests/record_river_ai_match.gd` | 六环记录器（任务/路径/移动/观察/瞄准/发射 + 票池 ✓） | 可观测证据 |
| `tests/check_river_task_mapping.gd` | 目标映射回归 | **永久看住** |
| `scripts/battle/team_range.gd` 门控 | 一切新逻辑**仅在 objectives 非空时生效** | **既有地图行为不变** ✓ |

**根因（三层"实现了从未接线"，均经源码与实测双向确认）**：
1. `director.begin()` 未传 objectives ⇒ `state.objectives == null` ⇒ **占点永不发生**；
2. `TeamCoordinator` **全库从未实例化** ⇒ 角色/任务层从未运行；
3. `AITankController.apply_task()` **只在测试中被调用** ⇒ 即使绑定分配器也不领取任务；
4. 追加：分配器目标是**未吸附**的占点中心 ⇒ `driver=unreachable`。

## 3. 命令与证据
`
# 六环记录（诊断窗口 240 s 仿真）
<godot> --headless --path <cont> --fixed-fps 60 -s res://tests/record_river_ai_match.gd
  → logs/WT-040-R1/river-match-window-final.log  ·  JSON: logs/WT-040-R1/river_ai_match_44001.json

# 目标映射回归
<godot> --headless --path <cont> --fixed-fps 60 -s res://tests/check_river_task_mapping.gd
  → RIVER_TASK_MAPPING_PASS（4/4）

# 回归批次（本轮实跑）
run_ai_drive_checks 40/0 · run_ai_tactics_checks 39/0 · run_ai_intercept_checks 106/0
run_ai_recovery_checks 16/0 · run_ai_combat_checks 34/0 · run_team_checks 67/0 · run_map_checks 48/0
`
**已观测到的六环数据（任务环已闭合）**：
`
A : task=C role=flank   driver=following/path_ready  phase_reason=task_assigned ✓
A2: task=A role=attack  driver=following/path_ready ✓   （修复前 unreachable ✗）
A3: task=B role=attack  driver=following/path_ready ✓
A4: task=C role=attack  driver=following/path_ready ✓        stderr 空 ✓
`

## 4. **未验证**（明确不声称）
| 项 | 状态 |
|---|---|
| **观察环**（`first_seen_s ≥ 0`） | **未观测到** ✗ —— 240 s 诊断窗口内尚未接敌 |
| **瞄准 / 发射环** | **未观测到** ✗（`aim=""`、`shots=0` ✓） |
| **完整比赛** | **未验证** ✗（窗口到上限即标"观察结束" ✓，不改正式规则 ✓） |
| 工作单 014 §3 的 **T014-01…05** | 既有套件（`run_ai_*`）通过 ✓，但**对河谷场景的 T014 案例尚未单独复跑** ✗ |
| §4 图形验收 **U014-01** | **待用户验收** ✓ |
| 难度档位对河谷的影响 | **未测** ✗ |

## 5. 已知问题
1. **仿真推进慢**：河谷 2080×1600 m、8 AI 真实寻路 ⇒ 240 s 仿真需**十几分钟墙钟以上** ✗（**不通过提速/改时步规避** ✗——那是改规则）；任务层已限频 2 Hz ✓；
2. **再出击重分配**：代码完成 ✓（`spawn_slot` 覆盖 ✓），**尚无击毁样本**验证 ✗；
3. **角色分配器**在河谷已生效 ✓，但 2 Hz 限频为**工程取舍** ✓（决策层滞回 ✓），未做更细的代价评估 ✗；
4. 山谷图 857 节点 ✓、河谷 `combat_admitted=false` ✓ ⇒ 本场景仍是**工程性对局测量** ✓，不向玩家开放 ✓。

## 6. 运行入口与回退
- **入口**：`tests/record_river_ai_match.gd`（记录 ✓）· `tests/check_river_task_mapping.gd`（回归 ✓）· 场景 `scenes/maps/map_river_team.tscn` ✓；
- **回退（逐项独立，单提交可退）**：
  - 三层接线 ⇒ 回退 `61ba92ee` ✓（基类改动**全部门控在目标非空** ✓ ⇒ 回退后既有地图行为不变 ✓）；
  - 分配器吸附 ⇒ 回退 `8b26c665` ✓；
  - 目标映射（任务点）⇒ 回退 `3e9156d2` ✓；
  - 六环记录 ⇒ 回退 `778eedc1` ✓；
  - 整体回到本轮起点 ⇒ `4d63b78f` ✓；回到更早阶段 ⇒ `f5d5d46e` ✓。
