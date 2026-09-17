extends SceneTree
## Bounded P1 diagnosis: production packets/physics, no speed, collision or rule overrides.
var rows: Array = []
var output := "res://logs/WT040-progress/before.json"
var selected_case := "all"
var duration := 12
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func inspect_running(actor: VehicleActor) -> void:
	for part in [TrackAssembly.LEFT,TrackAssembly.RIGHT]:
		var frame := actor.tank.track_left_frame if part==TrackAssembly.LEFT else actor.tank.track_right_frame
		for mesh in frame.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=(actor.tank.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
			print("RUNNING_MESH ",actor.definition.id," ",part," ",mesh.name," ",bounds)
func sample(actor: VehicleActor, label: String, elapsed: float, start: Vector3) -> void:
	var body := actor.tank
	var ai: AIPathDriver = actor.controller as AIPathDriver
	if actor.controller is AITankController: ai=actor.controller.driver
	var submitted: VehicleCommand = actor.controller.last_command if ai!=null else null
	var collisions: Array=[]
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i); var collider := hit.get_collider()
		collisions.append({"name":str(collider.name) if collider is Node else str(collider),"normal":str(hit.get_normal())})
	var row := {"case":label,"seconds":elapsed,"entity":actor.entity_id,"vehicle":actor.definition.id,
		"position":str(body.global_position),"displacement":body.global_position.distance_to(start),"speed":body.forward_speed,
		"consumed_throttle":actor.last_consumed_throttle,"consumed_steer":actor.last_consumed_steer,
		"submitted_throttle":submitted.throttle if submitted!=null else float(Input.is_action_pressed("move_forward"))-float(Input.is_action_pressed("move_back")),
		"submitted_steer":submitted.steer if submitted!=null else Input.get_axis("turn_right","turn_left"),
		"waypoint_position":str(ai.path[ai.waypoint]) if ai!=null and ai.waypoint<ai.path.size() else "",
		"path_ids":ai.path_ids.duplicate() if ai!=null else [],"events":ai.events.duplicate(true) if ai!=null else [],
		"capabilities":actor.capabilities(),"ground":body.ground_state.duplicate(true),"collisions":collisions,
		"traction_acceleration":body.powertrain.traction_acceleration,"slope_blocked":body.slope_blocked,
		"collision_size":str(actor.definition.drive_collision_size),"collision_center":str(actor.definition.drive_collision_center),
		"probe_offsets":body.track_probe_offsets.duplicate(true),"forward_accel":actor.definition.forward_accel,
		"max_speed":actor.definition.forward_max_speed,"phase":ai.phase if ai!=null else "player",
		"slope_limit":actor.definition.max_slope_deg,"floor_contact":body.is_on_floor(),"velocity":str(body.velocity),
		"reason":ai.reason if ai!=null else "","waypoint":ai.waypoint if ai!=null else -1,
		"desired_goal":str(ai.goal) if ai!=null else "","heading":body.global_rotation.y}
	rows.append(row)
	print("SAMPLE ",label," ",actor.entity_id," t=",elapsed," d=",snappedf(row.displacement,.01)," speed=",snappedf(row.speed,.01)," command=",row.submitted_throttle,"/",row.consumed_throttle," support=",body.ground_state.left_support,"/",body.ground_state.right_support," phase=",row.phase," wp=",row.waypoint," p=",row.position)
func flat_case(id: String, use_ai: bool) -> void:
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	if not catalog.load_all(defs).ok or not catalog.load_engineering(defs).ok: push_error("catalog rejected"); quit(1); return
	var world := Node3D.new(); root.add_child(world); current_scene=world
	TerrainFixtures.box(world,Vector3(0,-.5,0),Vector3(1000,1,1000))
	VehicleSimulationDriver.for_scene(world)
	var actor := VehicleActor.new(); actor.presentation_enabled=false; world.add_child(actor)
	if not actor.setup(defs,id,"A",1,Transform3D(Basis.IDENTITY,Vector3(0,.15,0)),2,null).ok: push_error("setup rejected"); quit(1); return
	var driver: Node
	if use_ai:
		var nav := DriveNavigator.new()
		nav.configure({"schema_version":1,"map_id":"flat_control","through_waypoints":true,"nodes":[{"id":"start","position":[0,0,0]},{"id":"mid","position":[0,0,-35]},{"id":"end","position":[0,0,-70]}],"edges":[{"a":"start","b":"mid","width":12},{"a":"mid","b":"end","width":12}]})
		driver=AIPathDriver.new(); actor.add_child(driver); driver.configure(actor,nav)
	else: driver=PlayerController.new(); actor.add_child(driver)
	actor.set_controller(driver); await frames(60)
	inspect_running(actor)
	var start := actor.tank.global_position
	if use_ai: driver.set_goal(Vector3(0,0,-70))
	else: Input.action_press("move_forward")
	for step in duration/2:
		await frames(120); sample(actor,"flat_ai" if use_ai else "flat_player",(step+1)*2,start)
	Input.action_release("move_forward"); world.free(); await frames(3)
func river_case(single: bool, player: bool=false) -> void:
	var scene := RiverTeamRange.new(); scene.selected_vehicle_id="ussr_t_80b"; scene.opposing_engineering_id="germ_leopard_2a4"; scene.ai_only=not player; scene.match_seed=44001
	root.add_child(scene); current_scene=scene; await frames(195)
	if not scene.team_ready: push_error("river not ready"); quit(1); return
	if single:
		for actor in scene.combat_actors():
			if actor!=scene.actor: actor.free()
	var starts := {}
	for actor in scene.combat_actors(): starts[actor.entity_id]=actor.tank.global_position
	if player: Input.action_press("move_forward")
	for step in duration/2:
		await frames(120)
		for actor in scene.combat_actors(): sample(actor,"river_player" if player else ("river_single" if single else "river_roster"),(step+1)*2,starts[actor.entity_id])
	if selected_case=="player_recovery":
		Input.action_release("move_forward"); Input.action_press("move_back")
		for step in 6:
			await frames(120); sample(scene.actor,"river_player_reverse",duration+(step+1)*2,starts[scene.actor.entity_id])
		Input.action_release("move_back")
	Input.action_release("move_forward"); scene.free(); await frames(3)
func run() -> void:
	InputBindingService.initialize()
	var args := OS.get_cmdline_user_args(); var i := args.find("--out")
	if i>=0: output=args[i+1]
	i=args.find("--case")
	if i>=0: selected_case=args[i+1]
	i=args.find("--seconds")
	if i>=0: duration=int(args[i+1])
	if selected_case in ["all","flat"]:
		for id in ["ussr_t_80b","germ_leopard_2a4"]:
			await flat_case(id,false); await flat_case(id,true)
	if selected_case in ["all","roster"]: await river_case(false)
	if selected_case in ["all","single"]: await river_case(true)
	if selected_case in ["all","player","player_recovery"]: await river_case(true,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"scope":"bounded diagnostic, not acceptance","samples":rows},"\t")); file.close()
	OS.delay_msec(150); print("PROGRESS_DIAG_DONE samples=",rows.size()); quit(0)
