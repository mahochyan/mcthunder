# WT-036-R1 收尾：11 个 DEFERRED 套件的长预算重跑（阶段记录）

- 依据：第 2 轮回归门（`REGRESSION_GATE_ROUND2_FULL.md`）把 11 个套件记为 **DEFERRED（超出 120 s 仍在输出）**，当时**未计入通过**
- 本单方法：**每套件 600 s 上限**、headless、逐套件落盘到 `logs/WT-036-r1/<suite>.log`
- **判据更正（本单新增）**：一个套件若在 600 s 内**一条检查都不输出**（日志仅剩引擎头几行），应判为**挂起 / 依赖窗口或引擎专有流程**（NOT_RUN），**而不是"慢"**——这与"跑了很久但有检查产出"是两回事

## 1. 已完成结果

| 套件 | 状态 | PASS | FAIL | 用时 | 证据/注 |
|---|---|---|---|---|---|
| `run_art_showcase` | **TIMEOUT 无检查** | 0 | 0 | 601.1 s | 日志 75 B（仅引擎头）→ **窗口/渲染依赖，挂起** |
| `run_export_checks` | **TIMEOUT 无检查** | 0 | 0 | 601.1 s | 日志 75 B → **引擎/导出流程依赖，挂起** |
| `run_challenge_checks` | **FAIL（2）** | **138** | **2** | 558.8 s | **能跑**；两项失败为同一检查：`real defense script pilot completes finite waves with opponent AI untouched` |

### `run_challenge_checks` 失败证据（日志末尾）
```
[active defense] { } held=45.0 kills={ } player_shots=0 remaining=6
   enemies=[{ "id": "B1", "position": (-77.96, 0.00026, 25.91), ... } ...]
[FAIL] real defense script pilot completes finite waves with opponent AI untouched
=== 结果: 140 项检查, 2 失败 ===
```
→ **脚本飞行员在防守关内 45 s、0 击杀、仍余 6 敌**：挑战模式的"防守波次"用脚本飞行员**无法完成**（不是挂起、是真实的玩法/AI 结果）。该检查此前从未跑过（第 2 轮为 DEFERRED），**属新暴露项**，需单独立项。

## 2. 待完成（后台仍在跑）
`run_industrial_battle_checks` · `run_industrial_checks` · `run_research_thumbnail_bake` · `run_river_driving_checks` · `run_river_engagement_checks` · `run_traffic_attribution` · `run_traffic_telemetry_checks` · `run_village_battle_checks`

## 3. 收尾后的动作
1. 汇总全部结果 → 更新门禁 JSON（新增 `deferred-rerun.json`）与第 2 轮门文档附录；
2. DEFERRED 计数从 **11** 缩减为实际仍无法跑者（预计：挂起 2 项改判 NOT_RUN、其余给出真实 PASS/FAIL）；
3. 新暴露的失败（如 challenge 的防守波次）登记为独立条目，**不混入门禁的"回归"口径**（它们此前从未被测量）。
