extends SceneTree
var count := 0
var failed := 0
var world: Node3D
var map := VillageDefinition.create()
var terrain: StaticBody3D
var defs := VehicleDefs.new()
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	terrain = VillageWorld.build(world,map,true)
	await frames()
	var validation := map.validate()
	check(validation.ok,"map schema, bounds, 16 spawn candidates and independent alternate routes: "+str(validation))
	var space := world.get_world_3d().direct_space_state
	var bake := NavigationBakePipeline.build(map,space,terrain.get_rid())
	print("[bake] ",bake.get("samples",0)," samples; failures=",bake.get("failures",bake.get("errors",[])))
	check(bake.ok,"T018-03 every authored road has real ground and clears maximum vehicle envelope")
	var sights := SpawnSelector.opposing_spawn_sightlines(space,map)
	check(sights.ok,"T018-01 both spawn rows blocked at 1.4/2.4/3.5m; "+str(sights.tested)+" physical rays")
	check(WorldCollisionRules.classify("low_grass").blocks_shell == false and WorldCollisionRules.classify("solid_fence").blocks_shell,"grass and visibly solid plank fence use explicit shared rules")
	var original := map.graph.duplicate(true)
	map.graph.nodes[0].position[0] = 900
	check(not map.validate().ok,"map validator rejects out-of-bounds navigation data")
	map.graph = original
	check(defs.load_defaults().ok,"actual production vehicle definitions load")
	if not bake.ok: world.free(); finish(); return
	var times := {}
	for team in [1,2]:
		for index in 8:
			var result := await drive_route(team,index,false,false)
			print("[route] team=",team," slot=",index," ",result)
			check(result.phase == "arrived" and result.bounded,"T018-H01 actual actor from spawn %d/%d reaches own capture position"%[team,index])
			times["%d_%d"%[team,index]] = result.seconds
	print("[spawn arrival seconds] ",times)
	for team in [1,2]:
		var result := await drive_route(team,0,true,false)
		print("[alternate] team=",team," ",result)
		check(result.phase == "arrived" and result.min_x>-40 and result.max_x>65,"blocked western entrances force the independent eastern main route %d"%team)
	var wide := await drive_route(1,0,false,true)
	print("[maximum-size] ",wide)
	check(wide.phase == "arrived" and wide.bounded,"4.2x2.4x8.5m physical proxy drives the real road without teleport")
	var flank := await drive_route(1,0,false,true,true)
	print("[long hill flank maximum-size] ",flank)
	check(flank.phase == "arrived" and flank.peak_y>6 and flank.min_x < -118,"maximum-size proxy actually climbs and descends the western hill to far-side approach")
	var blocked := await drive_route(1,0,false,false,false,true)
	print("[real parked vehicle blockage] ",blocked)
	var recovered := false
	for event in blocked.events: recovered = recovered or event.phase == "reverse"
	check(blocked.phase == "arrived" and recovered,"T018-02 actual parked vehicle triggers recovery and another path to the point")
	world.free()
	finish()
func finish() -> void:
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MAP_CHECKS_PASS" if failed == 0 else "MAP_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

func drive_route(team: int, index: int, alternate: bool, wide: bool, flank: bool = false, blocked: bool = false) -> Dictionary:
	var parked: VehicleActor
	if blocked:
		parked = VehicleActor.new()
		world.add_child(parked)
		parked.setup(defs,"player_tank","parked_vehicle_fixture",team,Transform3D(Basis.IDENTITY,Vector3(-72,0.03,87)),4,null)
		parked.set_physics_process(false)
	var actor := VehicleActor.new()
	world.add_child(actor)
	actor.setup(defs,"player_tank","route_proxy",team,map.spawns[team][index],4,null)
	actor.set_physics_process(false)
	actor.gunner.aim_preview_enabled = false
	actor.cam_rig.set_process(false)
	actor.cam_rig.set_physics_process(false)
	if wide:
		actor.definition = actor.definition.duplicate(true)
		actor.definition.drive_collision_size = map.max_vehicle_size
		actor.definition.drive_collision_center = Vector3(0,map.max_vehicle_size.y/2,0)
		actor.tank.defs = actor.definition
		for child in actor.tank.get_children():
			if child is CollisionShape3D:
				child.shape = BoxShape3D.new()
				child.shape.size = map.max_vehicle_size
				child.position = actor.definition.drive_collision_center
	var nav := DriveNavigator.new()
	nav.configure(map.graph)
	if alternate:
		for i in range(nav.edges.size()-1,-1,-1):
			var e: Dictionary = nav.edges[i]
			if e.a == "hub%d_w"%team or e.b == "hub%d_w"%team: nav.edges.remove_at(i)
	var driver := AIPathDriver.new()
	actor.add_child(driver)
	driver.configure(actor,nav)
	actor.set_controller(driver)
	var goals: Array = [Vector3(-120,0,65),Vector3(-120,VillageDefinition.height(-120,0),0),Vector3(-120,0,-65),TeamArena.goal(2,index%4)] if flank else [TeamArena.goal(team,index%4)]
	driver.set_goal(goals.pop_front())
	await frames()
	var bounded := true
	var previous := actor.tank.global_position
	var max_x := 0.0
	var min_x := 0.0
	var peak_y := 0.0
	var steps := 0
	# Fixed-step integration fixture uses actual poll/submit/consume/drive/collision methods.
	for i in 15000:
		actor._physics_process(1.0/60)
		var p := actor.tank.global_position
		bounded = bounded and p.is_finite() and p.distance_to(previous)<actor.definition.forward_max_speed/60+0.2
		previous = p
		max_x = maxf(max_x,absf(p.x))
		min_x = minf(min_x,p.x)
		peak_y = maxf(peak_y,p.y)
		steps += 1
		if driver.phase == "arrived" and not goals.is_empty(): driver.set_goal(goals.pop_front())
		elif driver.phase in ["arrived","failed","unreachable"]: break
	var result := {"phase":driver.phase,"seconds":steps/60.0,"bounded":bounded,"max_x":max_x,"min_x":min_x,"peak_y":peak_y,"position":previous,"events":driver.events.duplicate(true)}
	actor.free()
	if parked != null: parked.free()
	await frames()
	return result
