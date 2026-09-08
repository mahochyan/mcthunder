extends SceneTree
## Authored-map renderer fixture, separate from player-flow evidence and FPS claims.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size = Vector2i(1280,720)
	var directory := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): directory=args[i+1]
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	for id in MapRegistry.IDS:
		var world := Node3D.new(); root.add_child(world); current_scene=world
		var map := MapRegistry.definition(id)
		if id=="industrial_edge": IndustrialWorld.build(world,map)
		else: VillageWorld.build(world,map)
		var camera := Camera3D.new(); world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size=500 if id=="industrial_edge" else 390
		camera.position=Vector3(200,350,260); camera.look_at(Vector3.ZERO); camera.current=true; camera.far=1000
		var canvas := CanvasLayer.new(); world.add_child(canvas)
		var title := Label.new(); title.add_theme_font_override("font",CoreUI.FONT)
		title.text = map.title+" · 地图布局观察夹具（非玩家视角）"; title.position=Vector2(24,20); title.add_theme_font_size_override("font_size",24); canvas.add_child(title)
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var ok := not frame.is_empty() and frame.save_png(directory.path_join(id+"_overview.png"))==OK
		print(("[PASS] " if ok else "[FAIL] ")+"real renderer overview "+id)
		world.free(); await process_frame
		if not ok: quit(1); return
	print("MAP_OVERVIEW_PASS"); quit(0)
