# WT-040-R1 **交付报告**（第 ③ 步：两辆现代样车战斗包）
> 本文件是**正式交付入口** ✓；详细内容**不在此重复** ✓，按第 4 阶段六项要求给出**指针** ✓。
> 状态日期 ✓：2026-09-15/16 · 分支 `work/continuation-20260913` ✓ · 基线 `main @ a1bac406` ✓（**未改动** ✓）

## 1. 完成项 ✓（**均由项目自身校验器验证** ✓）
| 项 | 证据指针 |
|---|---|
| 两车适配产物（T-80B 新建 ✓ / 豹2 首次生成 ✓；98 行全 verified ✓） | `WT-040-R1_EVIDENCE_TABLE.md` §1 |
| `geometry` 实测 15 字段 ✓ + **自校验 29/29** ✓ + adapter↔source 逐项一致 ✓ | 同上 §2 |
| `facts` 带引用 ✓ · `assembly` 六项 ✓ · `armor` 17 zone 草案 ✓（T-80B **12 项如实 unknown** ✓） | 同上 §5–§7 |
| `modules`（7 kind ✓ 弹架**精确配平** 38/42 ✓）· `crew`（角色引用 ✓ 位置派生 ✓） | 同上 §7 |
| **两车 `definitions` 全 0 错误** ✓✓ | 同上 §2 |
| 一条命令的流水线（`tests/run_modern_vehicle_pipeline.ps1` ✓ **9 步全绿** ✓） | 同上 §3 |
| **三项数据完整性回查** ✓ + **环↔AABB 交叉验证** ✓ | 同上 §5–§8 |
| **两项几何修正经证伪循环落地** ✓✓（T-80B `LayoutValidator` **4 → 0** ✓ · 豹2 **7 → 2** ✓） | 同上 §12 · `WT-040-R1_NEXT_FIX_DETAILS.md` |
| **官方全量门禁干净运行 = 基线** ✓✓（**126 PASS / 2 FAIL** ✓，两红为登记非回归 ✓） | 同上 §12 |
| **第 3 阶段运行证据** ✓：应用流程 **127/0** ✓ · 辅助能力 **51/0** ✓ · 科技树 **50/0** ✓ · **无注入真实对局**（完整流程通过 ✓） | 同上 §14–§16 |

## 2. 未完成项及原因 ✗（**逐项归属明确** ✓）
| 项 | 原因 | 归属 |
|---|---|---|
| 弹种集（`compatible_shells` ✓ 两车 ✓） | `VehicleShellCatalog`：`vehicle has no admitted shell set` ✓ | **设计/资料** |
| 复合装甲 `response_profile`（豹2 ✓ ×2） | 项目要求**显式版本化游戏规则** ✓ | **设计** |
| `dimensions.*` · `assembly.year/suspension/mount` | 需**文献原值 + 推导** ✓（档案唯一日期是**参考游戏上线日** ✓ 已拒绝 ✓） | **史料** |
| `reload_time` · `pitch_min/max` · `penetration_curve` | 档案**均无** ✓（曲线须**多点** ✓） | **设计** |
| **armor 准入判断** | 档案自称 `runtime_admitted:false` ✓ | **您裁定** |
| **独立包校验** | `build_release.ps1` 的 `fresh_import` **退出码 `$null`** 陷阱 ✗ | **您裁定**（修 ✗/缓 ✓） |
| 河谷队内拥堵 | 四次修复**证伪并逐字节回退** ✓；b 机制**已细化但未实施** ✗ | **您选 a/b/c** |

## 3. 验证证据 ✓
统一入口 ✓：`WT-040-R1_EVIDENCE_TABLE.md`（**每条结论 → 可复现日志** ✓；含门禁三次运行 §12 ✓ 与运行证据 §14–§16 ✓）。

## 4. 已知风险 ✓
1. 档案为 `warthunder_reference` ✓（`historical_verified:false` ✓，含 **`街机功率倍率 ×1.5`** ✗）⇒ **只作可引起点** ✓；
2. **两车机动值完全相同** ✗（75/10/30/4.0 ✓）⇒ 归一化征兆 ✓；
3. 豹2 结论部分基于**探针占位环** ✓（每次输出均标注 ✓）；
4. **加速单位是假设** ✓（档案键名为 `…unspecified_units` ✓ 且值为空 ✓ ⇒ 已在事实中**显式标注** ✓）；
5. `ring_half` 为**派生+夹紧** ✓ · `open_top` 为**推断** ✓ · `muzzle_brake` 为**几何猜测** ✓（均写入 `methods` ✓）；
6. **两个独立待查项** ✓（**非本阶段交付** ✓）：票数消耗非交战驱动 ✗ · 河谷队内拥堵 ✗。

## 5. 回滚方式 ✓
- **产品代码**：本会话**仅 1 处 8 行**有意修正 ✓（`role_mapping_audit.gd` 的 `GUN_MESH_HINTS` ✓）；`modern_model_mount_adapter.gd` ✓ 与 `river_junction_navigation.gd` ✓ **逐字节等于基线** ✓；
- **测试工具**：`generate_modern_geometry.gd` ✓ 与 `check_modern_geometry.gd` ✓ 为本次修正载体 ✓ ⇒ `git checkout <基线> -- <文件>` 即可回退 ✓；
- **适配产物**：由 `export_model_binding_adapter.gd` **确定性重生成** ✓（已验证 98 个重跑**逐字节相同** ✓）；
- **草案与日志**：全部位于 `logs/WT-040-R1/` ✓ ⇒ **删除即净** ✓，**未触碰任何配置** ✓。

## 6. 交接说明与变更清单 ✓
- **新增测试/工具** ✓：`run_modern_vehicle_pipeline.ps1` ✓ · `generate_modern_geometry.gd` ✓ · `check_modern_geometry.gd` ✓ · `build_modern_{facts,armor,crew,modules,evidence}_draft.gd` ✓ · `check_modern_package_gaps.gd` ✓ · `probe_package_layers.gd` ✓ · `probe_source_nodes.gd` ✓ · `export_model_binding_adapter.gd`（参数化 ✓）；
- **产品代码** ✓：1 处 8 行 ✓（见 §5）；
- **产物** ✓：T-80B 适配产物新建 ✓ + 5 辆无炮车移除虚假原点标记 ✓；
- **文档** ✓：25 篇 `WT-040-R1_*` ✓（索引见 `DOC_INDEX.md` ✓）；
- **环境** ✓：在 `tools/godot/` 下按项目约定放入引擎 ✓（`.gitignore` 已忽略 ✓，可逆 ✓）—— 因 `build_release.ps1` **无 `-EnginePath`** 参数 ✓。

## 7. 待您裁定（**四项** ✓）
**①** armor 三项（含**准入** ✓）· **②** 河谷 **a/b/c** ✓ · **③** G–L 外部输入 ✓ · **④** 构建：**修退出码判定** ✓ 或 **包校验暂缓** ✓。
