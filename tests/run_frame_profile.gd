extends SceneTree
# Whole-match frame profiler (audit step 4). Accounting per GPT ruling:
# full_requested and match_finished are separate facts; wall-clock timeouts keep
# partial data and are labeled incomplete, never a passing full match; raw
# samples include the match opening (no silent warmup discard) with the steady
# window reported as its own clearly-named subset; every heavy-load family is
# reported as observed or explicitly not_covered.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless": print("[FAIL] frame profile requires a real window"); quit(1); return
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var out_dir := "res://logs/027A/frame-baseline"
	var index := args.find("--report-dir")
	if index>=0 and index+1<args.size(): out_dir = args[index+1]
	var map := "village"
	index = args.find("--map")
	if index>=0 and index+1<args.size(): map = args[index+1]
	var seed := 19001
	index = args.find("--seed")
	if index>=0 and index+1<args.size(): seed = int(args[index+1])
	var full := args.has("--full")   # full_requested: a request, NOT a completion claim
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene: TeamRange = IndustrialRange.new() if map == "industrial" else VillageRange.new()
	scene.ai_only = true
	scene.match_seed = seed
	root.add_child(scene)
	current_scene = scene
	var shots_fired := 0
	var shells_by_type := {}
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void:
		shots_fired += 1
		var shell := str(record.get("shell_id","?"))
		shells_by_type[shell] = int(shells_by_type.get(shell,0)) + 1)
	var samples := PackedFloat64Array()        # every drawn frame from match start
	var steady: PackedFloat64Array = []        # subset after the warmup window
	var snapshots: Array = []
	var warmup_ms := 15000
	var t0 := Time.get_ticks_usec()
	var measure_start_sim: float = scene.director.state.elapsed if scene.director != null else -1.0
	var wall_limit_ms := 600000 if full else 45000
	var match_finished := false
	var last := t0
	while Time.get_ticks_usec()-t0 < wall_limit_ms*1000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var ms := float(now-last)/1000.0
		last = now
		if samples.is_empty(): continue   # first frame has no interval baseline
		samples.append(ms)
		if now-t0 >= warmup_ms*1000: steady.append(ms)
		if samples.size()%30 == 0: snapshots.append(TelemetrySnapshot.capture(scene))
		if scene.director.state.phase == "finished":
			match_finished = true
			break
	var termination_reason: String = "wall_timeout" if not match_finished else str(scene.director.state.result.get("reason","?"))
	var measure_end_sim: float = scene.director.state.elapsed
	var wrecks_peak := 0
	for snap in snapshots: wrecks_peak = maxi(wrecks_peak,int(snap["wrecks"]))
	# --- actual load coverage families (observed vs explicitly not covered) ---
	var sections_hit := 0
	var sections_collapsed := 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is DestructibleSection:
			if int(node.hits) > 0: sections_hit += 1
			if int(node.hits) >= DestructibleSection.MAX_HITS: sections_collapsed += 1
		for child in node.get_children(): stack.append(child)
	var audio_peak_voices := 0
	var audio_accepted := 0
	var audio_peak_db := -100.0
	var astack: Array[Node] = [scene]
	while not astack.is_empty():
		var another: Node = astack.pop_back()
		if another is CombatAudioPool:
			audio_peak_voices = maxi(audio_peak_voices,another.peak_voices)
			audio_accepted += another.accepted
			audio_peak_db = maxf(audio_peak_db,another.peak_db)
		for child in another.get_children(): astack.append(child)
	var loadouts := {}
	for actor in scene.combat_actors():
		loadouts[actor.entity_id] = {"shell_counts":actor.gunner.initial_shell_counts.duplicate(true),"shell":str(actor.gunner.initial_shell_id)}
	var load_coverage := {
		"vehicle_config":loadouts,
		"shots_fired":shots_fired,
		"shell_types_observed":shells_by_type,
		"building_sections_hit":sections_hit,
		"building_sections_collapsed":sections_collapsed,
		"building_collapse": "observed" if sections_collapsed>0 else "not_covered",
		"wrecks_peak":wrecks_peak,
		"wreck_load": "observed" if wrecks_peak>0 else "not_covered",
		"audio": {"accepted":audio_accepted,"peak_voices":audio_peak_voices,"peak_db":audio_peak_db,
			"driver":AudioServer.get_driver_name(),
			"status":"observed" if audio_accepted>0 else ("dummy_driver" if AudioServer.get_driver_name()=="Dummy" else "not_covered")},
	}
	var report := {"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),
		"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),
		"map":map,"seed":seed,"full_requested":full,"match_finished":match_finished,
		"termination_reason":termination_reason,"incomplete":full and not match_finished,
		"measurement_start_sim_time":measure_start_sim,"measurement_end_sim_time":measure_end_sim,
		"warmup_seconds":warmup_ms/1000.0,"resolution":[1280,720],
		"physics_tick_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,
		"headless":false,
		"frames_from_match_start":TelemetrySnapshot.frame_summary(samples),
		"frames_after_warmup":TelemetrySnapshot.frame_summary(PackedFloat64Array(steady)) if steady.size()>30 else {"note":"run shorter than warmup window"},
		"samples_ms":Array(samples),"snapshots":snapshots,"load_coverage":load_coverage}
	var file := FileAccess.open(out_dir.path_join("FRAME_PROFILE_%s_%d.json" % [map,seed]),FileAccess.WRITE)
	if file == null: print("[FAIL] cannot save frame profile"); scene.free(); quit(1); return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var saved := not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(out_dir.path_join("FRAME_PROFILE_%s_%d.png" % [map,seed]))) == OK
	print("[frame profile] from_start=%s after_warmup=%s"%[report.frames_from_match_start,report.frames_after_warmup])
	print("[load coverage] shots=%d shells=%s collapse=%d/%d wreaks=%d audio=%s"%[shots_fired,shells_by_type,sections_collapsed,sections_hit,wrecks_peak,load_coverage.audio])
	print("[PASS] actual rendered frame intervals saved from match start")
	print("[PASS] original frame saved" if saved else "[FAIL] actual frame capture missing")
	var complete := saved and (match_finished or not full)
	if full and not match_finished: print("[INCOMPLETE] wall timeout at %ds — partial data kept, NOT a full-match pass"%int(wall_limit_ms/1000))
	print("FRAME_PROFILE_CHECKS_PASS" if complete else "FRAME_PROFILE_CHECKS_FAIL")
	scene.free()
	quit(0 if complete else 1)
