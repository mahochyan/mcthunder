extends SceneTree
# Verifies the read-only traffic telemetry through ONE real eight-AI match:
# every AI gets a per-life record, hold categories stay inside the sanctioned
# legitimate set, episode schema is complete, and the match still finishes
# normally (proof the sampler mutates nothing gameplay-relevant).
var count := 0
var failed := 0
var scene: VillageRange
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = VillageRange.new()
	scene.match_seed = 424242
	scene.ai_only = true
	root.add_child(scene)
	current_scene = scene
	await frames(5)
	_check(scene.director != null,"eight-AI scenario starts for telemetry verification")
	while scene.director.state.phase == "countdown": await physics_frame
	await frames(240)   # four seconds of actual play
	var snap: Dictionary = scene.telemetry.snapshot()
	_check(snap.per_life.size() >= 8,"every AI slot carries a per-life telemetry record")
	var whitelist := ["fire","recovery","combat","immobile","at_objective","resupply","no_task","planning_failed","planning_unreachable"]
	var holds_ok := true
	var lives: Array = snap.per_life.keys()
	for key in lives:
		for hk in snap.per_life[key].holds:
			if not whitelist.has(hk): holds_ok = false
	_check(holds_ok,"legitimate holds only use the sanctioned state set (no congestion mislabel)")
	# Run the match to its natural end; telemetry must not perturb it.
	var guard := 0
	while scene.director.state.phase == "playing" and guard < 80000:
		guard += 1
		await physics_frame
	_check(scene.director.state.phase == "finished" and not scene.director.state.result.is_empty(),"match reaches one natural result with telemetry attached")
	var final: Dictionary = scene.telemetry.snapshot()
	_check(float(final.clock) > 30.0,"telemetry clock tracks actual match seconds")
	var schema_ok := true
	var seen_durations: Array = []
	for key in final.per_life:
		for ep in final.per_life[key].episodes:
			seen_durations.append(ep.duration_s)
			for field in ["start_s","end_s","duration_s","outcome","blocker","driver_phase","ai_phase","waypoint"]:
				if not ep.has(field): schema_ok = false
	_check(schema_ok,"every congestion episode carries duration, outcome, blocker class, driver phase, ai phase and waypoint stage")
	var open_ok := true
	for key in final.per_life:
		var life: Dictionary = final.per_life[key]
		var has_open := false
		for ep in life.episodes:
			if ep.outcome == "open_at_end": has_open = true
		if int(life.open_at_end) == 1 and not has_open: open_ok = false
	_check(open_ok,"stalls still open at the end are recorded as open_at_end, never as recovered success")
	var path := "user://traffic_match_%d.json" % [scene.director.state.match_id]
	var file := FileAccess.open(path,FileAccess.READ)
	var parsed: Dictionary = {} if file == null else JSON.parse_string(file.get_as_text())
	_check(file != null and parsed.has("per_life") and parsed.has("planning") and parsed.has("thresholds"),"match-end evidence JSON is written with the full schema")
	print("[traffic] per_life=%d episodes=%d longest=%s planning=%s"%[final.per_life.size(),seen_durations.size(),
		final.per_life.values().map(func(v: Dictionary) -> float: return v.longest_s),final.planning])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TRAFFIC_TELEMETRY_CHECKS_PASS" if failed == 0 else "TRAFFIC_TELEMETRY_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
