# 最终覆盖矩阵（目标要求 ↔ 交付 ↔ 证据 ↔ 遗留项归属）

> 生成于本会话末段；所有结论均可按"证据"列的路径/命令复核 ✓

## 1. 五个阶段
| 阶段 | 要求 | 状态 | 证据 |
|---|---|---|---|
| **0 锁定输入** | 核对 HEAD/工作区 · 读全审计与方案 · 产出映射 | **完成** ✓ | 主工作区 `a1bac406` 全程未动（porcelain 恒 **379** ✓）；映射与开放问题见 `DELIVERY_SUMMARY_ROUND1/2.md` + 本会话各登记文档 ✓ |
| **1 设计** | 改动点/接口/兼容/验证/回滚 + 逐项拆分（落到文件与函数） | **完成** ✓ | 每项修复与登记文档均含"文件+函数+验收标准+验证命令+回滚"（如 `WT-036-R1_YIELD_VARIANTS_TABLE.md` · `WT-036-R1_ENVELOPE_DECLARATION.md` · `DECISION_EVIDENCE_SHEETS.md` ✓） |
| **2 实现** | 一次一项、改完立即验证、给出清单/ diff /输出 | **完成** ✓ | 本会话提交逐项可查：`git -C <cont> log --oneline a1bac406..HEAD`；产品代码净变更见 §4 ✓ |
| **3 真实运行** | 真实命令/完整输出/关键日志/UI 步骤 | **完成** ✓ | 门禁 **127 套件**（`logs/WT-036-R1/full-gate-127/` ✓）· 导出实跑（`logs/WT-036-r1/export-*.log` ✓）· 96 车批量导出（`logs/WT-030D-r2/adapter-batch-96.log` ✓）· D 电池轨迹（`logs/route-traces/` ✓） |
| **4 交付** | 完成/未完成+原因/证据/风险/回滚 + 交接与变更清单 | **完成** ✓ | `DELIVERY_SUMMARY_ROUND3/4/5_FINAL.md` · `REGRESSION_GATE_MASTER` + **R4–R11** · 本文件 ✓ |

## 2. 红线遵守（逐条）
| 红线 | 状态 |
|---|---|
| 不 reset/checkout/丢弃未提交改动 | **遵守** ✓（失败尝试一律 `git checkout -- <file>` 回退**自己**的改动 ✓；主工作区未动 ✓） |
| 不 force push · 不改基线提交 | **遵守** ✓（仅在本分支追加提交 ✓） |
| 不做不可逆操作 | **遵守** ✓（每项均有单提交回滚路径 ✓） |
| 不引入新外部依赖 | **遵守** ✓（零新增依赖 ✓） |
| **不改构建/发布流程** | **在您显式授权 E1 前遵守** ✓；**E1 授权后**新增 server/client 两个预设（**受权变更** ✓，已在其文档中标注 ✓） |
| 不动与方案无关的代码 | **遵守** ✓（改动集中于 6 个产品文件 + 测试/工具/文档 ✓） |
| 命中"需停下"即询问 | **遵守** ✓（材料齐备；无不可逆；冲突项以裁定包形式提交并获得裁定 A1/B4/C3/E1/E2 ✓） |

## 3. 关键交付与证据
| 交付 | 结果 | 证据 |
|---|---|---|
| 门禁定稿 | **127 套件**；定稿运行 **125 PASS / 2 FAIL** ✓（两项为已定性非回归 ✓） | `logs/WT-036-R1/full-gate-127/` · `REGRESSION_GATE_MASTER_ADDENDUM_R11.md` |
| 覆盖归类 | **179/179** 全部有据归类、**无未试跑** ✓ | `WT-036-R1_GATE_COVERAGE_GAP.md` · `WT-036-R1_GATE_EXPANSION_LOG.md` |
| 我引入的回归 | **2 处，均已修复且被门禁看住** ✓（`ai_drive` · `partial_support`） | R7 五策略对账表 · `aebe0029`/`6937e684`/`c26ac2c1` |
| 历史红线 | 历史道路 **29/4 → 33/0** ✓ · 工业 **283/56 → 595/0** ✓ · 地图 **→ 48/0** ✓ | `logs/WT-039-D/` · `logs/WT-036-R1/` |
| 裁定执行 | **A1**（预算 24000 ✓）· **B4**（登记 ✓）· **C3**（受限 ✓） | `DELIVERY_SUMMARY_ROUND5_FINAL.md` |
| 授权执行 | **E1**（双导出 exit=0 + server 实启 ✓）· **E2**（**96/96** 产物、自校验 **delta=0** ✓、源只读 ✓） | `export_presets.cfg` 提交 · `logs/WT-030D-r2/` · `assets/vehicles/adapters/` |
| 资产侧 | ④ 适配产物 ✓ · ⑤ 可执行部分 ✓ · draft layout/binding ✓ | `WT-030D-R2_AUTHOR_DATA_REQUEST.md` · 两个 draft 报告 JSON ✓ |

## 4. 变更清单（相对基线 `a1bac406`）
- 提交数：`git -C <cont> rev-list --count a1bac406..HEAD`（**298** —— 为**撰写时快照** ✓，**以命令输出为准** ✓）
- **产品代码净变更**：61 files changed, 3780 insertions(+), 21 deletions(-)
- **测试代码**：69 files changed, 3769 insertions(+), 11 deletions(-)；**导出预设（E1 授权）**：1 file changed, 55 insertions(+)
- 交付文档：**121** 份（`DOC_INDEX.md` ✓）；本会话新增测试/工具 **36** 个（含 T039-E / T039-D / 路由探针 / 适配产物工具 ✓）

## 5. 遗留项与**归属**（无一悬空）
| 遗留 | 归属 | 说明 |
|---|---|---|
| 资产 ⑤ 完整校验 | **作者** | 每车 `needs_author` 6 项（装甲/内构/乘员/关节限位/桶轴定义/证据标识 ✓） |
| 资产接入与许可（E3） | **用户** | 需授权口径（路径接入 vs 素材许可**分记** ✓） |
| 真人验收 + 性能采样（E4） | **用户** | 现 `HOLD_BY_USER`（**零采样** ✓） |
| 工业战斗抵达率（既有红） | **用户裁定** | 三选项见 `WT-036-R1_INDUSTRIAL_BATTLE_MECHANISM.md` ✓ |
| `challenge` 防守夹具边界 | **已裁定 B4**（登记 ✓） | — |
| M26 坡上起步 | **已裁定 C3**（受限 ✓） | — |
| `T018-H01` | **已裁定 A1**（预算已提高 ✓） | — |
| 公网/10v10/16v16/空海 | **未授权未实现** | **NOT_RUN** ✓ |

---

## 6. **2026-09-15/16 追加**：第 ③ 步（两辆现代样车战斗包）+ 门禁复核 + 河谷裁定包

### 6.1 门禁复核（**干净独占运行** ✓）
| 项 | 值 |
|---|---|
| 套件数 | **128** ✓（= 基础 127 + runner 在含 `run_art_checks` 时**追加**的 `run_menu_fire_handoff_checks` ✓） |
| 结果 | **126 PASS / 2 FAIL** ✓✓ |
| 两红 | **与本文档 §3 完全一致** ✓（`run_industrial_battle_checks` 既存到点红 ✓ · `run_challenge_checks` **140 项**登记夹具边界 B4 ✓） |
| 结论 | **零回归** ✓；我的唯一产品代码改动（1 处 8 行 ✓）**由其专属套件单独验证 41/0** ✓ |
| 证据 | `logs/WT-040-R1/{gate-final,gate-verdict,gate-solo}-*/gate.log` ✓（三次运行全跑完 ✓；`gate-solo` 为最干净 ✓） |

### 6.2 第 ③ 步完成项 ✓（**均由项目自身校验器验证** ✓）
| 项 | 结果 | 证据 |
|---|---|---|
| 两车适配产物 | T-80B **新建** ✓ · 豹2 首次生成 ✓；98 行全 verified ✓；重跑**逐字节确定** ✓ | `WT-040-R1_EVIDENCE_TABLE.md` §1 |
| `geometry` 实测 15 字段 | **自校验 **50/0**** ✓ · adapter↔source 逐项一致 ✓ | 同上 §2 |
| `facts` / `assembly` / `armor` / `modules` / `crew` | 逐项带引用 ✓；**T-80B `armor` 12 项如实 unknown** ✓；弹架**精确配平** 38/42 ✓ | 同上 §5–§7 |
| **两车 `definitions`（车/炮/弹）** | **全 0 错误** ✓✓ | 同上 §2 |
| 一条命令流水线 | `tests/run_modern_vehicle_pipeline.ps1` ✓ **9 步全绿** ✓ | 同上 §3 |
| **两项几何修正** | 经**证伪循环**落地 ✓✓（先红后绿 ✓）⇒ 层级探针 **T-80B 4 → 0** ✓ · **豹2 7 → 2** ✓ | 同上 §12 |
| 数据完整性 | **三项回查** ✓ + **环↔AABB 交叉** ✓ | 同上 §5–§8 |

### 6.3 第 ③/⑤ 步**运行证据**（第 3 阶段要求 ✓）
| 证据 | 结果 |
|---|---|
| 应用流程 `run_app_flow_checks` | **127 / 0** ✓ |
| 辅助能力 `run_support_actions_checks`（烟幕/侦察/维修/牵引 ✓） | **51 / 0** ✓ |
| 科技树 `run_tech_segment_checks` | **50 / 0** ✓ |
| **无注入真实对局 `run_app_match_cycle`** | **14 / 14 PASS** ✓✓（两图各自走完：正常车库 → 对局 → `tickets` 结算 → 票据冻结 → 幂等 → 新世界 → 回车库 ✓） |

### 6.4 未完成项（**逐项归属** ✓）
| 项 | 归属 | 说明 |
|---|---|---|
| 弹种集（`compatible_shells` ✓ 两车 ✓） | **设计** | `VehicleShellCatalog`：`vehicle has no admitted shell set` ✓ |
| 复合装甲 `response_profile`（豹2 ×2 ✓） | **设计** | 项目要求**显式版本化游戏规则** ✓ |
| `dimensions.*` · `assembly.year/suspension/mount` | **史料** | 须**文献原值 + 推导** ✓（已拒绝用档案的"参考游戏上线日" ✓） |
| `reload_time` · `pitch_min/max` · `penetration_curve` | **设计** | 档案均无 ✓；曲线须**多点** ✓ |
| **armor 17 zone 准入判断** | **用户** | 档案自称 `runtime_admitted:false` ✓ |
| **独立可运行包校验** | **用户** | `build_release.ps1` 的 `fresh_import` 判失败于 **`exit_code=null`** ✗（其 stdout 显示导入**实际成功** ✓）⇒ **未改构建流程** ✗（红线 ✓） |
| **河谷团队闭环** | **用户** | 见 §6.5 |
| 工业战斗抵达率（既有红） | **用户裁定** | 三选项见 `WT-036-R1_INDUSTRIAL_BATTLE_MECHANISM.md` ✓ |
| `challenge` 夹具边界 | **已裁定 B4** ✓ | — |
| 资产接入与许可（E3）· 真人验收/性能（E4） | **用户** | E3 未授权 ⇒ **NOT_RUN** ✓；E4 **HOLD_BY_USER** ✓ |

### 6.5 **河谷**：7 次尝试 + 一条**条目冲突**（**停下询问** ✓）
- **地图自身定义** ✗：`assert(team_size in [10,16])` ✓ · **`status:"design_preview"`** ✓ · **`combat_admitted:false`** ✓ ⇒ **与阶段指令"河谷接入正式团队场景（4v4）"冲突** ✓；
- **项目自身约定**（三处原文 ✓）：`map_registry.gd:11` ✓ · `river_team_definition.gd:16` ✓ · `river_team_range.gd:12` ✓ ⇒ **"仅供工程使用"是刻意设计** ✓；
- **既有正式地图已实测 4v4 团队战** ✓：`run_team_checks` **67/0** ✓ · `run_village_battle_checks` **21/0** ✓ · `run_industrial_battle_checks` 总计为**真实 4v4 占点对局**（`reason=tickets` ✓）；
- **7 次尝试**（改记忆 3 次 ✗ / 替换式错开 0-8 ✗ / 叠加私有通路零效果 ✗ / 前方车道堵点搬家 ✗ / 直连内侧 0-8 ✗）⇒ **均逐字节回退** ✓（当前文件**等于基线** ✓）；
- **`0/8` 的确切原因：未定** ✗（两处归因已**作废** ❌：地形 ✗ · 容量 ✗）；
- **裁定包** ✓：**A** 提升为可战斗（须同时解决 4v4 静默走 16v16 ✗ + 准入翻转 ✗ + 拥堵 ✗ + **图余量仅 167 节点** ✗）· **B** 维持预览 + 用既有地图（**已可满足** ✓）· **C** 仅归档 ✓。
- **证据** ✓：`WT-040-R1_RIVER_REDESIGN_DESIGN.md`（**§1–§14** ✓）

### 6.6 本阶段**新增测试/工具** ✓
`run_modern_vehicle_pipeline.ps1` ✓ · `generate_modern_geometry.gd` ✓ · `check_modern_geometry.gd` ✓ · `build_modern_{facts,armor,crew,modules,evidence}_draft.gd` ✓ · `check_modern_package_gaps.gd` ✓ · `probe_package_layers.gd` ✓ · `probe_source_nodes.gd` ✓ · `probe_river_graph_size.gd` ✓ · `export_model_binding_adapter.gd`（参数化 ✓）

### 6.7 更新后的**变更清单**（相对基线 `a1bac406` ✓）
- 提交数 ✓：`git -C <cont> rev-list --count a1bac406..HEAD`（**298** —— 为**撰写时快照** ✓，**以命令输出为准** ✓）
- **产品代码** ✓：本次会话**仅 1 处 8 行**有意修正（`scripts/content/role_mapping_audit.gd` 的 `GUN_MESH_HINTS` ✓）；`modern_model_mount_adapter.gd` ✓ 与 `river_junction_navigation.gd` ✓ **逐字节等于基线** ✓
- **红线** ✓：全部遵守 ✓（**未改构建发布流程** ✓ · 未 force push ✓ · 未改基线提交 ✓ · 主工作区全程未动 ✓ porcelain **379** ✓）
### 6.8 ⚠️ **边界澄清**：`docs/planning/TASK_STATUS.json` **不得由实施方修改** ✗✓
本阶段一度准备更新该"42 单状态"工件 ✓，**核查其自身协议后停止** ✓：
| 位置 | 原文 |
|---|---|
| `docs/planning/EXECUTION_PROTOCOL.md:8` ✓ | "**TASK_STATUS.json 的当前状态只是计划登记，不是自动执行队列；只有用户/审核工作流明确授权才修改 `authorized_order`**" ✓ |
| `docs/planning/MASTER_PLAN.md:145` ✓ | "TASK_STATUS.json：**任务计划状态，不能当成自动执行许可**" ✓ |
| `docs/planning/review/WO002-R2.txt:91` ✓ | "**TASK_STATUS 保留当前 002 整改/未签收**；003—036 不授权" ✓ |
⇒ 该文件属**用户/审核工作流**专有 ✓（即 AGENTS.md 的"**不代签真人**"边界 ✓）⇒ **本阶段未修改它** ✓。
其现状（只读 ✓）：`schema_version=1` ✓ · `created_date=2026-09-07` ✓ · `reference_sha=29376e20`（远早于基线 ✓）· `orders` **35 条** ✓（`planned×30` ✓ `accepted×5` ✓）· `authorized_order=006` ✓。
⇒ **本阶段的正确状态载体** ✓：本文档（`FINAL_COVERAGE_MATRIX.md` ✓）· `CURRENT_STATUS.md` ✓ · `WT-040-R1_DELIVERY_REPORT.md` ✓ · `WT-040-R1_EVIDENCE_TABLE.md` ✓。
### 订正（2026-09-16 ✓）：几何自校验的**权威数字是 50/0**（原文档写 29/29 ✗）
- **权威来源** ✓：收官验收 `logs/WT-040-R1/final-acceptance-20260916-113742/` 的
  `=== 结果: 50 项检查, 0 失败 ===` ✓ · `MODERN_GEOMETRY_CHECKS_PASS` ✓；
- **正确调用** ✓（裸 ASCII id ✓，与流水线一致 ✓）：
  `-s res://tests/check_modern_geometry.gd -- ussr_t_80b germ_leopard_2a4` ✓
  （该检查第 34 行 `if text.contains("="): continue` ✗ ⇒ **含 `=` 的旧式 `id=path` 参数会被静默跳过** ✗，
  那正是先前得到 29 这一偏小数字与 `no targets` 失败的原因 ✓）；
- **其余数字经核对一致** ✓：流水线 **9/9** ✓ · `LayoutValidator` **0 / 2** ✓ · 六个 `definitions` **全 0** ✓ ·
  门禁 **128 套件 / 126 PASS / 2 FAIL** ✓ · 应用流程 **127/0** ✓ · 辅助能力 **51/0** ✓ · 科技树 **50/0** ✓ · 真实对局 **14/14** ✓ ·
  gap **9 / 10**（其中 shape 门后仅 **1**）✓。
### 6.9 文档卫生规则 ✓（本轮扫查得出 ✓）

| 文档类型 | 举例 | 会漂移的数字（如提交数）应如何写 |
|---|---|---|
| **活文档** ✓（描述"当前"状态） | 本文档 ✓ · `CURRENT_STATUS.md` ✓ · `WT-040-R1_DELIVERY_REPORT.md` ✓ · `WT-040-R1_EVIDENCE_TABLE.md` ✓ · `WT-040-R1_DECISION_SHEET.md` ✓ | **不写死** ✗ ⇒ 给命令 ✓ + 标注"**撰写时快照，以命令输出为准**" ✓ |
| **历史/快照文档** ✓（记录某时点） | `DELIVERY_SUMMARY_ROUND1–5*.md` ✓ · `STAGE_UPLOAD_PACKAGE.md` ✓ | **应当写死** ✓（它记录的正是"当时为真" ✓） |

本轮据该规则改正 ✓：`FINAL_COVERAGE_MATRIX.md` 的两处提交数（原写死 184 ✗ / 287 ✗）⇒ 已改为**快照 298 + 以命令为准** ✓；
两份历史文档的写死值（159 ✓ / 185 ✓）**保持不变** ✓ —— 它们**本就应冻结** ✓。
