extends SceneTree
var count := 0
var failed := 0
var world: Node3D
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
	check(defs.load_defaults().ok,"four actual historical definitions load for map matrix")
	check(VehicleCatalog.new().load_all(defs).ok,"historical catalog admitted into the common definitions")
	check(MapRegistry.IDS.size() == 2 and not MapRegistry.contains("missing") and MapRegistry.definition("missing") == null,"registry accepts exactly the two playable maps")
	var profile := ProfileStore.new()
	var settings := profile.snapshot()
	check(profile.validate(settings).ok,"022 village profile remains valid without schema migration")
	settings.garage.map = "industrial_edge"
	check(profile.validate(settings).ok,"same profile validator admits registered industrial map")
	settings.garage.map = "missing"
	check(not profile.validate(settings).ok,"unregistered map cannot be saved or launched")
	for id in MapRegistry.IDS:
		var map := MapRegistry.definition(id)
		world = Node3D.new(); root.add_child(world); current_scene = world
		var terrain := IndustrialWorld.build(world,map) if id == "industrial_edge" else VillageWorld.build(world,map)
		await frames()
		var space := world.get_world_3d().direct_space_state
		var validation := map.validate()
		check(validation.ok,id+": schema and alternate paths "+str(validation))
		var bake := NavigationBakePipeline.build(map,space,terrain.get_rid())
		print("[bake ",id,"] ",bake.get("samples",0)," samples; failures=",bake.get("failures",bake.get("errors",[])))
		check(bake.ok,id+": every road clears maximum real vehicle envelope including final scenery")
		var sights := SpawnSelector.opposing_spawn_sightlines(space,map)
		check(sights.ok,id+": all "+str(sights.tested)+" opposing spawn rays blocked")
		if id == "industrial_edge": collision_cases(map,space)
		if bake.ok:
			var nav := DriveNavigator.new(); nav.configure(map.graph)
			var times := {}
			for type_id in VehicleCatalog.IDS:
				for team in [1,2]:
					for slot in 8:
						for destination in ["capture","supply"]:
							var goal := TeamArena.goal(team,slot%4) if destination == "capture" else map.supply_reservations[team-1]
							var result := await drive(map,nav,type_id,team,slot,goal)
							var key := "%s/%s/%d/%d/%s"%[id,type_id,team,slot,destination]
							print("[route] ",key," ",result)
							check(result.phase == "arrived" and result.bounded,"T023-02 actual driving "+key)
							if destination == "capture": times["%s/%d/%d"%[type_id,team,slot]] = result.seconds
			for type_id in VehicleCatalog.IDS:
				var a := 0.0; var b := 0.0
				for slot in 8: a += times["%s/1/%d"%[type_id,slot]]; b += times["%s/2/%d"%[type_id,slot]]
				print("[arrival means] ",id," ",type_id," team1=",a/8," team2=",b/8)
				check(absf(a-b)/maxf(a,b)<0.15,id+": same vehicle mean spawn arrival imbalance below 15% "+type_id)
		world.free(); await frames()
	await transitions()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("INDUSTRIAL_CHECKS_PASS" if failed == 0 else "INDUSTRIAL_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

func drive(map: MapDefinition, nav: DriveNavigator, type_id: String, team: int, slot: int, goal: Vector3) -> Dictionary:
	var actor := VehicleActor.new(); world.add_child(actor)
	var setup := actor.setup(defs,type_id,"route_fixture",team,map.spawns[team][slot],4,null)
	if not setup.ok: actor.free(); return {"phase":"setup_failed","bounded":false,"seconds":0}
	actor.set_physics_process(false); actor.gunner.aim_preview_enabled = false
	actor.cam_rig.set_process(false); actor.cam_rig.set_physics_process(false)
	var driver := AIPathDriver.new(); actor.add_child(driver); driver.configure(actor,nav); actor.set_controller(driver)
	driver.set_goal(goal)
	await frames()
	var previous := actor.tank.global_position
	var bounded := true; var steps := 0
	# Explicit fixed-step driving fixture: normal command polling and actual CharacterBody collision.
	for i in 18000:
		actor._physics_process(1.0/60)
		var p := actor.tank.global_position
		bounded = bounded and p.is_finite() and p.distance_to(previous)<actor.definition.forward_max_speed/60+0.2 and map.bounds.has_point(Vector2(p.x,p.z))
		previous = p; steps += 1
		if driver.phase in ["arrived","failed","unreachable"]: break
	var result := {"phase":driver.phase,"seconds":steps/60.0,"bounded":bounded,"position":previous,"recovery_attempts":driver.attempts}
	if driver.phase != "arrived": result.events = driver.events.duplicate(true)
	actor.free(); await frames(1)
	return result

func collision_cases(map: MapDefinition, space: PhysicsDirectSpaceState3D) -> void:
	var manager := ProjectileManager.new(); world.add_child(manager); manager.set_physics_process(false)
	var shot := 0
	for item in map.obstacles:
		var obstacle := world.get_node(NodePath(item.id)) as StaticBody3D
		var shape := obstacle.get_child(0) as CollisionShape3D
		# TerrainFixtures adds a mesh before collision in some callers: locate by type.
		for child in obstacle.get_children():
			if child is CollisionShape3D: shape = child; break
		check(shape != null and shape.shape is BoxShape3D and shape.shape.size == item.size,"T023-H02 visible/physical dimensions "+item.id)
		var from: Vector3 = item.position+Vector3(0,0,item.size.z/2+2)
		var velocity := Vector3(0,0,-300)
		if str(item.id).begins_with("boundary_x"):
			from = item.position+Vector3(-item.size.x/2-2,0,0); velocity = Vector3(300,0,0)
		shot += 1
		var spec := {"round_id":1,"shooter_id":"fixture","shooter_life_id":1,"shooter_team_id":1,"shot_id":shot,"shell_id":"map_fixture","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,500)]),"position_world":from,"velocity_world":velocity,"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":90.0}
		var accepted := manager.try_spawn(spec)
		var projectile := manager.get_projectile_state(accepted.projectile_id)
		manager.advance_projectile(projectile,0.04,[],space)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+velocity*0.04,GameConfig.LAYER_WORLD))
		check(projectile.terminal_reason == "impact_world" and not hit.is_empty() and hit.collider == obstacle,"T023-04 actual shell and LOS stop at "+item.id)
	for side in [-1,1]:
		for x in [78,95]:
			var a := Vector3(side*x,2.4,24); var b := Vector3(side*x,2.4,-24)
			check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,GameConfig.LAYER_WORLD)).is_empty(),"central loading block breaks long street and alley line %d/%d"%[side,x])
		var flank := Vector3(side*160,2.4,100)
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(flank,Vector3(side*160,2.4,-100),GameConfig.LAYER_WORLD)).is_empty(),"independent outer road stays open for flanking "+str(side))
	var rails := world.find_children("Cosmetic_FlushRailAssembly","MeshInstance3D",true,false)
	var rails_valid := rails.size()==1 and WorldCollisionRules.classify("road").blocks_shell == false
	if rails_valid:
		var rail_vertices: PackedVector3Array=rails[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for x in [-13.75,-12.25,12.25,13.75]:
			var has_strip:=false
			for v in rail_vertices:
				if absf(v.x-x)<0.05 and v.y>0.009 and absf(v.z)>34: has_strip=true
			rails_valid=rails_valid and has_strip
			for z in [-29.0,29.0]:
				rails_valid=rails_valid and space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,0.08,z),Vector3(x,0.001,z),GameConfig.LAYER_WORLD)).is_empty()
	check(rails_valid,"all four visible flush rail strips remain in the batch and actual world rays find no rail collision")
	manager.free()

func transitions() -> void:
	var app := AppFlow.new(); root.add_child(app); current_scene = app; await frames()
	var previous: WeakRef
	for id in ["industrial_edge","hill_village","industrial_edge"]:
		app.garage.vehicle_choice.select(1); app.garage.vehicle_choice.item_selected.emit(1)
		app.garage.preparation.map_choice.select(MapRegistry.IDS.find(id))
		var selected := app.garage.preparation.build_match()
		check(selected.ok and selected.config.map_id()==id,"garage freezes chosen map "+id)
		app.enter_laboratory("team"); await frames(8)
		var scene := app.training as VillageRange
		check(scene != null and scene.team_ready and scene.definition.id == MapRegistry.definition(id).id and scene.combat_actors().size()==8,"T023-01 actual scene selection "+id)
		check(scene.nav.valid and scene.battle_ui.overlay.minimap.world_rect==scene.definition.bounds,"selected graph and minimap match "+id)
		if previous != null: check(previous.get_ref()==null,"previous map and its actors freed")
		var old_id := scene.get_round_id(); previous = weakref(scene)
		app.restart_match(); await frames(8)
		check(previous.get_ref()==null and app.training.get_round_id()!=old_id and app.training.definition.id==MapRegistry.definition(id).id,"restart frees old world and preserves selected map "+id)
		previous = weakref(app.training); app.return_to_garage(); await frames(8)
		check(previous.get_ref()==null and app.garage != null and app.training==null,"return frees point, actors and paths "+id)
		check(MapRegistry.IDS[app.garage.preparation.map_choice.selected]==id,"saved garage restores selected map "+id)
	app.free(); await frames()
