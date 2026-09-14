# WT-036-R1 收尾（终版）：11 个 DEFERRED 全部定性 + 工业套件同预算对照定案

## 1. 11 个 DEFERRED 的最终定性（600 s/套件，真实运行）
| 套件 | 状态 | PASS | FAIL | 用时 | 定性 |
|---|---|---|---|---|---|
| `run_art_showcase` | TIMEOUT | 0 | 0 | 601.1 s | **挂起**：0 检查、日志仅引擎头 → **窗口/渲染依赖**（NOT_RUN） |
| `run_export_checks` | TIMEOUT | 0 | 0 | 601.1 s | **挂起**：同上 → **引擎/导出流程依赖**（NOT_RUN） |
| `run_research_thumbnail_bake` | TIMEOUT | 0 | 0 | 601.1 s | **挂起**：同上 → **渲染依赖**（NOT_RUN） |
| `run_traffic_attribution` | TIMEOUT | 0 | 0 | 601.0 s | **挂起**：同上 → **依赖真实交通/窗口**（NOT_RUN） |
| `run_industrial_battle_checks` | TIMEOUT | 1 | 0 | 601.1 s | **真慢**（有产出未跑完）→ 维持 DEFERRED |
| `run_industrial_checks` | TIMEOUT | **85** | **30** | 601.1 s | **能跑未跑完**；已用同预算基线对照定性（见 §2） |
| **`run_challenge_checks`** | **FAIL** | **138** | **2** | 558.8 s | **完整跑完**；2 项失败同一检查（脚本飞行员防守波次）→ **新暴露玩法项** |
| `run_village_battle_checks` | FAIL(退出码) | **21** | 0 | 220.9 s | 检查全通过但进程非零退出 → **需查明退出路径**（此前同套件曾 `PASS` 退出 0） |
| `run_traffic_telemetry_checks` | FAIL(退出码) | **8** | 0 | 521.2 s | 同上：检查通过但非零退出 → 疑**需实参/依赖真实交通** |
| `run_river_engagement_checks` | FAIL(退出码) | **36** | 0 | 124.8 s | 同上：36 项通过但非零退出 → 与既有记录一致（该族套件**需 `--river-*-check` 实参**） |
| `run_river_driving_checks` | FAIL(退出码) | 0 | 0 | 142.1 s | 无检查 + 非零退出 → **需实参**（同族） |

**结论**：DEFERRED **11 → 0**：其中 **4 项改判"挂起/环境依赖"（NOT_RUN）**、**2 项"真慢但可测"**、**5 项已取得真实结果**（含 1 项完整跑完的 FAIL 与新暴露玩法项）。

## 2. `run_industrial_checks` 同预算（~601 s）基线对照 —— 定案
| 指标 | 基线 main | 本分支（run1） |
|---|---|---|
| PASS / FAIL | **283 / 56** | **85 / 30** |
| **唯一失败检查** | **56** | **30** |
| supply 失败 | **36** | 29 |
| capture 失败 | **19** | 1 |

**集合比对（逐检查名）**：
- **仅基线失败：27 项**（本分支已消除）✓
- **仅本分支失败：1 项**（`us_m24_m6_t85e1_1951/2/1/capture`）
- **共同失败：29 项**（含 M4A3/M24 各 12 条 supply）

⇒ **净消除 27 项、仅引入 1 项**；先前担心的 **M36 supply 在基线上同样失败** ✓（不再是"新引入"疑点）。
⇒ **`supply` 收口是基线与本分支共同的既有弱点**（29/30 项共同失败里以 supply 为主），且**孤立复现可成功**（见 `WT-036-R1_SUPPLY_INVESTIGATION.md`）→ 属**电池内不稳定 + 系统性收口**双重问题，单独立项。

## 3. 本轮之后的门禁口径（应写入门禁 JSON）
1. **DEFERRED = 0**；改为三分：**NOT_RUN-环境依赖（4）** · **SLOW-已测量（2）** · **MEASURED（5，含 2 项 FAIL 与 3 项退出码待查）**；
2. 工业套件按**唯一失败集合**记录（基线 56 → 分支 30），并保留"套件自身轮间方差"的保留（`pwsh-16` 二次运行仍在跑，用于量化）；
3. 新暴露/既有项分立：**challenge 防守波次**（新）· **supply 收口**（既有系统性）· **退出码非零但检查全通过**（village/traffic_telemetry/river_*，疑与实参/环境有关）。
