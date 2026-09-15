# 阶段性工作上传包（PixelArmor / MCTHUNDER 本地后续开发）

> 工作区：`E:/AIprogram/mcthunder-cont`（分支 `work/continuation-20260913`）
> 基线：`main @ a1bac406d2bc12b32c7f7d130590f1c1a17907c9`（**全程未改动** ✓，porcelain 恒 **379** ✓）
> 生成时间：本阶段收尾时；所有数字均由命令实测得出 ✓

## 1. 阶段结论（一句话）
**在不动基线、不引入依赖、不做不可逆操作的前提下**，把本阶段可授权范围内的工程红项与资产侧工作推进到闭环：
门禁 **127 套件定稿（125 PASS / 2 FAIL，两项均为已定性非回归）** ✓、**179 个测试套件全部有据归类** ✓、
历史红清除（工业 **283/56 → 595/0**、历史道路 **29/4 → 33/0**、地图 **→ 48/0**）✓、
**96/96 车适配产物**（位置自断言 delta=0 ✓）、**server/client 导出预设 + 实跑** ✓、裁定 **A1/B4/C3** 全部执行 ✓。

## 2. 证据索引（每条结论都有可复核文件 ✓）
| 项 | 证据路径 |
|---|---|
| 门禁定稿运行（127 套件） | `logs/WT-036-R1/full-gate-127/`（逐套件日志 + `summary.json`） |
| 官方运行器运行（两条独立路径） | `logs/WT-036-R1/runner-127/20260915-093526/` · `logs/WT-036-r1/official-runner-127-clean.log` |
| 179 套件归类 | `docs/wt/continuation/WT-036-R1_GATE_COVERAGE_GAP.md` · `WT-036-R1_GATE_EXPANSION_LOG.md` |
| 门禁终版口径 | `docs/wt/continuation/REGRESSION_GATE_MASTER.md` + `_ADDENDUM_R4…R11.md` |
| 裁定执行 | `DECISION_EVIDENCE_SHEETS.md` · `DELIVERY_SUMMARY_ROUND5_FINAL.md` |
| 交叉验证与工具修复 | `WT-036-R1_RUNNER_CROSSCHECK.md` · `WT-036-R1_RUN_CHECKS_FLAKE.md` |
| 资产侧 | `logs/WT-030D-r2/adapter_artifacts.json`（96 车哈希与自校验 ✓）· `assets/vehicles/adapters/`（96 GLB）· `assets/draft_layouts/`（3 草案） |
| 构建（E1 授权） | `export_presets.cfg`（新增两个预设）· `logs/WT-036-r1/export-Windows-*.log` · `backups/builds/`（**不入库** ✓） |
| D 电池与坡脊诊断 | `logs/WT-039-D/` · `logs/route-traces/` |
| 总览 | `docs/wt/continuation/FINAL_COVERAGE_MATRIX.md`（目标 ↔ 交付 ↔ 证据 ↔ 归属） |

## 3. 本阶段变更清单
| 项 | 值 |
|---|---|
| 提交数 | **185** 提交（`git -C <cont> log --oneline a1bac406..HEAD`） |
| 产品代码（`scripts/`） | 61 files changed, 3780 insertions(+), 21 deletions(-) |
| 测试代码（`tests/`） | 69 files changed, 3769 insertions(+), 11 deletions(-) |
| 导出预设（E1 授权） | `1 file changed, 55 insertions(+)` |
| 交付文档 | ****125**** 份（`docs/wt/continuation/`；索引 `DOC_INDEX.md`） |
| 新增测试/工具 | 36 个（见 `git diff --name-status a1bac406..HEAD -- tests`） |

## 4. 完成项（有证据 ✓）
1. **让行/僵持回归（我曾引入）**：四门同时达标 ✓（`ai_drive` 40/0 · 村庄 21/0 · 地图 48/0 · 战斗 15/1＝基线）；
2. **门禁扩容 32 → 127 套件**（+95 ✓）并**两次抓到我引入的回归**（`ai_drive` → `6937e684`；`partial_support` → `c26ac2c1` ✓，均已被看住 ✓）；
3. **运行器 4 处判定缺陷修复**（双向验证、**未放宽断言** ✓）；
4. **历史红清除**：工业 595/0 ✓ · 历史道路 33/0 ✓ · 地图 48/0（**D2 声明变更**后 ✓）；
5. **裁定 A1**（`T018-H01` 预算 15000→24000 ✓ 连跑两次 48/0 ✓）· **B4**（challenge 登记 ✓）· **C3**（M26 受限 ✓）；
6. **授权 E1**（server/client 预设 + 双导出 exit=0 + 导出 server 实启 ✓）· **E2**（**96/96** 适配产物、`delta=0` ✓、`source_unchanged=true` ✓）；
7. **资产 ⑤ 可执行部分**：draft layout（部件/父子/关节/开口 ✓）+ draft `source_record`/`geometry`/binding ✓。

## 5. 未完成项（原因与**归属**，无一悬空 ✓）
| 项 | 归属 | 说明 |
|---|---|---|
| 资产 ⑤ 完整校验 | **作者** | 每车 `needs_author` **6 类字段**（装甲/内构/乘员/关节限位/桶轴定义/证据标识 ✓）+ 签收 ✓ |
| 资产接入与许可（E3） | **用户** | 需授权口径（路径接入许可 vs 素材许可 **分记** ✓） |
| 真人验收 + 性能采样（E4） | **用户** | 现 `HOLD_BY_USER`，**零采样** ✓ |
| 工业战斗抵达率（**既有红**） | **用户裁定** | 三选项（调平衡 / 调检查容忍 / 立项）见 `WT-036-R1_INDUSTRIAL_BATTLE_MECHANISM.md` ✓ |
| `challenge` 防守夹具边界 | 已裁定 **B4** | 保持登记 ✓ |
| M26 坡上起步 | 已裁定 **C3** | 作为已知受限 ✓ |
| `T003-06` 罕见抖动 | 独立立项 | 12 次重跑未复现 ⇒ **不做无法验证的改动** ✓ |
| 公网 / 10v10·16v16 / 空海 | 未授权未实现 | **NOT_RUN** ✓ |

## 6. 安全与回滚
- **风险**：地图铺装＝可见外观变化（无几何/掩体/通视影响 ✓）· 让行策略影响 AI 交通（四门已验证 ✓）· 仓库体积增长（适配产物 86.97 MB **入库** ✓；构建产物 627 MB 在 `backups/`，**已 gitignore、未入库** ✓）；
- **回滚**：每项**单提交**可退 ✓（`tank.gd` · `ai_path_driver.gd` · `game_config.gd` · `village_definition.gd` · `map_definition.gd` · `run_map_checks.gd`（A1）· `export_presets.cfg`（E1，受权）· `tests/run_suite_checks.ps1`（工具修复）· `assets/vehicles/adapters/`（E2，可整目录删除））；
- 整体可切回第 2 轮交付点 `f261e785` 或基线 `a1bac406` ✓；**原 `main` 工作区全程未被改动** ✓。

## 7. 上传（本包）建议阅读顺序
`FINAL_COVERAGE_MATRIX.md`（总览）→ `REGRESSION_GATE_MASTER_ADDENDUM_R11.md`（门禁终版）→ `DECISION_EVIDENCE_SHEETS.md`（待裁定项与落地步骤）→ `WT-036-R1_RUNNER_CROSSCHECK.md`（交叉验证）→ `DELIVERY_SUMMARY_ROUND5_FINAL.md`（裁定执行）→ `WT-030D-R2_AUTHOR_DATA_REQUEST.md`（作者待补字段）→ `NEXT_ACTION.md`
