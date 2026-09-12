extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"actual M4 and M24 production actors ready")
	var curb := TerrainFixtures.box(world,Vector3(-22,0.125,0),Vector3(4,0.25,20))
	for actor in world.actors:
		var tank := actor.tank
		var profile := actor.definition.drive_profile
		check(profile.suspension_enabled,"sample vehicle enables suspension "+actor.entity_id)
		actor.reset_vehicle(); tank.global_position=Vector3(-20,0.25,0)
		await ticks(180)
		print("[CURB] ",actor.entity_id," hull=",tank.hull_frame.transform," left=",tank.track_left_frame.position," right=",tank.track_right_frame.position," rates=",tank.suspension.velocity)
		check(tank.track_right_frame.position.y < -0.2 and absf(tank.track_left_frame.position.y)<0.03,"unsprung sides follow real 25cm curb independently "+actor.entity_id)
		check(tank.hull_frame.rotation.z < -0.02 and tank.hull_frame.position.y < -0.04,"terrain changes actual hull height and roll "+actor.entity_id)
		check(tank.suspension.velocity.all(func(v: float) -> bool: return absf(v)<0.002),"parked suspension converges "+actor.entity_id)
		check(GeometryOverlay.compare(actor).ok,"suspended hull armor and visual surfaces coincide "+actor.entity_id)
		var query := QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		check(query.part_world_transforms.hull==tank.hull_frame.global_transform and actor.turret.get_parent()==tank.hull_frame,"weapon and shot query use sprung authority "+actor.entity_id)
		var before := tank.suspension.snapshot()
		paused=true; for i in 4: await process_frame
		check(tank.suspension.snapshot()==before,"pause freezes spring state "+actor.entity_id)
		paused=false
		curb.position.y=0.275 # 40cm top, beyond the 30cm extension range.
		actor.reset_vehicle(); tank.global_position=Vector3(-20,0.4,0)
		await ticks(60)
		check(tank.is_on_floor() and tank.ground_state.left_support==1.0 and tank.ground_state.right_support==0.0 and tank.ground_state.track_contacts[TrackAssembly.RIGHT].all(func(c: Dictionary) -> bool: return c.hit),"visible ditch floor beyond travel grants no right traction "+actor.entity_id)
		curb.position.y=0.125
		actor.reset_vehicle(); tank.global_position=Vector3(world.actors.find(actor)*16,2,0)
		var compression := 0.0
		var valid := true
		var air_droop := false
		for i in 240:
			await physics_frame
			compression=minf(compression,tank.hull_frame.position.y)
			valid=valid and VehicleFramePose.valid(VehicleFramePose.capture(tank)) and tank.suspension.displacement.all(func(x: float) -> bool: return x>=-profile.suspension_compression_m-0.0001 and x<=profile.suspension_extension_m+0.0001)
			if not tank.is_on_floor() and tank.track_left_frame.position.y < -0.2: air_droop=true
		print("[DROP] ",actor.entity_id," compression=",compression," impacts=",tank.suspension.impacts," hull=",tank.hull_frame.position," rates=",tank.suspension.velocity)
		check(air_droop,"airborne running gear extends within travel "+actor.entity_id)
		check(compression < -0.03 and tank.suspension.impacts==1,"real landing compresses sprung hull once "+actor.entity_id)
		check(valid,"spring travel and rigid poses remain bounded throughout drop "+actor.entity_id)
		check(tank.is_on_floor() and tank.suspension.velocity.all(func(v: float) -> bool: return absf(v)<0.002) and absf(tank.hull_frame.position.y)<0.02,"landing returns to resting pose without recurring bounce "+actor.entity_id)
		actor.reset_vehicle()
		check(tank.suspension.impacts==0 and not tank.suspension.initialized and tank.suspension.displacement.all(func(x: float) -> bool: return x==0) and tank.hull_frame.transform==Transform3D.IDENTITY,"respawn clears spring memory and relative hull pose "+actor.entity_id)
	var invalid := DriveProfile.new(); invalid.suspension_response_rate=NAN
	check(not invalid.validate().is_empty(),"invalid suspension tuning fails admission")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("SUSPENSION_CHECKS_PASS" if failures==0 else "SUSPENSION_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
