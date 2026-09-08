extends SceneTree
var count := 0
var failed := 0
var scene: TerrainRange
var tank: TankVehicle
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _place(p: Vector3, forward: Vector3 = Vector3.FORWARD) -> void:
	tank.global_transform = Transform3D(VehiclePose.compose(forward,Vector3.UP),p)
	tank.forward_speed = 0
	tank.velocity = Vector3.ZERO
	_step(90,0,0)
func _step(n: int, throttle: float, steer: float) -> void:
	for i in n: tank.apply_drive(throttle,steer,1.0/60)
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = TerrainRange.new()
	root.add_child(scene)
	current_scene = scene
	await _frames(10)
	await physics_frame
	tank = scene.source_actor.tank
	for actor in [scene.source_actor,scene.target_actor]: actor.set_physics_process(false)
	scene.target_actor.tank.collision_layer = 0 # Isolate ramp geometry; restore for the actor-blocking case.
	_check(scene.ready_drive,"actual terrain laboratory initializes two production actors")
	_check(tank.defs != scene.defs.get_vehicle("player_tank") and scene.defs.get_vehicle("player_tank").drive_collision_size == GameConfig.DRIVE_COLLISION_SIZE,"profile does not mutate shared legacy definition")
	var profile := scene.source_actor.damage_layout_override
	var mesh_ok := true
	for patch in profile.armor_patches:
		var parent: Node3D = tank if patch.part_id == "hull" else scene.source_actor.turret
		var visual := parent.get_node_or_null("Skin_"+patch.id) as MeshInstance3D
		mesh_ok = mesh_ok and visual != null and visual.mesh != null
		if visual != null and visual.mesh != null:
			var arrays := visual.mesh.surface_get_arrays(0)
			for vertex in arrays[Mesh.ARRAY_VERTEX]: mesh_ok = mesh_ok and patch.vertices_local_m.has(vertex)
	_check(mesh_ok and profile.armor_patches.size() > 40,"all silhouette armor skins render actual finite query vertices")
	var detail_instances := 0
	var detail_triangles := 0
	var draw_groups := 0
	for mesh in tank.find_children("*","MultiMeshInstance3D",true,false):
		detail_instances += mesh.multimesh.instance_count
		var arrays: Array = mesh.multimesh.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var triangles: int = indices.size()/3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		detail_triangles += triangles*mesh.multimesh.instance_count
		draw_groups += 1
	_check(detail_instances > 0 and detail_triangles < 18000 and draw_groups < 40,"low-poly mechanical detail mesh stays within recorded budget (%d instances / %d triangles / %d groups)"%[detail_instances,detail_triangles,draw_groups])
	_place(Vector3(0,0.05,0))
	_step(240,1,0)
	print("[drive10] ",tank.global_position," slope=",tank.ground_state.slope_deg," pose=",tank.global_rotation_degrees)
	_check(tank.global_position.z < -15 and tank.global_position.y > 0.4,"real 10-degree ramp lifts vehicle through actual drive")
	_check(absf(tank.global_rotation_degrees.x) > 5 and tank.ground_state.support_count >= 3,"hull aligns to sampled incline with real support")
	_place(Vector3(0,1.1,-18))
	_step(30,1,0)
	_step(180,0,0)
	var stop := tank.global_position
	_step(360,0,0)
	_check(stop.y > 0.5 and tank.ground_state.slope_deg > 5 and tank.global_position.distance_to(stop) < 0.08 and absf(tank.forward_speed) < 0.01,"coast decelerates then holds stationary on actual permitted slope")
	_step(200,-1,0)
	_check(tank.global_position.z > stop.z+4 and absf(tank.forward_speed) <= tank.defs.reverse_max_speed+0.001,"reverse descends actual slope with reverse speed cap")
	_place(Vector3(18,0.05,0))
	scene.target_actor.tank.global_position = Vector3(50,0,20)
	_step(235,1,0)
	print("[drive20] ",tank.global_position," slope=",tank.ground_state.slope_deg," pose=",tank.global_rotation_degrees)
	_check(tank.global_position.z < -15 and tank.global_position.y > 1,"20-degree route is climbable")
	_check(tank.global_basis.is_finite() and absf(tank.global_basis.determinant()-1) < 0.001,"slope orientation stays rigid without scale drift")
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(tank,profile)
	_check(snapshot.part_world_transforms.hull == tank.global_transform and snapshot.part_world_transforms.turret == scene.source_actor.turret.global_transform,"shot snapshot uses same tilted hull and turret transforms once")
	var aim := tank.global_position+tank.global_basis*Vector3(0,3,-30)
	scene.source_actor.turret.set_aim_point(aim)
	scene.source_actor.turret.snap_to_aim()
	var direction := (aim-scene.source_actor.turret.barrel_pivot.global_position).normalized()
	_check(scene.source_actor.turret.barrel_direction().dot(direction) > 0.999,"slope aiming computes local angles from full hull basis")
	_place(Vector3(36,0.05,0))
	_step(420,1,0)
	print("[drive30] ",tank.global_position," slope=",tank.ground_state.slope_deg," blocked=",tank.slope_blocked)
	_check(tank.global_position.z > -15 and tank.global_position.y < 1.5,"30-degree slope cannot be climbed past front-edge support")
	var edge := tank.global_position
	_step(180,-1,0)
	_check(tank.global_position.z > edge.z+2,"vehicle can reverse away from rejected slope")
	_place(Vector3(-18,0.05,-20))
	_step(3600,1,0)
	_check(tank.global_position.z > -25 and tank.global_position.is_finite(),"60 seconds of actual drive against wall neither tunnels nor explodes")
	var wall_pos := tank.global_position
	_step(240,0,0)
	wall_pos = tank.global_position
	_step(3600,0,1)
	_check(tank.global_position.is_finite() and tank.global_position.distance_to(wall_pos) < 3,"60 seconds of wall-adjacent turning remains bounded")
	_place(Vector3(0,0.05,10))
	scene.target_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0,0))
	scene.target_actor.tank.collision_layer = GameConfig.LAYER_VEHICLE
	await _frames()
	await physics_frame
	_step(240,1,0)
	_check(tank.global_position.z > 4.9,"two full-size actors remain physically blocking")
	_place(Vector3(-27,0.05,-10))
	_step(180,0,0)
	_check(tank.global_position.y < -0.6 and tank.global_position.y > -1.3,"pit has actual lowered collision floor")
	_place(Vector3(0,0.05,4))
	var before := tank.global_position
	scene.source_actor.state.module_states.engine.integrity = 0 # Explicit damage-state fixture; actual projectile case below.
	_step(180,1,1)
	_check(tank.global_position.distance_to(before) < 0.05,"disabled engine cannot propel on terrain executor")
	scene.source_actor.reset_vehicle()
	_check(scene.source_actor.capabilities().drive and tank.ground_state.points.is_empty(),"explicit vehicle reset clears damage and stale ground sample")
	var bad := VehicleDefinition.new()
	bad.id = "invalid_drive"
	bad.weapon_id = "test"
	bad.max_slope_deg = NAN
	bad.drive_collision_size.x = -1
	_check(not bad.validate().ok,"nonfinite slope and negative collision dimension rejected")
	# Actual production projectile, tilted target geometry and real module state commit.
	var b := scene.target_actor
	b.reset_vehicle()
	b.tank.global_transform = Transform3D(VehiclePose.compose(Vector3.FORWARD,Vector3(0,cos(deg_to_rad(20)),sin(deg_to_rad(20)))),Vector3(18,3,-20))
	scene.projectiles.set_physics_process(false)
	var spec := {"round_id":scene.get_round_id(),"shooter_id":"terrain_fixture_source","shooter_life_id":1,"shot_id":1,"shell_id":"terrain_fixture_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,120)]),"position_world":b.tank.global_transform*Vector3(0,1.3,5),"velocity_world":b.tank.global_basis*Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":100.0}
	var result := scene.projectiles.try_spawn(spec)
	_check(result.get("ok",false),"production projectile accepts tilted-target shot")
	if result.get("ok",false):
		var shell := scene.projectiles.get_projectile_state(result.projectile_id)
		scene.projectiles.advance_projectile(shell,1.0/60,[QuerySnapshotBuilder.build_from_vehicle(b.tank,b.damage_layout_override)],scene.get_world_3d().direct_space_state)
		_check(b.state.module_states.engine.integrity == 0 and not b.capabilities().drive and b.capabilities().fire,"real shell penetrates sloped vehicle rear and disables actual engine only")
		var hit_ok := false
		for damage in shell.damage_records:
			if damage.item_id == "engine": hit_ok = damage.box_world_transform.basis.is_equal_approx(b.tank.global_basis)
		_check(hit_ok,"actual damage record preserves tilted module pose")
	var generation := b.state.generation
	scene.select_route(0)
	_check(b.state.generation > generation and b.capabilities().drive and scene.projectiles.active_count() == 0,"normal new-route operation resets both lives and cancels old flight")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("DRIVE_CHECKS_PASS" if failed == 0 else "DRIVE_CHECKS_FAIL")
	scene.free()
	quit(0 if failed == 0 else 1)
