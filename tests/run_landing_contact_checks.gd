extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"historical landing fixture ready")
	for mode in [1.0,-1.0,0.0]:
		var actor := world.actors[0]
		actor.reset_vehicle(); actor.tank.global_position=Vector3(0,2,0)
		actor.tank.forward_speed=3
		actor.tank.global_basis=Basis(Vector3.RIGHT,deg_to_rad(4))
		var near_frames := 0
		var early_traction := false
		var early_pose := false
		var landed := false
		for tick in 90:
			var tank: TankVehicle=actor.tank
			var near_air := not tank.is_on_floor() and tank.global_position.y<0.55 and tank.global_position.y>0.15
			var speed := tank.forward_speed
			var pose := tank.global_basis
			var cmd := VehicleCommand.new(); cmd.throttle=mode; cmd.steer=1
			actor.submit_command(cmd); await physics_frame
			if near_air:
				near_frames+=1
				early_traction=early_traction or not is_equal_approx(speed,tank.forward_speed)
				early_pose=early_pose or not pose.is_equal_approx(tank.global_basis)
			if tank.is_on_floor(): landed=true; break
		check(near_frames>0,"actual fall traverses former 0.55m early-contact band "+str(mode))
		check(not early_traction and not early_pose,"near-ground flight retains speed and attitude until physical contact "+str(mode))
		check(landed,"collision solver confirms eventual landing "+str(mode))
		var speed := actor.tank.forward_speed
		var cmd := VehicleCommand.new(); cmd.throttle=mode; cmd.steer=0.5
		actor.submit_command(cmd); await physics_frame
		check(actor.tank.ground_state.grounded and actor.tank.tracks.yaw_rate!=0 and not is_equal_approx(speed,actor.tank.forward_speed),"confirmed contact restores driving and attitude response "+str(mode))
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("LANDING_CONTACT_CHECKS_PASS" if failed==0 else "LANDING_CONTACT_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
