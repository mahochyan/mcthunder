extends SceneTree
var checks := 0
var failures := 0
var event_sequence := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func damage(actor: VehicleActor, id: String) -> void:
	event_sequence+=1
	var result := actor.apply_projectile_damage({"kind":"module","entity_id":actor.entity_id,"life_id":actor.life_id,"module_id":id,"event_id":"track_test_%d"%event_sequence,"round_id":1,"shooter_id":"fixture","shooter_life_id":1,"shot_id":event_sequence,"projectile_id":event_sequence},120)
	check(result.get("ok",false) and actor.state.module_states[id].integrity==0,"production damage disables "+id)
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"real M4 and M24 actors ready")
	for i in 5: await physics_frame
	var origins: Array[Vector3]=[]
	for index in 2:
		var actor := world.actors[index]
		damage(actor,"track_left" if index==0 else "track_right")
		var caps := actor.capabilities()
		check(not caps.drive and caps.steer and caps.track_pivot and caps.left_track!=caps.right_track,"single track enables only restricted pivot "+str(index))
		origins.append(actor.tank.global_position)
	for tick in 60:
		for actor in world.actors:
			var cmd := VehicleCommand.new(); cmd.throttle=1; actor.submit_command(cmd)
		await physics_frame
	for index in 2:
		check(world.actors[index].tank.global_position.distance_to(origins[index])<0.03,"forward throttle cannot bypass broken track "+str(index))
	for tick in 120:
		for actor in world.actors:
			var cmd := VehicleCommand.new(); cmd.steer=1; actor.submit_command(cmd)
		await physics_frame
	for index in 2:
		var tank: TankVehicle=world.actors[index].tank
		var broken_speed := tank.tracks.left_speed if index==0 else tank.tracks.right_speed
		var travel := tank.global_position.distance_to(origins[index])
		print("[MEASURE] side=%d travel=%.4f yaw=%.4f speed=%.4f tracks=%.4f/%.4f"%[index,travel,tank.global_rotation.y,tank.forward_speed,tank.tracks.left_speed,tank.tracks.right_speed])
		check(absf(broken_speed)<0.00001 and travel>0.1 and travel<1 and absf(tank.global_rotation.y)>0.1,"real restricted arc leaves broken track stationary "+str(index))
		check(tank.forward_speed>0 if index==0 else tank.forward_speed<0,"opposite damaged side changes direction of center travel "+str(index))
	for i in 3: await physics_frame
	for tick in 725:
		for actor in world.actors:
			var cmd := VehicleCommand.new(); cmd.repair_requested=true; actor.submit_command(cmd)
		await physics_frame
	for index in 2:
		var actor := world.actors[index]
		var id := "track_left" if index==0 else "track_right"
		check(actor.state.module_states[id].integrity==50 and actor.capabilities().drive and not actor.capabilities().track_pivot,"actual timed repair restores normal drive "+str(index))
	var actor := world.actors[0]
	damage(actor,"track_left"); damage(actor,"track_right")
	check(not actor.capabilities().drive and not actor.capabilities().steer and not actor.capabilities().track_pivot,"two broken tracks disable all powered turning")
	var pose := actor.tank.global_transform
	for tick in 60:
		var cmd := VehicleCommand.new(); cmd.throttle=1; cmd.steer=1; actor.submit_command(cmd)
		await physics_frame
	check(actor.tank.global_position.distance_to(pose.origin)<0.02 and actor.tank.global_basis.is_equal_approx(pose.basis),"double-track damage blocks real commands")
	actor.reset_vehicle(); damage(actor,"track_left"); damage(actor,"engine")
	check(not actor.capabilities().track_pivot and not actor.capabilities().steer,"engine failure cannot exploit healthy track")
	actor.reset_vehicle()
	check(actor.capabilities().left_track and actor.capabilities().right_track and actor.capabilities().drive,"reset restores both independent track abilities")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("TRACK_DAMAGE_CHECKS_PASS" if failures==0 else "TRACK_DAMAGE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
