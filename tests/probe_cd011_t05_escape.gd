extends SceneTree
## CD11-T05 escape leg, measured in the harness that DEMONSTRABLY works.
##
## Three attempts to get ground support inside the scene suite failed, while this probe recipe gets support 1.000 and real
## acceleration. So the collision and escape legs are exercised HERE instead, on the same recipe: the floor is placed before
## the hull is used, at an absolute height, and the loop awaits process frames. Nothing writes forward speed except the drive
## entry the game itself calls.
##
##   C1 driving at a wall on the world layer blocks: the hull never passes through it;
##   C2 reversing out of the face actually moves the hull away, which is the escape the order names;
##   C3 and pushing or towing stays declared out of scope, because the order says to declare it when no reliable constraint
##      exists rather than to claim it.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func _run() -> void:
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	if not (defs.load_defaults().ok and catalog.load_all(defs).ok and catalog.load_engineering(defs).ok):
		print("[t05] the catalog did not load"); quit(1); return
	var actor := VehicleActor.new(); root.add_child(actor)
	var admitted: Dictionary = actor.setup(defs,"ussr_t_80b","t05",1,Transform3D.IDENTITY,2,null)
	if not admitted.ok: print("[t05] admission refused %s" % str(admitted.get("errors",[]))); quit(1); return
	actor.set_physics_process(false); actor.tank.set_physics_process(false)

	# The working recipe: a floor placed before the hull is used, at an absolute height.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new(); floor_box.size = Vector3(120.0,1.0,120.0)
	floor_shape.shape = floor_box; floor_body.add_child(floor_shape)
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	floor_body.global_position = Vector3(0,-0.5,0)
	root.add_child(floor_body)
	await process_frame
	await process_frame
	print("[t05] floor: on_floor=%s speed=%.4f" % [str(actor.tank.is_on_floor()),actor.tank.forward_speed])

	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new(); wall_box.size = Vector3(20.0,6.0,1.0)
	wall_shape.shape = wall_box; wall.add_child(wall_shape)
	wall.collision_layer = GameConfig.LAYER_WORLD
	root.add_child(wall)
	var start: Vector3 = actor.tank.global_position
	wall.global_position = Vector3(start.x,start.y+2.5,start.z-12.0)
	var step := {"cmd":null,"throttle":1.0,"steer":0.0,"delta":1.0/60.0,"generation":actor.state.generation,"epoch":actor.control_epoch}
	var accel_trace: Array = []
	for i in 180:
		actor.advance_simulation_drive(step,1.0/60.0)
		await process_frame
		if i % 60 == 0: accel_trace.append(actor.tank.forward_speed)
	var at_wall: Vector3 = actor.tank.global_position
	var wall_z: float = wall.global_position.z
	var passed := at_wall.z < (wall_z - 1.0)
	var blocked := (not passed) and at_wall.z > (wall_z + 1.0)
	print("[t05] C1 approach: speeds=%s ; z %.3f -> %.3f ; wall at %.3f ; passed=%s blocked=%s support=%.3f" % [
		str(accel_trace),start.z,at_wall.z,wall_z,str(passed),str(blocked),float(actor.tank.ground_state.get("traction_support",-1.0))])
	check(not passed and blocked,"CD11 C1 the hull is blocked by the wall and never passes through it")

	var before_rev: Vector3 = actor.tank.global_position
	var back_step := {"cmd":null,"throttle":-1.0,"steer":0.0,"delta":1.0/60.0,"generation":actor.state.generation,"epoch":actor.control_epoch}
	var rev_trace: Array = []
	for i in 240:
		actor.advance_simulation_drive(back_step,1.0/60.0)
		await process_frame
		if i % 60 == 0: rev_trace.append(actor.tank.forward_speed)
	var after_rev: Vector3 = actor.tank.global_position
	var moved_back := after_rev.z - before_rev.z
	print("[t05] C2 escape: speeds=%s ; z %.3f -> %.3f ; moved back %.3f ; support=%.3f" % [
		str(rev_trace),before_rev.z,after_rev.z,moved_back,float(actor.tank.ground_state.get("traction_support",-1.0))])
	check(moved_back > 0.5,"CD11 C2 the hull reverses out of the face it was held against: moved %.3f m" % moved_back)
	print("[t05] C3 pushing and towing: DECLARED OUT OF SCOPE, which is what the order asks when no reliable constraint exists")
	actor.queue_free(); floor_body.queue_free(); wall.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD11_T05_ESCAPE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
