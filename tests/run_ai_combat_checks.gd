extends SceneTree
var count := 0
var failed := 0
var scene: AICombatRange
var finished: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func place(player: Vector3, enemy: Vector3) -> void:
	scene.projectiles.cancel_all("test_fixture")
	scene.source_actor.reset_vehicle()
	scene.target_actor.reset_vehicle()
	scene.source_actor.set_controller(null)
	scene.source_actor.tank.global_transform = Transform3D(Basis.IDENTITY,player)
	scene.target_actor.tank.global_transform = Transform3D(Basis(Vector3.UP,PI),enemy)
	scene.ai.configure(scene.target_actor,scene.nav,Callable(scene,"combat_actors"),"hard",1401)
	scene.ai.has_patrol = false
	scene.target_actor.turret.set_aim_point(player+Vector3.UP*1.25)
	scene.target_actor.turret.snap_to_aim()
	scene.target_actor.state.recovery_enabled = true
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void: finished.append(record))
	await frames(5)
	_check(scene.combat_ready,"actual two-vehicle combat laboratory loads")
	var bot := scene.target_actor
	var player := scene.source_actor
	bot.set_physics_process(false)
	player.set_controller(null)
	place(Vector3(0,0.03,6),Vector3(0,0.03,-34))
	await frames()
	var sensor := scene.ai.sensor
	var hidden := sensor.scan(bot,1)
	_check(hidden.is_empty(),"T014-01 never-seen enemy behind opaque wall has no observation")
	_check(not scene.ai.update_command(0.5).fire_requested,"wall-hidden enemy cannot request fire")
	player.tank.global_position = Vector3(12,0.03,6)
	bot.tank.global_position.x = 12
	await frames()
	var seen := sensor.scan(bot,2)
	_check(seen.size() == 1 and seen[0].visible,"visible hull creates exterior observation")
	if seen.is_empty(): scene.free(); quit(1); return
	_check(seen[0].keys().size() == 7 and not seen[0].has("module_states") and not seen[0].has("actor"),"sensor observation contains numeric exterior data only")
	var frozen: Vector3 = seen[0].position
	seen[0].position = Vector3(999,999,999)
	_check(sensor.memory.A.position == frozen,"consumer cannot mutate sensor memory")
	player.tank.global_position = Vector3(0,0.03,6)
	bot.tank.global_position.x = 0
	await frames()
	var remembered := sensor.scan(bot,3)
	_check(remembered.size() == 1 and not remembered[0].visible and remembered[0].position == frozen,"T014-02 hiding freezes last-visible position")
	player.tank.global_position.z = 10
	await frames()
	remembered = sensor.scan(bot,4)
	_check(remembered[0].position == frozen and remembered[0].last_seen == 2,"moving behind cover does not update position or timestamp")
	_check(sensor.scan(bot,9).is_empty(),"last-seen memory expires after six seconds")
	place(Vector3(12,0.03,6),Vector3(12,0.03,-34))
	await frames()
	var cmd := scene.ai.update_command(0.01)
	_check(scene.ai.phase == "observe" and cmd.has_aim_point and not cmd.fire_requested,"first sight waits configured reaction time")
	_check(scene.ai.sensor.scans < 12,"perception scans are scheduled, not repeated by aim solver")
	bot.turret.set_aim_point(cmd.aim_world_point)
	bot.turret.rotation.y = PI/2
	cmd = scene.ai.update_command(0.6)
	_check(not cmd.fire_requested,"T014-03 off-axis turret cannot request a shot")
	bot.set_physics_process(true)
	var ammo_before := bot.gunner.rounds_remaining
	var before := bot.gunner.shots_fired
	var first_shot_at := -1
	for i in 600:
		await physics_frame
		if bot.gunner.shots_fired > before: first_shot_at = i; break
	_check(first_shot_at >= 0,"finite-rate turret eventually aims and launches actual projectile")
	_check(bot.gunner.rounds_remaining == ammo_before-1,"AI consumes same real ammunition inventory")
	var shot_count := bot.gunner.shots_fired
	await frames(30)
	_check(bot.gunner.shots_fired == shot_count,"held AI intent cannot bypass two-second reload")
	bot.set_physics_process(false)
	bot.gunner.cooldown_left = 0
	bot.state.module_states.breech.integrity = 0
	cmd = scene.ai.update_command(0.3)
	_check(not cmd.fire_requested and cmd.repair_requested and scene.ai.phase == "repair","damaged breech requests legal stopped repair instead of firing")
	bot.state.module_states.breech.integrity = bot.state.module_states.breech.max_integrity
	var gunner_person: String = bot.state.crew_assignments.gunner
	bot.state.crew_states[gunner_person].alive = false
	cmd = scene.ai.update_command(0.3)
	_check(not cmd.fire_requested and cmd.replace_crew_requested,"missing gunner requests legal replacement rather than firing")
	bot.state.crew_states[gunner_person].alive = true
	bot.gunner.rounds_remaining = 0
	_check(not scene.ai.update_command(0.3).fire_requested,"empty AI inventory cannot request fire")
	bot.gunner.rounds_remaining = 10
	bot.gunner.cooldown_left = 1
	_check(not scene.ai.update_command(0.3).fire_requested,"reload gate blocks AI fire request")
	bot.gunner.resume_grace = 1
	bot.gunner.cooldown_left = 0
	_check(not scene.ai.update_command(0.3).fire_requested,"resume grace applies to AI without delayed shot burst")
	bot.gunner.resume_grace = 0
	bot.gunner.cooldown_left = 0
	var old_observation := scene.ai.observation.duplicate(true)
	var barrier := TerrainFixtures.box(scene,bot.turret.muzzle.global_position+bot.turret.barrel_direction()*2,Vector3(8,4,1))
	await frames()
	_check(not sensor.fire_lane_clear(bot,old_observation),"fresh muzzle gate rejects newly inserted wall before next perception scan")
	barrier.free()
	barrier = TerrainFixtures.box(scene,bot.turret.barrel_pivot.global_position.lerp(bot.turret.muzzle.global_position,0.5),Vector3(2,2,0.3))
	await frames()
	_check(not sensor.fire_lane_clear(bot,old_observation),"barrel passing through wall blocks AI even when muzzle is beyond it")
	barrier.free()
	player.state.team_id = bot.state.team_id
	await frames()
	_check(not sensor.fire_lane_clear(bot,old_observation),"fresh team check rejects stale target that is now friendly")
	sensor.clear()
	_check(sensor.scan(bot,10).is_empty(),"friendly vehicle never becomes an enemy observation")
	player.state.team_id = 1
	var speed := bot.definition.forward_max_speed
	var penetration := bot.gunner.shell.penetration_curve.duplicate()
	var reload_time := bot.weapon.reload_time
	for level in ["easy","normal","hard"]:
		scene.ai.configure(bot,scene.nav,Callable(scene,"combat_actors"),level,1401)
		_check(bot.definition.forward_max_speed == speed and bot.gunner.shell.penetration_curve == penetration and bot.weapon.reload_time == reload_time,"T014-04 %s changes skill only"%level)
	scene.ai._new_error()
	var error := scene.ai._aim_error
	scene.ai.configure(bot,scene.nav,Callable(scene,"combat_actors"),"hard",1401)
	scene.ai._new_error()
	_check(scene.ai._aim_error == error,"seed 1401 reproduces angular error")
	scene.ai.sensor.scan(bot,11)
	bot.reset_vehicle()
	_check(scene.ai.observation.is_empty() and scene.ai.sensor.memory.is_empty(),"reset cancels target and pending intent")
	_check(not scene.ai.update_command(0.2).fire_requested,"generation change cannot carry old fire request")
	bot.set_controller(null)
	_check(scene.ai.sensor.memory.is_empty() and not scene.ai.driver.has_goal,"detaching clears memory and navigation")
	_check(scene.ai.events.size() <= 64,"combat transition log is bounded")
	# Actual AI launch versus a submitted player command, same gun and standard frontal plate.
	place(Vector3(12,0.03,6),Vector3(12,0.03,-34))
	bot.set_controller(scene.ai)
	await frames()
	finished.clear()
	bot.set_physics_process(true)
	for i in 600:
		await physics_frame
		if not finished.is_empty(): break
	bot.set_physics_process(false)
	var ai_result: Dictionary = finished.back().duplicate(true) if not finished.is_empty() else {}
	# AI may select its next exterior region after firing; compare the frozen launch.
	var replay_record := scene.projectiles.shot_records.get_record(scene.projectiles.shot_records.count()-1)
	var ai_point: Vector3 = replay_record.launch.position_world+replay_record.launch.velocity_world.normalized()*1000 if not replay_record.is_empty() else Vector3.ZERO
	_check(not ai_result.is_empty() and ai_result.target_id == "A" and ai_result.reason == "armor_stopped","actual AI round hits frontal standard plate through projectile manager")
	place(Vector3(12,0.03,6),Vector3(12,0.03,-34))
	bot.set_controller(null)
	bot.turret.set_aim_point(ai_point)
	bot.turret.snap_to_aim()
	await frames()
	finished.clear()
	cmd = VehicleCommand.new()
	cmd.has_aim_point = true
	cmd.aim_world_point = ai_point
	cmd.fire_requested = true
	bot.submit_command(cmd)
	await physics_frame
	bot._physics_process(1.0/60)
	await frames(30)
	_check(not finished.is_empty() and not ai_result.is_empty() and finished.back().reason == ai_result.reason and finished.back().surface_id == ai_result.surface_id,"T014-05 player command and AI launch produce same actual frontal armor result")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AI_COMBAT_CHECKS_PASS" if failed == 0 else "AI_COMBAT_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
