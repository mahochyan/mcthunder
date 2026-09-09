extends SceneTree
## Explicit model-inspection fixture; not normal player-flow evidence.
var count := 0
var failed := 0
var folder := "res://docs/evidence/025/wip-showcase"
func _initialize() -> void: call_deferred("_run")
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): folder=args[i+1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var defs:=VehicleDefs.new(); defs.load_defaults(); var loaded:=VehicleCatalog.new().load_all(defs)
	if not loaded.ok: quit(1); return
	var ids:=VehicleCatalog.IDS if not args.has("--prototype") else [VehicleCatalog.IDS[0]]
	for id in ids:
		var world:=Node3D.new(); root.add_child(world); current_scene=world
		WorldArtKit.box(world,Vector3(0,-0.5,0),Vector3(80,1,80),"grass")
		WorldLighting.build(world)
		var house:=WorldArtKit.box(world,Vector3(-11,2.5,12),Vector3(10,5,8),"plaster"); WorldArtKit.house_details(house,Vector3(10,5,8))
		WorldArtKit.tree(world,Vector3(11,0,14)); WorldArtKit.rocks(world,Vector3(6,0,11))
		var actor:=VehicleActor.new(); world.add_child(actor)
		var setup:=actor.setup(defs,id,"inspection",1,Transform3D.IDENTITY,2,null)
		if not setup.ok: failed+=1
		actor.label3d.visible=false
		var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(7,3.8,-10); camera.look_at(Vector3(0,1.3,0)); camera.current=true; camera.fov=48
		var canvas:=CanvasLayer.new(); world.add_child(canvas)
		var label:=Label.new(); label.add_theme_font_override("font",CoreUI.FONT); label.add_theme_font_size_override("font_size",22)
		label.position=Vector2(24,18); label.text="025 模型观察夹具 · "+str(defs.content_packets[id].display_name)+"\n统一材质与真实装甲外皮 · 非玩家视角"; canvas.add_child(label)
		await frames(20)
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		var error:=image.save_png(folder+"/"+id+".png")
		count+=1
		if error!=OK: failed+=1
		print(("[PASS] " if error==OK else "[FAIL] ")+"actual rendered model fixture "+id)
		world.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("ART_SHOWCASE_CHECKS_PASS")
	quit(0 if failed==0 else 1)
