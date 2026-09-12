extends SceneTree
var checks := 0
var failures := 0
var shot := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	TerrainFixtures.box(world,Vector3(-22,0.125,0),Vector3(4,0.25,20))
	var defs := VehicleDefs.new(); defs.load_defaults()
	check(VehicleCatalog.new().load_all(defs).ok,"historical layouts pass production admission")
	for id in VehicleCatalog.IDS:
		var actor := VehicleActor.new(); world.add_child(actor)
		check(actor.setup(defs,id,id,1,Transform3D.IDENTITY,2,null).ok,"normal assembly " + id)
		for i in 5: await physics_frame
		var tank := actor.tank
		var hull := tank.hull_frame
		var left := tank.track_left_frame
		var right := tank.track_right_frame
		check(left.get_parent()==tank and right.get_parent()==tank,"independent running gear parents " + id)
		check(left.has_node("Cosmetic_track_left") and right.has_node("Cosmetic_track_right") and left.has_node("Cosmetic_wheels_left") and right.has_node("Cosmetic_wheels_right"),"tracks and road wheels split by side " + id)
		var saved := QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		var left_pose := left.global_transform
		var right_pose := right.global_transform
		hull.position.y = -0.2
		var moved := QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		check(left.global_transform==left_pose and right.global_transform==right_pose and moved.part_world_transforms.running_left==left_pose,"hull compression cannot drag track visuals or shot volumes " + id)
		check(saved.part_world_transforms.hull!=moved.part_world_transforms.hull and saved.part_world_transforms.running_left==moved.part_world_transforms.running_left,"query snapshot freezes hull and running gear separately " + id)
		check(GeometryOverlay.compare(actor).ok,"displaced hull armor still matches appearance " + id)
		# Controlled articulation is a boundary fixture, not enabled suspension.
		left.position.y=0.25
		moved=QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		check(moved.part_world_transforms.running_left!=left_pose and moved.part_world_transforms.running_right==right_pose,"one side articulation leaves opposite hit volume unchanged " + id)
		actor.reset_vehicle()
		for i in 5: await physics_frame
		check(hull.transform==Transform3D.IDENTITY and left.transform==Transform3D.IDENTITY and right.transform==Transform3D.IDENTITY,"reset clears every relative frame " + id)
		tank.global_position=Vector3(-20,0.25,0)
		for i in 12: await physics_frame
		var curb: Dictionary=tank.ground_state
		check(curb.left_support==1 and curb.right_support==1 and curb.track_contacts.running_left.all(func(c: Dictionary) -> bool: return c.hit and is_equal_approx(c.position.y,0.25)) and curb.track_contacts.running_right.all(func(c: Dictionary) -> bool: return c.hit and absf(c.position.y)<0.001),"single-side curb records distinct terrain contacts " + id)
		check(hull.transform==Transform3D.IDENTITY and left.transform==Transform3D.IDENTITY and right.transform==Transform3D.IDENTITY,"curb does not silently enable spring animation " + id)
		for side in [-1,1]:
			actor.reset_vehicle()
			for i in 5: await physics_frame
			var module_id := "track_left" if side<0 else "track_right"
			var part := TrackAssembly.LEFT if side<0 else TrackAssembly.RIGHT
			var module: ModuleVolumeDefinition
			for candidate in actor.damage_layout_override.modules:
				if candidate.id==module_id: module=candidate
			check(module!=null and module.part_id==part and module.external,"external damage uses matching side frame " + id + module_id)
			var before: Dictionary=tank.ground_state.duplicate(true)
			check(before.left_support==1 and before.right_support==1 and before.track_contacts[part].size()==2,"both authored support points contact ground " + id + module_id)
			var manager := ProjectileManager.new(); world.add_child(manager); manager.set_physics_process(false)
			manager.damage_handler=func(event: Dictionary,budget: float) -> Dictionary: return actor.apply_projectile_damage(event,budget)
			var point := module.local_box_transform.origin
			point.x += side*module.size_m.x*0.3
			point.z += module.size_m.z*0.5+1.0
			shot+=1
			var spawned := manager.try_spawn({"round_id":1,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"fixture_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,200)]),"position_world":tank.to_global(point),"velocity_world":-tank.global_basis.z*600,"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":100.0})
			check(spawned.ok,"real projectile spawned " + id + module_id)
			var projectile := manager.get_projectile_state(spawned.projectile_id)
			manager.advance_projectile(projectile,1.0/60.0,[QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
			check(actor.state.module_states[module_id].integrity==0,"actual projectile query breaks selected track " + id + module_id)
			var opposite := "track_right" if side<0 else "track_left"
			check(actor.state.module_states[opposite].integrity>0 and not actor.capabilities().drive and actor.capabilities().track_pivot,"shot preserves other track and enables only damaged pivot " + id + module_id)
			for i in 5: await physics_frame
			check(tank.ground_state.left_support==before.left_support and tank.ground_state.right_support==before.right_support,"broken track retains physical ground support " + id + module_id)
			manager.free()
		actor.free(); await process_frame
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failures])
	print("TRACK_ASSEMBLY_CHECKS_PASS" if failures==0 else "TRACK_ASSEMBLY_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
