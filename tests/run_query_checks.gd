# 005：统一命中查询检查（run_query_checks.gd）
# 运行：godot --headless --path <root> -s res://tests/run_query_checks.gd
# 覆盖：005-a 身份隔离余项（开口边按 part 隔离 / 严格身份匹配 / 具体字段路径）
#       + 005-b 手算几何案例（5/6/7/8m 基准、世界遮挡、姿态、端点、接缝、身份、性能）
# 失败时退出码非 0。

extends SceneTree

var _pass := 0
var _fail := 0
var _layout: VehicleLayoutDefinition = null


func _initialize() -> void:
	_layout = load("res://configs/layouts/test_query_vehicle.tres") as VehicleLayoutDefinition
	if _layout == null:
		printerr("QUERY_CHECKS_FAIL: test_query_vehicle.tres failed to load")
		quit(1)
		return
	# 布局自身必须通过校验（test tier 豁免开口/crew/evidence）
	var v := LayoutValidator.validate(_layout, PackedStringArray(["EV-TEST-FIXTURE"]), {})
	if v["errors"].size() > 0:
		printerr("QUERY_CHECKS_FAIL: fixture layout invalid: %s" % str(v["errors"]))
		quit(1)
		return

	_identity_isolation_checks()
	_hand_calculated_cases()
	_world_occlusion_cases()
	_pose_cases()
	_endpoint_cases()
	_seam_and_multi_layer_cases()
	_identity_and_perf_cases()
	await _debug_panel_cases()
	_finale_cases()
	await _finale_panel_cases()

	print("=== 结果: %d 项检查, %d 失败 ===" % [_pass + _fail, _fail])
	if _fail > 0:
		print("QUERY_CHECKS_FAIL")
		quit(1)
	print("QUERY_CHECKS_PASS")
	quit(0)


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL[%d]: %s" % [_pass + _fail, label])


# --- 005-a：身份隔离余项 ---

func _identity_isolation_checks() -> void:
	# 1) 开口边按 part 隔离：两部件局部坐标相同，只声明其中一个开口 → 另一个必须报错
	var l := _mini_layout("r5_part_isolation", [
		{"id": "p_a", "part": "a", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
		{"id": "p_b", "part": "b", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [{"id": "o1", "part": "a", "boundary_loop": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]}])
	var e1 := PackedStringArray()
	var w1 := PackedStringArray()
	LayoutValidator.check_declared_openings(l, e1, w1)
	_ok(e1.size() > 0, "005-a same local coords on two parts: undeclared edge on part b is NOT exempted by part a opening")
	# 对照：两部件都声明 → 通过
	var l2 := _mini_layout("r5_part_both", [
		{"id": "p_a", "part": "a", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
		{"id": "p_b", "part": "b", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [
		{"id": "o1", "part": "a", "boundary_loop": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]},
		{"id": "o2", "part": "b", "boundary_loop": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]},
	])
	var e2 := PackedStringArray()
	var w2 := PackedStringArray()
	LayoutValidator.check_declared_openings(l2, e2, w2)
	_ok(e2.is_empty(), "005-a both parts declared: passes")

	# 2) 严格身份匹配：research 布局 + 无机器身份列表的 evidence key → 报错（不回退文本）
	var doc := {
		"evidence_keys": [
			{"key": "EV-NO-MACHINE-IDS", "origin": "historical_primary", "applies_to": "M4A3 (75mm wet stowage)", "title": "no machine ids"},
		],
		"fields": [
			{"field_path": "armor_patches.*.thickness_mm", "status": "verified", "source_refs": ["EV-NO-MACHINE-IDS"]},
		]
	}
	var l3 := _mini_layout("r5_strict_identity", [
		{"id": "p1", "part": "a", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [])
	l3.historical_identity_id = "us_m4a3_75w_vvss_1944"
	l3.armor_patches[0].evidence_keys = PackedStringArray(["EV-NO-MACHINE-IDS"])
	l3.armor_patches[0].thickness_status = "verified"
	l3.armor_patches[0].has_thickness = true
	l3.armor_patches[0].thickness_mm = 50.0
	var e3 := PackedStringArray()
	LayoutValidator.check_evidence_consistency(l3, doc, e3)
	_ok(e3.size() > 0, "005-a evidence without machine identity lists is rejected (no free-text fallback)")

	# 3) 具体字段路径：精确记录优先于通配；同程度冲突报错
	var doc2 := {
		"evidence_keys": [
			{"key": "EV-SRC", "origin": "historical_primary", "applies_to_identity_ids": ["us_m4a3_75w_vvss_1944"], "excluded_identity_ids": [], "title": "src"},
		],
		"fields": [
			{"field_path": "armor_patches.*.thickness_mm", "status": "verified", "source_refs": ["EV-SRC"]},
			{"field_path": "armor_patches.hull_front_upper.thickness_mm", "status": "verified", "source_refs": ["EV-SRC"]},
		]
	}
	var l4 := _mini_layout("r5_exact_path", [
		{"id": "hull_front_upper", "part": "a", "verts": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "tris": [0, 1, 2]},
	], [])
	l4.historical_identity_id = "us_m4a3_75w_vvss_1944"
	l4.armor_patches[0].evidence_keys = PackedStringArray(["EV-SRC"])
	l4.armor_patches[0].thickness_status = "verified"
	l4.armor_patches[0].has_thickness = true
	l4.armor_patches[0].thickness_mm = 50.0
	var e4 := PackedStringArray()
	LayoutValidator.check_evidence_consistency(l4, doc2, e4)
	_ok(e4.is_empty(), "005-a exact field record preferred over wildcard (no conflict error)")
	var doc3 := {
		"evidence_keys": [
			{"key": "EV-SRC", "origin": "historical_primary", "applies_to_identity_ids": ["us_m4a3_75w_vvss_1944"], "excluded_identity_ids": [], "title": "src"},
		],
		"fields": [
			{"field_path": "armor_patches.*.thickness_mm", "status": "verified", "source_refs": ["EV-SRC"]},
			{"field_path": "armor_patches.*.thickness_mm", "status": "estimated", "source_refs": ["EV-SRC"]},
		]
	}
	var e5 := PackedStringArray()
	LayoutValidator.check_evidence_consistency(l4, doc3, e5)
	_ok(e5.size() > 0, "005-a conflicting wildcard records at same specificity are rejected")


# --- 005-b：手算几何案例（GPT 9.1 基准） ---

func _hand_calculated_cases() -> void:
	# 基准：from=(0,1,-5) to=(0,1,5)；前板 z=0 → 5m；发动机盒 (0,1,1.5) size(1,1,1) → 6/7m；后板 z=3 → 8m
	var snap := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	var req := {
		"query_id": "q_hand", "physics_tick": 1,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}
	var r := ShotQueryService.query(req, [snap])
	_ok(r.get("ok", false), "005-b hand case: query ok")
	var events: Array = r["events"]
	_ok(events.size() == 4, "005-b hand case: exactly 4 events (front/engine enter/engine exit/rear), got %d" % events.size())
	if events.size() == 4:
		_ok(_ev(events[0], "armor", "surface", "hull_front") and _near(events[0], 5.0), "005-b event1 front plate at 5m (got %.3f %s)" % [_dist(events[0]), str(events[0].get("surface_id", ""))])
		_ok(_ev(events[1], "module", "enter", "engine") and _near(events[1], 6.0), "005-b event2 engine enter at 6m (got %.3f)" % _dist(events[1]))
		_ok(_ev(events[2], "module", "exit", "engine") and _near(events[2], 7.0), "005-b event3 engine exit at 7m (got %.3f)" % _dist(events[2]))
		_ok(_ev(events[3], "armor", "surface", "hull_rear") and _near(events[3], 8.0), "005-b event4 rear plate at 8m (got %.3f)" % _dist(events[3]))
	# 法线已知且朝外（005-R1：前板外法线 −Z）
	if events.size() > 0:
		var n: Vector3 = events[0]["normal_world"]
		_ok(events[0].get("normal_known", false) and n.z < -0.99, "005-b front plate normal -z (got %s)" % str(n))
	# 射线从面片旁边经过（y=2 高于车顶 1.35）→ 无命中
	var r2 := ShotQueryService.query({
		"query_id": "q_side", "physics_tick": 2,
		"from_world": Vector3(0, 2, -5), "to_world": Vector3(0, 2, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	_ok((r2["events"] as Array).is_empty(), "005-b ray beside plates (y=2) hits nothing")
	# 射程终点之后的对象不能命中（to 在 z=0 前）
	var r3 := ShotQueryService.query({
		"query_id": "q_short", "physics_tick": 3,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, -1),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	_ok((r3["events"] as Array).is_empty(), "005-b objects beyond segment end are not hit")
	# 零长度输入明确失败
	var r4 := ShotQueryService.query({
		"query_id": "q_zero", "physics_tick": 4,
		"from_world": Vector3(0, 1, 0), "to_world": Vector3(0, 1, 0),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	_ok(not r4.get("ok", false), "005-b zero-length segment fails explicitly")


func _world_occlusion_cases() -> void:
	var snap := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	# 挡墙 center=(0,1,-2.5) size=(3,3,1) → 最近墙面 2m
	var wall_contact := {
		"kind": "world", "event_type": "surface", "distance_m": 2.0,
		"point_world": Vector3(0, 1, -2.0), "normal_world": Vector3(0, 0, 1), "normal_known": true,
	}
	var r := ShotQueryService.query({
		"query_id": "q_wall", "physics_tick": 5,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop": wall_contact,
	}, [snap])
	_ok(absf(float(r["world_stop_distance_m"]) - 2.0) < 0.001, "005-b wall stop at 2m (got %.3f)" % float(r["world_stop_distance_m"]))
	_ok(r.get("world_stop", {}) == wall_contact, "005-b result echoes world_stop contact dict")
	# 墙后候选仍在 events 中（遮挡只是标注，服务不删除候选）
	_ok((r["events"] as Array).size() == 4, "005-b wall-behind candidates remain in events (occlusion is a display/rule concern)")
	# 墙后事件带 occluded_by_world 标注；墙前（无）不留
	for ev in r["events"]:
		var occluded: bool = float(ev.get("distance_m", 0.0)) > 2.0 + 1e-5
		_ok(bool(ev.get("occluded_by_world", false)) == occluded, "005-b occluded_by_world matches distance vs world stop (ev %.2fm occluded=%s)" % [float(ev.get("distance_m", 0.0)), str(ev.get("occluded_by_world", false))])
	# 移墙后（无 world_stop）→ 前板仍 5m；无 occluded 标注
	var r2 := ShotQueryService.query({
		"query_id": "q_nowall", "physics_tick": 6,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	_ok(float(r2["world_stop_distance_m"]) < 0.0 and (r2["events"] as Array).size() == 4, "005-b no wall: front plate first again")
	for ev in r2["events"]:
		_ok(not bool(ev.get("occluded_by_world", false)), "005-b no world stop: no occluded flags")
	# 旧字段兼容：只有 world_stop_distance_m（无数值 contact）也可用
	var r3 := ShotQueryService.query({
		"query_id": "q_wall_legacy", "physics_tick": 7,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop_distance_m": 2.0,
	}, [snap])
	_ok(absf(float(r3["world_stop_distance_m"]) - 2.0) < 0.001, "005-b legacy world_stop_distance_m still accepted")
	for ev in r3["events"]:
		var occluded3: bool = float(ev.get("distance_m", 0.0)) > 2.0 + 1e-5
		_ok(bool(ev.get("occluded_by_world", false)) == occluded3, "005-b legacy wall: occlusion flags consistent (ev %.2fm)" % float(ev.get("distance_m", 0.0)))


func _pose_cases() -> void:
	# 车体 yaw 90°：车头朝 +x（-Z 前向 → 旋转 90° 后 -Z 指向 +x？yaw=90° 绕 Y：-Z → +X）
	# 探测线沿世界 +x：from=(0,1,-5) to=(0,1,5) 在车体局部 = 沿 -z？验证交点/法线世界系正确。
	var yaw90 := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	var snap := _identity_snapshot("B", 1, yaw90)
	var r := ShotQueryService.query({
		"query_id": "q_yaw90", "physics_tick": 7,
		"from_world": Vector3(-5, 1, 0), "to_world": Vector3(5, 1, 0),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var events: Array = r["events"]
	_ok(events.size() == 4, "005-b yaw90: 4 events (got %d)" % events.size())
	if events.size() == 4:
		# 车体 yaw90 后 hull_front（局部 z=0）在世界 x=0；探测线沿 x 从 -5 到 5 → 前板 5m
		_ok(_near(events[0], 5.0) and _ev(events[0], "armor", "surface", "hull_front"), "005-b yaw90 front at 5m (got %.3f)" % _dist(events[0]))
		var n: Vector3 = events[0]["normal_world"]
		_ok(n.x < -0.99, "005-b yaw90 front normal rotated to -x (got %s)" % str(n))
	# 炮塔单独旋转 90°（turret part 变换旋转，hull 不变）：turret_front 面片交点随炮塔转
	var hull_t := Transform3D.IDENTITY
	var turret_t := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0, 1.35, 0))
	var barrel_t := Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.75))
	var snap2 := QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", _layout, {
		"hull": hull_t, "turret": turret_t, "barrel": barrel_t,
	})
	var r2 := ShotQueryService.query({
		"query_id": "q_turret90", "physics_tick": 8,
		"from_world": Vector3(-5, 1.5, 0), "to_world": Vector3(5, 1.5, 0),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap2])
	var has_turret_front := false
	for ev in r2["events"]:
		if ev.get("surface_id", "") == "turret_front":
			has_turret_front = true
	_ok(has_turret_front, "005-b turret rotated 90deg: turret_front hit by x-axis probe")
	# 火炮单独俯仰（barrel part 绕 X 旋转）：barrel_box 模块交点随俯仰变化。
	# barrel 世界变换 = turret 世界变换 × barrel 局部（含俯仰）。
	var barrel_pitch := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0, 0.15, -0.75))
	var snap3 := QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", _layout, {
		"hull": hull_t, "turret": turret_t, "barrel": turret_t * barrel_pitch,
	})
	var r3 := ShotQueryService.query({
		"query_id": "q_barrel10", "physics_tick": 9,
		"from_world": Vector3(-5, 1.71, 0), "to_world": Vector3(5, 1.71, 0),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap3])
	var barrel_hits := 0
	for ev in r3["events"]:
		if ev.get("module_id", "") == "barrel_box":
			barrel_hits += 1
	_ok(barrel_hits >= 1, "005-b barrel pitch 10deg: barrel_box module still intersected (got %d)" % barrel_hits)


func _endpoint_cases() -> void:
	var snap := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	# 起点在发动机盒内：from=(0,1,1.5)（盒中心）→ starts_inside，无 enter 事件，有 exit 事件
	var r := ShotQueryService.query({
		"query_id": "q_inside", "physics_tick": 10,
		"from_world": Vector3(0, 1, 1.5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var has_enter := false
	var has_exit := false
	for ev in r["events"]:
		if ev.get("module_id", "") == "engine":
			if ev.get("event_type", "") == "enter":
				has_enter = true
			if ev.get("event_type", "") == "exit":
				has_exit = true
	_ok(not has_enter and has_exit, "005-b start inside engine box: no fake enter, exit present")
	var has_interval := false
	for iv in r["volume_intervals"]:
		if iv.get("module_id", "") == "engine" and iv.get("starts_inside", false) and absf(float(iv["t_enter"]) - 0.0) < 0.0001:
			has_interval = true
	_ok(has_interval, "005-b start inside: volume interval starts at t=0")
	# 整段都在盒内：from=(0,1,1.5) to=(0,1,1.6) → 无 enter/exit 边界事件，interval 全覆盖
	var r2 := ShotQueryService.query({
		"query_id": "q_fully_inside", "physics_tick": 11,
		"from_world": Vector3(0, 1, 1.5), "to_world": Vector3(0, 1, 1.6),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var engine_events := 0
	for ev in r2["events"]:
		if ev.get("module_id", "") == "engine":
			engine_events += 1
	_ok(engine_events == 0, "005-b fully inside box: no boundary events fabricated")
	# 恰从表面出发：from=(0,1,1.0)（盒前表面 z=1）→ 起点在表面
	var r3 := ShotQueryService.query({
		"query_id": "q_from_surface", "physics_tick": 12,
		"from_world": Vector3(0, 1, 1.0), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var enter_at_start := false
	for ev in r3["events"]:
		if ev.get("module_id", "") == "engine" and ev.get("event_type", "") == "enter":
			enter_at_start = true
	_ok(enter_at_start, "005-b start exactly on box surface: enter boundary reported")
	# 终点恰在表面：to=(0,1,2.0)（盒后表面 z=2）
	var r4 := ShotQueryService.query({
		"query_id": "q_to_surface", "physics_tick": 13,
		"from_world": Vector3(0, 1, 1.2), "to_world": Vector3(0, 1, 2.0),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var exit_at_end := false
	for ev in r4["events"]:
		if ev.get("module_id", "") == "engine" and ev.get("event_type", "") == "exit":
			exit_at_end = true
	_ok(exit_at_end, "005-b end exactly on box surface: exit boundary reported")


func _seam_and_multi_layer_cases() -> void:
	var snap := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	# 同面片共享对角线：hull_front 顶点 (-1.15,0.55,0),(1.15,0.55,0),(1.15,1.35,0),(-1.15,1.35,0)，
	# 三角形 (0,1,2),(0,2,3) 共享边 0-2（对角线）：探针沿 z 在 y=0.95 ——
	# 与对角线交于同一点 → 去重后只报一次（on_edge 标记）。
	var r := ShotQueryService.query({
		"query_id": "q_seam", "physics_tick": 14,
		"from_world": Vector3(0, 0.95, -5), "to_world": Vector3(0, 0.95, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var front_count := 0
	for ev in r["events"]:
		if ev.get("surface_id", "") == "hull_front":
			front_count += 1
	_ok(front_count == 1, "005-b shared diagonal of one patch reported once (got %d)" % front_count)
	var on_edge := false
	for ev in r["events"]:
		if ev.get("surface_id", "") == "hull_front" and ev.get("on_edge", false):
			on_edge = true
	_ok(on_edge, "005-b shared diagonal crossing flagged on_edge")
	# 不同面片保留：front 与 rear 是两个 surface_id → 各报一次
	var rear_count := 0
	for ev in r["events"]:
		if ev.get("surface_id", "") == "hull_rear":
			rear_count += 1
	_ok(rear_count == 1, "005-b distinct patches kept separate")
	# 共面：探测线在 hull_top 平面内（y=1.35 沿 z）→ coplanar_unresolved 诊断 + complete=false
	var r2 := ShotQueryService.query({
		"query_id": "q_coplanar", "physics_tick": 15,
		"from_world": Vector3(0, 1.35, -5), "to_world": Vector3(0, 1.35, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var has_diag := false
	for d in r2["diagnostics"]:
		if str(d).contains("coplanar_unresolved"):
			has_diag = true
	_ok(has_diag, "005-b coplanar segment yields explicit diagnostic (no infinite loop)")
	_ok(not r2.get("complete", true), "005-b coplanar unresolved marks query incomplete (conservative)")


func _identity_and_perf_cases() -> void:
	# A 被排除但同车型 B 可命中
	var snap_a := _identity_snapshot("A", 1, Transform3D.IDENTITY)
	var snap_b := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	var r := ShotQueryService.query({
		"query_id": "q_excl", "physics_tick": 16,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [{"entity_id": "A", "life_id": 1}],
		"include_modules": true, "include_crew": false,
	}, [snap_a, snap_b])
	var a_hits := 0
	var b_hits := 0
	for ev in r["events"]:
		if ev.get("entity_id", "") == "A":
			a_hits += 1
		if ev.get("entity_id", "") == "B":
			b_hits += 1
	_ok(a_hits == 0 and b_hits == 4, "005-b A excluded, same-definition B still hit (A=%d B=%d)" % [a_hits, b_hits])
	# 快照副本隔离：构造后修改源变换字典不得影响已建快照（固定姿态语义）
	var src_transforms := {
		"hull": Transform3D.IDENTITY,
		"turret": Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0)),
		"barrel": Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.75)),
	}
	var snap_iso := QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", _layout, src_transforms)
	src_transforms["hull"] = Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	var r_iso := ShotQueryService.query({
		"query_id": "q_iso", "physics_tick": 17,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap_iso])
	_ok((r_iso["events"] as Array).size() == 4, "005-b snapshot transform dict duplicated at build time (later mutation not read)")
	# 缺失部件变换：明确失败（complete=false + 诊断），不使用单位变换伪装
	var snap_missing := QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", _layout, {
		"hull": Transform3D.IDENTITY,
	})
	var r_missing := ShotQueryService.query({
		"query_id": "q_missing", "physics_tick": 18,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap_missing])
	_ok(not r_missing.get("complete", true) and (r_missing["events"] as Array).is_empty(), "005-b missing part transform: entity skipped entirely (incomplete, no fake identity transforms)")
	# 非有限变换：同样明确失败
	var r_nan := ShotQueryService.query({
		"query_id": "q_nan", "physics_tick": 19,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", _layout, {
		"hull": Transform3D(Basis(), Vector3(NAN, 0, 0)),
	})])
	_ok(not r_nan.get("complete", true), "005-b non-finite transform: incomplete")
	var r_nan2 := ShotQueryService.query({
		"query_id": "q_nan2", "physics_tick": 20,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [{"entity_id": "B", "life_id": 1, "layout": _layout, "layout_revision": _layout.schema_version,
		"part_world_transforms": {"hull": Transform3D.IDENTITY}}])
	_ok(not r_nan2.get("complete", true), "005-b snapshot missing turret/barrel transforms: incomplete")
	# 模块局部旋转（部件未转、模块盒绕 Y 90°）：size (0.5,1,2) yaw90 → 世界 x±1.0、z±0.25。
	# 探针沿 +z 在 x=0.8：未旋转盒（x±0.25）不命中；旋转盒（x±1.0）命中 2 次（进/出）
	var rotated := _layout.duplicate(true)
	rotated.id = "rotated_fixture"
	var eng_rot: ModuleVolumeDefinition = rotated.modules[0]
	eng_rot.local_box_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), eng_rot.local_box_transform.origin)
	eng_rot.size_m = Vector3(0.5, 1.0, 2.0)
	rotated.modules.clear()
	rotated.modules.append(eng_rot)
	var r_rot := ShotQueryService.query({
		"query_id": "q_modrot", "physics_tick": 21,
		"from_world": Vector3(0.8, 1, -5), "to_world": Vector3(0.8, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [QuerySnapshotBuilder.build_identity_snapshot("B", 1, "player_tank", rotated, {
		"hull": Transform3D.IDENTITY, "turret": Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0)),
		"barrel": Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.75)),
	})])
	var rot_engine_hits := 0
	for ev in r_rot["events"]:
		if ev.get("module_id", "") == "engine":
			rot_engine_hits += 1
	_ok(rot_engine_hits == 2, "005-b module local rotation applied (yaw90 box hit by x=0.8 probe) (hits=%d)" % rot_engine_hits)
	# 非旋转对照：同一探针不命中
	var r_unrot := ShotQueryService.query({
		"query_id": "q_modunrot", "physics_tick": 22,
		"from_world": Vector3(0.8, 1, -5), "to_world": Vector3(0.8, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap_b])
	var unrot_engine_hits := 0
	for ev in r_unrot["events"]:
		if ev.get("module_id", "") == "engine":
			unrot_engine_hits += 1
	_ok(unrot_engine_hits == 0, "005-b unrotated module control: x=0.8 probe misses (hits=%d)" % unrot_engine_hits)
	# 法线-内点独立校验：每个面片外法线 · (面中心 − 盒内部点) > 0
	_ok(_normals_point_outward(), "005-b all fixture patch normals point outward vs interior point")
	# 模块-only 外部接触：命中 barrel_box（车体装甲外，y=1.5 越过车顶）→ 选择器 = miss（不判车辆）
	var r_ext := ShotQueryService.query({
		"query_id": "q_ext", "physics_tick": 23,
		"from_world": Vector3(0, 1.5, -5), "to_world": Vector3(0, 1.5, -1),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap_b])
	var sel_ext := ExternalContactSelector.select_contact(r_ext)
	_ok(sel_ext.get("status", "") == "miss", "005-b module-only external contact is NOT a vehicle hit (status=%s)" % str(sel_ext.get("status", "")))
	# 不完全查询 → 选择器 = unresolved（保守未决，不计命中）
	var sel_cop := ExternalContactSelector.select_contact({})
	_ok(sel_cop.get("status", "") == "unresolved", "005-b failed query selects unresolved")
	var sel_missing := ExternalContactSelector.select_contact(r_missing)
	_ok(sel_missing.get("status", "") == "unresolved", "005-b incomplete query selects unresolved")
	# 正常完整命中 → vehicle（首个有效装甲外表面）
	var sel_ok := ExternalContactSelector.select_contact(r)
	_ok(sel_ok.get("status", "") == "vehicle" and str(sel_ok.get("event", {}).get("surface_id", "")) == "hull_front", "005-b complete query selects first armor surface (status=%s)" % str(sel_ok.get("status", "")))
	# 墙（world stop）在装甲前 → world 优先；同距 → 墙优先（TIE_EPS）
	var r_wall_first := ShotQueryService.query({
		"query_id": "q_selwall", "physics_tick": 24,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop": {"kind": "world", "event_type": "surface", "distance_m": 4.9, "point_world": Vector3(0, 1, -0.1), "normal_known": false},
	}, [snap_b])
	_ok(ExternalContactSelector.select_contact(r_wall_first).get("status", "") == "world", "005-b wall before armor selects world")
	var r_wall_tie := ShotQueryService.query({
		"query_id": "q_seltie", "physics_tick": 25,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop": {"kind": "world", "event_type": "surface", "distance_m": 5.0, "point_world": Vector3(0, 1, 0.0), "normal_known": false},
	}, [snap_b])
	_ok(ExternalContactSelector.select_contact(r_wall_tie).get("status", "") == "world", "005-b wall vs armor tie prefers wall (TIE_EPS)")
	# 世界适配器 ok/hit/reason 语义（真实物理空间来自主场景；null 空间 = no_space）
	var wa_null := WorldQueryAdapter.query_world_stop(null, Vector3.ZERO, Vector3.UP, 10.0)
	_ok(not wa_null.get("ok", true) and wa_null.get("reason", "") == "no_space", "005-b world adapter null space: ok=false no_space")
	var wa_bad := WorldQueryAdapter.query_world_stop(null, Vector3(NAN, 0, 0), Vector3.UP, 10.0)
	_ok(not wa_bad.get("ok", true), "005-b world adapter invalid input: ok=false")
	# 性能边界：9 实体 → 明确失败
	var many: Array = []
	for i in range(9):
		many.append(_identity_snapshot("E%d" % i, 1, Transform3D.IDENTITY))
	var r3 := ShotQueryService.query({
		"query_id": "q_many", "physics_tick": 26,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, many)
	_ok(not r3.get("ok", false) and str(r3.get("diagnostics", [""])[0]).contains("too_many_entities"), "005-b >8 entities fails explicitly (no silent truncation)")


func _normals_point_outward() -> bool:
	# 独立校验（不经过查询）：每面片 外法线 ·（面中心 − 所属部件内部点）> 0
	var bad := ""
	for patch in _layout.armor_patches:
		var center := Vector3.ZERO
		for v in patch.vertices_local_m:
			center += v
		center /= patch.vertices_local_m.size()
		var part_t := Transform3D.IDENTITY
		if patch.part_id == "turret":
			part_t = Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0))
		elif patch.part_id == "barrel":
			part_t = Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.75))
		var interior := Vector3(0, 0.95, 1.5)   # 车体装甲盒内部点
		if patch.part_id != "hull":
			interior = part_t * (Vector3(0, 0.275, 0.1))   # 炮塔/炮管盒内部点
		var world_center: Vector3 = part_t * center
		var world_normal: Vector3 = part_t.basis * patch.outward_normal_local
		var dot: float = world_normal.dot(world_center - interior)
		if dot <= 0.0:
			bad += "%s(dot=%.3f) " % [patch.id, dot]
	return bad.is_empty()


# --- 005-d/005-R1-C：查询调试面板（范围入口/纯几何/弹药任务隔离/墙/陈旧/火键门/暂停先关面板） ---

func _debug_panel_cases() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 2:
		await process_frame
	main.open_query_debug()
	_ok(main._query_panel_open, "005-d open_query_debug opens panel")
	_ok(not main.controller.commands_enabled, "005-d panel open disables controller intent (no fire/drive/aim)")
	var panel: QueryDebugPanel = main._query_panel
	_ok(panel != null and panel.main == main, "005-d panel wired to main")
	var shots0: int = main.gunner.shots_fired
	var trial0: int = main.trial_hits
	# 005-R1：a_to_b = A 中心(0,1,8) → B 车体中心(8,0.95,0)（段长 11.314）：
	# A 发动机盒出口 0.424m（起点在盒内→仅 exit）→ A hull_right 出口 1.626m →
	# B hull_left 入口 9.687m → B 发动机盒入口 10.465m（模块仅调试候选）
	panel.set_probe("a_to_b")
	panel.set_vehicle_filter("ALL")
	panel.run_query()
	for i in 2:
		await physics_frame
	var qr_all: Dictionary = panel.last_result()
	var evs_all: Array = panel.last_events()
	_ok(qr_all.get("ok", false) and qr_all.get("complete", false), "005-d a_to_b ALL run ok+complete")
	_ok(evs_all.size() == 4, "005-d a_to_b ALL filter: 4 events (A engine exit + hull_right + B hull_left + B engine enter), got %d" % evs_all.size())
	if evs_all.size() == 4:
		_ok(_ev(evs_all[0], "module", "exit", "engine") and str(evs_all[0].get("entity_id", "")) == "A" and absf(_dist(evs_all[0]) - 0.424) < 0.01, "005-d ALL first = A engine exit ~0.424m (got %.3f)" % _dist(evs_all[0]))
		_ok(_ev(evs_all[1], "armor", "surface", "hull_right") and str(evs_all[1].get("entity_id", "")) == "A" and absf(_dist(evs_all[1]) - 1.626) < 0.01, "005-d ALL second = A hull_right exit ~1.626m (got %.3f)" % _dist(evs_all[1]))
		_ok(_ev(evs_all[2], "armor", "surface", "hull_left") and str(evs_all[2].get("entity_id", "")) == "B" and absf(_dist(evs_all[2]) - 9.687) < 0.01, "005-d ALL third = B hull_left enter ~9.687m (got %.3f)" % _dist(evs_all[2]))
		_ok(_ev(evs_all[3], "module", "enter", "engine") and str(evs_all[3].get("entity_id", "")) == "B", "005-d ALL fourth = B engine enter")
	_ok(panel.current_run_marker_count() == evs_all.size(), "005-d world markers match current-run events")
	# 车辆过滤 B：只见 B 的 2 个事件（装甲 + 模块——模块是调试候选，不参与计分）
	panel.set_vehicle_filter("B")
	panel.run_query()
	for i in 2:
		await physics_frame
	var evs: Array = panel.last_events()
	_ok(evs.size() == 2, "005-d a_to_b B filter: 2 events (got %d)" % evs.size())
	if evs.size() == 2:
		_ok(_ev(evs[0], "armor", "surface", "hull_left") and str(evs[0].get("entity_id", "")) == "B", "005-d a_to_b B first = hull_left")
	_ok(main.gunner.shots_fired == shots0 and main.trial_hits == trial0, "005-d debug query consumed no ammo/task (shots=%d trial=%d)" % [main.gunner.shots_fired, main.trial_hits])
	# 显式测试墙（物理体 + 世界接触）：置于线段的 (4,1,4)（薄轴沿 x、yaw 0）→
	# 世界接触 ~5.374m、先于 B 装甲 9.687m；B 装甲标 occluded
	panel.set_vehicle_filter("ALL")
	panel.set_wall_geometry(Vector3(4, 1, 4), Vector3(0.4, 3.0, 3.0), 0.0)
	_ok(panel.apply_wall(), "005-d apply test wall ok")
	_ok(panel.has_wall(), "005-d wall applied (has wall)")
	panel.run_query()
	for i in 2:
		await physics_frame
	var evs2: Array = panel.last_events()
	_ok(evs2.size() == 5, "005-d wall run: 5 rows (2 A + world + 2 B incl. occluded), got %d" % evs2.size())
	if evs2.size() == 5:
		_ok(str(evs2[2].get("kind", "")) == "world" and absf(_dist(evs2[2]) - 5.374) < 0.01, "005-d world contact ~5.374m (got %.3f)" % _dist(evs2[2]))
		_ok(_dist(evs2[2]) < _dist(evs2[3]), "005-d wall before B armor (%.2f < %.2f)" % [_dist(evs2[2]), _dist(evs2[3])])
		_ok(bool(evs2[3].get("occluded_by_world", false)) and bool(evs2[4].get("occluded_by_world", false)), "005-d B events after wall flagged occluded")
	var rows: Array = panel.current_rows()
	_ok(rows.size() == evs2.size(), "005-d row metadata matches events")
	var tags: Array = []
	for row in rows:
		tags.append(row.get("tag", ""))
	_ok(tags.size() == 5 and tags[2] == "WALL" and tags[3] == ">wall" and tags[4] == ">wall", "005-d occlusion tags (world WALL / after >wall): %s" % str(tags))
	# 非法墙参数拒绝应用（负尺寸/非有限）
	panel.set_wall_geometry(Vector3(4, 1, 4), Vector3(-0.4, 3.0, 3.0), 0.0)
	_ok(not panel.apply_wall(), "005-d invalid wall size rejected")
	_ok(panel.has_wall(), "005-d applied wall kept after rejected update")
	panel.set_wall_geometry(Vector3(NAN, 1, 4), Vector3(0.4, 3.0, 3.0), 0.0)
	_ok(not panel.apply_wall(), "005-d non-finite wall pos rejected")
	# 移除墙 → 墙接触消失（自动重跑同一线段：剩余 4 行）
	_ok(panel.remove_wall(), "005-d remove test wall ok")
	_ok(not panel.has_wall(), "005-d wall gone after remove")
	for i in 2:
		await physics_frame
	_ok(panel.last_events().size() == 4, "005-d after wall removal: wall row gone (got %d)" % panel.last_events().size())
	# 标记只保留最近一组：新运行清除旧标记
	panel.set_vehicle_filter("B")
	panel.run_query()
	for i in 2:
		await physics_frame
	_ok(panel.marker_count() == 2, "005-d markers keep only most recent run (markers=%d)" % panel.marker_count())
	# 陈旧标记：面板打开期间车辆姿态变化 → 结果标记 STALE（不伪造当前姿态）
	main.actor_b.tank.global_position += Vector3(0, 0, 0.6)
	for i in 2:
		await process_frame
	_ok(panel.is_stale(), "005-d pose change marks results STALE")
	panel.run_query()
	for i in 2:
		await physics_frame
	_ok(not panel.is_stale(), "005-d re-run clears STALE")
	# 清空：结果/标记/线段全清
	panel.clear_results()
	_ok(panel.last_events().is_empty() and panel.marker_count() == 0, "005-d clear removes results and markers")
	# 005-R1-C 火键释放门：面板期间按下的 fire 不得被当作开火边沿；关闭臂门；释放后新按被捕获
	Input.action_press("fire")
	for i in 2:
		await process_frame
	main.close_query_debug()
	_ok(not main._query_panel_open and main.controller.commands_enabled, "005-d close restores controller intent")
	_ok(main.controller._need_fire_release, "005-d close arms fire-release gate")
	Input.action_press("fire")
	main.controller._process.call(0.016)
	_ok(not main.controller._fire_pending, "005-d fire held across panel close is not captured as a shot request")
	Input.action_release("fire")
	main.controller._process.call(0.016)
	_ok(not main.controller._need_fire_release, "005-d gate cleared after release observed")
	Input.action_press("fire")
	main.controller._process.call(0.016)
	_ok(main.controller._fire_pending, "005-d new press captured after release")
	main.controller.reset_pending()
	Input.action_release("fire")
	for i in 2:
		await process_frame
	# 005-R1-C 暂停先关面板：面板开着进暂停 → 面板先关闭、再暂停，统一清理生效
	main.open_query_debug()
	for i in 2:
		await process_frame
	var panel2: QueryDebugPanel = main._query_panel
	panel2.set_probe("a_to_b")
	panel2.set_vehicle_filter("ALL")
	panel2.set_wall_geometry(Vector3(4, 1, 4), Vector3(0.4, 3.0, 3.0), 0.0)
	_ok(panel2.apply_wall(), "005-d reopen: wall applied")
	panel2.run_query()
	for i in 2:
		await physics_frame
	_ok(panel2.marker_count() >= 5, "005-d reopen run produced markers")
	main._pause()
	_ok(not main._query_panel_open and paused, "005-d pause with panel open closes panel first, then pauses")
	for i in 2:
		await process_frame   # queue_free 延迟释放生效（暂停期间帧照常派发）
	_ok(main.get_node_or_null("QueryDebugMarkers") == null, "005-d pause-close cleanup freed world markers")
	var tw_left := 0
	for c in main.world.get_children():
		if c.name == "TestWall":
			tw_left += 1
	_ok(tw_left == 0, "005-d pause-close cleanup removed test wall")
	main._resume()
	for i in 2:
		await process_frame
	main.close_query_debug()
	_ok(not main._query_panel_open, "005-d close idempotent")
	main.queue_free()
	for i in 2:
		await process_frame


# --- 005-R1 收尾：A 世界接触边界（纯函数）+ C 统一排序 ---

func _finale_cases() -> void:
	var mk := func(d: float, id: String) -> Dictionary:
		return {"distance_m": d, "kind": "armor", "entity_id": "E", "life_id": 1,
			"part_id": "hull", "surface_id": id, "event_type": "surface"}
	var a: Dictionary = mk.call(5.0, "s_a")
	var b: Dictionary = mk.call(5.000005, "s_b")
	var c: Dictionary = mk.call(5.00001, "s_c")
	var canonical: Array = [a, b, c]
	var perms: Array = [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]]
	for perm in perms:
		var sorted: Array = perm.duplicate()
		sorted.sort_custom(ShotQueryService.event_less)
		_ok(_same_events(sorted, canonical), "005-F-C six permutations of 3 close events sort identically")
	_ok(ShotQueryService.event_less(a, b) and not ShotQueryService.event_less(b, a)
		and ShotQueryService.event_less(b, c) and not ShotQueryService.event_less(c, b)
		and ShotQueryService.event_less(a, c) and not ShotQueryService.event_less(c, a),
		"005-F-C strict weak ordering across 3 close events")
	# 完全同距：确定性 tie-break（event_key 身份序）
	var t1: Dictionary = mk.call(5.0, "z_ee")
	var t2: Dictionary = mk.call(5.0, "a_w")
	_ok(ShotQueryService.event_key(t1) > ShotQueryService.event_key(t2),
		"005-F-C exact-tie key ordering is deterministic and identity-based")
	var tie_sorted: Array = [t1, t2]
	tie_sorted.sort_custom(ShotQueryService.event_less)
	_ok(_same_events(tie_sorted, [t2, t1]), "005-F-C exact-tie sort follows event_key (identity)")
	var wrow := {"distance_m": 5.0, "kind": "world", "entity_id": "world", "life_id": 0,
		"part_id": "world", "surface_id": "world_contact", "event_type": "surface"}
	var mix: Array = [wrow, t1]
	mix.sort_custom(ShotQueryService.event_less)
	_ok(_same_events(mix, [wrow, t1]) or _same_events(mix, [t1, wrow]),
		"005-F-C world/armor exact tie sorts deterministically")
	# 服务结果：ordered_contacts 权威统一序（事件 + 最近世界接触，面板直接读取）
	# 固定车体在原点：x=0 线段穿过车体——事件 [车首 5.0, 引擎进入 6.0, 引擎退出 7.0, 车尾 8.0]；
	# 世界 stop 6.5 应作为中段行插入（前驱 ≤ 6.5 < 后继），列表仍为单一严格距离序
	var snap_b := _identity_snapshot("B", 1, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	var rc := ShotQueryService.query({
		"query_id": "q_oc", "physics_tick": 31,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop": {"kind": "world", "event_type": "surface", "distance_m": 6.5,
			"point_world": Vector3(0, 1, 1.5), "normal_known": false},
	}, [snap_b])
	var oc: Array = rc.get("ordered_contacts", [])
	var oc_world := -1
	for i in oc.size():
		if str(oc[i].get("kind", "")) == "world":
			oc_world = i
	var oc_sorted := true
	for i in oc.size() - 1:
		if ShotQueryService.event_less(oc[i + 1], oc[i]):
			oc_sorted = false
	_ok(oc_world == 2 and oc_sorted
		and _dist(oc[oc_world - 1]) <= _dist(oc[oc_world]) and _dist(oc[oc_world]) < _dist(oc[oc_world + 1]),
		"005-F-C ordered_contacts merges world row at its true distance (world idx %d of %d)"
		% [oc_world, oc.size()])
	_ok(ExternalContactSelector.select_contact(rc).get("status", "") == "vehicle",
		"005-F-C selector policy unchanged (armor-surface 5.0m strictly before wall 6.5m)")
	# 完全同距（world 5.0 = armor 5.0）→ 列表确定性 + 选择器仍墙优先（政策不变）
	var rt := ShotQueryService.query({
		"query_id": "q_octie", "physics_tick": 32,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop": {"kind": "world", "event_type": "surface", "distance_m": 5.0,
			"point_world": Vector3(0, 1, 0.0), "normal_known": false},
	}, [snap_b])
	_ok(ExternalContactSelector.select_contact(rt).get("status", "") == "world",
		"005-F-C exact tie: selector still prefers wall (TIE_EPS policy)")
	var oct: Array = rt.get("ordered_contacts", [])
	var oct_sorted := true
	for i in oct.size() - 1:
		if not ShotQueryService.event_less(oct[i], oct[i + 1]):
			oct_sorted = false
	var mix2: Array = [wrow, t1]
	mix2.shuffle()
	mix2.sort_custom(ShotQueryService.event_less)
	_ok(oct.size() >= 3 and oct_sorted and _same_events(mix2, [t1, wrow]),
		"005-F-C exact tie ordered list consistent with service comparator (n=%d)" % oct.size())

	# A：legacy world_stop_distance_m 兼容——有限坐标重建（无 INF）；非法距离明确拒绝
	var snap_b2 := _identity_snapshot("B", 1, Transform3D(Basis.IDENTITY, Vector3(8, 0, 0)))
	var rl := ShotQueryService.query({
		"query_id": "q_legacy", "physics_tick": 33,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop_distance_m": 2.0,
	}, [snap_b2])
	var wc_l: Dictionary = rl.get("world_stop", {})
	var wp_l: Vector3 = wc_l.get("point_world", Vector3.INF)
	_ok(rl.get("ok", false) and wp_l.is_finite()
		and wp_l.is_equal_approx(Vector3(0, 1, -3.0)),
		"005-F-A legacy world_stop_distance_m rebuilds finite point (got %s)" % str(wp_l))
	_ok(absf(float(wc_l.get("distance_m", -1.0)) - 2.0) < 0.0001
		and absf(float(wc_l.get("t", 0.0)) - 0.2) < 0.0001 and not wc_l.get("normal_known", true),
		"005-F-A legacy world stop carries t + normal_known=false (t=%.3f)" % float(wc_l.get("t", 0.0)))
	var rl_bad := ShotQueryService.query({
		"query_id": "q_legacy_bad", "physics_tick": 34,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop_distance_m": 100.0,
	}, [snap_b2])
	_ok(not rl_bad.get("ok", true) and str(rl_bad.get("diagnostics", [""])[0]).contains("invalid_legacy_world_stop_distance"),
		"005-F-A legacy distance beyond segment rejected explicitly")
	# A：不可逆变换（零基底）→ 整实体明确未决（LayoutMath.is_rigid），不报告完整成功
	var degenerate := _identity_snapshot("D1", 1,
		Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(4, 0, 0)))
	var rd := ShotQueryService.query({
		"query_id": "q_degen", "physics_tick": 35,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [degenerate])
	_ok(not rd.get("complete", true) and rd.get("events", []).is_empty() and rd.get("diagnostics", []).size() > 0,
		"005-F-A non-rigid (zero basis) part transform fails the entity (no fake success)")
	_ok(str(rd.get("diagnostics", [""])[0]).find("invalid part transform") >= 0,
		"005-F-A diagnostic names the invalid part transform")
	# A：盒查询错误（无效模块尺寸）→ 诊断 + complete=false，不静默忽略
	var layout_bad: VehicleLayoutDefinition = _layout.duplicate(true)
	layout_bad.modules[0].size_m = Vector3(0.0, 0.5, 1.2)
	var rb := QuerySnapshotBuilder.build_identity_snapshot("E2", 1, "player_tank", layout_bad, {
		"hull": Transform3D(Basis.IDENTITY, Vector3.ZERO),
		"turret": Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0)),
		"barrel": Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.75)),
	})
	var rq := ShotQueryService.query({
		"query_id": "q_boxerr", "physics_tick": 36,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [rb])
	_ok(not rq.get("complete", true) and rq.get("diagnostics", []).size() >= 1
		and str(rq.get("diagnostics", [""])[0]).contains("box query error"),
		"005-F-A box query error appended to diagnostics and flips complete=false")


func _same_events(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var ea: Dictionary = a[i]
		var eb: Dictionary = b[i]
		if ShotQueryService.event_key(ea) != ShotQueryService.event_key(eb):
			return false
		if float(ea.get("distance_m", 0.0)) != float(eb.get("distance_m", 0.0)):
			return false
	return true


# --- 005-R1 收尾：A 世界适配器边界（真实物理空间）+ B 快照采样时点（面板） ---

func _finale_panel_cases() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 2:
		await process_frame
	main.open_query_debug()
	var panel: QueryDebugPanel = main._query_panel
	panel.set_probe("a_to_b")
	panel.set_vehicle_filter("ALL")
	var space := main.get_world_3d().direct_space_state
	# A：适配器边界——普通命中 t 正确 / 内部起点 / 整段在墙盒内
	panel.set_wall_geometry(Vector3(4, 1, 4), Vector3(0.4, 3.0, 3.0), 0.0)
	_ok(panel.apply_wall(), "005-F-A apply boundary wall")
	var d_ab := Vector3(8, -0.05, -8).normalized()
	var wa := WorldQueryAdapter.query_world_stop(space, Vector3(0, 1, 8), d_ab, 11.314)
	var wa_c: Dictionary = wa.get("contact", {}) if wa.get("hit", false) else {}
	_ok(wa.get("ok", false) and wa.get("hit", false)
		and absf(float(wa_c.get("distance_m", -1.0)) - 5.374) < 0.02,
		"005-F-A wall hit carries real distance (got %.3f)" % float(wa_c.get("distance_m", -1.0)))
	_ok(absf(float(wa_c.get("t", -1.0)) - 5.374 / 11.314) < 0.005 and wa_c.get("normal_known", false)
		and not wa_c.get("at_start", true),
		"005-F-A wall hit carries t/normal_known/at_start (t=%.4f)" % float(wa_c.get("t", -1.0)))
	var wi := WorldQueryAdapter.query_world_stop(space, Vector3(4, 1, 4), Vector3(1, 0, 0), 3.0)
	var wi_c: Dictionary = wi.get("contact", {}) if wi.get("hit", false) else {}
	_ok(wi.get("ok", false) and wi.get("hit", false) and float(wi_c.get("distance_m", -1.0)) <= 0.001
		and float(wi_c.get("t", -1.0)) <= 0.001 and not wi_c.get("normal_known", true)
		and wi_c.get("at_start", false),
		"005-F-A from-inside wall start: contact at origin, t~0, normal unknown")
	# A：整段在墙盒内——自定义线段（z=20）远离车辆，避免墙盒包住车辆引发物理推挤
	panel._custom_from.text = "0, 1, 20"
	panel._custom_to.text = "6, 1, 20"
	panel.set_probe("custom")
	panel.set_wall_geometry(Vector3(2, 1, 20), Vector3(8, 3, 3), 0.0)
	_ok(panel.apply_wall(), "005-F-A apply wall covering whole custom probe")
	var ww := WorldQueryAdapter.query_world_stop(space, Vector3(0, 1, 20), Vector3(1, 0, 0), 4.0)
	var ww_c: Dictionary = ww.get("contact", {}) if ww.get("hit", false) else {}
	_ok(ww.get("ok", false) and ww.get("hit", false) and float(ww_c.get("distance_m", -1.0)) <= 0.001
		and not ww_c.get("normal_known", true) and ww_c.get("at_start", false),
		"005-F-A whole segment inside wall box: contact at origin (t=%.3f)" % float(ww_c.get("t", -1.0)))
	# 面板级：自定义线段整段在墙盒内 → 世界行排第一（距离≈0）；墙移除后线段恢复无接触
	panel.run_query()
	for i in 2:
		await physics_frame
	var evs_whole: Array = panel.last_events()
	_ok(evs_whole.size() == 1 and str(evs_whole[0].get("kind", "")) == "world" and _dist(evs_whole[0]) < 0.01,
		"005-F-A panel whole-inside run: world row first at ~0m (rows=%d first=%.3f)" % [evs_whole.size(), _dist(evs_whole[0])])
	panel.remove_wall()
	for i in 2:
		await physics_frame
	_ok(panel.last_events().is_empty(),
		"005-F-A wall removal re-run clears probe (rows=%d)" % panel.last_events().size())
	panel.set_probe("a_to_b")
	# B：提交只冻结输入——提交后、执行前 += 移动 B → 结果用执行时快照（B 移出命中区 → 无 B 事件）
	panel.run_query()
	main.actor_b.tank.global_position += Vector3(0, 0, 3)   # 执行前移动（无 await 中间步）
	for i in 2:
		await physics_frame
	var evs_t0: Array = panel.last_events()
	_ok(evs_t0.size() == 2 and str(evs_t0[0].get("entity_id", "")) == "A",
		"005-F-B submit-then-move: result uses execution-time snapshot (B missed, got %d)" % evs_t0.size())
	_ok(_near(evs_t0[0], 0.424), "005-F-B A events match execution-time pose (first=%.3f)" % _dist(evs_t0[0]))
	# B 移回原位；提交后切换筛选框 → 不改变已提交请求（仍按 B 执行）
	main.actor_b.tank.global_position += Vector3(0, 0, -3)
	for i in 2:
		await physics_frame
	panel.set_vehicle_filter("B")
	panel.run_query()
	panel.set_vehicle_filter("ALL")   # 提交后切换（执行前）
	for i in 2:
		await physics_frame
	var evs_t1: Array = panel.last_events()
	_ok(evs_t1.size() == 2 and str(evs_t1[0].get("entity_id", "")) == "B" and _dist(evs_t1[0]) > 9.0,
		"005-F-B filter switch after submit does not mutate the submitted request (got %d)" % evs_t1.size())
	# 签名只覆盖实际参与的快照：B 筛选下移动 A → 不 STALE
	main.actor_a.tank.global_position += Vector3(0, 0, 0.5)
	for i in 2:
		await process_frame
	_ok(not panel.is_stale(), "005-F-B signature covers only snapshots actually used (A move not stale under B filter)")
	# 只转炮塔（B）→ STALE（签名包含全部部件变换，不止车体位置）
	# 断开 B 炮塔对自身相机 rig 的跟随：否则 rig 每帧向瞄点收敛，旋转不会保持、签名持续漂移
	main.actor_b.tank.turret_rig.cam_rig = null
	main.actor_b.tank.turret_rig.rotation.y += deg_to_rad(25.0)
	for i in 2:
		await process_frame
	_ok(panel.is_stale(), "005-F-B turret-only rotation marks result STALE")
	panel.run_query()
	for i in 2:
		await physics_frame
	_ok(not panel.is_stale(), "005-F-B re-run clears STALE after turret rotation")
	main.close_query_debug()
	main.queue_free()
	for i in 2:
		await process_frame


# --- 辅助 ---

func _identity_snapshot(entity_id: String, life_id: int, hull_transform: Transform3D) -> Dictionary:
	# 零姿态快照：hull 给定变换；turret/barrel 按布局 bind 链组合（hull 之上）。
	var turret_t := hull_transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0))
	var barrel_t := turret_t * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -0.75))
	return QuerySnapshotBuilder.build_identity_snapshot(entity_id, life_id, "player_tank", _layout, {
		"hull": hull_transform, "turret": turret_t, "barrel": barrel_t,
	})


func _ev(ev: Dictionary, kind: String, event_type: String, id: String) -> bool:
	return ev.get("kind", "") == kind and ev.get("event_type", "") == event_type \
		and (ev.get("surface_id", ev.get("module_id", ev.get("crew_id", ""))) == id)


func _dist(ev: Dictionary) -> float:
	return float(ev.get("distance_m", -1.0))


func _near(ev: Dictionary, expected: float) -> bool:
	return absf(_dist(ev) - expected) < 0.001


func _mini_layout(id: String, patches: Array, openings: Array) -> VehicleLayoutDefinition:
	var l := VehicleLayoutDefinition.new()
	l.id = id
	l.content_tier = "research"
	l.display_name = id
	l.historical_identity_id = "us_m4a3_75w_vvss_1944"
	var part_a := LayoutPartDefinition.new()
	part_a.id = "a"
	part_a.parent_id = ""
	part_a.joint_kind = "fixed"
	part_a.bind_local = Transform3D.IDENTITY
	var part_b := LayoutPartDefinition.new()
	part_b.id = "b"
	part_b.parent_id = ""
	part_b.joint_kind = "fixed"
	part_b.bind_local = Transform3D.IDENTITY
	l.parts = [part_a, part_b]
	for p in patches:
		var patch := ArmorPatchDefinition.new()
		patch.id = p["id"]
		patch.part_id = p["part"]
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
		declared.append({"id": o["id"], "part": o["part"], "boundary_loop": PackedVector3Array(o["boundary_loop"]), "note": "r5 fixture"})
	l.declared_openings = declared
	return l