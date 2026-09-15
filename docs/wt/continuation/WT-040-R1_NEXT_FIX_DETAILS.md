# 两项几何修正的**执行细节**（敲定后即可一次落地 ✓）

## 0. 前置事实（已核实 ✓）
- 生成器 `tests/generate_modern_geometry.gd` **只读适配产物** ✓（不读档案 ✗）；
- 炮盾下限需要 **`caliber_mm`** ✓，而它**不在**适配产物里 ✗；
- 但 **`modern_facts_draft.json`** 的每行含 **`assembly.caliber_mm`** ✓（T-80B **125.0** ✓ / 豹2 **120.0** ✓，均已回查档案确认 ✓）。

## 1. 修正 ①：炮盾必须包住炮孔 ✓
**改动点** ✓：`tests/generate_modern_geometry.gd`，`mantlet` 派生处（约 165–188 行 ✓）。
**新增输入** ✓：`const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"` ✓（只读 ✓，缺则**响亮跳过** ✓）。
**逻辑** ✓：
```gdscript
var bore := 0.0
var fr: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACTS))
if fr is Dictionary:
    for r in fr.get("rows",[]):
        if str(r.get("id","")) == id:
            bore = float(r.get("assembly",{}).get("caliber_mm",0.0)) / 2000.0
if bore <= 0.0:
    row.notes.append("calibre unavailable: mantlet floor NOT applied (loud, not silent)")
else:
    var fw: float = maxf(derived_w, bore*1.6)
    var fh: float = maxf(derived_h, bore*1.3)
```
**`methods` 文案** ✓：`"DERIVED ... with a floor of 1.6x / 1.3x the cited bore radius (%.4f m) so the shield encloses the hole"` ✓。
**依据** ✓：`historical_vehicle_geometry.gd:78-96` ✓（环形面 `outer(±hw,±hh) − inner(±bore)` ✓）；实测 `hh=0.054 < bore=0.0625` ✗ ⇒ 负宽环 ✓。

## 2. 修正 ②：轮廓去重 ✓
**改动点** ✓：同文件 `turret_outline` 产出处（`_convex_outline` 之后 ✓）。
**逻辑** ✓：
```gdscript
# 吸附后按 5 mm 去重；<8 点则响亮失败（校验器要求 8–32）
var raw: Array = _convex_outline(bot)
var dedup: Array = []
for p in raw:
    var far := true
    for q in dedup:
        if sqrt(pow(p[0]-q[0],2) + pow(p[1]-q[1],2)) < 0.005: far = false; break
    if far: dedup.append(p)
if dedup.size() < 8:
    row.notes.append("turret_outline REJECTED: only %d distinct points after 5 mm de-duplication (validator needs 8-32)" % dedup.size())
else:
    f["turret_outline"] = dedup
```
**依据** ✓：豹2 实测 15 点 ⇒ 其中**相邻最小间距 0 m** ✗（重合点 ✓）；去重后 **13** ✓ ≥ 8 ✓。

## 3. 同批验证（任一不绿即**逐字节回退** ✗）
```
godot --headless --path <cont> -s res://tests/generate_modern_geometry.gd -- <两个适配产物>
godot --headless --path <cont> -s res://tests/check_modern_geometry.gd -- ussr_t_80b germ_leopard_2a4     # 必须 29/29 ✓
godot --headless --path <cont> -s res://tests/probe_package_layers.gd                                    # 期望 T-80B 4→0 · 豹2 7→2
```
**验收** ✓：`check_modern_geometry` 仍 **29/29** ✓ 且探针的几何类错误**消失** ✓；否则回退 ✓。
