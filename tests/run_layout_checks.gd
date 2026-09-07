# 004-a：布局系统无窗口检查（独立入口，与 run_checks.gd 并行）。
# 运行：godot --headless --path <root> -s res://tests/run_layout_checks.gd
# 覆盖：T004-02 部件变换（独立数值真值）、T004-03 非法数据、T004-04 几何完整性
# （边邻接封闭 + 缺口定位）、T004-05 参数真实映射、LayoutValidator 三级校验、
# LayoutCatalog 加载、T004-01 实例隔离基础（共享定义不可变）。
# 失败时退出码非 0。

extends SceneTree

var _checks := 0
var _failures := PackedStringArray()


func _ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("FAIL[%d]: %s" % [_checks, label])
		print("FAIL[%d]: %s" % [_checks, label])
	else:
		print("ok[%d]: %s" % [_checks, label])


func _finish() -> void:
	print("=== 结果: %d 项检查, %d 失败 ===" % [_checks, _failures.size()])
	print("LAYOUT_CHECKS_PASS" if _failures.is_empty() else "LAYOUT_CHECKS_FAIL")
	quit(0 if _failures.is_empty() else 1)


func _init() -> void:
	var evidence := PackedStringArray(["EV-TEST-FIXTURE"])

	# --- T004-02：部件变换（GPT 指定独立数值真值，不用待测函数生成期望） ---
	var hull_bind := Transform3D(Basis.IDENTITY, Vector3(10, 0, 20))
	var turret_bind := Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	var yaw90 := LayoutMath.posed_local(turret_bind, "yaw", 90.0, -180.0, 180.0)
	_ok(yaw90["ok"], "T004-02 turret yaw +90 accepted")
	var turret_world := LayoutMath.compose_world(hull_bind, yaw90["transform"])
	_ok(turret_world["ok"], "T004-02 turret world composed")
	var gunner_point: Vector3 = turret_world["transform"] * Vector3(0, 0, -1)
	_ok(gunner_point.distance_to(Vector3(9, 1, 20)) < 0.001,
		"T004-02 turret-local (0,0,-1) yaw+90 -> world (9,1,20), got %s" % str(gunner_point))
	var engine_point: Vector3 = hull_bind * Vector3(0, 0, 2)
	_ok(engine_point.distance_to(Vector3(10, 0, 22)) < 0.001,
		"T004-02 hull-local point unaffected by turret yaw -> (10,0,22)")
	var yaw_clamped := LayoutMath.posed_local(turret_bind, "yaw", 500.0, -180.0, 180.0)
	_ok(yaw_clamped["ok"] and absf(yaw_clamped["applied_deg"] - 180.0) < 0.001,
		"T004-02 yaw request clamped to joint limits")
	var pitch := LayoutMath.posed_local(Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), "pitch", -10.0, -20.0, 20.0)
	_ok(pitch["ok"] and absf(pitch["applied_deg"] + 10.0) < 0.001, "T004-02 pitch joint applies requested angle")
	var pitched: Transform3D = pitch["transform"]
	_ok(pitched.origin.distance_to(Vector3(0, 1.5, 0)) < 0.001,
		"T004-02 pitch rotates about part's own bind origin")
	var fixed := LayoutMath.posed_local(turret_bind, "fixed", 45.0, -1.0, 1.0)
	_ok(fixed["ok"] and fixed["applied_deg"] == 0.0, "T004-02 fixed joint ignores requested angle")
	var scaled := Transform3D(Basis.from_scale(Vector3(0.01, 0.01, 0.01)), Vector3.ZERO)
	_ok(not LayoutMath.is_rigid(scaled), "T004-03 non-rigid (scaled) transform rejected by LayoutMath")
	_ok(not LayoutMath.posed_local(scaled, "yaw", 10.0, -90.0, 90.0)["ok"],
		"T004-03 posed_local rejects non-rigid bind_local")
	_ok(not LayoutMath.posed_local(turret_bind, "spin", 10.0, -90.0, 90.0)["ok"],
		"T004-03 unknown joint_kind rejected")

	# --- box_world_corners：独立数值 ---
	var box_corners := LayoutMath.box_world_corners(
		Transform3D(Basis.IDENTITY, Vector3(10, 0, 20)),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)),
		Vector3(2, 1, 4))
	_ok(box_corners.size() == 8, "T004-02 box corners: 8 returned for valid box")
	var min_x := INF
	var max_z := -INF
	for c in box_corners:
		min_x = minf(min_x, c.x)
		max_z = maxf(max_z, c.z)
	_ok(absf(min_x - 9.0) < 0.001, "T004-02 box corners reach expected -X extent (x=9)")
	_ok(absf(max_z - 21.0) < 0.001, "T004-02 box corners reach expected +Z extent (z=21)")
	_ok(LayoutMath.box_world_corners(Transform3D(Basis.IDENTITY, Vector3.ZERO),
		Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0, 0, -1)).is_empty(),
		"T004-03 box corners: invalid size returns empty (failure, not success)")
	_ok(LayoutMath.box_world_corners(Transform3D(Basis.IDENTITY, Vector3.ZERO),
		Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(1, 1, 1)).size() == 8,
		"T004-02 box corners: valid box returns 8 corners")

	# --- T004-03：ArmorPatchMesh 几何反例 ---
	var quad := PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
	var tri_fwd := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var n_back := Vector3(0, 0, -1)
	var tri_bwd := PackedInt32Array([0, 2, 1, 0, 3, 2])
	_ok(ArmorPatchMesh.validate_geometry(quad, tri_bwd, n_back).is_empty(),
		"T004-03 valid quad with agreeing winding passes")
	_ok(ArmorPatchMesh.validate_geometry(quad, tri_fwd, n_back).size() > 0,
		"T004-03 winding against outward normal fails")
	_ok(ArmorPatchMesh.validate_geometry(
		PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ONE]),
		PackedInt32Array([0, 1, 2]), n_back).size() > 0,
		"T004-03 degenerate triangle rejected")
	var nonplanar := PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0.1)])
	_ok(ArmorPatchMesh.validate_geometry(nonplanar, tri_bwd, n_back).size() > 0,
		"T004-03 non-planar patch rejected")
	_ok(ArmorPatchMesh.validate_geometry(quad, PackedInt32Array([0, 1, 5]), n_back).size() > 0,
		"T004-03 index out of bounds rejected")
	_ok(ArmorPatchMesh.build_surface(quad, tri_bwd, n_back) != null,
		"T004-05 build_surface returns mesh for valid patch")
	_ok(ArmorPatchMesh.build_surface(quad, tri_fwd, n_back) == null,
		"T004-03 build_surface returns null for bad winding")
	_ok(ArmorPatchMesh.build_wire(quad, tri_bwd, n_back) != null,
		"T004-05 build_wire returns line mesh for valid patch")

	# --- T004-04：封闭夹具边邻接通过；删面缺口可定位 ---
	var hull_layout: VehicleLayoutDefinition = load("res://configs/layouts/test_closed_hull.tres")
	_ok(hull_layout != null and hull_layout.id == "test_closed_hull", "T004-04 closed hull fixture loads")
	if hull_layout != null:
		var welded := ArmorPatchMesh.weld_patches(hull_layout.armor_patches)
		_ok(welded["vertices"].size() == 8, "T004-04 weld: 6 quads share 8 corners")
		_ok(welded["triangles"].size() == 36, "T004-04 weld: 12 triangles indexed")
		_ok(LayoutValidator.check_edge_adjacency(welded["vertices"], welded["triangles"]).is_empty(),
			"T004-04 closed fixture fully sealed (no boundary edges)")
		var broken := PackedInt32Array(welded["triangles"])
		broken.remove_at(0)
		broken.remove_at(0)
		broken.remove_at(0)   # remove one whole triangle (3 indices)
		var boundary := LayoutValidator.check_edge_adjacency(welded["vertices"], broken)
		_ok(boundary.size() == 3, "T004-04 removing one triangle yields exactly 3 boundary edges")
		_ok(boundary.size() > 0 and boundary[0].contains(":"),
			"T004-04 boundary edges located by vertex pair (not global ignore)")

	# --- T004-05：参数真实映射 ---
	var panels: VehicleLayoutDefinition = load("res://configs/layouts/test_armor_panels.tres")
	_ok(panels != null and panels.armor_patches.size() == 9, "T004-05 panel fixture loads with 9 patches")
	if panels != null:
		var p20: ArmorPatchDefinition = null
		var p80: ArmorPatchDefinition = null
		var p30deg: ArmorPatchDefinition = null
		for patch in panels.armor_patches:
			if patch.id == "test_panel_20mm_0deg":
				p20 = patch
			elif patch.id == "test_panel_80mm_0deg":
				p80 = patch
			elif patch.id == "test_panel_40mm_30deg":
				p30deg = patch
		_ok(p20 != null and p80 != null and absf(p20.thickness_mm - 20.0) < 0.01 and absf(p80.thickness_mm - 80.0) < 0.01,
			"T004-05 thickness values stored per patch (20 vs 80 mm)")
		_ok(p30deg != null and p30deg.outward_normal_local.angle_to(Vector3(0, 0.5, -0.8660254)) < 0.01,
			"T004-05 30deg panel normal rotated in geometry (not just a label)")
		_ok(p20 != null and p80 != null and p20.thickness_mm != p80.thickness_mm,
			"T004-05 thickness differs between patches (mapping has real data)")

	# --- LayoutValidator：合法夹具零错误 ---
	var v_hull := LayoutValidator.validate(hull_layout, evidence)
	_ok(v_hull["errors"].is_empty(), "T004-04 validator: closed hull has 0 errors")
	var v_panels := LayoutValidator.validate(panels, evidence)
	_ok(v_panels["errors"].size() == 0, "T004-05 validator: panel fixture has 0 errors")

	# --- T004-03：非法数据反例（错误定位字段路径） ---
	var v_dup := LayoutValidator.validate(_dup_id(hull_layout), evidence)
	_ok(v_dup["errors"].size() > 0, "T004-03 duplicate patch id rejected")

	var orphan := _clone(hull_layout)
	orphan.id = "test_invalid_orphan"
	orphan.parts.append(_part("turret", "ghost_parent", "yaw"))
	_ok(LayoutValidator.validate(orphan, evidence)["errors"].size() > 0, "T004-03 missing parent rejected")

	var cyclic := _clone(hull_layout)
	cyclic.parts = [_part("pa", "pb", "fixed"), _part("pb", "pa", "fixed")]
	_ok(LayoutValidator.validate(cyclic, evidence)["errors"].size() > 0, "T004-03 circular parent reference rejected")

	var bad_thick := _clone(panels)
	bad_thick.armor_patches[0].thickness_mm = 0.0
	bad_thick.armor_patches[0].has_thickness = true
	_ok(LayoutValidator.validate(bad_thick, evidence)["errors"].size() > 0, "T004-03 zero declared thickness rejected")

	var fake_known := _clone(panels)
	fake_known.armor_patches[0].has_thickness = false
	fake_known.armor_patches[0].thickness_status = "verified"
	_ok(LayoutValidator.validate(fake_known, evidence)["errors"].size() > 0, "T004-06 unknown thickness faked as verified rejected")

	var no_evidence := _clone(panels)
	no_evidence.armor_patches[0].thickness_status = "verified"
	no_evidence.armor_patches[0].evidence_keys = PackedStringArray()
	_ok(LayoutValidator.validate(no_evidence, evidence)["errors"].size() > 0, "T004-06 verified field without evidence rejected")

	var bad_key := _clone(panels)
	bad_key.armor_patches[0].evidence_keys = PackedStringArray(["EV-NONEXISTENT"])
	_ok(LayoutValidator.validate(bad_key, evidence)["errors"].size() > 0, "T004-06 unknown evidence key rejected")

	var layout_with_mod := _clone(hull_layout)
	var mod := ModuleVolumeDefinition.new()
	mod.id = "m1"
	mod.kind = "test"
	mod.part_id = "hull"
	mod.size_m = Vector3(0, 1, 1)
	layout_with_mod.modules = [mod]
	_ok(LayoutValidator.validate(layout_with_mod, evidence)["errors"].size() > 0, "T004-03 non-positive module size rejected")

	var hist := _clone(hull_layout)
	hist.content_tier = "research"
	hist.historical_identity_id = "test_hist"
	_ok(LayoutValidator.validate(hist, evidence)["errors"].size() > 0, "T004-06 research layout without 5 crew roles rejected")

	var scaled_layout := _clone(hull_layout)
	_apply_scaled_part(scaled_layout)
	_ok(LayoutValidator.validate(scaled_layout, evidence)["errors"].size() > 0, "T004-03 scaled (non-rigid) part transform rejected")

	# --- LayoutCatalog ---
	LayoutCatalog.clear_cache()
	_ok(LayoutCatalog.load_layout("nonexistent_layout") == null, "catalog: missing layout rejected")
	_ok(LayoutCatalog.load_layout("") == null, "catalog: empty id rejected")
	var l1 := LayoutCatalog.load_layout("test_closed_hull")
	var l2 := LayoutCatalog.load_layout("test_closed_hull")
	_ok(l1 != null and l1 == l2, "catalog: repeated load returns same shared resource")

	# --- T004-01：实例隔离（共享定义不可变） ---
	var shared_thickness: float = hull_layout.armor_patches[0].thickness_mm
	var copy_layout := hull_layout.duplicate(true)
	copy_layout.armor_patches[0].thickness_mm = 999.0
	_ok(hull_layout.armor_patches[0].thickness_mm != 999.0,
		"T004-01 mutating a duplicate does not change shared definition")
	_ok(absf(hull_layout.armor_patches[0].thickness_mm - shared_thickness) < 0.01,
		"T004-01 shared definition thickness unchanged")

	# --- 004-b：历史研究布局（us_m4a3_75w_vvss_1944） ---
	LayoutCatalog.register_evidence(PackedStringArray([
		"EV-TM9759-IDENTITY", "EV-TM9759-SPECS", "EV-TM9759-ENGINE", "EV-TM9759-TRANS",
		"EV-TM9759-TURRET-FLOOR", "EV-TM9759-STOWAGE", "EV-TM9759-GEN",
		"EV-TM9759-RADIO", "EV-TM9759-TRAVERSE", "EV-FM1767-CREW"]))
	var m4a3 := LayoutCatalog.load_layout("us_m4a3_75w_vvss_1944")
	_ok(m4a3 != null and m4a3.id == "us_m4a3_75w_vvss_1944", "004-b M4A3 layout loads via catalog with validation")
	if m4a3 != null:
		_ok(m4a3.content_tier == "research", "004-b M4A3 content_tier=research")
		var roles_seen: PackedStringArray = []
		for st in m4a3.crew_stations:
			if not roles_seen.has(st.role):
				roles_seen.append(st.role)
		var crew_ok := true
		for required in ["commander", "gunner", "loader", "driver", "assistant_driver_bow_gunner"]:
			if not roles_seen.has(required):
				crew_ok = false
		_ok(crew_ok, "004-b M4A3 has all five crew roles (no 4-man template)")
		var all_unknown := true
		for patch in m4a3.armor_patches:
			if patch.has_thickness:
				all_unknown = false
		_ok(all_unknown, "004-b M4A3 armor thickness all unknown (no faked values)")
		var gunner_right := false
		var loader_left := false
		for st2 in m4a3.crew_stations:
			if st2.role == "gunner" and st2.local_box_transform.origin.x > 0.0:
				gunner_right = true
			if st2.role == "loader" and st2.local_box_transform.origin.x < 0.0:
				loader_left = true
		_ok(gunner_right and loader_left, "004-b FM 17-67: gunner right of gun, loader left of gun")
		var engine_rear := false
		for m in m4a3.modules:
			if m.id == "engine_main" and m.local_box_transform.origin.z > 0.0:
				engine_rear = true
		_ok(engine_rear, "004-b TM 9-759: engine in rear of hull")
		var yaw_joint := false
		for part in m4a3.parts:
			if part.id == "turret" and part.joint_kind == "yaw":
				yaw_joint = true
		_ok(yaw_joint, "004-b turret yaw joint exists")

	# --- 004-c：检视查看器（不依赖 VehicleActor / Gunner / PlayerController / 命中信号） ---
	var insp := VehicleInspector.new()
	var src := load("res://scripts/inspection/vehicle_inspector.gd") as GDScript
	var banned := ["VehicleActor", "Gunner", "PlayerController", "accept_hit", "fire_shell"]
	var combat_ok := true
	for b in banned:
		for ln in src.source_code.split("\n"):
			var stripped := ln.strip_edges()
			if stripped.begins_with("#") or stripped.begins_with("##"):
				continue   # 注释里的职责边界说明不算代码依赖
			if ln.contains(b):
				combat_ok = false
	_ok(combat_ok, "004-c inspector script has no combat dependencies")
	insp.queue_free()
	var preview := VehiclePreviewModel.new()
	preview.setup(m4a3)
	_ok(preview._part_nodes.has("hull") and preview._part_nodes.has("turret") and preview._part_nodes.has("gun"), "004-c preview builds part nodes from layout")
	var pose := preview.set_pose(90.0, -30.0)
	_ok(pose.get("yaw_applied", 0.0) == 90.0, "004-c set_pose applies yaw 90 via LayoutMath")
	_ok(pose.get("pitch_applied", 0.0) == -25.0, "004-c set_pose clamps pitch to joint limit -25")
	var pose_bad := preview.set_pose(400.0, 99.0)
	_ok(absf(pose_bad.get("yaw_applied", 0.0)) <= 360.0, "004-c set_pose clamps yaw beyond limits")
	var hit_turret := false
	for part in m4a3.parts:
		if part.id == "turret":
			var n: Node3D = preview._part_nodes[part.id]
			# 炮塔 bind 原点 = (0,1.72,0)：yaw 后位置不变（绕自身 bind 原点旋转）
			hit_turret = n.transform.origin.distance_to(Vector3(0, 1.72, 0)) < 0.001
	_ok(hit_turret, "004-c posed turret rotates about its own bind origin")
	preview.set_mode("armor")
	var any_wire := false
	for w in preview._extra_nodes:
		if w.name.begins_with("Wire_") and w.visible:
			any_wire = true
	_ok(any_wire, "004-c armor mode shows patch wires")
	preview.set_mode("interior")
	var module_visible := false
	for mid in preview._module_nodes.keys():
		if (preview._module_nodes[mid] as MeshInstance3D).visible:
			module_visible = true
	_ok(module_visible, "004-c interior mode shows module volumes")
	preview.set_mode("appearance")
	var thick_unknown := true
	for patch in m4a3.armor_patches:
		if patch.has_thickness:
			thick_unknown = false
	var unknown_color := true
	if thick_unknown:
		for patch in m4a3.armor_patches:
			var mi: MeshInstance3D = preview._patch_nodes[patch.id]
			var mat := mi.material_override as StandardMaterial3D
			if mat.albedo_color != VehiclePreviewModel.COLOR_UNKNOWN:
				unknown_color = false
	_ok(unknown_color, "004-c unknown-thickness patches render UNKNOWN color (not 0 mm)")
	preview.select_patch("hull_front_upper")
	var sel_mi: MeshInstance3D = preview._patch_nodes["hull_front_upper"]
	var sel_mat := sel_mi.material_override as StandardMaterial3D
	_ok(sel_mat != null and sel_mat.albedo_color == VehiclePreviewModel.COLOR_HIGHLIGHT, "004-c selection highlight uses instance material override")
	preview.select_patch("")
	var restored := sel_mi.material_override as StandardMaterial3D
	_ok(restored.albedo_color == VehiclePreviewModel.COLOR_UNKNOWN, "004-c deselect restores per-patch color")
	preview.queue_free()
	# layout_id 向后兼容：默认空串不破坏校验
	var vd := VehicleDefinition.new()
	vd.id = "compat_probe"
	vd.validate()
	_ok(vd.layout_id == "", "004-c VehicleDefinition.layout_id defaults empty (backward compatible)")

	_finish()


func _apply_scaled_part(layout: VehicleLayoutDefinition) -> void:
	layout.parts[0].bind_local = Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(10, 0, 20))


func _clone(layout: VehicleLayoutDefinition) -> VehicleLayoutDefinition:
	return layout.duplicate(true) as VehicleLayoutDefinition


func _part(id: String, parent_id: String, joint_kind: String) -> LayoutPartDefinition:
	var p := LayoutPartDefinition.new()
	p.id = id
	p.parent_id = parent_id
	p.joint_kind = joint_kind
	p.bind_local = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	return p


func _dup_id(layout: VehicleLayoutDefinition) -> VehicleLayoutDefinition:
	var dup := _clone(layout)
	dup.id = "test_invalid_dup"
	dup.armor_patches[1].id = dup.armor_patches[0].id
	return dup