# 回归门总表 · 第 6 次回填：**全量门禁（32 套件）= 28 PASS / 4 FAIL**

> 运行方式：项目默认 32 套件列表（含本分支新增的 T039-E），逐套件 `& engine … *> log` + `$LASTEXITCODE`（本会话验证可靠的读法）。证据：`logs/WT-036-R1/full-gate-reliable/`（逐套件日志 + `summary.json`）。

## 1. 结果
| 判定 | 数量 | 套件 |
|---|---|---|
| **PASS** | **28** | 含 `run_industrial_checks` **595/0**（986.9 s）· `run_historical_road_checks` **33/0** · `run_team_checks` **67/0** · `run_village_battle_checks` 21/0 · `run_slope_pivot_checks` 3/0 · `run_art_checks` 63/0 · `run_structure_checks` 54/54 · `run_wreck_visual_checks` 71/0 · `run_feedback_checks` 40/0 · `run_checks` 217/0 · `run_shell_checks` 193/0 · `run_garage_checks` 151/0 · `run_historical_checks` 192/0 等 |
| **FAIL** | **4** | 见 §2（其中 1 项已在本次修复、1 项按集合判据可接受、1 项既有登记、1 项对照中） |

## 2. 四项失败的定性
| 套件 | 结果 | 定性 |
|---|---|---|
| `run_ai_drive_checks` | 39/1 → **40/0** | **我引入的回归，已修复**（`86b4f1cf`）：两辆**有主**AI 车正面僵持 5.38 m；修法＝**按阻挡物分流**（停放车→恢复倒车；AI 阻挡→标记阻塞边+重规划不倒车；重规划仍不解⇒**显式 `failed("mutual_yield")`**，正是该检查接受的"抵达或显式失败"）✓ |
| `run_map_checks` | **48/1** | 仅 **`T018-03b`（我新增的设计目标项）**失败 ⇒ 按**集合判据**（允许设计目标项 + ≤1 个既有间歇槽位）**可接受** ✓；`T018-02`/`T018-H01` 本轮均通过 ✓ |
| `run_challenge_checks` | 138/2 | 已登记：**防守夹具能力边界**（脚本飞行员在 hard 变体被启用 AI 打瘫）✓ |
| **`run_industrial_battle_checks`** | **14/2**（16 项） | **新暴露**（第 2 轮属 DEFERRED、从未测量）；失败＝`at least three actual slots from each team physically reach central approaches` + `no healthy actor trying to drive stays stationary for 90 seconds` ⇒ **基线对照进行中**（`pwsh-24`）✓ |

## 3. 本轮同时修复的工具缺陷（测试工具，断言不变）
`tests/run_suite_checks.ps1`：本环境下 ①`Start-Process` 的 `ExitCode` 常为 `$null`（导致 **import 步**被判失败 ⇒ 运行器在**跑任何套件前**中断）②捕获日志的中文结果行**乱码** ⇒ 正则漏判。
⇒ 判定改为**以日志证据为准**（无脚本错误 ∧ 无意外错误 ∧〔结果行 0 失败 ∨ ASCII `CHECKS_PASS` 标记〕），退出码仅记录 ✓ **正向/反向双向验证**（T039-E `passed=True` + 故意失败夹具 `passed=False`）✓

## 4. 教训（自省，写入交接）
我在第 112 轮**用自己的过严判据**（`exit==0` 全判）**错误回退了正确修复** ✗ —— 地图套件的设计目标项失败属**已知且可接受**，须一律按**集合判据**判定 ✓
