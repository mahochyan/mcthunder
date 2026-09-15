# 第 ③ 步 B 类：**17 zone ↔ 档案节点映射表**（T-80B，逐行带证据 ✓）

> 数据源：`assets/reference_data/candidates/ussr_t_80b.json` ✓
> `source`：`origin=warthunder_reference` · `historical_verified=**false**` ✓ · `resource_version=2.57.1.137` ✓ · `sha256=97947ab4a1cfa892…` ✓
> ⇒ `evidence_profile` 只能取 **`game_reference`** ✓（**不冒称** `historical_verified` ✗）

## 1. 映射表（每行：项目 zone ← 档案节点 · 厚度 · 行号 · 材料 · 依据/注意 ✓）
| 项目 zone | 档案节点 | mm | line | armorClass | 依据/注意 |
|---|---|---|---|---|---|
| `hull_front_upper` | `body_front_dm` | 80 | 51 | (未标注 ✓) | 档案**未区分**首上/首下 ⇒ 上下共用同一值 ✓（**已注明** ✓） |
| `hull_front_lower` | `body_front_dm` | 80 | 51 | — | 同上 ✓ |
| `hull_sides_front` | `body_side_dm` | 80 | 53 | — | — |
| `hull_sides_rear` | `body_side_dm` | 80 | 53 | — | 档案未区分前后侧 ✓ |
| `hull_sides_lower` | `body_side_dm` | 80 | 53 | — | 档案未区分上/下侧 ✓ |
| `hull_sides_lower_rear` | `body_side_dm` | 80 | 53 | — | 同上 ✓ |
| `hull_rear_upper` | `body_back_dm` | 60 | 58 | — | 另见 `superstructure_back_dm` 50 L59 ✓ |
| `hull_rear_lower` | `body_back_dm` | 60 | 58 | — | 同上 ✓ |
| `hull_roof_front` | `body_top_dm` | 30 | 54 | — | — |
| `hull_roof_rear` | `body_top_dm` | 30 | 54 | — | 档案未区分前后顶 ✓ |
| `hull_floor_front` | `body_bottom_dm` | 20 | 56 | — | — |
| `hull_floor_rear` | `body_bottom_dm` | 20 | 56 | — | 档案未区分前后底 ✓ |
| `turret_front` | `turret_front_dm` | **250** | 91 | `CHA_tank_modern` | 另有 `turret_01_front_dm` 250 L89 ✓（同值 ✓） |
| `turret_sides` | `turret_side_dm` | **157** | 90 | `CHA_tank_modern` | 侧向多段：125/160/90 ✓，取**代表性** 157 ✓（**须评审** ✓） |
| `turret_rear` | `turret_back_dm` | **90** | 88 | `CHA_tank_modern` | 另有 `turret_01_back_dm` 65 L82 ✓ |
| `turret_roof` | `turret_03_top_dm` | **90** | 80 | `CHA_tank_modern` | 顶向多段：45/60/140/30 ✓，取 90 ✓（**须评审** ✓） |
| `gun_shield` | `gun_mask_01_dm` | **50** | 94 | `CHA_tank_modern` | 另有 `gun_mask_02_dm` 90 L95 ✓ |

## 2. 材料映射（→ 项目 `material_kind`：`rolled` / `cast` / `composite` / `unknown` ✓）
| 档案 armorClass | 项目 material_kind |
|---|---|
| `RHA_tank_modern` | `rolled` ✓ |
| `CHA_tank_modern` | `cast` ✓ |
| `t_80b_composite_armor` | `composite` ✓ |
| `tank_structural_steel` | `rolled` ✓（结构钢按轧制 ✓） |
| `titanium_alloy_vt6` / `ship_wood` / `t_90_rubber_fabric_screens` / `tank_barrel` | **`unknown`** ✓（**不硬套** ✗） |

## 3. facts 条目写法（满足校验器 ✓）
```json
"facts": {
  "armor.turret_front": {
    "value": 250,
    "status": "reference",
    "origin": "warthunder_reference",
    "source_refs": ["wt-2.57.1.137#L91"],
    "location": "T-80B dossier line 91: turret_front_dm armorThickness=250.0 armorClass=CHA_tank_modern"
  }
}
```
- **不写 `local_mm`** ✓ ⇒ 不触发"positive + estimate_reason"要求 ✓（若要写本地估计 ✓，**必带** `estimate_reason` ✓）；
- `status:"reference"` ✓（≠ `unknown` ⇒ 有厚度 ✓，与 `HistoricalVehicleGeometry` 的 `has_thickness` 语义一致 ✓）。

## 4. **必须评审的三处**（我不擅自定 ✗）
1. **档案粒度 < 项目粒度** ✓：首上/首下、上/下侧、前/后顶、前/后底在档案中**同值** ✓ ⇒ 是"**接受同值**"还是"**留待设计拆分**" ✓？
2. **多段取代表值** ✓：`turret_sides`（125/160/90）与 `turret_roof`（45/60/140/30）取哪一个 ✓？
3. **准入判断** ✗：档案**所有节点**都标 `runtime_admitted: **false**` ✓ ⇒ 是否允许把它作为**参考轨**生成**draft** 战斗包 ✓？（`evidence_profile = game_reference` ✓）

## 5. 本轮状态
- **未落盘** ✗：映射表**待评审** ✓（符合"先设计后实现" ✓）；
- 未动产品代码 ✓、未动验收闸门 ✓；豹2A4 同表待做 ✓（其档案结构与 T-80B 同构 ✓）。
