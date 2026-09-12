extends SceneTree
var passed := 0
var failed := 0
var app: AppFlow
var scene: RiverJunctionRange
var shot_dir := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func frames(n: int=3) -> void:
	for i in n: await physics_frame
	await process_frame
func click(button: Button) -> void:
	await frames(3)
	if DisplayServer.get_name()=="headless": button.pressed.emit(); await frames(3); return
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=button.get_global_rect().get_center(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; Input.parse_input_event(event); await frames(3)
func capture(label: String) -> void:
	if shot_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	check(root.get_texture().get_image().save_png(shot_dir+"/"+label+".png")==OK,"actual screenshot "+label)
func run() -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index>=0: shot_dir=args[index+1]
	root.size=Vector2i(1280,720)
	app=AppFlow.new(); app.profile=ProfileStore.new(""); root.add_child(app); current_scene=app
	await frames(8); app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1); app.garage.frontend.show_page(2)
	var saved := app.profile.snapshot()
	await click(app.garage.frontend.map_drive_button); await frames(12)
	scene=app.training as RiverJunctionRange
	check(scene!=null and scene.navigator.valid,"garage driving entry builds admitted local navigation graph")
	scene._pause(); scene.select_stop(0); scene.route_choice.select(1)
	await click(scene.route_button)
	check(scene._paused and scene.route_active and scene.map_atlas.route.size()>10 and scene.route_note.begins_with("导航 B"),"real pause button plans route to B without resuming")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(scene.route_button.get_global_rect()),"last pause action fits default window")
	await capture("01_route_menu")
	await click(scene.hud.resume_btn); await frames(4)
	check(not scene._paused and scene.actor.controller==scene.controller and scene.map_atlas.route[-1].distance_to(Vector2(scene.navigation.goals.B.x,scene.navigation.goals.B.z))<.1,"route guide preserves local driver and terminates at real objective approach")
	await capture("02_south_to_B")
	scene._pause(); scene.route_choice.select(2); scene.route_choice.item_selected.emit(2); await frames(3)
	check(scene.route_note.begins_with("导航 C"),"changing objective replans through normal selector")
	scene.set_trial_size(10); await frames(3)
	check(scene.navigator.map_id=="river_junction_10v10" and Array(scene.map_atlas.route).all(func(p: Vector2) -> bool: return RiverJunctionDefinition.layout(10).bounds.has_point(p)),"layout switch uses inner road graph and clears outer route")
	scene.actor.tank.global_position=Vector3(200,8,200); scene.plan_route()
	check(scene.map_atlas.route.is_empty() and scene.route_note.contains("回到道路"),"off-network location clears stale route and gives recovery instruction")
	scene.select_stop(5); await click(scene.hud.resume_btn); await frames(10)
	await capture("03_quarry_road")
	var road_clear := true; var sampled := 0
	var space := scene.get_world_3d().direct_space_state
	for z in range(85,241,3):
		var x := RiverJunctionDefinition.lane_x(-520,z)
		for offset in [-10.5,0,10.5]:
			var p := Vector3(x+offset,8,z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*4,p-Vector3.UP*2,1))
			road_clear=road_clear and not hit.is_empty() and hit.position.y<8.035; sampled+=1
	check(road_clear,"quarry road and shoulders remain above physical terrain across "+str(sampled)+" samples")
	var start := scene.actor.tank.global_position
	var key := InputEventKey.new(); key.physical_keycode=KEY_W; key.keycode=KEY_W; key.pressed=true; Input.parse_input_event(key)
	await frames(180); key=InputEventKey.new(); key.physical_keycode=KEY_W; key.keycode=KEY_W; key.pressed=false; Input.parse_input_event(key); await frames(20)
	check(scene.actor.tank.global_position.distance_to(start)>5,"normal W input continues driving on corrected quarry road")
	await capture("04_quarry_driving")
	scene._pause(); scene.hud.training_requested.emit(); await frames(5)
	check(app.training==null and app.garage!=null and app.profile.snapshot()==saved and app.match_token.is_empty(),"route planning returns normally without changing profile or creating match rewards")
	app.free(); await frames(2); print("RESULT river_route_ui passed=%d failed=%d"%[passed,failed]); quit(0 if failed==0 else 1)
