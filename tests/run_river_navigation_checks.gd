extends SceneTree
var passed := 0
var failed := 0
var scene: RiverJunctionRange
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func frames(count: int=3) -> void:
	for i in count: await physics_frame
	await process_frame

func geometry(builder: RiverJunctionNavigation) -> void:
	var blocked: Array=[]; var unsupported: Array=[]
	var space := scene.get_world_3d().direct_space_state
	for edge in builder.edges.values():
		var a: Vector3=builder.nodes[edge.a]; var b: Vector3=builder.nodes[edge.b]
		var side := (b-a).cross(Vector3.UP).normalized()*1.9
		for sign in [-1,0,1]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a+Vector3.UP+side*sign,b+Vector3.UP+side*sign,1))
			if not hit.is_empty(): blocked.append({"edge":edge,"hit":hit.position,"body":hit.collider.name}); break
		for i in 4:
			var p := a.lerp(b,float(i)/3)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,1))
			if hit.is_empty() or absf(hit.position.y-p.y)>.4: unsupported.append({"edge":edge,"point":p,"hit":hit.get("position")}); break
	print("GEOMETRY nodes=",builder.nodes.size()," edges=",builder.edges.size()," blocked=",blocked.size()," unsupported=",unsupported.size())
	for row in blocked.slice(0,8): print("BLOCKED ",row)
	for row in unsupported.slice(0,8): print("UNSUPPORTED ",row)
	check(blocked.is_empty(),"navigation corridors clear physical world at tank hull width")
	check(unsupported.is_empty(),"navigation segments have physical ground or bridge support")

func drive(capacity: int,team: int,slot: int,target: String) -> void:
	var builder := RiverJunctionNavigation.new(); var nav := DriveNavigator.new(); nav.configure(builder.build(capacity))
	var pose := RiverJunctionDefinition.spawns(capacity,team)[slot]
	scene.actor.tank.set_spawn(pose); scene.actor.reset_vehicle()
	var driver := AIPathDriver.new(); scene.actor.add_child(driver); driver.configure(scene.actor,nav); scene.actor.set_controller(driver)
	scene.actor.cam_rig.cam.current=true
	await frames(10)
	var result := driver.set_goal(builder.goals[target])
	check(result.ok,"production driver plans deployment to "+target+" / "+str(capacity)+" / "+str(team))
	var ticks := 0
	while ticks<42000 and driver.has_goal:
		await physics_frame; ticks+=1
		if ticks%6000==0: print("DRIVING ",capacity," ",target," tick=",ticks," pos=",scene.actor.tank.global_position," phase=",driver.phase," waypoint=",driver.waypoint,"/",driver.path.size())
	print("ARRIVAL ",capacity," team=",team," slot=",slot," target=",target," ticks=",ticks," phase=",driver.phase," reason=",driver.reason," position=",scene.actor.tank.global_position)
	if driver.phase!="arrived": print("DRIVER_EVENTS ",driver.events)
	check(driver.phase=="arrived" and scene.actor.tank.global_position.distance_to(builder.goals[target])<3,"actual M4 reaches objective through authored road network")
	scene.actor.set_controller(null); driver.free()

func run() -> void:
	InputBindingService.initialize()
	scene=RiverJunctionRange.new(); scene.selected_vehicle_id=VehicleCatalog.IDS[0]; root.add_child(scene); current_scene=scene
	await frames(12); scene.capture_director.set_physics_process(false)
	for capacity in [10,16]:
		var builder := RiverJunctionNavigation.new(); var nav := DriveNavigator.new()
		check(nav.configure(builder.build(capacity)).ok,"real navigator accepts "+str(capacity)+" layout")
		var reachable := true; var routes := 0
		for team in [1,2]:
			for pose in RiverJunctionDefinition.spawns(capacity,team):
				for goal in builder.goals.values():
					var result := nav.request_path(pose.origin,goal,3.5); reachable=reachable and result.ok; routes+=1
		check(reachable,"all "+str(routes)+" spawn/objective combinations reachable in graph")
		for lane in RiverJunctionDefinition.layout(capacity).crossings:
			var blocked := {}
			for edge in builder.edges.values():
				var a: Vector3=builder.nodes[edge.a]; var b: Vector3=builder.nodes[edge.b]
				var crossing_z := RiverJunctionDefinition.river_z(lane)
				if absf(a.x-lane)<1 and absf(b.x-lane)<1 and minf(a.z,b.z)<=crossing_z and maxf(a.z,b.z)>=crossing_z:
					blocked[DriveNavigator.edge_key(edge.a,edge.b)]=true
			var alternate := nav.request_path(RiverJunctionDefinition.spawns(capacity,1)[0].origin,builder.goals.B,3.5,blocked)
			check(not blocked.is_empty() and alternate.ok,"single bridge closure retains a cross-river alternative: "+str(lane)+" / "+str(capacity))
		geometry(builder)
	if failed==0 and not OS.get_cmdline_user_args().has("--geometry-only"):
		await drive(16,1,5,"B")
		await drive(10,2,0,"A")
		await drive(16,1,13,"C")
	scene.free(); await frames(2)
	# Fixed-fps headless simulation can finish before the audio mixing thread releases stopped voices.
	OS.delay_msec(150)
	print("RESULT river_navigation passed=%d failed=%d"%[passed,failed]); quit(0 if failed==0 else 1)
