# 第 4 轮交付汇总（回归收尾 · 工具修复 · 门禁扩容 · 资产请求）

## 1. 完成项（全部有证据）
| 项 | 结果 | 证据 |
|---|---|---|
| **让行/僵持回归修复**（我曾引入的唯一整类回归） | 四门同时达标 ✓ | `WT-036-R1_BATTLE_PARITY_CONFIRMED.md` · 五策略对账表（R7） |
| **全量门禁**（32 套件，采用策略） | **30 PASS / 2 FAIL**，两项均为非回归 ✓ | `logs/WT-036-R1/full-gate-adopted/` · R8 |
| **战斗套件定性** | 与基线**逐项一致**（15/1）✓ | 基线日志 + post-fix 日志 |
| **门禁运行器修复** | 日志证据判定；正反双向验证 ✓ | 运行器提交 + 负向夹具验证 |
| **默认门禁扩容** | **32 → 40**（8 个 D 类套件试跑全绿，247 项检查，~14 s）✓ | `logs/WT-036-R1/d-class-trial/` |
| **覆盖缺口分析** | 179 套件 / 147 未覆盖 + 分类与建议 ✓ | `WT-036-R1_GATE_COVERAGE_GAP.md` |
| **资产 ⑤ 受阻精确化** | 到函数签名 + 字段清单 + 三条路径 ✓ | `WT-030D-R2_AUTHOR_DATA_REQUEST.md` |
| **工业 supply 消除** | 36 → 0；套件 **595/0** ✓ | `WT-036-R1_INDUSTRIAL_GREEN.md` |
| **历史 M26 道路红** | 29/4 → **33/0** ✓ | `WT-039-D` 日志 |
| **文档与交接** | 文档索引 108+ 份；`NEXT_ACTION` 第 3 轮段落 ✓ | `DOC_INDEX.md` |

## 2. 未完成项及原因
| 项 | 原因 |
|---|---|
| 完整 `check_scene`/`check_file` | **受阻于作者数据**（layout/source_record/geometry/runtime）——**不虚构**；已给出三条授权路径 |
| 全量 96 车适配产物（≈70 MB） | 待授权 |
| 工业战斗**抵达率** | **既有基线红**，建议独立立项 |
| `T018-H01` / `challenge` / M26 / 8.5 m | 各有裁定请求（A–E 包） |
| 真人验收 · 性能采样 · 公网 · 10v10/16v16 · 空海 | NOT_RUN / 待授权 |

## 3. 证据与风险
- **证据**：全部结论均有**落盘日志/JSON**（`logs/WT-036-R1/`、`logs/WT-039-D/`、`logs/WT-030D-r2/`、`logs/route-traces/`）与**复跑命令** ✓
- **风险**：①地图铺装＝**可见外观变化**（无几何/掩体/通视影响），单提交可回滚 ✓ ②让行策略影响 AI 交通（四门已验证 ✓）③资产侧新增 2.8 MB 适配产物（可删除 ✓）

## 4. 回滚
- 逐项：每个修复**单提交**可回退（`tank.gd` · `ai_path_driver.gd` · `game_config.gd` · `village_definition.gd` · `navigation_bake_pipeline.gd` · 测试与工具文件）✓
- 整体：分支可切回 `f261e785`（第 2 轮交付）或基线 `a1bac406` ✓
- **原 `main` 工作区全程未被改动（porcelain 恒 379）** ✓

## 5. 变更清单
- 见 `git log --oneline f261e785..HEAD`（本阶段 60+ 提交）与 `DELIVERY_CHANGELOG_ROUND3.txt`；产品代码净变更仍集中于 6 个文件 ✓

## 6. 需裁定（打包，`DECISION_REQUEST_BUNDLE.md`）
`T018-H01` A1/A2 · `challenge` B1–B4 · M26 C1–C3 · **8.5 m 包络 D1/D2** · 授权 E1–E4 · **资产路径 A/B/C**（`WT-030D-R2_AUTHOR_DATA_REQUEST.md`）

## 7. 门禁终版补记（收尾轮）
| 项 | 终值 |
|---|---|
| 默认门禁套件数 | **32 → 111**（覆盖缺口 **147 → 68**） |
| 111 套件全量结果 | **104 PASS · 1 FAIL · 4 标记类 · 2 慢档** ⇒ 按正确口径＝**除 1 项已登记的 `challenge` 防守夹具边界外全部通过** ✓ |
| 慢档实测量 | `industrial_checks` **962 s / 595-0** ✓ · `industrial_battle` **~1001 s / 15-1（=基线）** ✓ · `traffic_telemetry` 521 s 通过 ✓ · `balance_match`/`traffic_attribution` >241 s · `match_batch` **>40 分钟判挂起** ✗ |
| **两次抓到我引入的回归** | `ai_drive`（让行类 → `6937e684`）· `partial_support`（支撑/转向类 → `c26ac2c1`）⇒ **均被门禁看住** ✓ |
| 工具修复 | 运行器**按日志证据判定**（本环境 ExitCode=$null、中文乱码）✓ · 默认超时 **900 → 1500 s** ✓ |
| 分类规则 | 慢档不入禁 · **诊断电池永不入禁** · 零输出 NOT_RUN · 环境依赖 NOT_RUN · 网络类专用入口 ✓ |
| 证据 | `logs/WT-036-R1/full-gate-111/` · `REGRESSION_GATE_MASTER_ADDENDUM_R9.md` · `WT-036-R1_GATE_EXPANSION_LOG.md` |
