# 第 ③ 步 B 类：**17 zone ↔ 档案节点映射表**（豹2A4 ✓）

> 数据源：`assets/reference_data/candidates/germ_leopard_2a4.json` ✓（9 组 114 节点 ✓）
> `source`：`origin=warthunder_reference` · `historical_verified=**false**` ✓ · `version=2.57.1.137` ✓
> ⇒ `evidence_profile = **game_reference**` ✓（不冒称 `historical_verified` ✗）

## 映射表（每行带节点 · mm · 行号 · armorClass ✓）
| 项目 zone | 档案节点 | mm | line | armorClass |
|---|---|---|---|---|
| `hull_front_upper` | `body_front_dm` | **400** | 44 | `leopard_2a5_turret_nera` ⚠（节点名与 class 名不一致：class 说 turret ✗ —— **须评审** ✓） |
| `hull_front_lower` | `superstructure_front_dm` | 35 | 48 | `RHAHH_tank` |
| `hull_sides_front` | `superstructure_side_dm` | 40 | 49 | `RHAHH_tank` |
| `hull_sides_rear` | `body_side_dm` | 35 | 55 | `RHA_tank_modern` |
| `hull_sides_lower` | `body_side_dm` | 35 | 55 | `RHA_tank_modern` |
| `hull_sides_lower_rear` | `body_side_dm` | 35 | 55 | `RHA_tank_modern` |
| `hull_rear_upper` | `superstructure_back_dm` | 20 | 60 | `RHA_tank_modern` |
| `hull_rear_lower` | `body_back_dm` | 20 | 61 | `RHA_tank_modern` |
| `hull_roof_front` | `superstructure_top_dm` | 35 | 50 | `RHA_tank_modern` |
| `hull_roof_rear` | `body_top_dm` | 20 | 62 | `RHA_tank_modern` |
| `hull_floor_front` | `superstructure_bottom_dm` | 20 | 56 | `RHA_tank_modern` |
| `hull_floor_rear` | `body_bottom_dm` | 20 | 58 | `RHA_tank_modern` |
| `turret_front` | `turret_09_front_dm` | **250** | 113 | `CHA_tank_modern`（effMax 250 ✓） |
| `turret_sides` | `turret_07_side_dm` | **160** | 99 | `CHA_tank_modern`（effMax 160 ✓） |
| `turret_rear` | `turret_07_back_dm` | **40** | 76 | `RHA_tank_modern`（另见 `turret_01_back_dm` 25 L74 ✓） |
| `turret_roof` | `turret_07_top_dm` | **40** | 75 | `RHA_tank_modern` |
| `gun_shield` | `gun_mask_05_dm` | **50** | 139 | `RHA_tank_modern`（mask 组共 7 项 ✓） |

**与 T-80B 表相比** ✓：豹2 档案**粒度更细** ✓（首上/首下有独立条目 ✓）⇒ 被迫共用的情况更少 ✓。

## 材料映射补充 ✓
| 档案 armorClass | → `material_kind` |
|---|---|
| `RHAHH_tank` | `rolled` ✓（轧制均质装甲 ✓） |
| `leopard_2a5_turret_nera` | `composite` ✓ |
| `RHA_tank_modern` / `CHA_tank_modern` | `rolled` / `cast` ✓ |
| `spaced_armor_air` / `hull_side_special_armor` / `rubber_metal_screens` / `ship_wood` / `tank_structural_steel` / `tank_barrel` | **`unknown`** ✓（不硬套 ✗；结构钢可评后再定 ✓） |
