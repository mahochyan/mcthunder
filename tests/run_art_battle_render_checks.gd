extends SceneTree
## Real window/real time, actual eight-AI battles. Observer camera is a render
## measurement fixture; no teleporting actors, forced kills, skipped clocks or fixed FPS.
var count:=0
var failed:=0
var directory:=""
var reports: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	count+=1
	if not value: failed+=1
	print(("[PASS] " if value else "[FAIL] ")+label)
func _run() -> void:
	if DisplayServer.get_name()=="headless": print("[FAIL] requires real renderer"); quit(1); return
	root.size=Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): directory=args[i+1]
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	for map_index in MapRegistry.IDS.size():
		var id: String=MapRegistry.IDS[map_index]
		var scene:=(load(MapRegistry.scene_path(id)) as PackedScene).instantiate() as VillageRange
		scene.selected_vehicle_id=VehicleCatalog.IDS[0]; scene.ai_only=true; scene.match_seed=25025+map_index
		root.add_child(scene); current_scene=scene
		for i in 180: await process_frame
		check(scene.team_ready and scene.combat_actors().size()==8,id+": real map contains eight actual AI actors")
		var ids:={}
		for actor in scene.combat_actors(): ids[actor.definition.id]=true
		check(ids.size()==4,id+": same battle contains all four vehicle types")
		var total:=AssetBudgetReport.inspect(scene)
		var camera:=scene.spectator
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=500 if id=="industrial_edge" else 390
		camera.position=Vector3(180,330,240); camera.look_at(Vector3.ZERO); camera.far=1000; camera.current=true
		var overview:=await sample(scene,8.0,false)
		check(overview.max_frustum_actors==8 and overview.max_live==8,id+": full-map sample actually includes all eight living vehicle centers in the frustum")
		await capture(id+"_eight_vehicle_overview")
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE; camera.fov=68
		var close:=await sample(scene,12.0,true)
		await capture(id+"_battle_follow")
		check(overview.frames.count>60 and close.frames.count>60 and overview.max_draw_calls>0 and close.max_primitives>0,id+": positive rendered frames/draw calls/primitives measured in both views")
		check(scene.director.state.elapsed>10 and scene.director.state.phase=="playing",id+": actual battle clock and AI remain live throughout sample")
		reports.append({"map":id,"seed":scene.match_seed,"configured_vehicles":8,"types":ids.keys(),"scene_budget":total,
			"overview":overview,"follow":close,"ending_telemetry":TelemetrySnapshot.capture(scene)})
		scene.free(); await process_frame; await process_frame
	var output:={"engine":Engine.get_version_info().string,"renderer":"gl_compatibility","gpu":RenderingServer.get_video_adapter_name(),
		"cpu":OS.get_processor_name(),"resolution":[1280,720],"vsync":"disabled","frame_cap":120,"fixed_fps":false,
		"scope":"real-time short eight-AI scene samples; observer cameras; not full-round performance acceptance","samples":reports}
	var file:=FileAccess.open(directory+"/RENDER_BUDGET.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ")); file.close()
	print("[render budget] ",JSON.stringify(output))
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("ART_BATTLE_RENDER_CHECKS_PASS")
	quit(0 if failed==0 else 1)
func sample(scene: VillageRange, seconds: float, follow: bool) -> Dictionary:
	var started:=Time.get_ticks_usec(); var previous:=started
	var frames_ms:=PackedFloat64Array()
	var maximum_draw:=0; var maximum_primitives:=0; var maximum_actors:=0; var maximum_live:=0; var minimum_live:=99
	while Time.get_ticks_usec()-started<int(seconds*1000000):
		if follow:
			var p:=scene.actor.tank.global_position
			scene.spectator.position=p+Vector3(-10,6,14); scene.spectator.look_at(p+Vector3(0,1.2,-9))
		await process_frame
		var now:=Time.get_ticks_usec(); frames_ms.append((now-previous)/1000.0); previous=now
		maximum_draw=maxi(maximum_draw,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		maximum_primitives=maxi(maximum_primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		var in_frame:=0; var living:=0
		for actor in scene.combat_actors():
			if not actor.state.destroyed: living+=1
			if scene.spectator.is_position_in_frustum(actor.tank.global_position+Vector3.UP): in_frame+=1
		maximum_actors=maxi(maximum_actors,in_frame); maximum_live=maxi(maximum_live,living); minimum_live=mini(minimum_live,living)
	return {"frames":TelemetrySnapshot.frame_summary(frames_ms),"max_draw_calls":maximum_draw,"max_primitives":maximum_primitives,
		"max_frustum_actors":maximum_actors,"max_live":maximum_live,"min_live":minimum_live}
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"actual render measurement image "+name)
