extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	var defs := VehicleDefs.new(); defs.load_defaults()
	check(VehicleCatalog.new().load_all(defs).ok,"historical definitions loaded")
	for id in VehicleCatalog.IDS:
		var actor := VehicleActor.new(); world.add_child(actor)
		check(actor.setup(defs,id,id,1,Transform3D.IDENTITY,2,null).ok,"actual vehicle assembled "+id)
		for i in 5: await physics_frame
		var tank: TankVehicle=actor.tank
		var collision: CollisionShape3D
		for child in tank.get_children():
			if child is CollisionShape3D: collision=child
		var support_transform := collision.global_transform
		var hull_transform := tank.hull_frame.global_transform
		var muzzle := actor.turret.muzzle.global_transform
		check(actor.turret.get_parent()==tank.hull_frame and actor.cam_rig.get_parent()==tank.hull_frame,"weapon and camera belong to hull frame "+id)
		# Controlled displacement validates the boundary; spring motion is not enabled yet.
		tank.hull_frame.position.y=-0.12
		var shift := tank.hull_frame.global_position-hull_transform.origin
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		check(collision.global_transform==support_transform and shift.length()>0.1,"hull can move independently of drive collision "+id)
		check(actor.turret.muzzle.global_position.is_equal_approx(muzzle.origin+shift) and (snapshot.part_world_transforms.hull as Transform3D).is_equal_approx(tank.hull_frame.global_transform),"muzzle and query follow displaced hull "+id)
		check(GeometryOverlay.compare(actor).ok,"all armor triangles remain aligned after hull displacement "+id)
		actor.reset_vehicle()
		check(tank.hull_frame.transform==Transform3D.IDENTITY,"reset clears relative hull displacement "+id)
		actor.free(); await process_frame
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("HULL_FRAME_CHECKS_PASS" if failed==0 else "HULL_FRAME_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
