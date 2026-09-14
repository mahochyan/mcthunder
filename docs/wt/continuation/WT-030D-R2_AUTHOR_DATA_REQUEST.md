# WT-030D-R2 ⑤：完整绑定校验所需的**作者数据清单**（可直接执行的请求）

## 1. 受阻原因（精确到函数签名）
```gdscript
static func check_scene(binding, expected_vehicle_id, model_root: Node3D,
                        layout: VehicleLayoutDefinition, geometry := {}, runtime := {}) -> Dictionary
static func check_file(binding, expected_vehicle_id, source_record: Dictionary,
                       layout: VehicleLayoutDefinition, geometry := {}, runtime := {},
                       retain_scene := false) -> Dictionary
```
⇒ 除**已具备**的 `binding`（形状契约 ✓ 已枚举）与**适配产物**（含 `MuzzlePoint` ✓、六角色可解析 ✓）之外，还必须有：
1. **仓库内 `VehicleLayoutDefinition`**（每车一份）；
2. `source_record`（`id` / `path` / `sha256` 且 **sha 必须与 binding 一致**）；
3. 可选 `geometry`：`turret_origin` · `gun_origin` · `barrel_length`（用于 `_runtime_mounts` 的静止姿态一致性）；
4. 可选 `runtime`：`yaw_min/yaw_max` · `pitch_min/pitch_max`（与机构一致）。

## 2. `VehicleLayoutDefinition` 必需字段（源码 `scripts/layout/vehicle_layout_definition.gd`）
| 字段 | 说明 |
|---|---|
| `schema_version` · `id` · `historical_identity_id` · `content_tier` · `display_name` | 标识层 |
| **`parts: Array[LayoutPartDefinition]`** | 部件（几何） |
| **`armor_patches: Array[ArmorPatchDefinition]`** | 装甲块 |
| **`modules: Array[Volume/ModuleVolumeDefinition]`** | 内构模块 |
| **`crew_stations: Array[CrewStationDefinition]`** | 乘员位 |
| `source_catalog_id` · `field_evidence_id` | 来源与史料证据 |
| `declared_openings` · `allowed_overlaps` | **真实结构开口**（炮塔环/炮口等）与**有意重叠**（对象对 + 原因） |
| `recovery_enabled` | 显式 opt-in |

## 3. 我**不能**代作者做的事（红线：不虚构）
- 装甲厚度、内构模块边界、乘员位、结构开口与有意重叠 **均为设计/史料数据** ⇒ **不得凭空生成** ✗；
- 因此 ⑤ 的完整通过**必须**由作者提供上述 layout（或授权我按**明确来源**整理）。

## 4. 建议的三条可行路径（请择一授权）
| 路径 | 内容 | 我的工作量 |
|---|---|---|
| **A** | 作者按 §2 提供 layout（每车一份，可先只做 3 车样例：`35t`/`KPz70`/`M48`） | 我只做接入与校验 |
| **B** | 授权我按**源模型自身节点结构 + 索引数据**生成 **draft layout**（明确标注 `draft`、`field_evidence_id` 留空、**需作者签收**） | 中（可自动化，产 draft + 报告） |
| **C** | 暂缓 ⑤，交付侧按现状记录"**形状契约 ✓ + 适配产物 ✓ + 六角色解析 ✓；完整 layout 校验待作者数据**" | 0 |

**我的建议**：**B**（先 3 车样例，产出 draft + 差异报告，作者据此签收或修正）——既不虚构（全程标注 draft 与来源），又能把 ⑤ 推进到"仅差签收" ✓

## 5. 现状（已完成、可复现）
| 步骤 | 证据 |
|---|---|
| 形状契约（字段格式） | 已从 `model_binding_validator.gd::_shape` 全量枚举 ✓ |
| 适配产物（3 车）+ 双哈希 | `logs/WT-030D-r2/adapter_artifacts.json`（2,192 B）✓ |
| 产物自校验（含 `MuzzlePoint`、炮口为**作者节点**、六角色可解析） | `logs/WT-030D-r2/adapter_verification.json`（4,388 B）✓ |
| 96 车只读审计 | `logs/WT-030D-r2/german_intake_audit.json`（41,370 B）✓ |

---

## 附录：draft layout 已按裁定 **B** 生成（本轮）
- 工具：`tests/export_draft_layouts.gd` ✓；产物：`assets/draft_layouts/{35t,KPz70,M48}_draft.tres`（各 ~1.8 KB ✓）
- **仅由模型自身派生**：`parts`（id / parent_id / **bind_local**（父子相对变换，取自真实场景 ✓）/ `joint_kind`（由角色决定：hull=root、turret=yaw、gun=pitch ✓））· `declared_openings`（炮塔环 / 炮口 / 结构开口的**实测位置** ✓）
- **一律留空并列入 `needs_author`（每车 6 项 ✓）**：`armor_patches`（厚度/材料/分组）· `modules`（体积/完整度）· `crew_stations`（乘员角色/位置）· `parts.min/max_angle_deg`（机构限位）· `historical_identity_id`/`source_catalog_id`/`field_evidence_id`（无史料依据 ✓）· 以及**未能解析为节点的角色**（如 running_gear ✓）
- **draft 标记**：`content_tier = "test"` ✓ + `field_evidence_id = ""` ✓ + 目录名 `draft_layouts/` ✓ + 报告 JSON ✓（不冒充作者数据 ✓）
- 报告：`logs/WT-030D-r2/draft_layouts_report.json`（逐车 `derived_parts` 与 `needs_author` ✓）
- **下一步**：作者按报告补齐上述 6 类字段并签收 ⇒ 即可跑 `check_scene`（仍需 `source_record` 与 `geometry`/`runtime` ✓）

---

## 附录二：draft 几何**已修正为实测值**（含一处**不确定性**，须作者确认）
修复同一根因（**离线读 `global_position` 一律返回 0** ✗ ⇒ 两个 draft 工具也中招 ✓）后重生成：

| 车 | `turret_origin` (m) | `gun_origin` (m) | `barrel_length` (m) |
|---|---|---|---|
| `35t` | (0, **1.4346**, −0.3248) | (0.00004, **1.7277**, −0.8460) | **2.048** |
| `KPz70` | (0, **1.4978**, −0.8300) | (0.00124, **1.8731**, −2.4342) | **3.705** |
| `M48` | (0.00001, **1.6396**, −0.6835) | (−0.0118, **1.9819**, −1.6889) | **4.111** |

**不确定性（须作者确认）**：作者模型用**空枢轴**（`TurretPivot`/`GunPivot` 位置由作者给定 ✓），而**炮口位置**是我从**炮管网格端点**经父链实测的 ✓。二者**不在同一基准**上（例：`35t` 的 `GunPivot` 在 y≈1.73 m，而实测炮口在 y≈0.0026 m）⇒ 由此算出的 `barrel_length` **可能不是真实炮管长度** ✗，而是"枢轴到炮口端点的距离" ✓。
⇒ 因此该值在草案中标为 **draft**，并列入 `needs_author` ✓（作者应给出 `gun_origin` 与炮管轴线的**权威定义** ✓）。

**其余 draft 内容不受影响**：`parts` 结构与 `bind_local`（父子相对变换 ✓）、`declared_openings`（实测开口位置 ✓）均基于**树内实测** ✓。
