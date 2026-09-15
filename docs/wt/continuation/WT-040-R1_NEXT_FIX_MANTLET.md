# 下一步（一次可验证的修改）：**炮盾必须包住炮孔** ✓
## 改动点 ✓
`tests/generate_modern_geometry.gd` ✓ —— 在派生 `mantlet_half_width/height` 之后加**下限**：
```gdscript
var bore := caliber_mm / 2000.0          # 125mm -> 0.0625（来自可引的 assembly.caliber_mm ✓）
mantlet_half_width  = max(derived_w, bore * 1.6)
mantlet_half_height = max(derived_h, bore * 1.3)
```
并把规则写进 `methods` ✓（"派生值经下限约束：炮盾必须包住炮孔 ✓"）。
## 依据 ✓
`historical_vehicle_geometry.gd:75-96` ✓：`mantlet` 为 `outer(±hw,±hh) − inner(±bore)` 的**环形面** ✓；
T-80B 实测 `hh = 0.054 < bore = 0.0625` ✗ ⇒ **负宽环** ⇒ 非流形 ✓（报错坐标与之逐一对上 ✓）。
## 验证命令（改动后立即执行 ✓）
```
godot --headless --path <cont> -s res://tests/generate_modern_geometry.gd -- <adapters>
godot --headless --path <cont> -s res://tests/check_modern_geometry.gd -- ussr_t_80b germ_leopard_2a4   # 29/29 ✓
godot --headless --path <cont> -s res://tests/probe_package_layers.gd                                  # 期望 T-80B 4 → 0
```
## 验收 ✓
`armor_patches(part barrel)` 的 4 条非流形边**消失** ✓，且 `check_modern_geometry` 仍 **29/29** ✓；若否则**逐字节回退** ✗。
