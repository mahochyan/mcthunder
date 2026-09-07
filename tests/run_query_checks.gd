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
	# 法线已知且朝外（前板 +z）
	if events.size() > 0:
		var n: Vector3 = events[0]["normal_world"]
		_ok(events[0].get("normal_known", false) and n.z > 0.99, "005-b front plate normal +z (got %s)" % str(n))
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
	var r := ShotQueryService.query({
		"query_id": "q_wall", "physics_tick": 5,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
		"world_stop_distance_m": 2.0,
	}, [snap])
	_ok(absf(float(r["world_stop_distance_m"]) - 2.0) < 0.001, "005-b wall stop at 2m (got %.3f)" % float(r["world_stop_distance_m"]))
	# 墙后候选仍在 events 中（遮挡标记由上层/面板处理，服务不删除候选）
	_ok((r["events"] as Array).size() == 4, "005-b wall-behind candidates remain in events (occlusion is a display/rule concern)")
	# 移墙后（无 world_stop）→ 前板仍 5m
	var r2 := ShotQueryService.query({
		"query_id": "q_nowall", "physics_tick": 6,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	_ok(float(r2["world_stop_distance_m"]) < 0.0 and (r2["events"] as Array).size() == 4, "005-b no wall: front plate first again")


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
		_ok(n.x > 0.99, "005-b yaw90 front normal rotated to +x (got %s)" % str(n))
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
	# 同面片对角线：hull_front 是 quad（两三角形共享对角线 (0,0,0)-(1.15,1.35,0)？不——
	# hull_front 顶点 (-1.15,0.55,0),(1.15,0.55,0),(1.15,1.35,0),(-1.15,1.35,0)，
	# 三角形 (0,1,2),(0,2,3) 共享边 0-2（对角线）。探测线沿 z 穿过 z=0 平面——
	# 与两个三角形都相交于同一点 → 去重后只报一次。
	var r := ShotQueryService.query({
		"query_id": "q_seam", "physics_tick": 14,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap])
	var front_count := 0
	for ev in r["events"]:
		if ev.get("surface_id", "") == "hull_front":
			front_count += 1
	_ok(front_count == 1, "005-b shared diagonal of one patch reported once (got %d)" % front_count)
	# 不同面片保留：front 与 rear 是两个 surface_id → 各报一次
	var rear_count := 0
	for ev in r["events"]:
		if ev.get("surface_id", "") == "hull_rear":
			rear_count += 1
	_ok(rear_count == 1, "005-b distinct patches kept separate")
	# 共面：探测线在 hull_top 平面内（y=1.35 沿 z）→ coplanar_unresolved 诊断，不无限循环
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
	# 旧快照不读取后来变化的姿态：快照变换固定（构造后改布局/节点不影响已建快照）
	var snap_fixed := _identity_snapshot("B", 1, Transform3D.IDENTITY)
	var moved := Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	var r2 := ShotQueryService.query({
		"query_id": "q_fixed", "physics_tick": 17,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, [snap_fixed])
	_ok((r2["events"] as Array).size() == 4, "005-b snapshot transform fixed at build time (later pose changes not read)")
	# 性能边界：9 实体 → 明确失败
	var many: Array = []
	for i in range(9):
		many.append(_identity_snapshot("E%d" % i, 1, Transform3D.IDENTITY))
	var r3 := ShotQueryService.query({
		"query_id": "q_many", "physics_tick": 18,
		"from_world": Vector3(0, 1, -5), "to_world": Vector3(0, 1, 5),
		"excluded_instances": [], "include_modules": true, "include_crew": false,
	}, many)
	_ok(not r3.get("ok", false) and str(r3.get("diagnostics", [""])[0]).contains("too_many_entities"), "005-b >8 entities fails explicitly (no silent truncation)")


# --- 005-d：查询调试面板（范围入口/纯几何/弹药任务隔离/墙/陈旧） ---

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
	# 探针 A 中心 → B 中心：B 车体局部 z 0..3、x 6.85..9.15——
	# 射线穿 hull_left（x=6.85, 9.69m）再达 hull_front（z=0, 终点 11.31m）
	panel.set_probe("a_to_b")
	# ALL 过滤：服务报告全部实体几何（含射手自身——排除是开火路径的责任）
	panel.set_vehicle_filter("ALL")
	var qr_all: Dictionary = panel.run_query()
	var evs_all: Array = panel.last_events()
	_ok(qr_all.get("ok", false) and evs_all.size() == 3, "005-d a_to_b ALL filter: 3 events (A front at_start + B left + B front), got %d" % evs_all.size())
	if evs_all.size() == 3:
		_ok(str(evs_all[0].get("entity_id", "")) == "A" and str(evs_all[0].get("surface_id", "")) == "hull_front" and _near(evs_all[0], 0.0), "005-d ALL filter reports shooter-own geometry at segment start (at_start)")
	# 车辆过滤 B：只见 B 的 2 个装甲事件
	panel.set_vehicle_filter("B")
	var qr: Dictionary = panel.run_query()
	var evs: Array = panel.last_events()
	_ok(qr.get("ok", false) and evs.size() == 2, "005-d a_to_b B filter: 2 armor events (got %d)" % evs.size())
	if evs.size() == 2:
		_ok(_ev(evs[0], "armor", "surface", "hull_left") and str(evs[0].get("entity_id", "")) == "B", "005-d a_to_b first event = B hull_left")
		_ok(_ev(evs[1], "armor", "surface", "hull_front") and _near(evs[1], Vector3(0, 1, 8).distance_to(Vector3(8, 1, 0))), "005-d a_to_b front at segment end (at_end hit, got %.3f)" % _dist(evs[1]))
	_ok(panel.current_run_marker_count() == evs.size(), "005-d world markers match current-run events")
	_ok(main.gunner.shots_fired == shots0 and main.trial_hits == trial0, "005-d debug query consumed no ammo/task (shots=%d trial=%d)" % [main.gunner.shots_fired, main.trial_hits])
	# 显式测试墙（纯几何）：置于线段中点 (4,1,4)，yaw45——先于 B 任何装甲
	panel.set_wall_geometry(Vector3(4, 1, 4), Vector3(0.4, 3.0, 3.0), 45.0)
	_ok(panel.add_wall(), "005-d add test wall ok")
	var qr2: Dictionary = panel.run_query()
	var evs2: Array = panel.last_events()
	_ok(evs2.size() == 4, "005-d wall run: 4 events (wall enter/exit + 2 armor), got %d" % evs2.size())
	if evs2.size() == 4:
		_ok(str(evs2[0].get("kind", "")) == "wall" and str(evs2[0].get("event_type", "")) == "enter", "005-d wall enter first")
		_ok(_dist(evs2[0]) < _dist(evs2[2]), "005-d wall enter before B armor (%.2f < %.2f)" % [_dist(evs2[0]), _dist(evs2[2])])
		_ok(str(evs2[3].get("kind", "")) == "armor", "005-d armor still reported after wall (candidate retention)")
	var rows: Array = panel.current_rows()
	_ok(rows.size() == evs2.size(), "005-d row metadata matches events")
	var tags: Array = []
	for row in rows:
		tags.append(row.get("tag", ""))
	_ok(tags.size() == 4 and tags[0] == "WALL" and tags[1] == ">wall" and tags[3] == ">wall", "005-d occlusion tags before/after wall (%s)" % str(tags))
	# 移除墙 → 墙事件消失（剩余 2 装甲事件）
	_ok(panel.remove_wall(), "005-d remove test wall ok")
	panel.run_query()
	_ok(panel.last_events().size() == 2, "005-d after wall removal: wall events gone (got %d)" % panel.last_events().size())
	# 陈旧标记：面板打开期间车辆姿态变化 → 结果标记 STALE（不伪造当前姿态）
	main.actor_b.tank.global_position += Vector3(0, 0, 0.6)
	for i in 2:
		await process_frame
	_ok(panel.is_stale(), "005-d pose change marks results STALE")
	panel.run_query()
	_ok(not panel.is_stale(), "005-d re-run clears STALE")
	# 清空：结果/标记/线段全清
	panel.clear_results()
	_ok(panel.last_events().is_empty() and panel.marker_count() == 0, "005-d clear removes results and markers")
	# 关闭：恢复控制器意图；再开再关幂等
	main.close_query_debug()
	_ok(not main._query_panel_open and main.controller.commands_enabled, "005-d close restores controller intent")
	main.close_query_debug()
	_ok(not main._query_panel_open, "005-d close idempotent")
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