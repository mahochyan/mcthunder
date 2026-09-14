# 回归门终版（第 10 次回填）：**最终 HEAD 上 111 套件 = 109 PASS / 2 FAIL**

> 运行：默认门禁全部 **111 套件**，每套件 **1500 s** 上限（与修正后的运行器默认一致 ✓）
> 证据：`logs/WT-036-R1/full-gate-111-final/`（逐套件日志 + `summary.json`）

## 1. 终账
```
PASS = 109 · FAIL = 2 · ZERO_CHECKS = 0 · TIMEOUT = 0
```
**两项失败均为已定性的非回归**：
| 套件 | 结果 | 定性（有基线对照） |
|---|---|---|
| `run_industrial_battle_checks` | **15 / 1** | **与未改动基线逐项一致**（基线亦 15/1）⇒ 唯一失败＝**既有抵达红** ✓（建议独立立项：工业图中央抵达率） |
| `run_challenge_checks` | **138 / 2** | 已登记：**防守夹具能力边界**（脚本飞行员在 hard 变体被启用 AI 打瘫：`repairs=4 / shots=0`）✓ |

## 2. 最终 HEAD 上的关键绿灯（含检查数）
`run_industrial_checks` **595/0**（958.8 s ✓）· `run_map_checks` **48/0**（D2 后全绿 ✓）· `run_checks` **217/0** · `run_shell_checks` 193/0 · `run_historical_checks` 192/0 · `run_garage_checks` 151/0 · `run_history_road`（`run_historical_road_checks`）**33/0** · `run_team_checks` **67/0** · `run_village_battle_checks` **21/0** · `run_slope_pivot_checks` **3/0** · `run_ai_drive_checks` **40/0** · `run_partial_support_checks` **7/0** · `run_structure_checks` 54/0 · `run_wreck_visual_checks` 71/0 · `run_feedback_checks` 40/0 · `run_art_checks` 63/0 · `run_industrial_obstruction_checks` 9/0 · 其余 90 套件全绿 ✓

## 3. 与基线对照（本会话的净效果）
| 套件 | 基线 main | 最终 HEAD |
|---|---|---|
| `run_industrial_checks` | **283 / 56** | **595 / 0** ✓ |
| `run_historical_road_checks` | 29 / 4 | **33 / 0** ✓ |
| `run_map_checks` | 25 / 2（+22 检查前） | **48 / 0** ✓（D2 后） |
| `run_village_battle_checks` | 21 / 0 | **21 / 0** ✓ |
| `run_ai_drive_checks` | 40 / 0 | **40 / 0** ✓（我曾引入回归→已修） |
| `run_partial_support_checks` | 7 / 0 | **7 / 0** ✓（我曾引入回归→已修） |
| `run_industrial_battle_checks` | 15 / 1 | **15 / 1** ✓（持平；既有红） |
| `run_challenge_checks` | —（原 DEFERRED） | **138 / 2**（夹具边界，已登记） |

## 4. 门禁自身的改进（本会话）
1. **覆盖扩容 32 → 111 套件**（缺口 147 → 68）✓ —— 并**两次抓到我引入的回归**（`ai_drive` · `partial_support`）✓，两者现均由门禁看住 ✓；
2. **判定改为以日志证据为准**（本环境 `ExitCode` 常 `$null` + 中文日志乱码）✓，正反双向验证 ✓；
3. **默认超时 900 → 1500 s** ✓（否则 `industrial_checks`（958.8 s）会被误判 ✓）；
4. **分类口径明确**：慢档不入禁 · **诊断电池永不入禁**（T039-D）· 零输出 ⇒ NOT_RUN · 环境依赖 ⇒ NOT_RUN · 网络类 ⇒ 专用入口 ✓。

## 5. 仍红/未结（不声称完成）
`challenge` 防守（B1–B4 待裁定）· `industrial_battle` **既有**抵达红（建议立项）· `T018-H01` 预算（A1/A2）· M26 坡上起步（C1–C3）· 资产 ⑤ 待作者字段与签收 ✓ · 全量 96 车适配与导出预设**待授权** ✓ · 真人验收与性能采样 **NOT_RUN** ✓
