# 河谷枢纽关键起终点可达矩阵（WT-032-R1）

- 依据：`02_首轮10张执行单.md` §05「必须交付：关键起终点可达矩阵」
- 生成方式：**生产 `DriveNavigator` + 生产 `RiverJunctionNavigation` 图**，逐泊位实际规划（车宽 3.8 m），**无传送**
- 机器可读输出：`logs/WT-032-r1/run_river_reachability_checks.log`（`RIVER_REACHABILITY_CHECKS_PASS`）

## 1. 矩阵（本单实测）

| 布局 | 起→终 | 组合数 | 可达 | 证据 |
|---|---|---|---|---|
| 10v10 | 双队全部泊位 → A/B/C | **60** | **60** | `[PASS] layout 10: all 60 spawn->objective routes are reachable` |
| 10v10 | 双队全部泊位 → 本方补给 | **20** | **20** | `[PASS] layout 10: all 20 spawn->resupply routes are reachable` |
| 16v16 | 双队全部泊位 → A/B/C | **96** | **96** | `[PASS] layout 16: all 96 spawn->objective routes are reachable` |
| 16v16 | 双队全部泊位 → 本方补给 | **32** | **32** | `[PASS] layout 16: all 32 spawn->resupply routes are reachable` |
| 合计 | 泊位 → 占点 | **156** | **156** | 与既有 `logs/WT032-navigation/RESULTS.json` 的 156 一致 |

## 2. 侧翼与替代路线

| 场景 | 10v10 | 16v16 | 证据 |
|---|---|---|---|
| **中央通路关闭**后仍有外侧路线到达 A/C | **10 条**可达 | **16 条**可达 | `[PASS] layout N keeps an outer flank route when the central crossing is closed` |
| 单座跨河桥关闭后可绕行 | 既有 8 例 | 既有 8 例 | `logs/WT032-navigation/RESULTS.json`（`single_bridge_closure_cases: 8`）+ `run_river_junction_checks` 45/45 |
| 逐段物理通道（车体宽度 3.8 m、每边 3 条射线）无阻挡 | 417 边 | 880 边 | `run_river_navigation_checks` **22/22**（`blocked=0`） |
| 地面/桥面支撑（每边 4 采样，±0.4 m 容差） | 同上 | 同上 | 同上（`unsupported=0`） |
| 生产 M4 实际跨越桥梁 | 5 座桥 | 5 座桥 | `run_river_driving_checks` **34/34**（`production M4 drives completely across bridge N`、`bridge traversal retains support and lateral clearance`） |

## 3. 出生槽占用（残骸）

| 条件 | 结果 | 证据 |
|---|---|---|
| 槽位空置 | 接受 | `[PASS] spawn selection accepts an unobstructed slot` |
| 首选槽位被残骸占用 | **改选其他槽位**（实测 moved） | `[PASS] an occupied slot yields another slot or a bounded spawn_blocked (moved)` |
| 全部槽位被占用 | **`spawn_blocked` 有界等待，不叠车** | `[PASS] every slot occupied reports spawn_blocked instead of stacking vehicles` |
| 残骸位置可查、清理即净 | 通过 | `WreckRegistry.wreck_positions()` / `clear_tracking()` |

## 4. 入口一致性

| 检查 | 结果 |
|---|---|
| 勘察入口 `scripts/ui/river_junction_survey.gd` 与正式入口 `scripts/maps/river_junction_range.gd` 同用 `RiverJunctionDefinition` | PASS（两者均含引用） |
| 布局与补给均由同一 `RiverJunctionDefinition` 派生 | PASS（`layout(` 与 `supply_points(` 均在正式入口路径） |
| 图生成确定性（两次独立构建 JSON 完全相同） | PASS |
| 图 `schema_version=1`、`map_id` 正确 | PASS（两布局） |

## 5. 限制（如实）

- 全部为**单车/受控规划**验证；**多车同时导航、会车、堵塞**仍 `NOT_RUN`（`logs/WT032-navigation/RESULTS.json.limitations.simultaneous_multi_vehicle_navigation`）。
- 20/32 人容量、网络、真人体验：`NOT_RUN`。
- 性能：`HOLD_BY_USER`，未采集 FPS/p95/p99。
- 射线采样不等于完整车体扫掠或所有车型通过性验收。
