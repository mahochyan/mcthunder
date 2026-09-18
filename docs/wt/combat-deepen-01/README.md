# COMBAT-DEEPEN-01 设计资料入口（本分支唯一入口 ✓）

本目录是 **MCT-COMBAT-DEEPEN-01** 在本分支（`work/combat-deepen-01`）的**单一入口** ✓。
`original/` 内的 17 个文件是 **2026-09-18 补发原件的逐字节副本** ✓（未改写、未重排 ✓）；
裁定与继续说明（`RESUME_DECISION_20260918.md`、`RULE_MIGRATION_INDEX.md`）是**本次新增的说明件**，与原件并列保存、**不冒充原始规范** ✓。

## 1. 原件清单（字节数与 SHA-256 为本地实测 ✓）

| 文件（`original/` 内） | 大小 | SHA-256(前 16) | 用途 |
|---|---|---|---|
| `07_WORK_ORDERS.json` | 48,329 B | `2BB4D87E45608C71` | 16 张子单与依赖（`WT-CD-001…016`） |
| `03_ALL_WORK_ORDERS.md` | 59,886 B | `8CDFBA1FF8FB0506` | 16 张子单全文（逐单原件在 ZIP 的 `work_orders/`） |
| `08_ACCEPTANCE_CASES.json` | 46,413 B | `8C73A585E23F11ED` | **96 个验收场景**（`CD01-T01…CD16-T06`，每单 6 条 ✓ `case_count=96` ✓） |
| `04_INTERFACE_CONTRACTS.md` | 5,149 B | `61D99E839EA6B807` | 接口契约（人读版） |
| `09_INTERFACE_CONTRACTS.json` | 7,095 B | `A37E98352B3B0D2C` | 接口契约（10 份，含 `CombatQuerySnapshotV2`／`TerminalResponseV2` 字段与不变式） |
| `05_DELIVERY_AND_ACCEPTANCE.md` | 5,480 B | `F5A8D5935B12AD6C` | 交付与验收协议（含第 6 节规则迁移要求） |
| `templates_RESULTS.template.json` | 766 B | `8D861A72BFDFFF03` | 交付模板：结果 |
| `templates_RULE_CHANGE.template.json` | 477 B | `EDFB0CD357EA1F01` | 交付模板：规则变更 |
| `11_SOURCES.md` | 11,973 B | `66E9864A63292313` | 战雷对照来源（W01–W07 公开机制 + R00–R11 项目依据 + H01） |
| `11_SOURCE_REGISTER.json` | 13,856 B | `38930ECFAD481EC3` | 来源登记（编号索引） |
| `10_BENCHMARK_MATRIX_TEMPLATE.json` | 1,857 B | `D15F6C147535DDFF` | 对照矩阵模板 |
| `work_orders_WT-CD-003.md` | 3,839 B | `D77EEF00B0E362A7` | CD003 边界：3A 静态有限截面 / 3B 平移 / 3C 旋转 |
| `work_orders_WT-CD-014.md` | 3,699 B | `9A48520CD0B4C321` | 旧 `team_standard_300` 与新 `ground_rb_like_v1` 的规则边界 |
| `REISSUE_MANIFEST.json` | 9,539 B | `33BFE86746537EE9` | 补发校验清单（35 个载荷的字节数与哈希 ✓） |
| `RESUME_DECISION_20260918.md` | 9,182 B | `4DEA287C5E04D3EF` | 本次继续执行裁定（含逐场景「可保留／尚需闭合」对照表 ✓） |
| `RULE_MIGRATION_INDEX.md` | 1,876 B | `98F93BB768D3DCCB` | 迁移入口索引（**索引，不是已执行的迁移记录** ✓） |
| `bundle_ALL_INPUTS.md` | 228,914 B | `710AA747E53C4E8F` | 单文件合集（便于单次投递；内容与原件的对应关系以 `REISSUE_MANIFEST.json` 为准 ✓） |

> 未包含：原始 ZIP 与逐单 `work_orders/WT-CD-001…016.md`（除 003/014 两份外）——它们在本会话的挂载包内，未逐字节落到本分支；
> 需要时以 `03_ALL_WORK_ORDERS.md` 全文 + `bundle_ALL_INPUTS.md` 为准 ✓，**不凭记忆补写** ✓。

## 2. 场景编号 → 子单（`08_ACCEPTANCE_CASES.json` 的 `work_order` 字段 ✓）

`CD01-T01…T06` = `WT-CD-001` · `CD02-*` = `WT-CD-002` · `CD03-*` = `WT-CD-003` · … · `CD16-*` = `WT-CD-016`（每单 6 条，共 96 ✓）。
96 条是**覆盖清单**，不是测试数量上限 ✓；允许在既有 ID 下补子检查，**但不得删除原场景**或用新检查替代尚未执行的要求 ✓（裁定 §6 ✓）。

## 3. 当前执行状态在哪看（本分支 ✓）

| 内容 | 位置 |
|---|---|
| 阶段 1 基线清单（五块位置/入口/结构/测试/调用链） | `../COMBAT_DEEPEN01_BASELINE.md` |
| CD001 证据档（含 `CD01-T01/T02/T03/T04` 实测与冲突登记） | `../COMBAT_DEEPEN01_CD001_EVIDENCE.md` |
| 探针工具（可复跑 ✓） | `tests/run_ammo_three_state_probe.gd` |
| 原始日志与回归汇总 | `logs/COMBAT-DEEPEN-01/**` |

## 4. 纪律（与本入口一并生效 ✓）

- 原件**只读**：不改 `original/` 内任何文件 ✓；本 README 是唯一新增入口 ✓。
- 不合并 `main`、不强推、不公开发布、不改用户未提交资产 ✓；性能 `HOLD_BY_USER`、真人 `PENDING`、`release_ready/public_release=false` ✓。
- 任何新增条目必须能挂到某张子单或某个验收场景上 ✓；缺来源的数值按 `design/estimated` 冻结并标 `NOT_COMPARED` ✓，原始事实字段保持 `unknown` ✓。
