extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless": print("[FAIL] frame profile requires a real window"); quit(1); return
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var out_dir := "res://logs/019/wip-uncommitted/frame_baseline"
	var index := args.find("--report-dir")
	if index>=0 and index+1<args.size(): out_dir = args[index+1]
	var map := "village"
	index = args.find("--map")
	if index>=0 and index+1<args.size(): map = args[index+1]
	var seed := 19001
	index = args.find("--seed")
	if index>=0 and index+1<args.size(): seed = int(args[index+1])
	# --full measures until the match settles naturally (audit step 4: whole
	# firefight under live fire/APHE/building damage/wrecks/audio, not 30s).
	var full := args.has("--full")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene: TeamRange = IndustrialRange.new() if map == "industrial" else VillageRange.new()
	scene.ai_only = true
	scene.match_seed = seed
	root.add_child(scene)
	current_scene = scene
	var warmup_end := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<warmup_end: await RenderingServer.frame_post_draw
	var samples := PackedFloat64Array()
	var snapshots: Array = []
	var last := Time.get_ticks_usec()
	var measured_until := Time.get_ticks_msec()+(600000 if full else 30000)
	var measure_t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec()<measured_until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
		if samples.size()%30 == 0: snapshots.append(TelemetrySnapshot.capture(scene))
		if full and scene.director.state.phase == "finished": break
	var summary := TelemetrySnapshot.frame_summary(samples)
	var report := {"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"map":map,"seed":seed,"full_match":full,"resolution":[1280,720],"warmup_wall_seconds":15,"measurement_wall_seconds":(Time.get_ticks_msec()-measure_t0)/1000.0,"physics_tick_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,"headless":false,"frames":summary,"samples_ms":Array(samples),"snapshots":snapshots}
	var file := FileAccess.open(out_dir.path_join("FRAME_PROFILE_%s_%d.json" % [map,seed]),FileAccess.WRITE)
	if file == null: print("[FAIL] cannot save frame profile"); scene.free(); quit(1); return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var saved := not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(out_dir.path_join("FRAME_PROFILE_%s_%d.png" % [map,seed]))) == OK
	print("[frame profile] ",summary)
	print("[PASS] actual rendered frame intervals saved after warmup")
	print("[PASS] original frame saved" if saved else "[FAIL] actual frame capture missing")
	scene.free()
	print("FRAME_PROFILE_CHECKS_PASS" if saved else "FRAME_PROFILE_CHECKS_FAIL")
	quit(0 if saved else 1)
