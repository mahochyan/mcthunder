extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"actual vehicle actors ready")
	for i in 5: await physics_frame
	for mode in [1.0,-1.0,0.0]:
		var actor := world.actors[0]
		actor.reset_vehicle()
		actor.tank.global_position=Vector3(0,30,0)
		actor.tank.forward_speed=6
		actor.tank.velocity=Vector3(0,0,-6)
		actor.tank.global_basis=Basis(Vector3.RIGHT,deg_to_rad(12))
		var start := actor.tank.global_transform
		for tick in 30:
			var cmd := VehicleCommand.new(); cmd.throttle=mode; cmd.steer=1; actor.submit_command(cmd)
			await physics_frame
		var tank: TankVehicle=actor.tank
		check(not tank.ground_state.grounded and is_equal_approx(tank.forward_speed,6),"airborne throttle/brake/coast preserves horizontal engine speed "+str(mode))
		check(tank.global_basis.is_equal_approx(start.basis) and tank.tracks.yaw_rate==0,"airborne steering cannot rotate or auto-level hull "+str(mode))
		check(tank.global_position.y<start.origin.y-0.5 and tank.velocity.y<0,"gravity still advances real airborne vehicle "+str(mode))
	var actor := world.actors[0]
	actor.reset_vehicle(); actor.tank.global_position=Vector3(0,1.5,0)
	for tick in 120: await physics_frame
	check(actor.tank.ground_state.grounded,"vehicle regains actual floor contact after falling")
	for tick in 60:
		var cmd := VehicleCommand.new(); cmd.throttle=1; cmd.steer=0.5; actor.submit_command(cmd)
		await physics_frame
	check(actor.tank.forward_speed>1 and absf(actor.tank.global_rotation.y)>0.1,"landing restores propulsion and steering through same command path")
	TerrainFixtures.box(world,Vector3(0,3,0),Vector3(12,1,20))
	actor.reset_vehicle(); actor.tank.global_position=Vector3(0,3.5,0)
	for tick in 10: await physics_frame
	var left_ledge := false
	var landed := false
	var supported: bool = actor.tank.ground_state.grounded
	for tick in 420:
		var cmd := VehicleCommand.new(); cmd.throttle=1; actor.submit_command(cmd)
		await physics_frame
		if not actor.tank.ground_state.grounded and actor.tank.global_position.z < -10: left_ledge=true
		if left_ledge and actor.tank.ground_state.grounded and actor.tank.global_position.y<0.1: landed=true
	check(supported and left_ledge and landed and actor.tank.global_position.z < -15,"normal throttle drives off physical ledge, loses support, falls and regains lower ground")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AIRBORNE_DRIVE_CHECKS_PASS" if failed==0 else "AIRBORNE_DRIVE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
