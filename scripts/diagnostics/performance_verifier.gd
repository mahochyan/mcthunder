extends Node
## Opt-in release diagnostic. Measures real frames; never supplies battle outcomes.
var checks := 0
var failed := 0
var samples: Array = []
var lifecycle: Array = []
var frames_ms := PackedFloat64Array()
var scene: VillageRange
var folder := ""
var last_frame_us := 0
var capture_frames := false
var frame_groups := {}
var group := ""
var minimum_cycles := 20
var replay_probes: Array = []
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if capture_frames and last_frame_us>0 and frames_ms.size()<216000:
		var elapsed := (now-last_frame_us)/1000.0
		frames_ms.append(elapsed)
		if not frame_groups.has(group): frame_groups[group]=PackedFloat64Array()
		frame_groups[group].append(elapsed)
	last_frame_us=now
func cleanup() -> Dictionary:
	return {"nodes":get_tree().get_node_count(),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
func write_report(duration: float, complete: bool) -> void:
	var summaries := {}
	for key in frame_groups: summaries[key]=TelemetrySnapshot.frame_summary(frame_groups[key])
	var gpu_available:=samples.any(func(row: Dictionary) -> bool: return float(row.render_gpu_ms)>0)
	var static_memory_available:=lifecycle.any(func(row: Dictionary) -> bool: return int(row.static_memory_bytes)>0)
	var report := {"complete":complete,"requested_wall_seconds":duration,"requested_cycles":minimum_cycles,"gpu_timer_available":gpu_available,"static_memory_monitor_available":static_memory_available,"process_memory_source":"external Windows PrivateMemorySize64 and WorkingSet64 sampler","rendered":DisplayServer.get_name()!="headless","engine":Engine.get_version_info(),"os":OS.get_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"logical_cpus":OS.get_processor_count(),"gpu":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_video_adapter_api_version(),"resolution":str(get_tree().root.size),"renderer":RenderingServer.get_current_rendering_method(),"frame_times":TelemetrySnapshot.frame_summary(frames_ms),"groups":summaries,"samples":samples,"lifecycle":lifecycle,"checks":checks,"failed":failed}
	report["replay_probes"]=replay_probes
	var file:=FileAccess.open(folder+"/performance.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"  ")); file.close()
func run(app: AppFlow) -> void:
	var duration := 1800.0
	var args:=OS.get_cmdline_user_args(); var index:=args.find("--performance-seconds")
	if index>=0 and index+1<args.size(): duration=clampf(float(args[index+1]),10,3600)
	index=args.find("--performance-cycles")
	if index>=0 and index+1<args.size(): minimum_cycles=clampi(int(args[index+1]),2,40)
	folder="user://tests/performance033_%d"%Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(folder)
	print("PERFORMANCE_REPORT="+ProjectSettings.globalize_path(folder+"/performance.json"))
	check(OS.has_feature("release") and DisplayServer.get_name()!="headless","actual rendered Release performance run")
	app.garage.hide()
	ShotQueryService.measure_enabled=true
	ShotQueryService.measured_calls=0; ShotQueryService.measured_usec=0
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(),true)
	var started:=Time.get_ticks_msec()
	var next_sample:=0.0
	var cycle:=0
	while (Time.get_ticks_msec()-started)/1000.0<duration or cycle<minimum_cycles:
		var map_id: String=MapRegistry.IDS[cycle%2]
		AccessibilitySettings.fx_level=2-(int(cycle/2)%3)
		group=map_id+"_fx"+str(AccessibilitySettings.fx_level)
		scene=load(MapRegistry.scene_path(map_id)).instantiate()
		scene.unattended_diagnostic=true
		scene.selected_vehicle_id=VehicleCatalog.IDS[cycle%4]; scene.ai_only=true; scene.match_seed=33001+cycle*137
		add_child(scene)
		check(scene.team_ready,"complete eight-vehicle map cycle "+str(cycle+1))
		var cycle_started:=Time.get_ticks_msec()
		var short_cycle: bool=(cycle_started-started)/1000.0>=duration
		var allowed:=5.0 if short_cycle else minf(300.0,duration-(cycle_started-started)/1000.0)
		capture_frames=not short_cycle
		while (Time.get_ticks_msec()-cycle_started)/1000.0<allowed and scene.director.state.phase!="finished":
			await get_tree().process_frame
			var wall: float=(Time.get_ticks_msec()-started)/1000.0
			if wall>=next_sample:
				var snapshot:=TelemetrySnapshot.capture(scene)
				snapshot.merge({"query_calls_total":ShotQueryService.measured_calls,"query_cpu_ms_total":ShotQueryService.measured_usec/1000.0})
				var fire_count:=0
				for actor in scene.combat_actors(): fire_count+=actor.state.fires.size()
				var fragment_paths:=0
				for record in scene.projectiles.shot_records._records: fragment_paths+=record.get("fragments",[]).size()
				snapshot.merge({"fires":fire_count,"retained_fragment_paths":fragment_paths})
				snapshot.merge({"wall_seconds":wall,"map":map_id,"fx_level":AccessibilitySettings.fx_level,"cycle":cycle+1,"audio_voices":scene.projectiles.feedback.audio.active_count(),"fx_active":scene.projectiles.feedback.fx.active_count(),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(get_tree().root.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_tree().root.get_viewport_rid())})
				samples.append(snapshot)
				if snapshot.live>8 or snapshot.wrecks>RecoveryRules.WRECK_MAX_COUNT or snapshot.projectiles>ProjectileManager.MAX_ACTIVE or snapshot.audio_voices>CombatAudioPool.CAPACITY or snapshot.fx_active>CombatFXPool.CAPACITY: check(false,"live resource budget exceeded")
				next_sample=wall+2
				if samples.size()%30==0: print("[performance] wall=%.1f map=%s cycle=%d nodes=%d memory=%d"%[wall,map_id,cycle+1,snapshot.nodes,snapshot.static_memory_bytes]); write_report(duration,false)
		capture_frames=false
		if cycle<2:
			await RenderingServer.frame_post_draw
			check(get_tree().root.get_texture().get_image().save_png(folder+"/"+map_id+".png")==OK,"actual rendered map frame saved")
		scene.leave_match()
		check(scene.director.state.finish_count==1 and scene.projectiles.active_count()==0,"normal exit settles and clears accepted projectiles once")
		var replay_index:=scene.projectiles.shot_records.latest_replayable_index()
		var newest:=scene.projectiles.shot_records.get_record(scene.projectiles.shot_records.count()-1)
		var probe:={"cycle":cycle+1,"map":map_id,"short_cycle":short_cycle,"records":scene.projectiles.shot_records.count(),"selected_index":replay_index,"newest_complete":newest.get("complete",false),"newest_frames":newest.get("frames",[]).size(),"newest_unavailable_reason":newest.get("unavailable_reason","")}
		# Long battle probes must actually render an eligible record. Five-second
		# creation/exit cycles can legitimately have no shot history at all.
		if not short_cycle and allowed>=60: check(replay_index>=0,"long battle retains an actual complete replay with target geometry")
		if replay_index>=0:
			var settled:=scene.director.state.result.duplicate(true)
			var opened:=scene.replay.show_history(replay_index)
			probe["opened"]=opened; probe["error"]=scene.replay.view.error_reason
			check(opened,"settled battle opens its real recorded replay")
			group=map_id+"_replay"; capture_frames=true
			for frame in 12: await get_tree().process_frame
			capture_frames=false; scene.replay.view.close_view()
			check(scene.director.state.result==settled,"replay presentation preserves frozen battle result")
		replay_probes.append(probe)
		scene.free(); scene=null
		for frame in 8: await get_tree().process_frame
		lifecycle.append(cleanup())
		cycle+=1
		write_report(duration,false)
	var baseline: Dictionary=lifecycle[mini(3,lifecycle.size()-1)]
	var bounded:=true
	for row in lifecycle.slice(4): bounded=bounded and row.nodes==baseline.nodes and row.orphans==baseline.orphans and row.resources<=baseline.resources+8 and row.objects<=baseline.objects+32 and row.static_memory_bytes<=baseline.static_memory_bytes+16*1024*1024
	check(bounded,"scene lifecycles remain bounded after four warm-up cycles")
	check((Time.get_ticks_msec()-started)/1000.0>=duration and cycle>=minimum_cycles,"requested real wall duration and lifecycle count completed")
	check(not frames_ms.is_empty() and samples.size()>0,"real frame-time and resource samples captured")
	check(frames_ms.size()<216000,"bounded frame recorder did not truncate the requested measurement")
	write_report(duration,true)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("PERFORMANCE_CHECKS_PASS" if failed==0 else "PERFORMANCE_CHECKS_FAIL")
	get_tree().quit(0 if failed==0 else 1)
