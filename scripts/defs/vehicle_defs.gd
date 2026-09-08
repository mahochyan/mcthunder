class_name VehicleDefs
extends RefCounted
## 003：定义注册表与默认配置工厂。配置可共享（同一 Resource 被多实例引用）；
## 校验失败明确报错并定位字段，不悄悄给默认值掩盖错误。

const VEHICLE_PATH := "res://configs/player_tank_vehicle.tres"
const WEAPON_PATH := "res://configs/player_tank_weapon.tres"
const SHELL_PATH := "res://configs/ap_75_shell.tres"

var vehicles: Dictionary = {}   # id -> VehicleDefinition
var weapons: Dictionary = {}    # id -> WeaponDefinition
var shells: Dictionary = {}     # id -> ShellDefinition
var layouts: Dictionary = {}    # Validated generated layouts; legacy resources still use LayoutCatalog.
var content_packets: Dictionary = {}

func load_defaults() -> Dictionary:
	# 返回 {ok, errors}；加载三个默认 .tres 并校验
	var errors: Array[String] = []
	var v: VehicleDefinition = load(VEHICLE_PATH)
	var w: WeaponDefinition = load(WEAPON_PATH)
	var s: ShellDefinition = load(SHELL_PATH)
	if v == null:
		errors.append("load: %s failed" % VEHICLE_PATH)
	elif not v.validate().ok:
		errors.append("vehicle %s: %s" % [v.id, ", ".join(v.validate().errors)])
	if w == null:
		errors.append("load: %s failed" % WEAPON_PATH)
	elif not w.validate().ok:
		errors.append("weapon %s: %s" % [w.id, ", ".join(w.validate().errors)])
	if s == null:
		errors.append("load: %s failed" % SHELL_PATH)
	elif not s.validate().ok:
		errors.append("shell %s: %s" % [s.id, ", ".join(s.validate().errors)])
	if errors.is_empty():
		vehicles[v.id] = v
		weapons[w.id] = w
		shells[s.id] = s
	return {"ok": errors.is_empty(), "errors": errors}

func get_vehicle(id: String) -> VehicleDefinition:
	return vehicles.get(id) as VehicleDefinition

func get_weapon(id: String) -> WeaponDefinition:
	return weapons.get(id) as WeaponDefinition

func get_shell(id: String) -> ShellDefinition:
	return shells.get(id) as ShellDefinition

func resolve_vehicle(id: String) -> Dictionary:
	# 装配用：解析车辆定义及其武器/弹种引用；缺引用 → 失败并定位字段
	# 003-R2：装配边界再次校验三个定义本体——手工注册进注册表的定义
	# 不经 load_defaults() 也会在此被拦截（引用存在 ≠ 定义有效）
	var errors: Array[String] = []
	var v := get_vehicle(id)
	if v == null:
		return {"ok": false, "errors": ["vehicle_id: unknown vehicle '%s'" % id]}
	var w := get_weapon(v.weapon_id)
	if w == null:
		return {"ok": false, "errors": ["weapon_id: unknown weapon '%s' referenced by vehicle '%s'" % [v.weapon_id, v.id]]}
	var s := get_shell(w.shell_id)
	if s == null:
		return {"ok": false, "errors": ["shell_id: unknown shell '%s' referenced by weapon '%s'" % [w.shell_id, w.id]]}
	var vv := v.validate()
	if not vv.ok:
		errors.append("vehicle %s: %s" % [v.id, ", ".join(vv.errors)])
	var wv := w.validate()
	if not wv.ok:
		errors.append("weapon %s: %s" % [w.id, ", ".join(wv.errors)])
	var sv := s.validate()
	if not sv.ok:
		errors.append("shell %s: %s" % [s.id, ", ".join(sv.errors)])
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var result := {"ok": true, "vehicle": v, "weapon": w, "shell": s}
	if content_packets.has(id):
		if not layouts.has(v.layout_id): return {"ok":false,"errors":["layout_id: registered historical layout is missing"]}
		result["layout"] = layouts[v.layout_id]
		result["packet"] = content_packets[id]
	return result
