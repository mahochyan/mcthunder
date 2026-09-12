extends SceneTree
var passed := 0
var failed := 0
var app: AppFlow
var scene: RiverJunctionRange
var shots := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func frames(count: int=3) -> void:
	for i in count: await physics_frame
	await process_frame
func capture(label: String) -> void:
	if shots.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	check(root.get_texture().get_image().save_png(shots+"/"+label+".png")==OK,"actual driving image "+label)
func throttle(down: bool) -> void:
	if DisplayServer.get_name()=="headless":
		if down: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
	else:
		var event := InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=down; Input.parse_input_event(event)
func click(button: Button) -> void:
	if DisplayServer.get_name()=="headless": button.pressed.emit(); await process_frame; return
	var p := button.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=p; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; Input.parse_input_event(event)
		for i in 3: await process_frame

func cross_bridge(index: int) -> void:
	scene.select_stop(index+2); await frames(12)
	var lane: float=RiverJunctionDefinition.LANES[index]
	var start := scene.actor.tank.global_position
	var minimum_y := start.y; var ticks := 0
	throttle(true)
	while ticks<3600 and scene.actor.tank.global_position.z>RiverJunctionDefinition.river_z(lane)-90:
		await physics_frame; ticks+=1; minimum_y=minf(minimum_y,scene.actor.tank.global_position.y)
		if scene._paused: break
	throttle(false); await frames(3)
	var end := scene.actor.tank.global_position
	print("TRAVERSE ",lane," ticks=",ticks," start=",start," end=",end," min_y=",minimum_y)
	check(end.z<RiverJunctionDefinition.river_z(lane)-85,"production M4 drives completely across bridge "+str(index))
	check(minimum_y>7.0 and absf(end.x-lane)<20,"bridge traversal retains support and lateral clearance "+str(index))

func drive_exit(side: int) -> void:
	scene.select_stop(0); await frames(12)
	var start := scene.actor.tank.global_position
	var target_yaw := -side*PI*.5
	var ticks := 0
	while ticks<1800 and absf(scene.actor.tank.global_position.x-start.x)<105:
		var forward := -scene.actor.tank.global_basis.z
		var error := wrapf(target_yaw-atan2(-forward.x,-forward.z),-PI,PI)
		Input.action_release("turn_left"); Input.action_release("turn_right")
		if absf(error)>.025: Input.action_press("turn_left" if error>0 else "turn_right")
		throttle(absf(error)<.10)
		await physics_frame; ticks+=1
	throttle(false); Input.action_release("turn_left"); Input.action_release("turn_right"); await frames(4)
	var end := scene.actor.tank.global_position
	print("EGRESS ",side," ticks=",ticks," start=",start," end=",end)
	check((end.x-start.x)*side>100 and absf(end.z-start.z)<12,"real tank clears deployment via "+("west" if side<0 else "east")+" exit")

func run() -> void:
	var args := OS.get_cmdline_user_args(); var shot_index := args.find("--shot-dir")
	if shot_index>=0 and shot_index+1<args.size(): shots=args[shot_index+1]
	root.size=Vector2i(1280,720)
	app=AppFlow.new(); app.profile=ProfileStore.new(""); root.add_child(app); current_scene=app
	await frames(8)
	app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
	app.garage.frontend.show_page(2); await frames(4)
	var profile_before := app.profile.snapshot()
	await click(app.garage.frontend.map_drive_button)
	for i in 120:
		if app.training is RiverJunctionRange and app.training.ready_drive: break
		await process_frame
	scene=app.training as RiverJunctionRange
	check(scene!=null and scene.ready_drive,"garage opens actual large-map driving scene")
	if scene==null: app.free(); quit(1); return
	await frames(20)
	check(scene.actor.definition.id==VehicleCatalog.IDS[0],"garage selected historical vehicle reaches real Actor")
	check(scene.actor.controller==scene.controller and scene.actor.gunner.projectile_manager==scene.projectiles,"normal input and projectile manager remain wired")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(scene.map_atlas.get_global_rect()),"driving tactical map stays inside the default window")
	check(scene.world_builder.stats.hard_cover>=30,"physical earthworks installed")
	print("WORLD ",scene.world_builder.stats)
	await capture("01_bridge_start")
	var space := scene.get_world_3d().direct_space_state
	for count in [10,16]:
		var clear := true; var protected_count := 0; var threat_count := 0
		for team in [1,2]:
			for pose in RiverJunctionDefinition.spawns(count,team):
				var ground_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin+Vector3.UP*10,pose.origin-Vector3.UP*2,1))
				clear=clear and not ground_hit.is_empty() and absf(ground_hit.position.y-pose.origin.y+.15)<.2
				for goal in RiverJunctionDefinition.OBJECTIVES.values():
					var from := RiverJunctionDefinition.point(goal.xz,4)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,pose.origin+Vector3.UP*3.5,1))
					threat_count+=1
					if not hit.is_empty(): protected_count+=1
					else: print("EXPOSED ",count," team=",team," from=",from," to=",pose.origin+Vector3.UP*3.5)
		print("DEPLOYMENT LOS ",count," blocked=",protected_count," / ",threat_count)
		check(clear,"earthworks leave all deployment bays clear "+str(count))
		check(protected_count==threat_count,"three objective observation samples cannot see deployment roofs "+str(count))
	var road_x := RiverJunctionDefinition.lane_x(0,200)
	var road_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(road_x,20,200),Vector3(road_x,0,200),1))
	check(not road_hit.is_empty() and DriveSurface.kind_at(road_hit.collider,road_hit.position)=="road","physical terrain reports road surface under road")
	var ground_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(110,40,190),Vector3(110,-5,190),1))
	check(not ground_hit.is_empty() and DriveSurface.kind_at(ground_hit.collider,ground_hit.position)=="grass","off-road terrain reports grass drag")
	if args.has("--geometry-only"):
		app.free(); await frames(2); quit(0 if failed==0 else 1); return
	var routes := [0,1,2,3,4] if DisplayServer.get_name()=="headless" else [2]
	for index in routes: await cross_bridge(index)
	if DisplayServer.get_name()=="headless":
		for side in [-1,1]: await drive_exit(side)
	await capture("02_bridge_crossed")
	scene._pause(); var paused_pose := scene.actor.tank.global_transform; var cooldown := scene.actor.gunner.cooldown_left
	throttle(true); await frames(20); throttle(false)
	check(scene.actor.tank.global_transform==paused_pose and scene.actor.gunner.cooldown_left==cooldown,"pause freezes real vehicle and loading")
	scene.deployment_choice.select(9); scene.deployment_choice.item_selected.emit(9); await frames(3)
	check(scene._paused and scene.stop_index==9 and scene.actor.tank.global_position.distance_to(RiverJunctionDefinition.point(Vector2(520,185),.15))<.1,"pause deployment selector resets to actual town location while remaining paused")
	await capture("03_deployment_menu")
	scene._resume(); await frames(15)
	var town_start := scene.actor.tank.global_position
	throttle(true); await frames(180); throttle(false); await frames(10)
	check(scene.actor.tank.global_position.distance_to(town_start)>5,"normal player input drives through town street")
	await capture("04_town_driving")
	scene._reset_range(); await frames(15)
	check(scene.actor.tank.global_position.distance_to(RiverJunctionDefinition.point(Vector2(520,185)))<1,"reset returns to selected deployment location")
	var rounds := scene.actor.gunner.rounds_remaining
	# Submit an actual input action; controller owns the normal edge and Actor issues the shot.
	Input.action_press("fire"); await frames(3); Input.action_release("fire"); await frames(6)
	check(scene.actor.gunner.rounds_remaining==rounds-1,"normal player fire consumes exactly one loaded round on new map")
	scene.actor.tank.global_position=RiverJunctionDefinition.point(Vector2(1100,700),.15)
	await frames(60)
	check(scene.boundary_seconds>0 and not scene.boundary_warning.is_empty(),"leaving active driving area starts visible return countdown")
	await frames(270)
	check(scene.boundary_seconds==0 and scene.actor.tank.global_position.distance_to(RiverJunctionDefinition.point(Vector2(520,185)))<1,"out-of-bounds recovery returns to chosen deployment point")
	scene._pause(); scene.area_choice.select(1); scene.area_choice.item_selected.emit(1); await frames(3)
	check(scene.trial_team_size==10 and scene.map_atlas.team_size==10 and scene.deployment_choice.item_count==8,"10v10 driving layout uses inner crossings and its own deployment stops")
	check(scene._paused and scene.actor.tank.global_position.distance_to(RiverJunctionDefinition.point(Vector2(0,90),.15))<.1,"layout change safely places tank at active central crossing")
	await capture("05_inner_layout")
	scene.area_choice.select(0); scene.area_choice.item_selected.emit(0); scene.select_stop(0); scene._resume(); await frames(15)
	await capture("06_deployment_yard")
	scene._pause(); scene.hud.training_requested.emit(); await frames(6)
	check(app.training==null and app.garage!=null,"normal pause return restores garage")
	check(app.profile.snapshot()==profile_before and app.match_token.is_empty(),"free driving does not create match rewards or overwrite profile")
	app.free(); await frames(2)
	print("RESULT river_driving passed=%d failed=%d"%[passed,failed]); quit(0 if failed==0 else 1)
