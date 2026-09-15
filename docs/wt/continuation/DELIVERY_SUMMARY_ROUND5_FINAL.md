# 第 5 轮交付终稿（裁定执行 · E1/E2 授权项 · 门禁 127 定稿）

## 1. 您本轮裁定的执行结果（全部落地、均有证据）
| 裁定 | 执行 | 证据 |
|---|---|---|
| **A1** 提高 `T018-H01` 预算 | **15000 → 24000 tick**（250→400 s ✓），代码注释中**显式记为测试语义变更** ✓，未放宽任何断言 ✓ | `run_map_checks` **连跑两次 48/0（exit=0，约 74 s）** ✓ |
| **B4** challenge 保持登记 | 无需改码 ✓（登记维持 ✓） | 127 套件终账中仍为 **138/2** ✓ |
| **C3** M26 作为已知受限 | 无需改码 ✓（D 电池判定表已按"受限"记录 ✓） | T039-D 诊断电池不入禁 ✓ |
| **E1** 导出预设（授权） | **完成** ✓：新增 `Windows Server`（`dedicated_server=true` ✓）与 `Windows Client` ✓ | **两次导出 exit=0** ✓（各 exe 104.08 MB + pck 92.71 MB ✓）；**导出的 server 已 headless 实启**（stderr 为空 ✓） |
| **E2** 96 车全量适配（授权） | **完成** ✓：**96/96** 生成，**位置自校验 96/96 通过、delta 最大 = 0** ✓、`source_unchanged=true` 96/96 ✓ | **86.86 MB**、96 个 GLB 入库 ✓；生成耗时 9.9 s ✓ |
| **E3/E4**（未授权） | 保持 **NOT_RUN** ✓（资产接入/许可分记 · 真人与性能采样 ✓） | — |

## 2. 门禁定稿
- **默认门禁 127 套件** ✓；**179** 个 `run_*.gd` **全部有据归类、无未试跑残留** ✓
- **定稿全量运行（127 套件）：125 PASS / 2 FAIL / 0 ZERO / 0 TIMEOUT** ✓
  - 两项失败**始终**是同一对已定性非回归：`industrial_battle` **15/1＝基线持平**（既有抵达红 ✓）· `challenge` **138/2**（已登记 ✓，您裁定 B4 ✓）
- 四次全量运行（32 / 111 / 120 / 127）失败项**始终相同** ⇒ **扩容与裁定执行均未引入新红** ✓

## 3. 裁定后的**回归复核**（本轮新增证据）
在 **96 个新产物 + A1 改动**之后，资产相关 **9 个套件全部通过**（共 **534 项检查** ✓）：
`asset_registry` 44/0 · `blender_asset` 16/0 · `model_binding` 63/0 · `model_binding_probe` 60/0 · `bound_model_package` 59/0 · `equipment_package` 74/0 · `content_record` 65/0 · `reference_admission` 105/0 · **`map_checks` 48/0** ✓

## 4. 未完成项（原因明确）
| 项 | 原因 |
|---|---|
| 资产 ⑤ 完整校验 | **待作者字段与签收**（每车 `needs_author` 6 项 ✓；草案已生成 ✓）——**不虚构** ✓ |
| 资产接入与许可（E3） | **待您给出授权口径** ✓ |
| 真人验收与性能采样（E4） | **待授权**（现 `HOLD_BY_USER`，零采样 ✓） |
| 工业战斗抵达率 | **既有基线红** ⇒ 建议独立立项 ✓ |
| 公网/10v10/16v16/空海 | 未授权未实现 ✓（**NOT_RUN** ✓） |

## 5. 风险与回滚
- **风险**：地图铺装＝可见外观变化（无几何/掩体/通视影响 ✓）· 让行策略影响 AI 交通（四门已验证 ✓）· 仓库体积因 **96 适配产物（86.86 MB）+ 构建产物**增长（构建在 `backups/` 且**不入库** ✓）；
- **回滚**：逐项**单提交**可退（`tank.gd` · `ai_path_driver.gd` · `game_config.gd` · `village_definition.gd` · `map_definition.gd`（注释）· `run_map_checks.gd`（A1 ✓）· `export_presets.cfg`（E1 ✓）· `assets/vehicles/adapters/`（E2，可整目录删除 ✓））；整体可切回 `f261e785` 或基线 `a1bac406` ✓；
- **原 `main` 工作区全程未被改动**（porcelain 恒 **379** ✓）。

## 6. 交接（先读顺序）
`NEXT_ACTION.md`（含门禁定稿 + 四条工程陷阱 ✓）→ `REGRESSION_GATE_MASTER.md` + `_ADDENDUM_R4–R11` → `DECISION_EVIDENCE_SHEETS.md` → 本文件 → `WT-030D-R2_AUTHOR_DATA_REQUEST.md` → `DOC_INDEX.md`
