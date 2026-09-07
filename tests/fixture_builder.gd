# 004-a：布局测试夹具生成器（一次性工件生成器，可重复运行）。
# 运行：godot --headless --path <root> -s res://tests/fixture_builder.gd
# 生成 configs/layouts/test_closed_hull.tres 与 test_armor_panels.tres。
# 面片绕序在构建时断言：(b-a)×(c-a) 与外法线同向，构建错误立即失败。

extends SceneTree


func _init() -> void:
	var failures := PackedStringArray()

	var hull_layout := _build_closed_hull(failures)
	var panels_layout := _build_armor_panels(failures)

	if failures.is_empty():
		var ok1 := ResourceSaver.save(hull_layout, "res://configs/layouts/test_closed_hull.tres")
		var ok2 := ResourceSaver.save(panels_layout, "res://configs/layouts/test_armor_panels.tres")
		if ok1 != OK:
			failures.append("save test_closed_hull failed: %d" % ok1)
		if ok2 != OK:
			failures.append("save test_armor_panels failed: %d" % ok2)

	if failures.is_empty():
		print("FIXTURES_OK: test_closed_hull + test_armor_panels saved")
	else:
		for f in failures:
			printerr("FIXTURE FAIL: " + f)
	quit(0 if failures.is_empty() else 1)


func _mk_hull_part() -> LayoutPartDefinition:
	var hull := LayoutPartDefinition.new()
	hull.id = "hull"
	hull.parent_id = ""
	hull.bind_local = Transform3D(Basis.IDENTITY, Vector3(10, 0, 20))
	hull.joint_kind = "fixed"
	hull.evidence_keys = PackedStringArray(["EV-TEST-FIXTURE"])
	return hull


func _check_winding(corners: PackedVector3Array, triangles: PackedInt32Array, normal: Vector3, name: String, failures: PackedStringArray) -> void:
	# 构建期断言：每个三角形 (b-a)×(c-a) 与外法线同向
	var start := 0
	while start < triangles.size():
		var a: Vector3 = corners[triangles[start]]
		var b: Vector3 = corners[triangles[start + 1]]
		var c: Vector3 = corners[triangles[start + 2]]
		if (b - a).cross(c - a).normalized().dot(normal) < 0.999:
			failures.append("%s winding disagrees with normal (tri %d)" % [name, start / 3])
		start += 3


func _tri_for_quad(corners: Array, normal: Vector3) -> PackedInt32Array:
	# corners[0..3] 为 quad 边界顺序顶点；对角线 0-2 分割，自动选与 normal 同向的绕序
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		return PackedInt32Array([0, 1, 2, 0, 2, 3])
	return PackedInt32Array([0, 2, 1, 0, 3, 2])


func _build_closed_hull(failures: PackedStringArray) -> VehicleLayoutDefinition:
	# 1m(宽,X) × 1m(高,Y) × 2m(长,Z) 封闭盒：6 面各 2 三角形，边邻接完全封闭
	var layout := VehicleLayoutDefinition.new()
	layout.schema_version = 1
	layout.id = "test_closed_hull"
	layout.historical_identity_id = ""
	layout.content_tier = "test"
	layout.display_name = "TEST ONLY: closed hull fixture (dev fixture, no historical basis)"
	layout.parts = [_mk_hull_part()]

	# 顶点（局部，米）：x=±0.5，y=0..1，z=±1（-Z 前）
	var v := [
		Vector3(-0.5, 0, -1), Vector3(0.5, 0, -1),
		Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1),
		Vector3(-0.5, 1, -1), Vector3(0.5, 1, -1),
		Vector3(0.5, 1, 1), Vector3(-0.5, 1, 1)
	]

	# 六面：quad 顶点索引 + 两个三角形 + 外法线（绕序已手工推导，构建期断言复核）
	var faces := [
		{"id": "hull_front", "n": Vector3(0, 0, -1), "q": [0, 1, 5, 4], "t": [0, 5, 1, 0, 4, 5]},
		{"id": "hull_right", "n": Vector3(1, 0, 0), "q": [1, 2, 6, 5], "t": [1, 6, 2, 1, 5, 6]},
		{"id": "hull_back", "n": Vector3(0, 0, 1), "q": [2, 3, 7, 6], "t": [2, 7, 3, 2, 6, 7]},
		{"id": "hull_left", "n": Vector3(-1, 0, 0), "q": [3, 0, 4, 7], "t": [3, 4, 0, 3, 7, 4]},
		{"id": "hull_top", "n": Vector3(0, 1, 0), "q": [4, 5, 6, 7], "t": [4, 7, 5, 5, 7, 6]},
		{"id": "hull_bottom", "n": Vector3(0, -1, 0), "q": [0, 3, 2, 1], "t": [0, 1, 2, 0, 2, 3]}
	]

	var built: Array[ArmorPatchDefinition] = []
	for face in faces:
		var arr := PackedVector3Array()
		for vi in face["q"]:
			arr.append(v[vi])
		var normal: Vector3 = face["n"]
		var tris := _tri_for_quad(arr, normal)
		_check_winding(arr, tris, normal, face["id"], failures)

		var patch := ArmorPatchDefinition.new()
		patch.id = face["id"]
		patch.plate_group_id = "test_hull"
		patch.part_id = "hull"
		patch.vertices_local_m = arr
		patch.triangles = tris
		patch.outward_normal_local = normal
		patch.has_thickness = true
		patch.thickness_mm = 40.0
		patch.thickness_status = "estimated"
		patch.material_kind = "rolled"
		patch.geometry_status = "estimated"
		patch.evidence_keys = PackedStringArray(["EV-TEST-FIXTURE"])
		built.append(patch)
	layout.armor_patches = built

	# 封闭性自检（构建期）：面片按坐标焊接为单一网格后做边邻接检查
	var welded := ArmorPatchMesh.weld_patches(layout.armor_patches)
	if welded["vertices"].is_empty():
		failures.append("closed_hull weld failed")
	else:
		var problems := LayoutValidator.check_edge_adjacency(welded["vertices"], welded["triangles"])
		for problem in problems:
			failures.append("closed_hull adjacency: " + problem)

	return layout

	return layout


func _build_armor_panels(failures: PackedStringArray) -> VehicleLayoutDefinition:
	# 九块标准板：20/40/80 mm × 0/30/60°（板外法线相对 -Z 的夹角，绕 X 轴）
	var layout := VehicleLayoutDefinition.new()
	layout.schema_version = 1
	layout.id = "test_armor_panels"
	layout.historical_identity_id = ""
	layout.content_tier = "test"
	layout.display_name = "TEST ONLY: armor panel fixture (dev fixture, no historical basis)"
	layout.parts = [_mk_hull_part()]

	var patches: Array[ArmorPatchDefinition] = []
	var col := 0
	for angle_deg in [0.0, 30.0, 60.0]:
		for thickness in [20.0, 40.0, 80.0]:
			var rad := deg_to_rad(angle_deg)
			var rot := Basis(Vector3.RIGHT, rad)
			var center := Vector3(-4.0 + col * 1.2, 0.5, 0.0)
			# 板局部（竖直面，normal -Z）：bl/br/tr/tl
			var local := [
				Vector3(-0.5, -0.5, 0.0),
				Vector3(0.5, -0.5, 0.0),
				Vector3(0.5, 0.5, 0.0),
				Vector3(-0.5, 0.5, 0.0)
			]
			var corners := PackedVector3Array()
			for l in local:
				corners.append(center + rot * l)
			var normal: Vector3 = rot * Vector3(0, 0, -1)
			var tris := PackedInt32Array([0, 2, 1, 0, 3, 2])
			_check_winding(corners, tris, normal, "%dmm_%ddeg" % [int(thickness), int(angle_deg)], failures)

			var patch := ArmorPatchDefinition.new()
			patch.id = "test_panel_%dmm_%ddeg" % [int(thickness), int(angle_deg)]
			patch.plate_group_id = "test_panels"
			patch.part_id = "hull"
			patch.vertices_local_m = corners
			patch.triangles = tris
			patch.outward_normal_local = normal
			patch.has_thickness = true
			patch.thickness_mm = thickness
			patch.thickness_status = "estimated"
			patch.material_kind = "rolled"
			patch.geometry_status = "estimated"
			patch.evidence_keys = PackedStringArray(["EV-TEST-FIXTURE"])
			patches.append(patch)
		col += 1
	layout.armor_patches = patches
	return layout