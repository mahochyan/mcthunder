extends SceneTree
## Regression at the actual river road coordinates of the recorded A/A2 jam.
## Initial fixture positions only; all subsequent movement uses ordinary commands.
var actors: Array[VehicleActor]=[]
var drivers: Array[AIPathDriver]=[]
var controllers: Array[Node]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: print("ENTRY_TRAFFIC_TIMEOUT"); quit(2))
	var args := OS.get_cmdline_user_args()
	var full_ai := not args.has("--driver-only")
	var index := args.find("--out")
	var output: String=args[index+1] if index>=0 and index+1<args.size() else "res://logs/WT040-progress/entry-traffic.json"
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	if not catalog.load_all(defs).ok or not catalog.load_engineering(defs).ok: quit(2); return
	var world := Node3D.new(); root.add_child(world); current_scene=world
	RiverJunctionWorld.new().build(world)
	VehicleSimulationDriver.for_scene(world)
	var nav := DriveNavigator.new()
	nav.configure(RiverJunctionNavigation.new().build(16,4))
	for i in 2:
		var actor := VehicleActor.new(); actor.presentation_enabled=false; world.add_child(actor)
		var pose := Transform3D(Basis(Vector3.UP,-PI/2 if i==0 else PI/2),Vector3(-259.0378 if i==0 else -252.3133,8.1,220.03))
		var configured := actor.setup(defs,"ussr_t_80b" if i==0 else "germ_leopard_2a4","A" if i==0 else "A2",1,pose,2,null)
		if not configured.ok: print(configured); quit(2); return
		actors.append(actor)
		if full_ai:
			var ai := AITankController.new(); world.add_child(ai)
			ai.configure(actor,nav,func() -> Array: return actors,"normal",44001+i)
			ai.advance_while_engaged=true # Same persistent objective policy as TeamRange.
			controllers.append(ai); drivers.append(ai.driver)
		else:
			var driver := AIPathDriver.new(); world.add_child(driver); drivers.append(driver); controllers.append(driver)
			driver.configure(actor,nav)
	for step in 30: await physics_frame
	for i in 2:
		actors[i].set_controller(controllers[i])
		var goal: Vector3=nav.nodes[nav.nearest(Vector3(520,8,100) if i==0 else Vector3(-504,8,120))]
		if full_ai: (controllers[i] as AITankController).set_patrol(goal,actors[i].tank.global_position)
		else: drivers[i].set_goal(goal)
	var samples: Array=[]
	var origins: Array[Vector3]=[actors[0].tank.global_position,actors[1].tank.global_position]
	var departed := [false,false]
	var finite := true
	var previous: Array[Vector3]=origins.duplicate()
	for step in 60*120:
		await physics_frame
		for i in 2:
			var now := actors[i].tank.global_position
			finite=finite and now.is_finite() and now.distance_to(previous[i])<=actors[i].definition.forward_max_speed/60.0+.2
			previous[i]=now
			if step<=60*60 and now.distance_to(origins[i])>30: departed[i]=true
		if step%120!=0: continue
		var row := {"seconds":float(step)/60,"actors":[]}
		for i in 2:
			var actor := actors[i]; var driver := drivers[i]
			var obstacle := driver._obstacle(actor)
			var collider: Variant=obstacle.get("collider")
			row.actors.append({"id":actor.entity_id,"position":actor.tank.global_position,"yaw":actor.tank.rotation.y,"speed":actor.tank.forward_speed,
				"phase":driver.phase,"reason":driver.reason,"attempts":driver.attempts,"waypoint":driver.waypoint,"path_start":driver.path_ids.slice(0,4),
				"target":driver.path[driver.waypoint] if driver.waypoint<driver.path.size() else Vector3.INF,"blocked":driver._blocked_edges.duplicate(),
				"plans":driver.planning_counts.duplicate(),"throttle":controllers[i].last_command.throttle,"steer":controllers[i].last_command.steer,
				"obstacle":str(collider.get_path()) if collider is Node else ""})
		samples.append(row)
		if step%600==0: print("[entry] ",row)
	var record := {"fixture":"authored starting poses on actual river; production geometry, actors and shared simulation","full_ai":full_ai,"samples":samples,
		"resource_root":ProjectSettings.globalize_path("res://"),"driver_sha256":FileAccess.get_sha256("res://scripts/ai/ai_path_driver.gd"),"both_leave_jam_within_60s":departed[0] and departed[1],"bounded_physical_movement":finite}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(record,"  ")); file.close()
	var reached := drivers[1].phase=="arrived" and actors[1].tank.global_position.distance_to(drivers[1].goal)<GameConfig.AI_GOAL_RADIUS_M
	var closing := actors[0].tank.global_position.distance_to(drivers[0].goal)<300
	var failed := 0
	if not args.has("--diagnose-only"):
		for row in [[finite,"all movement remains finite and within physical speed bounds"],[departed[0] and departed[1],"both vehicles physically leave the recorded jam within 60 seconds"],[reached,"Leopard reaches and parks at its original capture approach"],[closing,"T-80 closes within 300 metres of its original objective instead of keeping the cleared-road detour"]]:
			print(("[PASS] " if row[0] else "[FAIL] ")+row[1])
			if not row[0]: failed+=1
		print("=== 结果: 4 项检查, %d 失败 ===" % failed)
		print("ENTRY_TRAFFIC_CHECKS_PASS" if failed==0 else "ENTRY_TRAFFIC_CHECKS_FAIL")
	world.free(); await process_frame
	print("ENTRY_TRAFFIC_RECORDED ",output)
	quit(0 if failed==0 else 1)
