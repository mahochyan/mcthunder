class_name VehiclePreviewModel
extends Node3D

# 004-c：检视预览模型——从布局定义构建部件层级与三种显示模式。
# 只有 Node3D/网格/姿态——没有驾驶、Gunner、PlayerController 或命中信号；
# 不实例化 VehicleActor。姿态/选中/可见状态不写回共享布局定义。

signal selection_changed(id: String, kind: String)   # kind: part/patch/module/crew

const MODE_APPEARANCE := "appearance"
const MODE_ARMOR := "armor"
const MODE_INTERIOR := "interior"

# 厚度分档颜色（T004-05 参数真实映射：颜色随真实厚度数据变化）
const COLOR_UNKNOWN := Color(0.55, 0.55, 0.58)
const COLOR_ESTIMATED := Color(0.95, 0.6, 0.15)
const COLOR_THIN := Color(0.35, 0.75, 0.9)
const COLOR_MID := Color(0.3, 0.65, 0.35)
const COLOR_THICK := Color(0.85, 0.3, 0.25)
const COLOR_MODULE := Color(0.45, 0.5, 0.8)
const COLOR_CREW := Color(0.35, 0.85, 0.45)
const COLOR_HIGHLIGHT := Color(1.0, 0.95, 0.2)
const COLOR_APPEARANCE := Color(0.52, 0.54, 0.5)

var layout: VehicleLayoutDefinition
var mode: String = MODE_APPEARANCE
var selected_patch_id := ""
var _part_nodes: Dictionary = {}        # part_id -> Node3D
var _patch_nodes: Dictionary = {}       # patch_id -> MeshInstance3D
var _wire_nodes: Dictionary = {}        # patch_id -> MeshInstance3D
var _module_nodes: Dictionary = {}      # module_id -> MeshInstance3D
var _crew_nodes: Dictionary = {}        # station_id -> MeshInstance3D
var _extra_nodes: Array[Node] = []      # 外观附加件（履带/炮管）


func setup(l: VehicleLayoutDefinition) -> void:
	layout = l
	for child in get_children():
		child.queue_free()
	_part_nodes.clear()
	_patch_nodes.clear()
	_wire_nodes.clear()
	_crew_nodes.clear()
	_module_nodes.clear()
	_extra_nodes.clear()

	# 部件层级（bind transform 挂局部变换）
	var node_map: Dictionary = {}
	for part in layout.parts:
		if part == null:
			continue
		var n := Node3D.new()
		n.name = "Part_" + part.id
		n.transform = part.bind_local
		node_map[part.id] = n
		_part_nodes[part.id] = n
	for part in layout.parts:
		if part == null:
			continue
		var n: Node3D = node_map[part.id]
		if part.parent_id != "" and node_map.has(part.parent_id):
			(node_map[part.parent_id] as Node3D).add_child(n)
		else:
			add_child(n)

	_build_appearance_extras()
	_build_patches()
	_build_interior()
	set_mode(mode)


func _build_patches() -> void:
	for patch in layout.armor_patches:
		if patch == null or not _part_nodes.has(patch.part_id):
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Patch_" + patch.id
		var mesh := ArmorPatchMesh.build_surface(patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		if mesh != null:
			mi.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _thickness_color(patch)
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mi.material_override = mat   # 实例材质覆盖——不改共享定义/共享材质
			(_part_nodes[patch.part_id] as Node3D).add_child(mi)
			_patch_nodes[patch.id] = mi
		var wire := MeshInstance3D.new()
		wire.name = "Wire_" + patch.id
		var wmesh := ArmorPatchMesh.build_wire(patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		if wmesh != null:
			var wmat := StandardMaterial3D.new()
			wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wmat.albedo_color = Color(0.1, 0.1, 0.12)
			wire.mesh = wmesh
			wire.material_override = wmat
			wire.visible = false
			(_part_nodes[patch.part_id] as Node3D).add_child(wire)
			_extra_nodes.append(wire)


func _build_interior() -> void:
	for module in layout.modules:
		if module == null:
			continue
		if not _part_nodes.has(module.part_id):
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Module_" + module.id
		var mesh := BoxMesh.new()
		mesh.size = module.size_m
		mi.mesh = mesh
		mi.transform = module.local_box_transform
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_MODULE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		mi.material_override = mat
		mi.visible = false
		(_part_nodes[module.part_id] as Node3D).add_child(mi)
		_module_nodes[module.id] = mi
	for station in layout.crew_stations:
		if station == null:
			continue
		if not _part_nodes.has(station.part_id):
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Crew_" + station.id
		var mesh := BoxMesh.new()
		mesh.size = station.size_m
		mi.mesh = mesh
		mi.transform = station.local_box_transform
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_CREW
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.9
		mi.material_override = mat
		mi.visible = false
		(_part_nodes[station.part_id] as Node3D).add_child(mi)
		_crew_nodes[station.id] = mi


func _build_appearance_extras() -> void:
	# 外观附加件：履带外形（低模）+ 主炮管——让轮廓有辨识度，不是一个方盒
	if not _part_nodes.has("hull"):
		return
	var hull_node: Node3D = _part_nodes["hull"]
	for module in layout.modules:
		if module != null and module.external and module.kind == "track":
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = module.size_m
			mi.mesh = mesh
			mi.transform = module.local_box_transform
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.25, 0.28)
			mi.material_override = mat
			hull_node.add_child(mi)
			_extra_nodes.append(mi)
	if _part_nodes.has("gun"):
		var gun_node: Node3D = _part_nodes["gun"]
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel_LowPoly"
		var bmesh := BoxMesh.new()
		# M4A3 75mm M3：管长约 3.9 m，口径 0.075 m（长度 estimated 外观近似）
		barrel.mesh = BoxMesh.new()
		(barrel.mesh as BoxMesh).size = Vector3(0.09, 0.09, 3.1)
		barrel.position = Vector3(0, 0, -2.0)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.4, 0.42, 0.45)
		barrel.material_override = gmat
		gun_node.add_child(barrel)
		_extra_nodes.append(barrel)
		# 炮盾外观（estimated 方块，随炮俯仰）
		var mantlet := MeshInstance3D.new()
		mantlet.mesh = BoxMesh.new()
		(mantlet.mesh as BoxMesh).size = Vector3(1.0, 0.9, 0.35)
		mantlet.position = Vector3(0, 0, -0.45)
		mantlet.material_override = gmat
		gun_node.add_child(mantlet)
		_extra_nodes.append(mantlet)


func set_mode(m: String) -> void:
	mode = m
	var show_wires := m == MODE_ARMOR
	for patch_id in _patch_nodes.keys():
		var mi: MeshInstance3D = _patch_nodes[patch_id]
		mi.visible = m != MODE_INTERIOR
		if m == MODE_ARMOR or m == MODE_APPEARANCE:
			var mat := mi.material_override as StandardMaterial3D
			if mat != null:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = 1.0
		elif m == MODE_INTERIOR:
			var mat2 := mi.material_override as StandardMaterial3D
			if mat2 != null:
				mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat2.albedo_color.a = 0.12
	for wire in _extra_nodes:
		if wire.name.begins_with("Wire_"):
			wire.visible = show_wires
	for mid in _module_nodes.keys():
		var mod_mi: MeshInstance3D = _module_nodes[mid]
		mod_mi.visible = m == MODE_INTERIOR
	for cid in _crew_nodes.keys():
		var crew_mi: MeshInstance3D = _crew_nodes[cid]
		crew_mi.visible = m == MODE_INTERIOR
	for extra in _extra_nodes:
		if not extra.name.begins_with("Wire_"):
			extra.visible = m != MODE_INTERIOR


func set_pose(yaw_deg: float, pitch_deg: float) -> Dictionary:
	# 走 LayoutMath 正式路径（bind_local * 关节旋转，绕部件自身 bind 原点）
	var result := {"yaw_applied": 0.0, "pitch_applied": 0.0}
	var yaw_def := _find_joint("yaw")
	var pitch_def := _find_joint("pitch")
	if yaw_def != null:
		var posed := LayoutMath.posed_local(yaw_def.bind_local, "yaw", yaw_deg, yaw_def.min_angle_deg, yaw_def.max_angle_deg)
		if posed["ok"]:
			(_part_nodes[yaw_def.id] as Node3D).transform = posed["transform"]
			result["yaw_applied"] = posed["applied_deg"]
	if pitch_def != null:
		var posed2 := LayoutMath.posed_local(pitch_def.bind_local, "pitch", pitch_deg, pitch_def.min_angle_deg, pitch_def.max_angle_deg)
		if posed2["ok"]:
			(_part_nodes[pitch_def.id] as Node3D).transform = posed2["transform"]
			result["pitch_applied"] = posed2["applied_deg"]
	return result


func _find_joint(kind: String) -> LayoutPartDefinition:
	for part in layout.parts:
		if part != null and part.joint_kind == kind:
			return part
	return null


func get_visual_center() -> Vector3:
	# 004-R2-A：当前预览几何包围盒中心（面片+模块+乘员；地面/灯光不是本模型子节点，天然排除）。
	# 切换布局后观察中心跟随模型，不固定在某车型的炮塔环上方。
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for n in _part_nodes.values():
		var node := n as Node3D
		if node == null:
			continue
		for child in node.get_children():
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				var aabb := mi.get_aabb()
				if aabb.size == Vector3.ZERO:
					continue
				var g := mi.global_transform
				for i in range(8):
					var w: Vector3 = g * aabb.get_endpoint(i)
					mn = mn.min(w)
					mx = mx.max(w)
	if mn == Vector3.INF:
		return Vector3(0, 1.0, 0)
	return (mn + mx) * 0.5


func select_patch(patch_id: String) -> void:
	if selected_patch_id != "" and _patch_nodes.has(selected_patch_id):
		_restore_patch_color(_patch_nodes[selected_patch_id] as MeshInstance3D, selected_patch_id)
	selected_patch_id = patch_id
	if patch_id != "" and _patch_nodes.has(patch_id):
		var mi := _patch_nodes[patch_id] as MeshInstance3D
		# 选中高亮：实例自己的材质覆盖（不改共享定义/共享材质）
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_HIGHLIGHT
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.32, 0.05)
		mi.material_override = mat
	selection_changed.emit(patch_id, "patch")


func _select_box(id: String, nodes: Dictionary, restore_func: Callable) -> void:
	# 004-R1 组A：模块/乘员选中高亮（四类统一；实例材质覆盖，不改共享定义）
	if selected_patch_id != "":
		if _patch_nodes.has(selected_patch_id):
			_restore_patch_color(_patch_nodes[selected_patch_id] as MeshInstance3D, selected_patch_id)
		selected_patch_id = ""
	for key in nodes.keys():
		var mi: MeshInstance3D = nodes[key]
		if key == id:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = COLOR_HIGHLIGHT
			mat.emission_enabled = true
			mat.emission = Color(0.35, 0.32, 0.05)
			mi.material_override = mat
		else:
			restore_func.call(mi)
	selection_changed.emit(id, "")


func select_module(module_id: String) -> void:
	_select_box(module_id, _module_nodes, _restore_module_color)


func select_crew(station_id: String) -> void:
	_select_box(station_id, _crew_nodes, _restore_crew_color)


func clear_selection() -> void:
	select_patch("")


func _restore_module_color(mi: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_MODULE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	mi.material_override = mat


func _restore_crew_color(mi: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CREW
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mi.material_override = mat


func _restore_patch_color(mi: MeshInstance3D, patch_id: String) -> void:
	for patch in layout.armor_patches:
		if patch != null and patch.id == patch_id:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _thickness_color(patch)
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mi.material_override = mat
			return


func _thickness_color(patch: ArmorPatchDefinition) -> Color:
	# 参数真实映射：颜色来自真实数据（T004-05）
	if not patch.has_thickness:
		return COLOR_UNKNOWN   # 厚度未知——显示灰色"未知"，不是 0 mm
	if patch.thickness_status == "estimated":
		return COLOR_ESTIMATED
	if patch.thickness_mm <= 25.0:
		return COLOR_THIN
	if patch.thickness_mm <= 50.0:
		return COLOR_MID
	return COLOR_THICK


func patch_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for patch in layout.armor_patches:
		if patch != null:
			ids.append(patch.id)
	return ids