extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var definition := VehicleDefinition.new()
	var tracks := TrackDrive.new()
	check(tracks.step(6,0,1.0/60,definition)==6 and tracks.left_speed==tracks.right_speed,"straight input has no turn loss or differential")
	tracks.step(1,1,1.0/60,definition)
	var slow_yaw := tracks.yaw_rate
	var fast := tracks.step(6,1,1.0/60,definition)
	check(fast<6 and tracks.yaw_rate<slow_yaw,"high speed steering reduces speed and yaw rate")
	check(is_equal_approx((tracks.left_speed+tracks.right_speed)*0.5,fast) and is_equal_approx((tracks.right_speed-tracks.left_speed)/definition.drive_profile.track_spacing_m,tracks.yaw_rate),"track differential reconstructs longitudinal speed and yaw")
	var reverse := tracks.step(-6,1,1.0/60,definition)
	check(reverse<0 and absf(reverse)<6,"reverse turn loses magnitude without reversing travel direction")
	check(tracks.step(0,1,1.0/60,definition)==0 and tracks.left_speed==-tracks.right_speed and tracks.yaw_rate!=0,"neutral steering counter-rotates tracks without translation")
	definition.drive_profile.neutral_turn=false
	tracks.step(0,1,1.0/60,definition)
	check(tracks.yaw_rate==0 and tracks.left_speed==0 and tracks.right_speed==0,"profile can prohibit neutral steering")
	definition.drive_profile.neutral_turn=true
	var split := 6.0
	for i in 60: split=tracks.step(split,1,1.0/60,definition)
	var fine := 6.0
	for i in 120: fine=tracks.step(fine,1,1.0/120,definition)
	check(absf(split-fine)<0.01,"turn damping remains close across fixed-step subdivisions")
	var invalid := DriveProfile.new(); invalid.track_spacing_m=0
	check(not invalid.validate().is_empty(),"zero track spacing rejected")
	invalid=DriveProfile.new(); invalid.turn_speed_falloff=NAN
	check(not invalid.validate().is_empty(),"nonfinite steering curve rejected")
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"actual M4 and M24 authority actors ready")
	for i in 5: await physics_frame
	var straight: Array[float]=[]
	for mode in [0.0,1.0]:
		for actor in world.actors:
			actor.reset_vehicle(); actor.tank.forward_speed=6 # Equal-speed fixture.
		for tick in 120:
			for actor in world.actors:
				var cmd := VehicleCommand.new(); cmd.throttle=1; cmd.steer=mode; actor.submit_command(cmd)
			await physics_frame
		for index in world.actors.size():
			var tank: TankVehicle=world.actors[index].tank
			if mode==0: straight.append(tank.forward_speed)
			else:
				print("[MEASURE] actor=%d straight=%.4f turn=%.4f yaw=%.4f tracks=%.4f/%.4f"%[index,straight[index],tank.forward_speed,tank.global_rotation.y,tank.tracks.left_speed,tank.tracks.right_speed])
				check(tank.forward_speed<straight[index]-0.3 and absf(tank.global_rotation.y)>0.2,"real actor steering turns and costs speed "+str(index))
	for actor in world.actors: actor.reset_vehicle()
	var origin: Vector3=world.actors[0].tank.global_position
	for tick in 60:
		var cmd := VehicleCommand.new(); cmd.steer=1; world.actors[0].submit_command(cmd)
		await physics_frame
	var tank: TankVehicle=world.actors[0].tank
	var displacement := tank.global_position-origin; displacement.y=0
	check(displacement.length()<0.02 and absf(tank.global_rotation.y)>0.3,"actual neutral turn rotates without horizontal translation")
	tank.capabilities_provider=func() -> Dictionary: return {"drive":false,"steer":false}
	var yaw := tank.global_rotation.y
	for tick in 10:
		var cmd := VehicleCommand.new(); cmd.steer=1; world.actors[0].submit_command(cmd)
		await physics_frame
	check(is_equal_approx(yaw,tank.global_rotation.y) and tank.tracks.yaw_rate==0,"capability denial prevents actual steering")
	tank.reset()
	check(tank.tracks.yaw_rate==0 and tank.tracks.left_speed==0 and tank.tracks.right_speed==0,"vehicle reset clears track state")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("TRACK_DRIVE_CHECKS_PASS" if failures==0 else "TRACK_DRIVE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
