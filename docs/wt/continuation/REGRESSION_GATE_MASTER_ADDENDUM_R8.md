# 回归门终版（第 8 次回填）：**32 套件 → 30 PASS / 2 FAIL**（采用策略）

> 运行：项目默认 32 套件（本轮为扩容前列表；扩容后为 40，见 `WT-036-R1_GATE_COVERAGE_GAP` 与门禁列表提交）。
> 证据：`logs/WT-036-R1/full-gate-adopted/`（逐套件日志 + `summary.json`）。

## 1. 终账
**PASS = 30 / FAIL = 2** ✓，且**两项失败均为已定性的非回归**：
| 失败套件 | 结果 | 定性 |
|---|---|---|
| `run_industrial_battle_checks` | **15 / 1** | **与基线逐项一致**（基线亦 15/1）；唯一失败＝**既有抵达红** ✓ |
| `run_challenge_checks` | **138 / 2** | 已登记：**防守夹具能力边界**（`repair=4/shots=0`，hard 150 s 超时）✓ |

## 2. 全绿清单（含检查数）
`run_checks` **217/0** · `run_shell_checks` 193/0 · `run_historical_checks` 192/0 · `run_garage_checks` 151/0 · **`run_industrial_checks` 595/0** · `run_team_checks` 67/0 · `run_armor_checks` 81/0 · `run_replay_checks` 73/0 · `run_wreck_visual_checks` 71/0 · `run_recovery_checks` 64/0 · `run_art_checks` 63/0 · `run_damage_checks` 57/0 · `run_hud_checks` 56/0 · `run_core_checks` 55/0 · `run_structure_checks` 54/0 · `run_feedback_checks` 40/0 · **`run_ai_drive_checks` 40/0** · `run_ai_combat_checks` 34/0 · **`run_historical_road_checks` 33/0** · `run_duel_checks` 27/0 · `run_drive_checks` 26/0 · **`run_village_battle_checks` 21/0** · `run_blender_asset_checks` 16/0 · `run_industrial_obstruction_checks` 9/0 · `run_telemetry_checks` 8/0 · **`run_slope_pivot_checks` 3/0** · `run_map_checks` 48/1（**仅设计目标项** ⇒ 集合判据 PASS ✓）· `run_layout_checks`/`run_query_checks`/`run_projectile_checks` 0 失败 ✓

## 3. 本阶段消除的回归（唯一整类）
**让行/僵持处理**（我曾引入）经**四轮策略迭代**收敛为：**优先级 + 双时限重规划** ——
停放车**倒车**（判据含 `reverse`）· AI 车**不倒车**（村庄时序极紧）· **不放弃**（放弃减少抵达）· 高优先**先动**、低优先 **1.5 s** 后也动（路径分叉解对峙）· 静态几何**永不计时** ✓
⇒ 四门**同时**达标：`ai_drive` 40/0 ✓ · 村庄 21/0 ✓ · 地图 48/1（仅设计目标）✓ · 战斗 15/1（=基线）✓

## 4. 工具与覆盖
- **运行器**：改为**日志证据判定**（本环境 `Start-Process` 的 `ExitCode` 常 `$null`、中文日志乱码），正反双向验证 ✓
- **覆盖缺口**：179 套件 vs 默认 32 ⇒ **147 未覆盖**（分类与建议见 `WT-036-R1_GATE_COVERAGE_GAP.md`）；本轮**已补入 8 个** D 类套件（**32 → 40**）✓，剩余 139 建议分批补入 ✓

## 5. 仍未结（不声称完成）
战斗套件**既有**抵达红（建议独立立项：工业图中央抵达率）· `T018-H01` 预算（A1/A2）· `challenge` 防守（B1–B4）· M26 坡上起步（C1–C3）· 8.5 m 包络（D1/D2）· 授权 E1–E4 · 真人验收与性能（NOT_RUN）
