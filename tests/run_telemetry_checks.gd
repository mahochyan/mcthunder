extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 4) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene := VillageRange.new()
	scene.ai_only = true
	scene.match_seed = 19777
	root.add_child(scene)
	current_scene = scene
	await frames(200)
	var before := scene.director.state.tickets.duplicate()
	var ammo := scene.actor.gunner.rounds_remaining
	var sample := TelemetrySnapshot.capture(scene)
	check(sample.live == 8 and sample.ai_controllers == 8 and sample.local_controllers == 0 and sample.vehicle_cameras == 0 and sample.observer_camera,"AI-only scenario has eight actual AI controllers and one observer")
	check(scene.director.state.tickets == before and scene.actor.gunner.rounds_remaining == ammo,"telemetry capture leaves authoritative combat state unchanged")
	var map := scene.battle_ui.overlay.minimap
	var preparations: int = map.road_preparations
	var segments: PackedVector3Array = map._road_segments.duplicate()
	for i in 120:
		map.present_observations({"markers":[{"kind":"self","position":Vector3(i,0,0)}]},i%3)
	map.size = Vector2(240,220)
	await frames(6)
	check(segments.size()>0 and map.road_preparations == preparations and map._road_segments == segments,"dynamic markers and resizing reuse the static road geometry")
	map.roads = {}
	check(map._road_segments.is_empty(),"switching to a map without roads clears the previous layout")
	scene.free()
	await frames()
	var ordinary := VillageRange.new()
	root.add_child(ordinary)
	current_scene = ordinary
	await frames(200)
	sample = TelemetrySnapshot.capture(ordinary)
	check(sample.local_controllers == 1 and sample.ai_controllers == 7 and sample.vehicle_cameras == 1 and not ordinary.ai_only,"subsequent ordinary match restores one player and seven AI without scenario state leakage")
	ordinary.free()
	await frames()
	var summary := TelemetrySnapshot.frame_summary(PackedFloat64Array([10,20,30,40]))
	check(summary.mean_ms == 25 and summary.fps_from_mean == 40 and summary.p50_ms == 20 and summary.p95_ms == 40,"rendered-frame summary uses frame intervals and documented nearest-rank percentiles")
	check(TelemetrySnapshot.frame_summary(PackedFloat64Array()).count == 0,"empty frame measurements do not fabricate FPS")
	check(get_node_count() == 1,"diagnostic and ordinary scene teardown leaves only the root")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TELEMETRY_CHECKS_PASS" if failed == 0 else "TELEMETRY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
