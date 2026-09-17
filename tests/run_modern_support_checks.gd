extends SceneTree
## Real delivered models, physical curb/ditch controls and actual command execution.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	var loaded: bool = catalog.load_all(defs).ok and catalog.load_engineering(defs).ok
	check(loaded,"production historical and modern catalog admission")
	if not loaded: quit(1); return
	for id in VehicleCatalog.ENGINEERING_IDS:
		var world := Node3D.new(); root.add_child(world); current_scene=world
		VehicleSimulationDriver.for_scene(world)
		TerrainFixtures.box(world,Vector3(0,-.5,0),Vector3(200,1,200))
		var curb := TerrainFixtures.box(world,Vector3(-2,.125,0),Vector3(4,.25,80))
		var actor := VehicleActor.new(); actor.presentation_enabled=false; world.add_child(actor)
		var ready: bool = actor.setup(defs,id,id,1,Transform3D(Basis.IDENTITY,Vector3(-.2,.4,0)),2,null).ok
		check(ready,id+" installs actual bound model")
		if not ready: world.free(); continue
		await frames(90)
		var tank := actor.tank
		check(tank.is_on_floor() and tank.ground_state.left_support==1 and tank.ground_state.right_support==1,id+" both treads support on a physical 25 cm curb")
		var yaw := tank.global_rotation.y
		for tick in 30:
			var cmd := VehicleCommand.new(); cmd.steer=1; actor.submit_command(cmd)
			await physics_frame
		check(absf(wrapf(tank.global_rotation.y-yaw,-PI,PI))>.1,id+" normal steering crosses curb without phantom unsupported side")
		# A visible floor beyond reach must still contribute no right-track grip.
		curb.position.y=.875; curb.get_child(0).shape.size.y=.25
		actor.reset_vehicle(); tank.global_position=Vector3(-.2,1.15,0)
		await frames(90)
		check(tank.is_on_floor() and tank.ground_state.left_support==1 and tank.ground_state.right_support==0,id+" one metre drop retains unsupported-side rejection")
		yaw=tank.global_rotation.y
		for tick in 30:
			var cmd := VehicleCommand.new(); cmd.steer=1; actor.submit_command(cmd)
			await physics_frame
		check(is_equal_approx(yaw,tank.global_rotation.y),id+" cannot borrow steering from unsupported tread")
		curb.free(); actor.reset_vehicle(); tank.global_position=Vector3(0,.15,0)
		await frames(60)
		var nav := DriveNavigator.new()
		nav.configure({"schema_version":1,"map_id":"corner_control","through_waypoints":true,
			"nodes":[{"id":"start","position":[0,0,0]},{"id":"corner","position":[0,0,-40]},{"id":"end","position":[40,0,-40]}],
			"edges":[{"a":"start","b":"corner","width":12},{"a":"corner","b":"end","width":12}]})
		var driver := AIPathDriver.new(); actor.add_child(driver); driver.configure(actor,nav); actor.set_controller(driver)
		driver.set_goal(Vector3(40,0,-40))
		var min_z := 0.0
		var ticks := 0
		while ticks<3600 and driver.has_goal:
			await physics_frame; ticks+=1; min_z=minf(min_z,tank.global_position.z)
		check(driver.phase=="arrived",id+" production through-route completes right-angle corner")
		check(min_z>=-44,id+" corner stays inside 12 m road with hull clearance")
		print("CORNER ",id," ticks=",ticks," minimum_z=",min_z," phase=",driver.phase)
		actor.set_controller(null); actor.reset_vehicle(); tank.global_position=Vector3(0,.15,20)
		TerrainFixtures.ramp(world,Vector3.ZERO,35,12,30)
		await frames(60)
		for tick in 600:
			var cmd := VehicleCommand.new(); cmd.throttle=1; actor.submit_command(cmd)
			await physics_frame
		var blocked_position := tank.global_position
		check(blocked_position.z>-4 and blocked_position.y<3,id+" steep ramp still exceeds unchanged climb limit")
		for tick in 360:
			var cmd := VehicleCommand.new(); cmd.throttle=-1; actor.submit_command(cmd)
			await physics_frame
		check(tank.global_position.z>blocked_position.z+5 and tank.forward_speed<0 and tank.is_on_floor(),id+" real reverse input backs away after steep-face collision")
		print("SLOPE_RECOVERY ",id," blocked=",blocked_position," recovered=",tank.global_position," speed=",tank.forward_speed)
		world.free(); await frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MODERN_SUPPORT_CHECKS_PASS" if failed==0 else "MODERN_SUPPORT_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
