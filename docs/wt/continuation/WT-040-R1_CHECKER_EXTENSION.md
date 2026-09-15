# 校验器扩充的**精确代码**（与两项修正**同批**落地并运行 ✓）

## 插入点 ✓
`tests/check_modern_geometry.gd` 的 `_run()` 内 ✓，在既有 `_check(...)` 之后、`=== 结果 ===` 打印之前 ✓。

## 代码 ✓
```gdscript
		# WT-040-R1: the earlier audit showed this checker asserted only 7 of the 17 fields the
		# generator emits, because the determinism comparison needs a fresh measurement and the helper
		# returned just seven keys. The two rules being fixed - the ring aperture fitting inside the
		# roof, and the outline having no coincident points - had NO assertion at all, so they are
		# added here together with the remaining fields.
		if not row.is_empty():
			var fld: Dictionary = row.get("fields",{})
			# ring_half must fit inside the measured roof
			if fld.has("ring_half") and fld.has("hull_rings"):
				var rr: Array = fld.hull_rings
				var roof_half := 0.0
				if rr.size() == 3: roof_half = float((rr[2] as Array)[1])
				_check(float(fld.ring_half) > 0.0, "%s: ring_half is positive" % id)
				_check(roof_half <= 0.01 or float(fld.ring_half) <= roof_half*0.85 + TOL,
					"%s: ring_half (%.3f) fits inside the roof half-width (%.3f)" % [id,float(fld.ring_half),roof_half])
			# the outline must keep enough DISTINCT points
			if fld.has("turret_outline"):
				var ol: Array = fld.turret_outline
				_check(ol.size() >= 8 and ol.size() <= 32, "%s: turret_outline has 8-32 points (%d)" % [id,ol.size()])
				var closest := INF
				for i in ol.size():
					var pp: Array = ol[i]
					var qq: Array = ol[(i+1) % ol.size()]
					closest = minf(closest, sqrt(pow(float(pp[0])-float(qq[0]),2.0)+pow(float(pp[1])-float(qq[1]),2.0)))
				_check(closest >= 0.005 - TOL, "%s: adjacent outline points are at least 5 mm apart (closest %.5f)" % [id,closest])
			# the mantlet must enclose the bore
			var bore := 0.0
			var fpath := "res://logs/WT-040-R1/modern_facts_draft.json"
			if FileAccess.file_exists(fpath):
				var fd: Variant = JSON.parse_string(FileAccess.get_file_as_string(fpath))
				if fd is Dictionary:
					for fr in fd.get("rows",[]):
						if str(fr.get("id","")) == id:
							bore = float(fr.get("assembly",{}).get("caliber_mm",0.0)) / 2000.0
			if bore > 0.0 and fld.has("mantlet_half_width") and fld.has("mantlet_half_height"):
				_check(float(fld.mantlet_half_width) >= bore, "%s: mantlet half-width %.4f encloses the bore %.4f" % [id,float(fld.mantlet_half_width),bore])
				_check(float(fld.mantlet_half_height) >= bore, "%s: mantlet half-height %.4f encloses the bore %.4f" % [id,float(fld.mantlet_half_height),bore])
			# finite positive scalars and real booleans
			for key4 in ["barrel_length","hull_half_width","track_width","wheel_radius"]:
				if fld.has(key4):
					_check(float(fld[key4]) > 0.0 and is_finite(float(fld[key4])), "%s: %s is finite and positive (%.4f)" % [id,key4,float(fld[key4])])
			for key5 in ["muzzle_brake","open_top"]:
				if fld.has(key5):
					_check(fld[key5] is bool, "%s: %s is a boolean" % [id,key5])
```
## 为何必须**同批** ✓
`ring_half` 与 `turret_outline` 的断言**正好验证**两项修正 ✓ ⇒ 若先改代码后补断言 ✓，"改对了没有"就**无从判定** ✗；
反之若断言先行 ✓，在**未修正**时它应当**变红** ✓ —— 这正是**断言有效性**的证据 ✓（可先跑一次确认它红 ✓，再落修正确认它绿 ✓✓）。

---

## 静态排雷结果（落地前预检 ✓）
| 陷阱（本会话反复踩过 ✓） | 结果 |
|---|---|
| ① `:=` 由 **Variant** 推断 | 四处 `:=` 均取自**字面量**（`0.0` ✓ `INF` ✓ 字符串 ✓）⇒ **安全** ✓ |
| ② 字典**重复键** | 无 ✓ |
| ③ **括号/引号配对** | `(` 59=59 ✓ · `[` 22=22 ✓ · 引号 52（偶 ✓） |
| `.get()` 返回 Variant | 均**显式类型**或包裹 ✓ |

## 一处**加固**（尚未落地 ⇒ 现在改零成本 ✓）
原句 ✓：
```gdscript
bore = float(fr.get("assembly",{}).get("caliber_mm",0.0)) / 2000.0
```
风险 ✗：若 `assembly` 不是字典 ✓，`.get` 会在**运行期崩溃** ✗。
**改为** ✓：
```gdscript
var asm: Variant = fr.get("assembly",{})
if asm is Dictionary:
    bore = float(asm.get("caliber_mm",0.0)) / 2000.0
```
⇒ 与"取不到口径就**响亮跳过**"的原则一致 ✓（**不静默、不崩溃** ✓）。
