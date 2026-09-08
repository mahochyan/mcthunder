extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless": print("[FAIL] frame profile requires a real window"); quit(1); return
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var out_dir := "res://logs/019/wip-uncommitted/frame_baseline"
	var index := args.find("--report-dir")
	if index>=0 and index+1<args.size(): out_dir = args[index+1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene := VillageRange.new()
	scene.ai_only = true
	scene.match_seed = 19001
	root.add_child(scene)
	current_scene = scene
	var warmup_end := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<warmup_end: await RenderingServer.frame_post_draw
	var samples := PackedFloat64Array()
	var snapshots: Array = []
	var last := Time.get_ticks_usec()
	var measured_until := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<measured_until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
		if samples.size()%30 == 0: snapshots.append(TelemetrySnapshot.capture(scene))
	var summary := TelemetrySnapshot.frame_summary(samples)
	var report := {"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"seed":19001,"resolution":[1280,720],"warmup_wall_seconds":15,"measurement_wall_seconds":30,"physics_tick_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,"headless":false,"frames":summary,"samples_ms":Array(samples),"snapshots":snapshots}
	var file := FileAccess.open(out_dir.path_join("FRAME_PROFILE.json"),FileAccess.WRITE)
	if file == null: print("[FAIL] cannot save frame profile"); scene.free(); quit(1); return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var saved := not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(out_dir.path_join("FRAME_PROFILE.png"))) == OK
	print("[frame profile] ",summary)
	print("[PASS] actual rendered frame intervals saved after warmup")
	print("[PASS] original frame saved" if saved else "[FAIL] actual frame capture missing")
	scene.free()
	print("FRAME_PROFILE_CHECKS_PASS" if saved else "FRAME_PROFILE_CHECKS_FAIL")
	quit(0 if saved else 1)
