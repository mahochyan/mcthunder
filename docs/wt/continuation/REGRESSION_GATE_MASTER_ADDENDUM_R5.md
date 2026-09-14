# 回归门总表 · 第 5 次回填（供应链消除 + 既有红定性 + 资产侧进展）

> 承接 `REGRESSION_GATE_MASTER.md` 与 `…_ADDENDUM_R4.md`；仅记录新增/更正，均已实跑。

## 1. 工业套件：**`supply` 36 项全部消除**（用户已授权的 C 类铺装）
| 阶段 | PASS | FAIL | 总检查 |
|---|---|---|---|
| 加固前（原 339 项） | 300 | **39**（supply 36） | 339 |
| 加固后（+256 净空断言） | 558 | 37 | 595 |
| **铺装 `supply→spawn` 后** | **594** | **1** | 595 |
| 时序修复后（复验中） | — | — | 期望 **595 / 0** |

- **出生净空断言 256/256 通过** ✓（污染假设被否证，并留下永久守卫）
- 失败时**逐 tick 轨迹落盘** ✓（正是它让我们读出 supply 的机制）

## 2. 既有红 `restart frees old world and preserves selected map industrial_edge`：**定性为夹具时序，非产品缺陷**
- **等价 setup 的秒级探针**（`tests/probe_restart_release.gd`）三轮全部：`released=true` · `new_round=true` · `map_kept=true` ✓
- 机制：`restart_match()` 在 `_transitioning` 为真时**静默返回**；套件用**固定 8 帧**等异步转场 ⇒ restart 被吞 ⇒ 旧场景仍在 ⇒ 断言失败 ✓
- **测试侧修复**（断言不变）：转场后**有界等待 `_transitioning` 清零**（≤240 帧）✓
- 该检查在**基线**同样失败（4 份日志一致）⇒ 从未是"我们引入"的 ✓

## 3. 资产侧（作者素材入库路径）
| 步骤 | 状态 | 证据 |
|---|---|---|
| ① 只读入库审计（96 车） | **完成** | `logs/WT-030D-r2/german_intake_audit.json`（41,370 B） |
| ② 角色映射（含实测炮口、撤掉伪造来源） | **完成** | `logs/WT-031C-r2/german_role_mapping.json` |
| ④ 独立适配产物（3 车样例，源只读且重测哈希未变） | **完成** | `adapter_artifacts.json`（2,192 B） |
| ⑤ **可执行部分**：产物内含 `MuzzlePoint`、炮口解析为**作者节点**、六角色可解析、哈希一致 | **完成** | `adapter_verification.json`（4,388 B） |
| ⑤ 完整 `check_scene`/`check_file` | **受阻**：需仓库内 layout + packet（外部模型不具备）**未声称** | — |
| ⑥ 路径接入授权 / 许可依据分记 | **待授权** | `DECISION_REQUEST_BUNDLE.md` E3 |
| 全量 96 车适配产物（≈70 MB） | **待授权** | 同上 E2 |

## 4. 新增测试基础设施（本阶段）
`tests/route_harness.gd`（出生净空 + 逐 tick 轨迹）· `tests/run_slope_pivot_checks.gd`（T039-E）· `tests/run_flank_crest_traversal_checks.gd`（T039-D 电池）· `tests/probe_restart_release.gd`（秒级 restart 探针）· `tests/check_adapter_artifacts.gd`（适配产物自校验）· 三个资产导出工具（intake / role mapping / adapter）

## 5. 保留的产品改动（更新）
| 文件 | 内容 | 验证 |
|---|---|---|
| `tank.gd` + `game_config.gd` | 坡面自转修复 · 转向支撑下限 · `AI_YIELD_TIMEOUT_S` | T039-E 3/3 · 村庄 21/0 · 地图集合口径 |
| `ai_path_driver.gd` | 卡死窗口修复 · **让行死锁修复（仅"无主车辆"触发恢复）** | 地图 `T018-02` 通过（两轮）· 村庄 21/0 |
| `village_definition.gd` | **两处 C 类铺装**（`near→cap`、`supply→spawn`） | 历史 **33/0** · 工业 supply **36→0** |
| `navigation_bake_pipeline.gd` | 包络含地面诊断字段（不改 `ok`） | 地图集合口径 |
| `vehicle_actor.gd` | 只读可观测字段 | — |

## 6. 未结项（全部已有裁定请求或为环境依赖）
`T018-H01` 预算（A1/A2）· `challenge` 防守（B1–B4）· M26 坡上起步（C1–C3）· 8.5 m 包络（D1/D2）· 授权（E1–E4）· 工业时序修复复验（进行中）

## 7. 明确 NOT_RUN（不冒充通过）
真人验收 42/42 · 性能（`HOLD_BY_USER`，零采样）· 公网联网 · 10v10/16v16 · 空海扩展 · 完整 `check_scene`/`check_file`（待作者数据）· 全量 96 车适配（待授权）
