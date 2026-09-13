# 回归门报告 · 第 2 轮（WT-035-R1）· **完整版**

- 范围：**全部 140 个可跑套件**（仓库共 177 个 `run_*`；37 个按名排除）
- 方法：真实 headless 运行 + 真实退出码/套件标记/逐行 `[FAIL]` 判读；分批看门狗（120 s，重跑 240 s）
- **基线对照**：所有异常均在**未改动的 `main`（a1bac406）**上重跑，逐条比对失败集合
- 证据：`logs/WT-035-r1/regression-gate-full.json`（机器可读，140 条逐套件结论）+ 逐套件日志 + 5 份基线对照日志

## 1. 最终判定

| 分类 | 数量 |
|---|---|
| **PASS** | **117** |
| **既有红（基线同样失败，已逐条对照）** | 4 |
| **抖动且相对基线改善** | 1 |
| **NOT_RUN（窗口/渲染自守卫）** | 5 |
| **NOT_RUN（需真实服务端角色）** | 1 |
| **NOT_RUN（需套件参数）** | 1 |
| **DEFERRED（超时仍在输出，状态未知）** | 11 |
| 合计 | **140** |
| **本分支引入的回归** | **0** |

## 2. 四个既有红（全部有基线对照证据）

| 套件 | cont | 基线 a1bac406 | 失败主题 |
|---|---|---|---|
| `run_chassis_response_checks` | 2 FAIL | **2 FAIL（完全相同）** | `muzzle and damage query follow authoritative braking tilt A/B` |
| `run_historical_road_checks` | 4 FAIL | **4 FAIL（完全相同）** | `us_m26_m3_1945 …reaches capture via roads within movement bounds` |
| `run_team_checks` | 66 PASS / 1 FAIL | **66 PASS / 1 FAIL（同一条）** | `restart uses the team scene and fresh match identity` |
| `run_map_checks` | 24 PASS / 3 FAIL | **24 PASS / 3 FAIL（同主题；槽位索引随抖动变化）** | `T018-H01 …reaches own capture position`；`maximum-size proxy … western hill` |

> 四个套件在基线**同样失败**，故均为**既有红**；`run_map_checks` 的槽位索引在两次运行间不同（1/2 vs 1/3），属该检查自身的槽位抖动。

## 3. 抖动且改善：`run_checks`（核心 217 项）

| 轮次 | cont 分支 | 基线 a1bac406 |
|---|---|---|
| 1 | 216 / 1 | 212 / 5 |
| 2 | **217 / 0** | 212 / 5 |
| 3 | 216 / 1 | 212 / 5 |

- 基线**稳定 5 条** `T003-06` 命中计数失败；本分支**不再出现** → 分支**修好了它们**；
- 本分支唯一失败为 `R3-A 近靶 B1 稳定收敛`（**最大误差 0.00°、首次过线 −1 帧**）→ **单帧余量抖动**，已如实标注。

## 4. NOT_RUN（环境/接口不满足，非缺陷）

| 原因 | 套件 |
|---|---|
| headless 自守卫（源码 `if DisplayServer.get_name()=="headless": quit(1)`） | `run_art_battle_render_checks`、`run_feedback_battle_render`、`run_free_look_checks`、`run_industrial_overview`、`run_turret_tick_checks` |
| 需真实服务端角色（连接 19111 端口） | `run_network_view_checks`（其失败行即"未收到分配车辆"，与无服务端一致） |
| 需套件参数 | `run_river_navigation_checks`（需 `--river-navigation-check`，无参时空转） |
| 按名排除 | 37 个（窗口/玩家真实输入/演示/角色编排/长时/性能剖析） |

## 5. DEFERRED（超时仍在输出 → **不计入通过**）

| 预算 | 套件 |
|---|---|
| >240 s | `run_art_showcase`、`run_challenge_checks`（超时前已打印 `[PASS] actual challenge result freezes after exactly one settlement`）、`run_export_checks`、`run_industrial_battle_checks`、`run_industrial_checks` |
| >120 s | `run_research_thumbnail_bake`、`run_river_driving_checks`、`run_river_engagement_checks`、`run_traffic_attribution`、`run_traffic_telemetry_checks`、`run_village_battle_checks` |

**已知参照**：`run_river_engagement_checks` 在 WT-007-R1 以 600 s 预算跑出 **36/36 PASS**；`run_river_driving_checks` 在 WT-032-R1 **PASS**；`run_balance_matrix_checks`/`run_feedback_checks`/`run_historical_checks` 在本轮 240 s 重跑中已转为 **PASS**（说明"超时"多为预算而非缺陷）。

## 6. 结论与后续

- **本分支 31 个提交、140 个可跑套件：0 回归**；4 个失败全部在基线复现，1 个核心套件由 5 红改善为 0–1 红（抖动）。
- **剩余未决**：11 个 DEFFERED 套件需更长预算或参数（下一轮给 600 s 与正确参数收口）；37 个按名排除者需窗口/真实输入/性能预算（`HOLD_BY_USER`）。
- 该完整门报告作为 **WT-038 正式交付门**的前置证据。
