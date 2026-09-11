extends SceneTree
var count := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene := AICombatRange.new()
	root.add_child(scene); current_scene = scene
	scene.source_actor.set_controller(null)
	scene.target_actor.set_controller(null)
	await frames(30)
	var actor := scene.source_actor
	var tank := actor.tank
	for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3.BACK]:
		actor.reset_vehicle()
		await frames(30)
		actor.turret.set_aim_point(tank.global_position+Vector3.UP*1.5+direction*100)
		actor.turret.snap_to_aim()
		var start := tank.global_position
		var shots := actor.gunner.shots_fired
		var command := VehicleCommand.new(); command.fire_requested = true
		actor.submit_command(command)
		await frames(2)
		check(actor.gunner.shots_fired==shots+1 and tank.recoil_velocity.dot(direction)<-0.3,"successful real shot pushes chassis opposite barrel "+str(direction))
		var kick := tank.recoil_velocity
		check(not actor.gunner.try_fire() and tank.recoil_velocity==kick,"cooldown rejection adds no recoil")
		paused = true
		var paused_position := tank.global_position
		for i in 4: await process_frame
		check(tank.global_position==paused_position and tank.recoil_velocity==kick,"pause freezes physical reaction")
		paused = false
		await frames(120)
		var offset := tank.global_position-start
		check(offset.dot(-direction)>0.05 and offset.dot(-direction)<0.2 and tank.recoil_velocity==Vector3.ZERO,"real chassis travels a bounded distance and settles "+str(offset))
		check(absf(tank.forward_speed)<0.001,"recoil does not become a persistent engine command")
	tank.kick_recoil(Vector3.RIGHT)
	actor.reset_vehicle()
	check(tank.recoil_velocity==Vector3.ZERO,"reset clears pending recoil")
	# A real wall behind the chassis blocks the physical response.
	await frames(30)
	var start := tank.global_position
	var half_width := tank.defs.drive_collision_size.x*0.5
	var wall := TerrainFixtures.box(scene,start+Vector3(-half_width-0.55,1,0),Vector3(1,4,8))
	await frames(3)
	tank.kick_recoil(Vector3.RIGHT)
	await frames(120)
	check(start.x-tank.global_position.x < 0.07,"recoil cannot move the chassis through a blocking wall")
	wall.queue_free()
	await frames(3)
	var original_hz := Engine.physics_ticks_per_second
	var distances: Array[float] = []
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		tank.reset()
		await frames(hz)
		var origin := tank.global_position
		tank.kick_recoil(Vector3.RIGHT)
		await frames(hz*2)
		distances.append(origin.x-tank.global_position.x)
	Engine.physics_ticks_per_second = original_hz
	check(absf(distances.max()-distances.min())<0.002,"30/60/120 Hz recoil travel agrees within two millimetres: "+str(distances))
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("CHASSIS_RECOIL_CHECKS_PASS" if failed==0 else "CHASSIS_RECOIL_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
