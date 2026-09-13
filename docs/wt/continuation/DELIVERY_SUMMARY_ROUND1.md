# 首轮 10 张执行单 · 统一交付汇总（WT-023-R1 阶段四）

- **基线**：`a1bac406d2bc12b32c7f7d130590f1c1a17907c9`（用户提供的审计报告基线）
- **交付头**：`bbf68e4d`（分支 `work/continuation-20260913`，**未推送**，按权限边界保持本地）
- **规模**：**15 个提交** / 125 文件 / +6999 −19；其中**运行时代码 18 文件 / +599 −14**，其余为新增测试入口（14）、文档（31）、证据日志（55）
- **口径声明**：本汇总只写**有可观测证据**的结论；凡未跑、不可跑、需真人或需窗口者一律标 `NOT_RUN`，不折算为通过。

---

## 一、十单完成情况

| # | 执行单 | 提交 | 交付物 | 验证结果 |
|---|---|---|---|---|
| 1 | **WT-001-R1** 保全与隔离 | `0a330f98` `208648ae` | 快照根（tree 46008 文件/4.02 GB、bundle 1300.8 MB 已 verify）、`WORKSPACE_SNAPSHOT.json`、`dirty_file_ownership.json`、`WORKSPACE_RESTORE_CHECK.md`、`restore_check.txt/json` | **PASS**：6/6 已跟踪修改与 38615/38615 未跟踪项**全量哈希一致**（absent 0 / diff 0）；源目录 porclain 379 前后不变 |
| 2 | **WT-001-R2** 台账/身份/入口 | `81d848b9` `1e098ca1` `c5f53c31` | `LEDGER_DELTA.md`、`EXECUTION_PLAN_ADDENDUM.json`、`BUILD_IDENTITY.md`、`ARCHITECTURE_RESPONSIBILITY_INDEX.md`、`TEST_ENTRY_LIST.md`；WT-032 由 planned 更正 in_progress（**completed 仍为 0**） | **8/8**（headless 身份一致）+ **6/6**（真实窗口菜单显示开发候选身份，运行时 UI 树断言）；截图已存证（本模型无图像输入 → 目视 `NOT_RUN`） |
| 3 | **WT-031-R1** 113 分级 + 门禁 | `19cad9cc` `fdfd0da2` | `vehicle_readiness.gd`（五维台账）、`VEHICLE_READINESS.json`、`VEHICLE_EVIDENCE.json`、`PILOT_SELECTION.md`、`PILOT_CANDIDATE_REPORT.md`；门禁接入 `lineup.gd` 与 AI/重生槽位 | **76/76**（台账语义 + 分级 + 门禁拒绝 + 回退）；`run_garage_checks` 151/151；`run_match_batch_checks` 5/5（**门禁回退触发 0 次**） |
| 4 | **WT-002-R1** 权威状态/坐标/快照 | `f2fc6b9d` | `WT-002-R1_AUTHORITY_TABLE.md`（13 项权威状态）；修复基线陈旧测试 | **19/19**（同 tick 姿态、无陈旧缓存、脱离-重置 ×10 无残留、身份陈旧命令）；`run_drive_checks` 由基线 **25 项 1 失败 → 26/26** |
| 5 | **WT-032-R1** 河谷道路/补给/部署 | `58db3640` | `MAP_ROADGRAPH_VERSION.md`、`REACHABILITY_MATRIX.md`；河谷新增补给点并入图；残骸计入出生占用 | **34/34**（156 出生→占点 + 52 出生→补给全可达、中央通路关闭仍有侧翼 10/16 条、残骸占用换槽或 `spawn_blocked`）；既有河谷 22/45/34 全绿 |
| 6 | **WT-007-R1** 河谷观察/火控 | `14d6dce4` | `ENGAGEMENT_CONFIG.md`（观瞄/机构/交战差异 + 按键 + 中文原因）、`WT-007-R1_DESIGN.md` | **36/36**（三距离瞄准收敛 0.53/0.39/0.35°、开火门与单发消耗、**炮口在掩体内禁火**、切镜不污染装填、炮塔受损无法建立新瞄准）；既有火控/观瞄 57/24/34/3/35 全绿 |
| 7 | **WT-012-R1** 毁伤/装填实战链 | `d1f7f7a9` | `SHELL_ARMOR_MATRIX.md`、`PILOT_COMBAT_CHAIN.md`、`export_engagement_record.gd` + 事件 JSON | **18 套件 / 1217 项 / 0 失败**（全量重跑）；4 项 P1 阻断条件逐条对证未发现；事件 JSON 经生产编解码**往返无损** |
| 8 | **WT-020-R1** AI 分工/战术/让行 | `b6267dbd` | `ai_role_allocator.gd`（决策层）、`AI_TASK_TABLE.md`；控制器惰性接线 | **39/39**（分配覆盖 A/B/C + 1 侧翼、迟滞 12 s、紧急越权、决策留痕、**有界让行**、隐藏目标 500 tick 不跟真值）＋回归 40/34/35 |
| 9 | **WT-022-R1** 规则/票池/结算 | `499a6a1f` | `match_rule_preset.gd`（冻结 `team_standard_300@v1`）、`MATCH_RULES.md` | **43/43**（漂移守卫、占领/争夺/夺回、重复阵亡只扣一次、同 tick 双零=平局、奖励收据拒绝、新局干净）；回归 35/35 + 事件套件 PASS |
| 10 | **WT-023-R1** 独立可玩候选 | `1e7b3b1e` `bbf68e4d` | **真实导出** `PixelArmor.exe`(109,137,920 B) + `PixelArmor.pck`(65,608,880 B) + `CANDIDATE_MANIFEST_WT023_R1.json`（全 64 位哈希）+ `DELIVERY_WT023_R1.md` | 独立启动 headless **EXIT=0**、真实窗口 **EXIT=0**、隔离日志无错误、**真实档案 781→781 未污染** |

---

## 二、未完成项及原因（如实）

| 项 | 状态 | 原因 |
|---|---|---|
| 河谷枢纽作为 **8 槽正式战斗地图** 的端到端交互一局（进河谷→对战→恢复→死亡再出击→结算→下一局） | `NOT_RUN` | 该场景当前提供三点占点/驾驶/勘察演练；4v4 正式战斗在丘陵村落/工业边缘。做成交互脚本需窗口输入自动化，超出本单范围 |
| 河谷 **测距→装定→远距命中** | `NOT_RUN` | 该图 actor 由 `VehicleSimulationDriver` 托管命令邮箱；headless 保持炮镜需真实输入（三次探针被看门狗终止，已记录）。由窗口套件与实验室套件承担 |
| **窗口系套件**（`run_optics_player_checks`、`run_garage_demo`、`run_river_route_ui_checks`、`run_*_player_checks` 等） | `NOT_RUN` | 需真实鼠标/窗口；本批次一律未跑，**未以 headless 冒充** |
| `run_balance_match_checks`、`run_app_match_cycle` | `NOT_RUN` | 本机 headless 分别 600 s 超时 / 挂起（300 s 看门狗终止） |
| 现代两车（T-80B/豹 2A4）**整车命中—能力—恢复链** | `NOT_RUN` | 仍 `candidate_only`、`combat_definition` 为空、7 条作者缺口未闭合（`PILOT_CANDIDATE_REPORT.md`） |
| 10v10 / 16v16 **容量与整局验收** | `NOT_RUN` | 按范围界限不做容量压力采样；仅完成泊位/路线/占点定义与可达性 |
| **正式联网**（WT-024—026/037）、空海扩展（EXT-01—04） | `NOT_RUN` | 未实现，属后续批次 |
| **性能专项** | `HOLD_BY_USER` | 全程**未采集任何 FPS/p95/p99**；未优化 LOD/纹理/物理 |
| **真人验收** | `NOT_RUN` | 代理不代签；`DELIVERY_WT023_R1.md` 附空白验收表 |
| 全量 62 套回归在本分支重跑 | `NOT_RUN` | 本批次按单跑分块证据（毁伤 18 套 1217 项、AI 109 项、规则 43 项等）；整树全量回归未做 |

---

## 三、证据索引（可复现）

| 主题 | 主要证据路径 |
|---|---|
| 保全与恢复 | `E:/AIprogram/mcthunder-archive/continuation-preserve-20260913/`（tree/manifest/restore_check + preserve.ps1/verify.ps1） |
| 台账与身份 | `docs/wt/continuation/{LEDGER_DELTA.md,EXECUTION_PLAN_ADDENDUM.json,BUILD_IDENTITY.md,BASELINE.json(已更新 current_candidate)}`；`logs/WT-001-r2/identity-verification.log`；`docs/evidence/WT-001-r2/menu_identity.png` |
| 车型与门禁 | `docs/wt/continuation/{VEHICLE_READINESS.json,VEHICLE_EVIDENCE.json,PILOT_SELECTION.md,PILOT_CANDIDATE_REPORT.md}`；`logs/WT-031-r1/` |
| 权威与快照 | `docs/wt/continuation/WT-002-R1_AUTHORITY_TABLE.md`；`logs/WT-002-r1/` |
| 河谷道路/补给 | `docs/wt/continuation/{MAP_ROADGRAPH_VERSION.md,REACHABILITY_MATRIX.md}`；`logs/WT-032-r1/` |
| 观察与火控 | `docs/wt/continuation/ENGAGEMENT_CONFIG.md`；`logs/WT-007-r1/` |
| 毁伤与装填 | `docs/wt/continuation/{SHELL_ARMOR_MATRIX.md,PILOT_COMBAT_CHAIN.md}`；`logs/WT-012-r1/`（含 `engagement_record.json`） |
| AI 战术 | `docs/wt/continuation/AI_TASK_TABLE.md`；`logs/WT-020-r1/` |
| 规则与结算 | `docs/wt/continuation/MATCH_RULES.md`；`logs/WT-022-r1/` |
| 候选交付 | `E:/AIprogram/mcthunder-candidates/WT023R1/499a6a1f.../`；`docs/wt/continuation/{DELIVERY_WT023_R1.md,CANDIDATE_MANIFEST_WT023_R1.json}`；`logs/WT-023-r1/` |

---

## 四、已知风险

### A. 审计报告 12 项的处置

| 审计风险 | 本轮处置 |
|---|---|
| ① 主线未推送（243 领先、无 upstream） | **未推送**（权限边界）；隔离分支 `work/continuation-20260913` 承载全部工作，原 `main` 一字节未动（porcelain 始终 379） |
| ② 无 CI | 落地 `TEST_ENTRY_LIST.md`（本地门禁接口 + 判读规则）；云 CI 未接入 |
| ③ 379 项未提交改动 | **全部保全**（38615 未跟踪项全量哈希 + 6 修改项）；M1A1 脏资产按 02/06 要求保持隔离不并入 |
| ④ 台账滞后 20 提交 | **已追平**（`LEDGER_DELTA.md` + addendum；WT-032 更正 in_progress；**completed 仍 0**） |
| ⑤ 交付路径失效 | `BUILD_IDENTITY.md` §3 建立"旧路径 → 归档实际位置"映射；未改 `export_presets.cfg` |
| ⑥ `ARCHITECTURE.md` 为 004 版 | 新增 `ARCHITECTURE_RESPONSIBILITY_INDEX.md`（22 模块 + 入口 + 不变量）；旧文档保留 |
| ⑦ 版本号停在 rc.2 | 更新为 `1.0.0-rc.3-dev` + `continuation-20260913` + `RELEASE_READY=false`，并在菜单实时可见（窗口验证 6/6） |
| ⑧ 性能未达标 | 维持 `HOLD_BY_USER`；**零采样** |
| ⑨ 未跟踪杂物 | 仅登记与哈希保全；**未删除任何临时目录**（含 `.tmp-edge*`） |
| ⑩ `.git` 2.7 GB | 未做历史瘦身（不在范围）；bundle 1300.8 MB 作可校验备份 |
| ⑪ 24 个停滞分支 | 未清理 |
| ⑫ 未合并 3 分支 | 未合并（027 冻结 WIP 未触碰） |

### B. 本轮新发现的风险

| # | 风险 | 证据 |
|---|---|---|
| 1 | **基线自带红灯**：`run_drive_checks` 在 `a1bac406` 失败 1 项（陈旧蒙皮查找，`9f59025f` 后测试未跟进） | `f2fc6b9d` 修复并加严守卫；基线对照两次复现 |
| 2 | **口径冲突（未改参数）**：河谷独立进入默认 200 m 射线预算的遗留车，历史车为 2500 m | `ENGAGEMENT_CONFIG.md` §3 |
| 3 | **`assets/research/models` 113/113 无 `.import`** | 走场景 `load()` 的现代车路径会失败；机构适配器按字节读取不受影响 |
| 4 | **现代两车 7 条作者缺口** | `PILOT_CANDIDATE_REPORT.md`（含 `active_geometry`、`fire_control`、`ballistics_and_materials` 等） |
| 5 | **headless 无法保住炮镜**（该图驱动托管邮箱） | `WT-007-R1_DESIGN.md` §5；三次探针被看门狗终止 |
| 6 | 长时平衡/应用循环套件在本机 headless 不可用 | `run_balance_match_checks` 600 s 超时、`run_app_match_cycle` 挂起 |
| 7 | 本机工具链陷阱（PowerShell 别名冲突导致空文件、中文模式 `Select-String` 不可靠、`ConvertFrom-Json` 对空输入不报错） | 已在 `bbf68e4d` 透明记录并修正 |

---

## 五、回滚方式

| 层级 | 回滚方式 |
|---|---|
| 单个执行单 | `git revert <提交>`（运行时代码改动集中在 18 个文件 / +599 行，均为**追加式**，默认惰性） |
| 整个首轮 | 切回 `a1bac406` 即可；原工作区**从未被修改**（porcelain 379 恒定），隔离分支可整体保留或删除 |
| 保全快照 | 删除 `continuation-preserve-20260913` 目录 + `git worktree remove E:/AIprogram/mcthunder-cont` + `git branch -D work/continuation-20260913` |
| 候选包 | 删除 `E:/AIprogram/mcthunder-candidates/WT023R1/<sha>/`（仓库外，无副作用） |

---

## 六、变更清单（15 个提交）

```
bbf68e4d WT-023-R1 fix: manifest 空文件修正（别名冲突）+ 全 64 位哈希复核
1e7b3b1e WT-023-R1: 真实导出候选 + 交付报告 + SOURCE/BUILD/CONTENT/RULES 清单
499a6a1f WT-022-R1: 冻结 MatchRulePreset + 占点/票池/结算/奖励契约验证
b6267dbd WT-020-R1: AI 角色/任务分配 + 迟滞 + 决策留痕 + 有界让行
d1f7f7a9 WT-012-R1: 毁伤/装填 18 套件 1217 项 + 矩阵 + 链报告 + 事件 JSON
14d6dce4 WT-007-R1: 河谷交战 36/36 + 交战配置/按键/原因登记
58db3640 WT-032-R1: 河谷补给入图 + 残骸占用选槽 + 可达矩阵 + 版本兼容表
f2fc6b9d WT-002-R1: 权威状态表 + 基线红灯修复 + 新回归
fdfd0da2 WT-031-R1: 登记真实整局/车库证据 + 区分 passed_vehicle/passed_set
19cad9cc WT-031-R1: 五维车型台账 + 113 分级 + 门禁统一 + 两辆样车冻结
c5f53c31 WT-001-R2: 设计页 + 验证记录（含目视 NOT_RUN 声明）
1e098ca1 WT-001-R2: 身份验证入口（headless 8/8 + 真实窗口 6/6）+ 截图
81d848b9 WT-001-R2: 台账增量 + 构建身份 + 交付路径索引 + 架构/测试入口
208648ae WT-001-R1: 快照 + 归属 + 恢复校验（全量 SHA-256 PASS）
0a330f98 WT-001-R1: 设计页
```

**运行时代码改动全表**（18 文件）：`vehicle_readiness.gd`(新) · `build_identity.gd`(新) · `match_rule_preset.gd`(新) · `ai_role_allocator.gd`(新) · `lineup.gd` · `team_range.gd` · `team_match_state.gd` · `ai_tank_controller.gd` · `wreck_registry.gd` · `river_junction_definition.gd` · `river_junction_navigation.gd` · `river_junction_range.gd` · `garage_shell.gd` · `garage_frontend.gd` · `project.godot` · 以及 3 个 `.uid`

---

## 七、下一步建议

1. **推送决策需用户授权**（当前全部分支仅本地；`main` 领先远端 243 提交的状态未变）。
2. **下一批**建议按依赖顺序继续：WT-016/023 的关键真人门 → WT-017/018（观察权限/支援）→ WT-019/021（地图与交通收口）→ WT-024—026/037（正式联网）→ WT-027—029（现代能力，需先补两车 7 条缺口）→ WT-030D/031B—D（工具与车池量产）→ WT-034—038（产品化与发布门）。
3. **补齐本批缺口**：河谷 8 槽正式战斗整局（或明确河谷的定位为"演练图"）、窗口炮镜链、`assets/research/models` 的导入可见性、现代两车配置缺口。
4. **台账**：把本轮 R 单结果并入 `EXECUTION_PLAN_ADDENDUM`（本批已建 `EXECUTION_PLAN_ADDENDUM_ROUND1.json` 作初版），并按裁决继续"completed 由证据决定"。
