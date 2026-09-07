# 004-R2 前置：GPT 要求"先用当前实现运行对应反例，再修复"。
# 运行：godot --headless --path <root> -s res://tests/r2_counterexamples.gd
# 输出 docs/evidence/004-R2/counterexamples.json + 控制台摘要。本脚本只读现状，不改任何东西。

extends SceneTree

var _out := {}


func _init() -> void:
	_cam_counterexample()
	_openings_counterexample()
	_bounds_counterexample()
	_evidence_counterexample()
	var f := FileAccess.open("res://docs/evidence/004-R2/counterexamples.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_out, "  "))
	f.close()
	print("R2_COUNTEREXAMPLES_SAVED")
	quit(0)


func _cam_counterexample() -> void:
	# 当前 _update_camera：pitch 固定限幅 -10..80，focus=(0,1.7,0)，dist 3..30。
	# 相机高度 = 1.7 + dist*sin(pitch)。dist=30, pitch=-10 → 1.7-5.209 = -3.509 < 0.13（地面 -0.02+0.15）。
	var rows := []
	for dist in [3.0, 9.0, 30.0]:
		for pitch in [-10.0, 0.0, 18.0]:
			var y: float = 1.7 + dist * sin(deg_to_rad(pitch))
			rows.append({"dist": dist, "pitch_deg": pitch, "camera_y": y, "below_min_y_0_13": y < 0.13})
	_out["camera"] = {
		"claim": "fixed -10 deg pitch floor is unsafe at long distance: y = focus.y + dist*sin(pitch); at 30m/-10deg camera sinks below ground clearance 0.13m",
		"min_camera_y": 0.13,
		"rows": rows,
	}


func _openings_counterexample() -> void:
	# 当前 check_declared_openings：边界边两端点都在某 boundary_loop 顶点集合即豁免——
	# 不检查"相邻对"。反例 1：边界边 BD（对角线）被环 A->B->C->D->A 豁免。
	var l1 := _mini_layout("r2_diag", [
		{"id": "p1", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
		{"id": "p2", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], "tris": [0, 1, 2]},
		{"id": "p3", "verts": [Vector3(1, 0, 0), Vector3(1, 0, 2), Vector3(0, 0, 1)], "tris": [0, 1, 2]},
	], [{"id": "o1", "part": "p", "boundary_loop": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]}])
	var e1 := PackedStringArray()
	var w1 := PackedStringArray()
	LayoutValidator.check_declared_openings(l1, e1, w1)
	# 反例 2：重复三角形（同向）边计数 f+r=3，当前实现收集为边界边并可被环豁免。
	var l2 := _mini_layout("r2_dup", [
		{"id": "p1", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
		{"id": "p2", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [{"id": "o1", "part": "p", "boundary_loop": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]}])
	var e2 := PackedStringArray()
	var w2 := PackedStringArray()
	LayoutValidator.check_declared_openings(l2, e2, w2)
	_out["openings"] = {
		"diagonal_claim": "boundary edge BD (diagonal of loop A->B->C->D->A) is exempted because B and D are both loop vertices (not adjacent pair)",
		"diagonal_errors": e1.size(),
		"duplicate_triangle_claim": "duplicate same-direction triangle edge counts f+r=3; current code treats as boundary edge and can exempt via loop",
		"duplicate_errors": e2.size(),
	}


func _bounds_counterexample() -> void:
	# 当前 _inside_bounds：相交即"在界内"。模块盒 (-0.05..0.45) 与车辆 bbox (0..10) 相交但大部分在外。
	var corners := PackedVector3Array([
		Vector3(-0.05, 0, 0), Vector3(0.45, 0, 0), Vector3(-0.05, 0.5, 0), Vector3(0.45, 0.5, 0),
		Vector3(-0.05, 0, 0.5), Vector3(0.45, 0, 0.5), Vector3(-0.05, 0.5, 0.5), Vector3(0.45, 0.5, 0.5)])
	var bounds := {"min": Vector3(0, 0, 0), "max": Vector3(10, 10, 10)}
	_out["bounds"] = {
		"claim": "_inside_bounds uses intersection, not containment: a box mostly outside the vehicle is judged inside",
		"box_min": str(Vector3(-0.05, 0, 0)),
		"vehicle_min": str(bounds["min"]),
		"current_inside_verdict": LayoutValidator._inside_bounds(corners, bounds),
		"containment_verdict_expected": false,
	}


func _evidence_counterexample() -> void:
	# 当前 _check_keys：只查 key 登记/origin==test_fixture/applies_to 非空。
	# 反例 1：错误车型来源（applies_to 非空但属于另一车型）不被拒绝。
	# 反例 2：岗位依据（EV-FM1767-CREW）被拿去证明装甲厚度——当前不检查字段绑定。
	var doc := {
		"evidence_keys": [
			{"key": "EV-OTHER-TANK", "origin": "historical_primary", "applies_to": "M4A2 (75mm dry stowage)", "applies_to_identity_ids": ["us_m4a2_75w_dry"], "excluded_identity_ids": [], "title": "other vehicle manual"},
			{"key": "EV-FM1767-CREW", "origin": "historical_primary", "applies_to": "Medium Tank M4 series (5-man crew)", "applies_to_identity_ids": ["us_m4a3_75w_vvss_1944"], "excluded_identity_ids": [], "title": "crew drill"},
		],
		"fields": [
			{"field_path": "crew_stations.*.role_placement", "status": "verified", "source_refs": ["EV-FM1767-CREW"]},
		]
	}
	var layout := _mini_layout("r2_ev", [
		{"id": "p1", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [])
	layout.content_tier = "research"
	layout.historical_identity_id = "us_m4a3_75w_vvss_1944"
	layout.armor_patches[0].evidence_keys = PackedStringArray(["EV-OTHER-TANK"])
	var e1 := PackedStringArray()
	LayoutValidator.check_evidence_consistency(layout, doc, e1)
	layout.armor_patches[0].evidence_keys = PackedStringArray(["EV-FM1767-CREW"])
	layout.armor_patches[0].thickness_status = "verified"
	layout.armor_patches[0].has_thickness = true
	layout.armor_patches[0].thickness_mm = 50.0
	var e2 := PackedStringArray()
	LayoutValidator.check_evidence_consistency(layout, doc, e2)
	_out["evidence"] = {
		"wrong_vehicle_claim": "applies_to is non-empty text for another vehicle; current check does not reject",
		"wrong_vehicle_errors": e1.size(),
		"crew_for_thickness_claim": "crew placement source used as armor thickness backing; current check has no field binding",
		"crew_for_thickness_errors": e2.size(),
	}


func _mini_layout(id: String, patches: Array, openings: Array) -> VehicleLayoutDefinition:
	var l := VehicleLayoutDefinition.new()
	l.id = id
	l.content_tier = "research"
	l.display_name = id
	l.historical_identity_id = "us_m4a3_75w_vvss_1944"
	var part := LayoutPartDefinition.new()
	part.id = "p"
	part.parent_id = ""
	part.joint_kind = "fixed"
	part.bind_local = Transform3D.IDENTITY
	l.parts = [part]
	for p in patches:
		var patch := ArmorPatchDefinition.new()
		patch.id = p["id"]
		patch.part_id = "p"
		patch.vertices_local_m = PackedVector3Array(p["verts"])
		patch.triangles = PackedInt32Array(p["tris"])
		patch.outward_normal_local = Vector3(0, -1, 0)
		patch.has_thickness = false
		patch.thickness_status = "unknown"
		patch.material_kind = "unknown"
		patch.geometry_status = "estimated"
		l.armor_patches.append(patch)
	var declared: Array[Dictionary] = []
	for o in openings:
		declared.append({"id": o["id"], "part": o["part"], "boundary_loop": PackedVector3Array(o["boundary_loop"]), "note": "r2 fixture"})
	l.declared_openings = declared
	return l