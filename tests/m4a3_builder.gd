# 004-b：M4A3（75）W 历史研究布局生成器。
# 运行：godot --headless --path <root> -s res://tests/m4a3_builder.gd
# 生成 configs/layouts/us_m4a3_75w_vvss_1944.tres。
# 依据：docs/vehicles/us_m4a3_75w_vvss_1944/（IDENTITY/FIELD_EVIDENCE/GEOMETRY_NOTES）。
# 坐标：根原点 = 炮塔回转轴接地投影；-Z 前；米；乘员/模块/面片状态按档案标注。
# 装甲厚度全部 unknown（TM 9-759 无厚度表，图板未核验）——不填数。

extends SceneTree

const E_ID := "EV-TM9759-IDENTITY"
const E_SPECS := "EV-TM9759-SPECS"
const E_ENGINE := "EV-TM9759-ENGINE"
const E_TRANS := "EV-TM9759-TRANS"
const E_TFLOOR := "EV-TM9759-TURRET-FLOOR"
const E_STOW := "EV-TM9759-STOWAGE"
const E_GEN := "EV-TM9759-GEN"
const E_RADIO := "EV-TM9759-RADIO"
const E_TRAVERSE := "EV-TM9759-TRAVERSE"
const E_CREW := "EV-FM1767-CREW"


func _init() -> void:
	var layout := _build()
	LayoutCatalog.register_evidence(_evidence_keys())
	var validation := LayoutValidator.validate(layout, _evidence_keys())
	if validation["errors"].is_empty():
		var ok := ResourceSaver.save(layout, "res://configs/layouts/us_m4a3_75w_vvss_1944.tres")
		if ok == OK:
			print("M4A3_LAYOUT_OK: us_m4a3_75w_vvss_1944 saved")
		else:
			printerr("M4A3_LAYOUT FAIL: save error %d" % ok)
	else:
		for e in validation["errors"]:
			printerr("M4A3_LAYOUT FAIL: " + e)
	quit(0 if validation["errors"].is_empty() else 1)


func _evidence_keys() -> PackedStringArray:
	return PackedStringArray([E_ID, E_SPECS, E_ENGINE, E_TRANS, E_TFLOOR, E_STOW, E_GEN, E_RADIO, E_TRAVERSE, E_CREW])


func _rigid(origin: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin)


func _part(id: String, parent: String, origin: Vector3, joint: String, min_deg: float, max_deg: float, keys: PackedStringArray) -> LayoutPartDefinition:
	var p := LayoutPartDefinition.new()
	p.id = id
	p.parent_id = parent
	p.bind_local = _rigid(origin)
	p.joint_kind = joint
	p.min_angle_deg = min_deg
	p.max_angle_deg = max_deg
	p.evidence_keys = keys
	return p


func _append_patch(layout: VehicleLayoutDefinition, id: String, part_id: String, corners: PackedVector3Array, normal: Vector3, keys: Array) -> void:
	# 装甲面片：几何 estimated（按 verified 总尺寸拟合的低模）；
	# 厚度 unknown（has_thickness=false——不显示 0 mm，不冒充已核验）
	var patch := ArmorPatchDefinition.new()
	patch.id = id
	patch.plate_group_id = "m4a3_hull" if part_id == "hull" else "m4a3_turret"
	patch.part_id = part_id
	patch.vertices_local_m = corners
	patch.triangles = _tri_for_quad(corners, normal)
	patch.outward_normal_local = normal
	patch.has_thickness = false
	patch.thickness_mm = 0.0
	patch.thickness_status = "unknown"
	patch.material_kind = "unknown"   # 铸造/轧制分配需图版核验
	patch.geometry_status = "estimated"
	patch.evidence_keys = PackedStringArray(keys)
	layout.armor_patches.append(patch)


func _tri_for_quad(corners: PackedVector3Array, normal: Vector3) -> PackedInt32Array:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		return PackedInt32Array([0, 1, 2, 0, 2, 3])
	return PackedInt32Array([0, 2, 1, 0, 3, 2])


func _module(id: String, kind: String, part: String, origin: Vector3, size: Vector3, keys: Array, status := "estimated") -> ModuleVolumeDefinition:
	var m := ModuleVolumeDefinition.new()
	m.id = id
	m.kind = kind
	m.part_id = part
	m.local_box_transform = _rigid(origin)
	m.size_m = size
	m.external = false
	m.geometry_status = status
	m.evidence_keys = PackedStringArray(keys)
	return m


func _crew(id: String, role: String, part: String, origin: Vector3, box_size: Vector3) -> CrewStationDefinition:
	var c := CrewStationDefinition.new()
	c.id = id
	c.role = role
	c.part_id = part
	c.local_box_transform = _rigid(origin)
	c.size_m = box_size
	# 004-R1 组C：岗位/相对方位 verified（FM 17-67 §3/§4b 文字核验）；
	# 方盒实际中心坐标 estimated（手册不支持精确到米的座位中心）。
	c.role_placement_status = "verified"
	c.position_status = "estimated"
	c.volume_status = "estimated"
	c.evidence_keys = PackedStringArray([E_CREW])
	return c


func _append_polygon(layout: VehicleLayoutDefinition, id: String, part_id: String, verts: PackedVector3Array, tris: PackedInt32Array, normal: Vector3, keys: Array) -> void:
	# 004-R1 组B：任意多边形面片（带折点/带孔）；绕向由调用方保证与外法线一致。
	var patch := ArmorPatchDefinition.new()
	patch.id = id
	patch.plate_group_id = "m4a3_hull" if part_id == "hull" else "m4a3_turret"
	patch.part_id = part_id
	patch.vertices_local_m = verts
	patch.triangles = tris
	patch.outward_normal_local = normal
	patch.has_thickness = false
	patch.thickness_mm = 0.0
	patch.thickness_status = "unknown"
	patch.material_kind = "unknown"
	patch.geometry_status = "estimated"
	patch.evidence_keys = PackedStringArray(keys)
	layout.armor_patches.append(patch)


func _build() -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.schema_version = 1
	layout.id = "us_m4a3_75w_vvss_1944"
	layout.historical_identity_id = "us_m4a3_75w_vvss_1944"
	layout.content_tier = "research"
	layout.display_name = "M4A3 (75) W Sherman - 1944 reference configuration (VVSS, wet stowage)"
	layout.source_catalog_id = "SRC-TM9-759"
	layout.field_evidence_id = "FIELD-EVIDENCE-US-M4A3-75W-1944"

	# --- 部件层级：hull -> turret -> gun ---
	# 根原点 = 炮塔回转轴接地投影（estimated 站位居车体中部）
	var hull := _part("hull", "", Vector3.ZERO, "fixed", 0.0, 0.0, PackedStringArray([E_SPECS]))
	# 炮塔环面高 estimated 1.72 m（车体顶处环座）
	var turret := _part("turret", "hull", Vector3(0, 1.72, 0), "yaw", 0.0, 360.0, PackedStringArray([E_TRAVERSE, E_SPECS]))
	# 火炮俯仰轴 estimated：炮塔内 (0, 0.32, -0.3)
	var gun := _part("gun", "turret", Vector3(0, 0.32, -0.3), "pitch", -25.0, 20.0, PackedStringArray([E_ID]))
	layout.parts = [hull, turret, gun]

	# --- 车体装甲面片（estimated 几何；厚度 unknown） ---
	# 尺度锚点 verified：长 6.274 / 宽 2.667 / 高 3.375 / 履带中心距 2.108。
	# 车体本体（estimated 拟合）：z -2.95..+2.92，x ±1.15，y 0..1.72
	var hw := 1.15
	var zf := 2.95
	var zr := 2.92
	var roof := 1.72

	# 前上斜面（estimated 拟合：顶缘 y=1.72 z=-2.45，底 y=1.0 z=-2.95；
	# 斜面向量 (0,0.72,0.5) → 外法线 (0,0.5,-0.72) 归一化——校验器要求法线垂直于面片）
	_append_patch(layout, "hull_front_upper", "hull", PackedVector3Array([
		Vector3(-hw, 1.0, -zf),
		Vector3(hw, 1.0, -zf),
		Vector3(hw, roof, -zf + 0.5),
		Vector3(-hw, roof, -zf + 0.5)]), Vector3(0, 0.5, -0.72).normalized(), [E_SPECS])
	# 前下垂直面
	_append_patch(layout, "hull_front_lower", "hull", PackedVector3Array([
		Vector3(-hw, 0.0, -zf),
		Vector3(hw, 0.0, -zf),
		Vector3(hw, 1.0, -zf),
		Vector3(-hw, 1.0, -zf)]), Vector3(0, 0, -1), [E_SPECS])
	# 后垂直面
	_append_patch(layout, "hull_rear", "hull", PackedVector3Array([
		Vector3(hw, 0.0, zr),
		Vector3(-hw, 0.0, zr),
		Vector3(-hw, roof, zr),
		Vector3(hw, roof, zr)]), Vector3(0, 0, 1), [E_SPECS])
	# 左右侧板（004-R1 组B：5 顶点含前甲折点 (±1.15, 1.0, -2.95)——修复每侧 0.25m² 三角缺口）
	_append_polygon(layout, "hull_left", "hull", PackedVector3Array([
		Vector3(-hw, 0.0, 2.92),
		Vector3(-hw, 0.0, -zf),
		Vector3(-hw, 1.0, -zf),
		Vector3(-hw, roof, -zf + 0.5),
		Vector3(-hw, roof, 2.92)]), PackedInt32Array([0, 2, 1, 0, 3, 2, 0, 4, 3]), Vector3(-1, 0, 0), [E_SPECS])
	_append_polygon(layout, "hull_right", "hull", PackedVector3Array([
		Vector3(hw, 0.0, 2.92),
		Vector3(hw, 0.0, -zf),
		Vector3(hw, 1.0, -zf),
		Vector3(hw, roof, -zf + 0.5),
		Vector3(hw, roof, 2.92)]), PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 4]), Vector3(1, 0, 0), [E_SPECS])
	# 顶板（004-R1 组B：挖炮塔环开口——内环方形近似 ±0.95，环径未核验登记 OPEN_QUESTIONS）
	var ring_loop := PackedVector3Array([
		Vector3(-0.95, roof, 0.95),
		Vector3(0.95, roof, 0.95),
		Vector3(0.95, roof, -0.95),
		Vector3(-0.95, roof, -0.95)])
	_append_polygon(layout, "hull_top", "hull", PackedVector3Array([
		Vector3(-hw, roof, 2.92),
		Vector3(hw, roof, 2.92),
		Vector3(hw, roof, -zf + 0.5),
		Vector3(-hw, roof, -zf + 0.5),
		ring_loop[0], ring_loop[1], ring_loop[2], ring_loop[3]]),
		PackedInt32Array([0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7]),
		Vector3(0, 1, 0), [E_SPECS])
	# 底板
	_append_patch(layout, "hull_bottom", "hull", PackedVector3Array([
		Vector3(-hw, 0.0, -zf),
		Vector3(hw, 0.0, -zf),
		Vector3(hw, 0.0, 2.92),
		Vector3(-hw, 0.0, 2.92)]), Vector3(0, -1, 0), [E_SPECS])

	# --- 炮塔简化平面壳（estimated；真实为铸造曲面，OPEN_QUESTIONS 登记） ---
	# 炮塔局部：bind 原点=环心（y=0 为环面）。宽 ±0.9，长 -1.1..+0.9，顶 +0.95
	# 炮塔前片（004-R1 组B：挖炮盾/火炮安装开口——内环 y 0.07..0.57, x ±0.35，随板斜面）
	var z_at := func(y: float) -> float: return -1.1 + (y / 0.95) * 0.2
	var mount_loop := PackedVector3Array([
		Vector3(-0.35, 0.07, z_at.call(0.07)),
		Vector3(-0.35, 0.57, z_at.call(0.57)),
		Vector3(0.35, 0.57, z_at.call(0.57)),
		Vector3(0.35, 0.07, z_at.call(0.07))])
	_append_polygon(layout, "turret_front", "turret", PackedVector3Array([
		Vector3(-0.9, 0.0, -1.1),
		Vector3(-0.9, 0.95, -0.9),
		Vector3(0.9, 0.95, -0.9),
		Vector3(0.9, 0.0, -1.1),
		mount_loop[0], mount_loop[1], mount_loop[2], mount_loop[3]]),
		PackedInt32Array([0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7]),
		Vector3(0, 0.2, -0.95).normalized(), [E_SPECS])
	_append_patch(layout, "turret_right", "turret", PackedVector3Array([
		Vector3(0.9, 0.0, -1.1), Vector3(0.9, 0.0, 0.9),
		Vector3(0.9, 0.95, 0.9), Vector3(0.9, 0.95, -0.9)]), Vector3(1, 0, 0), [E_SPECS])
	_append_patch(layout, "turret_left", "turret", PackedVector3Array([
		Vector3(-0.9, 0.0, 0.9), Vector3(-0.9, 0.0, -1.1),
		Vector3(-0.9, 0.95, -0.9), Vector3(-0.9, 0.95, 0.9)]), Vector3(-1, 0, 0), [E_SPECS])
	_append_patch(layout, "turret_back", "turret", PackedVector3Array([
		Vector3(-0.9, 0.0, 0.9), Vector3(0.9, 0.0, 0.9),
		Vector3(0.9, 0.95, 0.9), Vector3(-0.9, 0.95, 0.9)]), Vector3(0, 0, 1), [E_SPECS])
	_append_patch(layout, "turret_top", "turret", PackedVector3Array([
		Vector3(-0.9, 0.95, 0.9), Vector3(0.9, 0.95, 0.9),
		Vector3(0.9, 0.95, -0.9), Vector3(-0.9, 0.95, -0.9)]), Vector3(0, 1, 0), [E_SPECS])

	# --- 内部模块（方盒；位置 estimated 除注明 verified） ---
	var mods: Array[ModuleVolumeDefinition] = []
	mods.append(_module("engine_main", "engine", "hull", Vector3(0, 0.85, 1.9), Vector3(1.4, 0.9, 1.6), [E_ENGINE]))             # rear of hull (verified text)
	mods.append(_module("transmission", "transmission", "hull", Vector3(0, 0.85, -2.55), Vector3(1.0, 0.7, 0.8), [E_TRANS]))
	mods.append(_module("driveshaft", "driveshaft", "hull", Vector3(0, 0.25, 0.2), Vector3(0.3, 0.3, 2.6), [E_TRANS]))
	mods.append(_module("ammo_75_floor_racks", "ammo", "hull", Vector3(0, 0.35, -0.4), Vector3(1.2, 0.7, 1.8), [E_STOW, E_TFLOOR]))
	mods.append(_module("ammo_30_right_front", "ammo", "hull", Vector3(0.85, 1.35, -1.6), Vector3(0.5, 0.6, 1.2), [E_STOW]))
	mods.append(_module("ammo_30_left_sponson", "ammo", "hull", Vector3(-0.85, 1.35, -0.5), Vector3(0.35, 0.6, 0.9), [E_STOW]))
	mods.append(_module("ammo_50_right_rear", "ammo", "hull", Vector3(0.85, 1.35, 0.9), Vector3(0.35, 0.6, 0.9), [E_STOW]))
	mods.append(_module("generator_aux", "electrical", "hull", Vector3(-0.85, 1.35, 1.15), Vector3(0.4, 0.55, 0.55), [E_GEN]))
	mods.append(_module("radio_scr508", "radio", "turret", Vector3(0, 0.55, 0.75), Vector3(0.6, 0.5, 0.6), [E_RADIO]))
	mods.append(_module("turret_drive_hydraulic", "turret_drive", "turret", Vector3(-0.3, -0.25, 0.3), Vector3(0.7, 0.4, 0.7), [E_TRAVERSE]))
	mods.append(_module("breech_75mm", "breech", "gun", Vector3(0, 0, 0.3), Vector3(0.55, 0.6, 0.55), [E_ID]))
	mods.append(_module("fuel_tank", "fuel", "hull", Vector3(-0.35, 0.5, 1.95), Vector3(0.7, 0.7, 1.3), [E_SPECS]))
	var trk_l := ModuleVolumeDefinition.new()
	trk_l.id = "track_left"
	trk_l.kind = "track"
	trk_l.part_id = "hull"
	trk_l.local_box_transform = _rigid(Vector3(-1.05, 0.38, 0.0))
	trk_l.size_m = Vector3(0.5, 0.76, 4.6)
	trk_l.external = true
	trk_l.geometry_status = "estimated"
	trk_l.evidence_keys = PackedStringArray([E_SPECS])
	mods.append(trk_l)
	var trk_r := trk_l.duplicate(true)
	trk_r.id = "track_right"
	trk_r.local_box_transform = _rigid(Vector3(1.05, 0.38, 0.0))
	mods.append(trk_r)
	layout.modules = mods

	# --- 五名乘员（FM 17-67 岗位/相对方位 verified；方盒中心与大小 estimated——004-R1 组C 拆分） ---
	var crew: Array[CrewStationDefinition] = []
	crew.append(_crew("crew_commander", "commander", "turret", Vector3(0.5, 0.15, 0.5), Vector3(0.55, 1.15, 0.5)))
	crew.append(_crew("crew_gunner", "gunner", "turret", Vector3(0.55, 0.0, 0.0), Vector3(0.5, 1.0, 0.6)))
	crew.append(_crew("crew_loader", "loader", "turret", Vector3(-0.55, 0.0, 0.0), Vector3(0.5, 1.0, 0.6)))
	crew.append(_crew("crew_driver", "driver", "hull", Vector3(-0.4, 0.65, -2.5), Vector3(0.5, 1.1, 0.5)))
	crew.append(_crew("crew_bow_gunner", "assistant_driver_bow_gunner", "hull", Vector3(0.4, 0.65, -2.5), Vector3(0.5, 1.0, 0.5)))
	layout.crew_stations = crew

	# --- 真实结构开口声明（004-R1 组B：必须指向具体边界环顶点） ---
	layout.declared_openings = [
		{"id": "turret_ring", "part": "hull", "boundary_loop": [ring_loop[0], ring_loop[1], ring_loop[2], ring_loop[3]], "note": "turret ring opening in hull top plate (ring diameter unverified; square approximation of circular ring)"},
		{"id": "gun_mount_front", "part": "turret", "boundary_loop": [mount_loop[0], mount_loop[1], mount_loop[2], mount_loop[3]], "note": "gun mount opening in turret front (M34/M34A1 mount; shield split unmodeled)"},
		{"id": "turret_bottom_ring", "part": "turret", "boundary_loop": [Vector3(-0.9, 0.0, -1.1), Vector3(-0.9, 0.0, 0.9), Vector3(0.9, 0.0, 0.9), Vector3(0.9, 0.0, -1.1)], "note": "turret shell bottom edge where shell meets hull top plate at the ring (turret shell has no floor plate of its own; 75mm wet stowage has full turret floor bracket-mounted inside)"}
	]
	layout.allowed_overlaps = [
		{"a": "fuel_tank", "b": "engine_main", "reason": "fuel tank at rear area adjacent to engine compartment; wet-stowage tank position estimated (capacity 168 gal verified only)"}
	]
	return layout