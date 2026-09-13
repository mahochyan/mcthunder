# WT-039-R1 调查记录（既有红：出生→占点可达）

- 目标：修复**基线即红**的两组失败（`run_historical_road_checks` 4 条、`run_map_checks` 3 条），且必须**用基线对照证明是修好而非放宽**
- 本单状态：**第 1 阶段（设计与定位）完成；尚未改任何代码**（避免盲修）

## 1. 失败清单与运行诊断（来自 `logs/WT-035-r1/` 的真实 `[route]` 事件流）

### 1.1 `run_historical_road_checks`：**仅 M26 失败**，槽 0 与 7（两队）
| 车 | slot 0 / 7 结果 | 终点 |
|---|---|---|
| M4A3 / M24 / M36 | `phase=arrived` | `(±6.7, 0.03, ±5.6)` |
| **M26** | **`phase=failed`** | **`(-40.43, 0.0005, 18.01)`**、`(40.46, …, 17.93)`、`(-40.46, …, -17.96)`、`(40.27, …, -17.63)` |

→ 三辆车正常抵达目标区，**唯独 M26**（四车中预计最宽）走偏约 40 m 并最终 `failed`，峰值速度正常（2.69–2.84 m/s）。

### 1.2 `run_map_checks`：两类不同症状
**槽 2（两队）——路径不可规划：**
```
team=1 slot=2: phase=unreachable  position=(8.99, 0.006, 115.33)  （起点 (9, 0.03, 116)，仅移动 ≈0.7 m）
  事件: following → reverse(insufficient_actual_progress) → turn_recovery → following
        → reverse → turn_recovery → unreachable(reason=unreachable_or_insufficient_width)
```
→ 在出生口附近连续两次倒车/转向恢复后判 `unreachable_or_insufficient_width`：**该出口的净宽不足**（对该车包络）。

**槽 0（两队）——抵达但触发运动边界：**
```
team=1 slot=0: phase=arrived  bounded=false  seconds=95.7
```
→ 路由成功，但测试的**运动边界断言**（每 tick 位移 < `forward_max_speed/60+0.2`、速度在 `[-reverse_max, +forward_max]` 内）**被触发** → 属**运动学/物理层**症状，而非寻路症状。

**maximum-size 代理**：`phase=arrived`、`bounded=true`、`peak_y=0.0635`（其余约 0.031）→ 通过爬坡段时高度抬升明显；其断言（西侧山丘往返）在本轮失败之一，需与坡道净空/车宽一并核对。

## 2. 已确认为事实的部分

| 结论 | 证据 |
|---|---|
| 两组失败**均为基线即红** | 在未改动的 `a1bac406` 工作区重跑：`run_historical_road_checks` 24/3 同主题、`run_map_checks` 24/3 同主题 |
| 失败**不是我在本分支引入** | 同上；本分支未改车辆包络与村庄地图图数据 |
| 槽位索引在 `run_map_checks` 中**抖动** | cont 为 1/0、1/2；基线为 1/0、1/3 → 同一根因的不同表现 |
| 车辆定义加载正常 | 分阶段探针：`VehicleDefs.load_defaults()` → `{ok:true}`；`VehicleCatalog.IDS` 四项齐全 |
| 诊断数据完整 | 两套件均输出 `[route]` 事件流（阶段、原因、tick 索引、位置），可用于逐步复现 |

## 3. 待验证的根因假设（下一轮用实测收敛）

| # | 假设 | 待测证据 | 候选修复点 |
|---|---|---|---|
| H1 | 出生口净宽对该车包络不足 | 对失败槽位跑 `DriveNavigator.request_path(spawn, goal, width, {})`，记录 `reason` 与所需/可用宽度 | `scripts/maps/village_definition.gd`（泊位/道路宽度）、`scripts/drive/drive_navigator.gd`（宽度门限） |
| H2 | M26 的 `drive_collision_size` 相对道路净空**偏大或数据异常** | 打印四车包络与最窄边宽度对比（M26 是否唯一越界） | 若是**数据错误** → 修定义；若是**设计值** → 修地图（**不改车辆参数**） |
| H3 | 槽 0 的 `bounded=false` 是**恢复/碰撞瞬间**的速度或位移尖峰 | 在边界断言处记录**越界的那一 tick**（时间、速度、位移、phase） | 视结果决定修物理/驱动，或确认为**测试阈值的测量窗口问题**（须先证明，不得直接放宽） |
| H4 | 西侧山丘坡道对最大包络净空不足 | 沿该坡道采样高度与可通行宽度 | `village_definition.gd` 地形/道路 |

## 4. 下一轮执行计划（落到具体命令与函数）

1. 修正宽度探针（本轮探针在地图/导航段挂起，已定位为**地图侧调用**问题；改为分阶段打印并**每阶段 flush**，避免被杀死时丢输出），产出：
   - 四车包络 vs 图边宽度表；
   - 失败槽位与失败终点的 `request_path` 结果（`ok/reason`）。
2. 由实测在 H1/H2 之间定性，然后**最小改动**修复（预计 1 处地图数据或 1 处宽度门限），并**同一命令先后对照**（基线→修复后），证明失败条数由 3/4 降为 0 且**未放宽阈值**。
3. 单独处理 H3（先取得越界 tick 证据；若属测量窗口问题，**先说明再改**，不放宽语义）。
4. 完成后重跑 `run_historical_road_checks`、`run_map_checks`、`run_river_*`（回归）与 `run_chassis_response_checks`、`run_team_checks`（另两个既有红）以确认无交叉影响。

## 5. 本轮交付物与边界

- 交付：本调查记录（含真实证据引用与已确认/待验证的清晰分界）。
- **未改任何代码**：本轮只做定位；按"每条结论必须有可观测证据"，缺少宽度实测前不猜测修复。
- 未触碰：车辆定义、村庄地图数据、导航实现、脏文件、构建流程。
