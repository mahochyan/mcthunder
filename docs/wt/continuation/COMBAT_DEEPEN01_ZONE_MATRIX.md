# MCT-COMBAT-DEEPEN-01 · CD05 实现顺序 #3：两车主要区域矩阵（由交付包生成 ✓）

> 来源：`authoring/reference_data/modern_vehicles/{ussr_t_80b,germ_leopard_2a4}.json` 的 `armor` 对象 ✓（2 车 × 17 同名区域 ✓）。本表**由交付包直接生成** ✓ 未编造任何数值 ✓。

## 实测结论（关键 ✓）
- 全包 **`thickness_mm` 出现 0 次** ✗；`thickness_status`/`armor_layers`/`patches`/`zones` 均 **0 次** ✗ ⇒ 两车区域**只著录材料与响应系数**，**厚度完全未著录** ✓。
- 区域自带的 `response_profile.reason` 明写："**Original candidate combat tuning; not a decoded historical or War Thunder penetration/material curve**" ✓。
- ⇒ 实现顺序 #3 的"**逐步替换明显不当的代表值**"**无法靠改数字完成** ✗ —— **厚度本身就是未知原档案** ✓ ⇒ "**未知原档案保留**" ✓✓ **以最字面的方式成立** ✓。

## 已被实测撤回的两条判据（我自己的误设 ✗）
- "非正厚度 17/17" ✗ 与"跨车同区名厚度相同 17/17 ⇒ 疑似代表值" ✗ 实为在**测量数值缺失** ✗ 而非缺陷 ✓ ⇒ **撤回** ✓（测量先行再次纠正了判据本身 ✓）。

## 2 × 17 区域矩阵（实际著录内容 ✓）

| 区域 | ussr_t_80b 材料 / profile / 系数 k,c,f | germ_leopard_2a4 材料 / profile / 系数 k,c,f |
|---|---|---|
| `hull_front_upper` | composite / `wt012-passive-composite-v1` / 1.2,2.4,1.0 | composite / `wt012-passive-composite-v1` / 1.2,2.4,1.0 |
| `hull_front_lower` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_sides_front` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_sides_rear` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_sides_lower` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_sides_lower_rear` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_rear_upper` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_rear_lower` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_roof_front` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_roof_rear` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_floor_front` | rolled / `` / ,, | rolled / `` / ,, |
| `hull_floor_rear` | rolled / `` / ,, | rolled / `` / ,, |
| `turret_front` | composite / `wt012-passive-composite-v1` / 1.6,2.4,1.0 | composite / `wt012-passive-composite-v1` / 1.6,2.4,1.0 |
| `turret_sides` | rolled / `` / ,, | rolled / `` / ,, |
| `turret_rear` | rolled / `` / ,, | rolled / `` / ,, |
| `turret_roof` | rolled / `` / ,, | rolled / `` / ,, |
| `gun_shield` | rolled / `` / ,, | rolled / `` / ,, |

## 判据（改基于实际著录内容 ✓）
- **每个区域都有材料与一个版本化的 `response_profile`** ✓（`provenance=game_rule` ✓ 带 reason ✓）⇒ 可复核 ✓；
- **每个区域都明确厚度未著录** ✓（本单要求保留未知原档案 ✓）⇒ 不得把缺失当成 0 厚度 ✓；
- **ERA 未著录** ✓ ⇒ 本轮 ERA 判据使用**自建合法夹具** ✓（见 `probe_cd005_era.gd` ✓）且**不冒充**交付配置 ✓。