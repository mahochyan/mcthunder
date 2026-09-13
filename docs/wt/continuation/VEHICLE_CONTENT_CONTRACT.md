# 可复用载具内容契约（WT-030-R1）

- 依据：`03_全部42项目标工作单.md` WT-030（行 1236-1276）
- 实现：新增 `scripts/content/vehicle_content_record.gd`（记录契约 + 字段来源 + 职责分离 + 校验器 + 分发门 + 可移植性 + 重建清单）
- 验证：新增 `tests/run_content_record_checks.gd`（**65/65 PASS**）

## 1. VehicleContentRecord 与字段来源规则（交付物第一条）

记录把**职责分成独立字段**，每个字段都声明来源：

| 字段 | 职责 | 来源（provenance） |
|---|---|---|
| `model` | 仅展示（路径/字节数/SHA-256/是否有 `.import`） | **fact**（仓库实测读取） |
| `reference_entry` | 参考条目（路径/字节数/SHA-256） | **fact** |
| `mount` | 机构挂点（root / gun mesh / 车轮前缀 / 车轮数） | **author**（`modern_model_mount_adapter.gd`） |
| `movement_collision` | 移动碰撞盒 | **author** |
| `muzzle_and_pivot` | 炮口与轴心变换 | **author** |
| `armor` / `modules` | 装甲与内构布局引用 | **unknown**（布局尚未挂接——如实标注，不假定） |
| `licence` / `source` | 来源与许可 | **unknown**（未确立） |

另有 `family_id` / `variant_id` / `nation` / `branch` / `scale` / `forward_axis` / `up_axis` / `evidence_grade`。
**套件断言**：每个字段的来源都取自声明的四类（fact / reference / author / unknown），且"未挂接的布局"与"未确立的许可"**明确为 unknown**。

## 2. 模型/战斗资源校验器（交付物第二条）

`validate(record)` 输出**具名错误**，绝不静默套用默认战斗车：

| 错误 | 触发 |
|---|---|
| `missing_model` / `unhashed_model` | 模型缺失或未计算哈希 |
| **`missing_muzzle`** / **`missing_pivot`** | 炮口或轴心缺失（各自具名） |
| **`missing_layout`** | 装甲/内构布局未挂接 |
| `negative_scale` / `scale_out_of_range` / `non_finite_scale` / `malformed_scale` | 负缩放、越界、非有限、维度错误 |
| `coordinate_convention_mismatch` | 前向不是 −Z 或上向不是 +Y |
| `transform_inconsistent` | 炮口/轴心偏移非有限或绝对值 > 20 m |
| `unknown_evidence_grade` / `unknown_licence_state` | 证据等级或许可状态非法 |
| `schema_version_mismatch` / `missing_<标识字段>` | 版本或标识缺失 |

**实测**：两辆样车当前**不通过**校验并**具名报告 `missing_layout`**（布局未挂接）——正是"明确报原因"而非"默认战斗车"；另用一条完整合成记录验证 **校验器不是空断言**（完整记录可通过）。

## 3. 来源/许可门（独立于游戏可用性）

`distribution_gate()`：未知来源 → **`blocked_pending_source`**：**只阻塞分发决策**（`blocks_public_candidate=true`），**不阻塞游戏使用**（`blocks_game_use=false`）；已声明不可分发 → `blocked_non_redistributable`；仅 `redistributable` 通过。
→ 与父项要求一致：**未知来源既不自动判合法也不自动判侵权**。

## 4. 可移植性（隔离目录可导入）

`portability()` 检测本机绝对路径（盘符或 POSIX 绝对路径；`res://`/`user://` 视为相对）：两样车记录**全部为 `res://` 路径**（通过）；注入 `E:/AIprogram/aimodel/...` 的负例被**检出并具名**。

## 5. 注册表与 113 模型实测（本轮关键事实）

| 事实 | 数值 |
|---|---|
| `configs/vehicles/model_sources.json` 内容 | `{"schema_version":1,"models":{}}` → **注册表为空** |
| `assets/research/models/*.glb` | **113 个** |
| 其中有 `.import` 伴随文件 | **0** |
| 其中已注册进 `model_sources.json` | **0** |
| `ResourceLoader.exists()` 可加载 | **0**（逐行断言） |

→ 113 个模型对资源加载器是**字节文件**（与 WT-024 的"缺显示资源不影响权威"一致）；把选中资产接入必须走**契约 + 挂点 + 注册**，而不是直接 `load()`。

## 6. 可重建的样车源→导出→接入清单（交付物第三条）

`rebuild_checklist(vehicle)` 四步，每步带**真实尺寸或哈希**：

| 步骤 | 产物 | 导出方式 |
|---|---|---|
| 1 源条目 | `assets/reference_data/candidates/<id>.json`（实测字节数 + SHA-256） | 无（仓库内 JSON） |
| 2 模型 | `assets/research/models/<id>.glb`（实测字节数 + SHA-256） | 作者 GLB，按字节读取（无 `.import`） |
| 3 挂点 | `scripts/content/modern_model_mount_adapter.gd`（SHA-256） | 作者机构规格 |
| 4 接入 | `configs/vehicles/model_sources.json`（SHA-256） | **注册表条目（当前为空：该样车尚未注册）** |

## 7. 验收对照

| 验收要求 | 结果 |
|---|---|
| 切换模型 LOD 不改变战斗配置 | **PASS**（`lod_switch_keeps_combat()` 实测：装甲/内构/碰撞/炮口全部不变；切到不存在路径亦不变） |
| 缺炮口/轴心/布局的车明确报原因，不套默认战斗车 | **PASS**（三者在列；两样车当前具名报 `missing_layout`；另以完整记录证明校验非空） |
| 隔离目录可导入选中资产且无本机绝对路径依赖 | **PASS（静态检查）**（全部 `res://`；绝对路径负例被检出）。**注**：WT-023-R1 已实测导出包可在干净目录独立启动；本单不重复该运行 |
| 不可分发素材不混入公开候选 | **PASS**（未知/不可分发均 `blocks_public_candidate`；WT-023 候选只含仓库内素材） |

## 8. 明确不做 / 未完成（如实）

- **不硬改**报告未展开的 `aimodel` / `j16` 素材；**不做**全库 LOD 减面或纹理性能专项。
- 六个脏文件继续按 WT-001-R1 隔离保全；M1A1 新二进制**输入/导出方式/用途未知** → **不选入构建**（仅登记为未整合 LOD 研究）。
- **注册表仍为空**（113 模型尚未登记）；两样车布局未挂接；`armor/modules` 字段仍为 unknown → 属 WT-030 剩余工作。
- 窗口 UI（模型展厅）与真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

---

## 更正与补充（WT-030D-R1 追加，2026-09-13）

1. **§5 的过强表述已更正**：`VehicleReadiness.resource_state()` **不依赖注册表**解析模型（用 `_model_paths()` + `FileAccess.file_exists()`，注释亦说明研究 GLB 按字节读取）。因此"未注册"**不等于不可用**；注册只对 `model_binding` 路径必要。
2. **两样车另有标准副本**：`assets/vehicles/modern_bound/{ussr_t_80b,germ_leopard_2a4}.glb` 存在，但**该目录带 `.gdignore`**（对资源加载器隐藏）；本契约记录中登记的仍是研究目录副本（字节文件）。
3. **注册表为何仍为空**：`BoundVehicleModel.check()` 要求 packet 带 `model_binding`、路径以 `res://assets/vehicles/` 开头、节点覆盖 `ModelBindingValidator.ROLES`，且注册行须有 `delivery_status/provenance/resource_version`。仓库内**当前无任何 packet 带 `model_binding`**（历史四车走 `legacy_model_path`），**贸然填表会让带绑定的车切到更严格路径** → 判决为 `deferred_pending_model_binding_and_source_fields`（见 `WT-030D-R1_DESIGN.md`）。
4. **资产事实**：`assets/vehicles/` 下 M1A1（18,071,366 B）、ZTZ-99A（41,272,302 B）、leopard2a7v（34,549,612 B）、modern_bound（1,986,100 B，带 `.gdignore`）——均以目录枚举 + SHA-256 实测。
