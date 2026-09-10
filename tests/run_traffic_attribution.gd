extends SceneTree
# Traffic attribution sampler (stabilisation step 2/3, GPT: measure WHY first).
# Runs real eight-AI matches on a chosen map and dumps per-life congestion
# attribution produced by the in-match TrafficTelemetry (read-only).
# usage: godot --headless --path <root> -s res://tests/run_traffic_attribution.gd -- [--map industrial] [--seeds 23023,23024]
func _initialize() -> void: call_deferred("_run")
func _arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--"+name)
	return args[i+1] if i>=0 and i+1 < args.size() else fallback
func _run() -> void:
	root.size = Vector2i(1280,720)
	var map := _arg("map","industrial")
	var seeds: Array = []
	for s in _arg("seeds","23023,23024").split(","):
		seeds.append(int(s))
	var out_dir := "res://logs/027A/traffic-attribution"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for seed in seeds:
		var scene: TeamRange = IndustrialRange.new() if map == "industrial" else VillageRange.new()
		scene.match_seed = seed
		scene.ai_only = true
		root.add_child(scene)
		current_scene = scene
		while scene.director.state.phase == "countdown": await physics_frame
		var guard := 0
		while scene.director.state.phase == "playing" and guard < 80000:
			guard += 1
			await physics_frame
		var snap: Dictionary = scene.telemetry.snapshot()
		var report := {"map":map,"seed":seed,"result":scene.director.state.result,"telemetry":snap}
		var file := FileAccess.open(out_dir.path_join("%s_seed_%d.json" % [map,seed]),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
		print("[attribution] map=%s seed=%d clock=%.1f" % [map,seed,snap.clock])
		for key in snap.per_life:
			var life: Dictionary = snap.per_life[key]
			if life.episodes.is_empty() and life.total_s == 0.0: continue
			print("  life %s team=%d longest=%.1fs total=%.1fs holds=%s" % [key,life.team,life.longest_s,life.total_s,life.holds])
			for ep in life.episodes:
				print("    episode %.1f-%.1fs (%.1fs) blocker=%s phase=%s wp=%s outcome=%s" % [ep.start_s,ep.end_s,ep.duration_s,ep.blocker,ep.driver_phase,ep.waypoint,ep.outcome])
		print("  planning=%s" % snap.planning)
		scene.free()
		await process_frame
	print("TRAFFIC_ATTRIBUTION_DONE")
	quit(0)
