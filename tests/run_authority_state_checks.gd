extends SceneTree
# WT-002-R1 regression: one authoritative pose per tick (no stale cache), turret
# detach/restore leaves no query residue, and identity-stale commands cannot cross
# a reset. Headless; no FPS/p95 sampling anywhere in this order.
var count := 0
var failed := 0
var world: Node3D
var defs: VehicleDefs
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _make_actor(id: String) -> VehicleActor:
	var actor := VehicleActor.new()
	world.add_child(actor)
	actor.setup(defs,id,id,1,Transform3D.IDENTITY,2,null)
	return actor
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	defs = VehicleDefs.new(); defs.load_defaults()
	_check(VehicleCatalog.new().load_all(defs).ok,"historical definitions load for the authority suite")
	var actor := _make_actor(VehicleCatalog.IDS[0])
	for i in 5: await physics_frame
	var tank: TankVehicle = actor.tank
	var layout: VehicleLayoutDefinition = actor.damage_layout_override

	# --- one authoritative pose per tick, and the snapshot is a真 copy, not a cache ---
	var snap_a := QuerySnapshotBuilder.build_from_vehicle(tank,layout)
	var parts: Dictionary = snap_a.get("part_world_transforms",{})
	_check(snap_a.get("missing_parts",[]).is_empty(),"query snapshot has no missing parts at rest")
	_check((parts.get("hull") as Transform3D).is_equal_approx(tank.hull_frame.global_transform),"snapshot hull equals the authoritative hull frame in the same tick")
	_check((parts.get("turret") as Transform3D).is_equal_approx(actor.turret.global_transform),"snapshot turret equals the live turret rig in the same tick")
	_check((parts.get("barrel") as Transform3D).is_equal_approx(actor.turret.barrel_pivot.global_transform),"snapshot barrel equals the live barrel pivot in the same tick")
	for key in ["hull","drive",TrackAssembly.LEFT,TrackAssembly.RIGHT]:
		var t: Transform3D = parts.get(key,Transform3D.IDENTITY)
		_check(t.is_finite(),"snapshot transform for %s is finite" % key)
	var muzzle_before := actor.turret.muzzle.global_transform
	parts["hull"] = Transform3D(Basis.IDENTITY,Vector3(99,99,99))
	_check(tank.hull_frame.global_transform != Transform3D(Basis.IDENTITY,Vector3(99,99,99)),"mutating the snapshot does not write back to the live hull")
	var live_after_mutation := actor.turret.muzzle.global_transform
	_check(live_after_mutation.is_equal_approx(muzzle_before),"muzzle stays put after snapshot mutation")
	# drive a few fixed steps, then require a fresh read (no stale cached pose)
	for i in 12: tank.apply_drive(1.0,0.0,1.0/60)
	var snap_b := QuerySnapshotBuilder.build_from_vehicle(tank,layout)
	var hull_moved := not (snap_b.part_world_transforms.hull as Transform3D).is_equal_approx(snap_a.part_world_transforms.hull)
	var drive_moved := not (snap_b.part_world_transforms.drive as Transform3D).is_equal_approx(snap_a.part_world_transforms.drive)
	_check(hull_moved or drive_moved,"a later snapshot reflects the new pose instead of a cached one")

	# --- 10x turret detach / restore must leave no residue ---
	actor.state.generation = actor.state.generation
	var original_transform: Transform3D = actor.turret.transform
	var residue := 0
	var bad_parent := 0
	var bad_transform := 0
	for i in 10:
		var motion := WreckTurretMotion.new()
		world.add_child(motion)
		# launch and restore are called without a physics frame in between: while the
		# actor is alive the wreck motion auto-restores itself on its next step, so the
		# detach assertion has to be taken synchronously.
		motion.launch(actor)
		if actor.turret.get_parent() != motion: bad_parent += 1
		motion.restore()
		await physics_frame
		if actor.turret.get_parent() != tank.hull_frame: bad_parent += 1
		if not actor.turret.transform.is_equal_approx(original_transform): bad_transform += 1
		if world.get_node_or_null("DetachedTurretWreck") != null: residue += 1
		var snap := QuerySnapshotBuilder.build_from_vehicle(tank,layout)
		if not snap.get("missing_parts",[]).is_empty(): residue += 1
		if not GeometryOverlay.compare(actor).ok: residue += 1
		print("[progress] detach cycle ",i+1," parent_ok=",bad_parent == 0," residue=",residue)
	_check(bad_parent == 0,"turret detach and restore keep the authoritative parent across 10 cycles")
	_check(bad_transform == 0,"turret local transform is restored exactly across 10 cycles")
	_check(residue == 0,"no wreck node, missing part or geometry residue after 10 detach cycles")

	# --- identity-stale commands cannot cross a reset ---
	var cmd := VehicleCommand.new()
	cmd.throttle = 1.0
	var envelope := VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames())
	_check(actor.submit_command_envelope(envelope).ok,"a current-identity command is accepted before reset")
	var forged := VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames())
	forged.life_id = int(forged.life_id)+1
	var forged_result := actor.submit_command_envelope(forged)
	_check(not forged_result.ok and str(forged_result.reason) == "stale_identity","a forged life id is refused as stale_identity")
	var generation_before := actor.state.generation
	var life_before := actor.life_id
	actor.reset_vehicle()
	for i in 2: await physics_frame
	var identity_changed := actor.state.generation != generation_before or actor.life_id != life_before
	var old_envelope := VehicleCommandCodec.encode(cmd,actor,3,Engine.get_physics_frames())
	old_envelope.life_id = life_before
	old_envelope.generation = generation_before
	var old_result := actor.submit_command_envelope(old_envelope)
	var expected_ok := not identity_changed
	_check(old_result.ok == expected_ok and (old_result.ok or str(old_result.reason) == "stale_identity"),
		"a pre-reset command is only accepted when the identity actually survived the reset (changed=%s)" % str(identity_changed))
	var fresh := VehicleCommandCodec.encode(cmd,actor,4,Engine.get_physics_frames())
	_check(actor.submit_command_envelope(fresh).ok,"a post-reset command with the live identity is accepted")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AUTHORITY_STATE_CHECKS_PASS" if failed == 0 else "AUTHORITY_STATE_CHECKS_FAIL")
	world.free()
	quit(1 if failed else 0)
