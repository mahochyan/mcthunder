# 回归门总表（第 2 轮 + WT-036 收尾后的权威口径）

> 本表汇总本分支相对基线 `a1bac406d2bc12b32c7f7d130590f1c1a17907c9` 的**可复现**门禁结论；
> 所有数字均来自**本机实跑**，未跑项一律标 `NOT_RUN` 或 `DEFERRED`，**不计入通过**。

## 1. 确定性套件（可直接作门禁）
| 套件 | 结果 | 证据 |
|---|---|---|
| **`run_historical_road_checks`** | **33 PASS / 0 FAIL**（曾 29/4，**M26 四条基线红已清除**） | `logs/WT-039-D/run_historical_road_checks-after-road-paint.log` |
| **`run_map_checks`** | **46 PASS / 3 FAIL，连跑 3 次失败项完全相同** | `logs/WT-039-D/run_map_checks-after-*` |
| **`run_slope_pivot_checks`（T039-E，本会话新增）** | **3 PASS / 0 FAIL**（平地/11.9°/12.7° 均 −176° 级自转） | `logs/WT-039-D/run_slope_pivot_checks-fix6.log` |
| `run_village_battle_checks` | **21 PASS / 0 FAIL** | `logs/WT-036-r1/run_village_battle_checks.log` |
| `run_structure_checks` | **54 PASS / 0 FAIL** | `logs/WT-039-r1/run_structure_checks-after-grading.log` |

`run_map_checks` 的 3 项失败为**已知且保留**：`T018-03b`（**我新增的设计目标检查**，8.5 m 刚体包络当前未通过，见 `WT-039-D_SEMANTIC.md`）、`T018-H01`（单条出生→占点）、`T018-02`（停放车绕行）。

## 2. 工业套件（`run_industrial_checks`）：完整对完整对照
| 指标 | 基线 main（完整） | 本分支（完整） |
|---|---|---|
| PASS / FAIL | 283 / 56 | **300 / 39** |
| **唯一失败检查** | **56** | **39** |
| 检查总数 | 339 | 339 |

- **仅基线失败 19** → 本分支**已消除**（以 M26/M36 捕获路线为主）；
- **仅分支失败 2** → ① 一项**基线同样失败**（`us_m24…/2/5/capture`）② 一项**三轮中仅一轮**（`imbalance <15%` 边际统计）⇒ **可归因回归 = 0**；
- **共同失败 37** → **supply 36 · capture 0** ⇒ **`supply` 收口 100% 属既有**；
- **轮间方差**（同分支两次）：**稳定失败 29** · 仅 run2 10 · 仅 run1 1（run1 被 600 s 截断）；
- 证据：`logs/WT-036-r1/{baseline-industrial-full,run_industrial_checks,cont-industrial-run2}.log`、`regression-gate-deferred-closeout.json`。

## 3. 第 2 轮 11 个 DEFERRED：**已全部定性（DEFERRED = 0）**
| 分类 | 套件 | 依据 |
|---|---|---|
| **NOT_RUN（环境依赖，4）** | `art_showcase` · `export_checks` · `research_thumbnail_bake` · `traffic_attribution` | 601 s、**0 检查**、日志仅引擎头 → 窗口/渲染/引擎流程依赖 |
| **SLOW-已测（2）** | `industrial_battle`（1 检查）· `industrial`（85/30 截断样本） | 有产出未跑完 |
| **MEASURED（5）** | `challenge` **138/2**（见 §4）· `village_battle` **21/0** · `traffic_telemetry` **8/0** · `river_engagement` **36/0** · `river_driving` **34/0** | 后三者曾被我误判 FAIL（**我的 `ExitCode=$null` 工具 bug**），已更正 |

## 4. 未结项（3 个，均有证据与归属）
| ID | 状态 | 要点 |
|---|---|---|
| `challenge_defence_waves` | **夹具缺口**（修复验证中） | `hold_ground` 需 **占区 + 击杀全部敌人**；实测 `held=45.0`（**已达上限**）但 `kills={}`、`player_shots=0`；敌人位于占区以北 **~75 m**，旧夹具**从不前出** ⇒ 无法击杀。修复：占区达标后**北上前出交战**（断言不动） |
| `supply_leg_closure` | **既有系统性 + 电池内不稳定** | 36 项 supply 在两棵树全失败；**同路线孤立运行可 0 恢复抵达** ⇒ 需测试侧加固（每路线独立世界 / 收敛与占用断言），**不改语义** |
| M26 重车坡上起步 | **调校冲突（已登记）** | 10.4° 坡、0.77 油门无法从静止起步；**九次驱动侧修复全部否证**；`WT-075-R1_RESTART_ON_GRADE_CONFLICT.md` |

## 5. 本会话保留的产品改动（相对基线，均经门禁验证）
| 文件 | 内容 | 验证 |
|---|---|---|
| `tank.gd` + `game_config.gd` | **坡面自转修复**（绕地面法线旋转 + 以 `compose` 重建）+ 转向支撑下限 | T039-E 3/3、村庄 21/0、地图 46/3 |
| `ai_path_driver.gd` | **卡死窗口修复**（重规划不再清零 + 需真实油门） | 村庄 21/0、地图 46/3 |
| `village_definition.gd` | **`near→cap` 铺装**（消除 M26 道路基线红） | 历史 **33/0** |
| `navigation_bake_pipeline.gd` | 包络**含地面**诊断字段（不改 `ok` 语义） | 地图 46/3（`T018-03b` 作为设计目标项保留失败） |
| `vehicle_actor.gd` | 只读可观测字段（诊断用） | — |

## 6. 明确 `NOT_RUN`（不冒充通过）
- **真人验收**：全 42 项 `NOT_RUN`；**性能**：`HOLD_BY_USER`（**零采样**）；
- **公网联网**：房间发现/中继/专管托管/账号——未授权且未实现；
- **10v10/16v16 容量对局**、**空海扩展（EXT-01—04）**；
- **需授权**：`export_presets.cfg` 的 server/client 预设；96 车适配产物全量（约 70 MB）。

---

## ⚠️ 最新状态指针（后续增补已改变下列结论，请以增补为准）
本文件成文于第 2 轮门禁；其后各增补与裁定改变了部分结论：
| 本文件中的旧结论 | 最新状态（以增补/裁定为准） |
|---|---|
| `T018-03b` 为"**设计目标检查，当前失败**" ✗ | **用户裁定 D2**：8.5 m 刚体包络改为**声明的设计目标（非硬性）** ⇒ 该检查已改为**信息报告**，`run_map_checks` **48/0 全绿** ✓（见 `WT-036-R1_ENVELOPE_DECLARATION.md`、`_ADDENDUM_R9.md`） |
| `run_historical_road_checks` 29/4 ✗ | **33/0** ✓（M26 道路红已清除 ✓） |
| `run_industrial_checks` 未测/56 失败 ✗ | **595/0** ✓（`_ADDENDUM_R9.md`） |
| `run_map_checks` 45–47 抖动 ✗ | **48/0（D2 后确定）** ✓ |
| 11 个 `DEFERRED` 套件 ✗ | **全部定性（DEFERRED = 0）** ✓（`WT-036-R1_DEFERRED_RERUN_FINAL.md`） |
| 默认门禁 32 套件 | **111 套件** ✓（覆盖缺口 147 → 68；`WT-036-R1_GATE_EXPANSION_LOG.md`） |
| `run_ai_drive_checks` 通过 | 我曾引入回归后**已修复**（40/0 ✓）——见 `_ADDENDUM_R7.md` 的五策略对账表 ✓ |
| `partial_support`（本文件未列） | 我曾引入回归后**已修复**（7/0 ✓，且已入默认门禁 ✓） |
**唯一仍红的项**：`run_challenge_checks` 138/2 ＝ **已登记**的防守夹具能力边界 ✓（`WT-036-R1_CHALLENGE_FIXTURE_BOUNDARY.md`）
