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
