extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func drive(actor: VehicleActor, throttle: float, ticks: int) -> void:
	for tick in ticks:
		var cmd := VehicleCommand.new(); cmd.throttle=throttle; actor.submit_command(cmd)
		await physics_frame
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"real historical actors ready")
	for actor in world.actors:
		actor.reset_vehicle()
		await drive(actor,0,10)
		var muzzle_rest := actor.tank.global_transform.affine_inverse()*actor.turret.muzzle.global_transform
		await drive(actor,1,120)
		var tank: TankVehicle=actor.tank
		check(tank.chassis.pitch>0.0001 and (-tank.global_basis.z).y>0,"acceleration raises actual hull nose "+actor.entity_id)
		var speed := tank.forward_speed
		await drive(actor,-1,12)
		print("[RESPONSE] ",actor.entity_id," before=",speed," after=",tank.forward_speed," pitch_deg=",rad_to_deg(tank.chassis.pitch))
		check(tank.forward_speed<speed and tank.chassis.pitch<0,"forward braking lowers actual hull nose "+actor.entity_id)
		check(absf(tank.chassis.pitch)<=deg_to_rad(actor.definition.drive_profile.pitch_limit_degrees),"braking response remains bounded "+actor.entity_id)
		var query := QuerySnapshotBuilder.build_from_vehicle(tank,actor.damage_layout_override)
		check((tank.global_transform*muzzle_rest).is_equal_approx(actor.turret.muzzle.global_transform) and (query.part_world_transforms.hull as Transform3D).is_equal_approx(tank.global_transform),"muzzle and damage query follow authoritative braking tilt "+actor.entity_id)
		var snapshot: Dictionary=world.snapshot(1).vehicles[world.actors.find(actor)]
		check(is_equal_approx(snapshot.hull_pitch,tank.global_rotation.x),"network snapshot contains actual hull pitch "+actor.entity_id)
		await drive(actor,0,360)
		check(absf(tank.forward_speed)<0.001 and absf(tank.chassis.pitch)<0.0001 and absf(tank.global_rotation.x)<0.0001,"stopped hull settles back to ground attitude "+actor.entity_id)
		await drive(actor,-1,120)
		check(tank.forward_speed<0 and tank.chassis.pitch<0,"reverse acceleration lowers nose "+actor.entity_id)
		await drive(actor,1,12)
		check(tank.chassis.pitch>0,"braking from reverse raises nose "+actor.entity_id)
		tank.global_position.y=30
		await drive(actor,1,2) # Let the real solver replace cached floor contact after fixture relocation.
		var takeoff := tank.global_basis
		var takeoff_pitch := tank.chassis.pitch
		await drive(actor,1,20)
		check(not tank.ground_state.grounded and tank.global_basis.is_equal_approx(takeoff) and tank.chassis.pitch==takeoff_pitch,"flight preserves takeoff pitch without ground recovery torque "+actor.entity_id)
		tank.chassis.pitch=0.01; tank.chassis.pitch_rate=0.2
		actor.reset_vehicle()
		check(tank.chassis.pitch==0 and tank.chassis.pitch_rate==0,"reset clears suspension response "+actor.entity_id)
	var profile := DriveProfile.new()
	var a := ChassisResponse.new(); var b := ChassisResponse.new()
	for i in 60: a.step(-4,1.0/60,profile)
	for i in 120: b.step(-4,1.0/120,profile)
	check(absf(a.pitch-b.pitch)<0.000001 and absf(a.pitch_rate-b.pitch_rate)<0.000001,"response integration agrees at 60 and 120 Hz for same acceleration")
	profile.pitch_response_rate=NAN
	check(not profile.validate().is_empty(),"invalid suspension profile rejected")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("CHASSIS_RESPONSE_CHECKS_PASS" if failed==0 else "CHASSIS_RESPONSE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
