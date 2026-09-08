extends SceneTree
var count := 0
var failed := 0
var scene: TeamRange
var shot := 1000
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func fresh(freeze: bool = true) -> void:
	if is_instance_valid(scene): scene.free()
	scene = TeamRange.new()
	root.add_child(scene)
	current_scene = scene
	await frames(190)
	if not freeze: return
	scene.director.set_physics_process(false)
	for vehicle in scene.combat_actors():
		vehicle.set_controller(null)
		vehicle.set_physics_process(false)
		vehicle.tank.velocity = Vector3.ZERO
		vehicle.tank.forward_speed = 0
func kill(vehicle: VehicleActor) -> void:
	if vehicle.state.destroy_once("test_fixture",{"round_id":scene.get_round_id()}):
		vehicle._commit_death()
		vehicle._publish_death()
func mathematical_cases() -> void:
	var s := TeamMatchState.new()
	s.initialize()
	s.phase = "playing"
	CapturePoint.step(s,[1,1,1],6)
	check(is_equal_approx(s.capture_progress,0.5) and s.capture_owner == 0,"T016-01 three occupants have the same twelve-second capture rate")
	CapturePoint.step(s,[],3)
	check(is_equal_approx(s.capture_progress,0.5),"empty neutral point preserves partial progress")
	CapturePoint.step(s,[1,2],3)
	check(s.contested and is_equal_approx(s.capture_progress,0.5),"T016-H01 contested point freezes progress")
	var owned := CapturePoint.step(s,[1],6)
	TicketLedger.apply_events(s,owned)
	check(s.capture_owner == 1 and s.tickets[2] == 300,"capture completed at tick end never drains earlier neutral time")
	TicketLedger.apply_events(s,CapturePoint.step(s,[],0.6))
	TicketLedger.apply_events(s,CapturePoint.step(s,[1,2],0.6))
	check(s.tickets[2] == 299 and is_equal_approx(s.drain_bank[2],0.2),"owned empty/contested point drains exactly one cumulative ticket per second")
	owned = CapturePoint.step(s,[2],12)
	check(s.capture_owner == 0 and is_zero_approx(s.capture_progress) and is_equal_approx(owned[1],12),"opponent first neutralizes in twelve seconds while previous owner retains drain")
	owned = CapturePoint.step(s,[2],14.5)
	check(s.capture_owner == 2 and is_equal_approx(owned[2],2.5),"opponent then captures; large tick allocates only actual owned time")
	for tickets in [{1:0,2:0},{1:10,2:10},{1:11,2:10},{1:9,2:10}]:
		s.tickets = tickets
		s.elapsed = 600
		var expected := "draw" if tickets[1] == tickets[2] else ("victory" if tickets[1]>tickets[2] else "defeat")
		check(TicketLedger.result_after_tick(s) == expected,"T016-02 simultaneous zero or timeout settles by both final ticket totals")
func lifecycle_cases() -> void:
	await fresh()
	var s := scene.director.state
	check(scene.team_ready and s.phase == "playing" and scene.combat_actors().size() == 8,"real three-second countdown creates eight actual vehicles")
	var ids := {}
	for vehicle in scene.combat_actors(): ids[vehicle.life_id] = true
	check(ids.size() == 8 and scene.query_snapshots().size() == 8,"each slot owns distinct life and actual collision snapshot")
	var a := scene.actor
	var generation := a.state.generation
	scene._reset_range()
	check(a.state.generation == generation,"formal R reset cannot replenish health or ammunition")
	a.tank.global_position = Vector3(0,0.03,0)
	s.roster.A.protection_left = 3.0
	scene.director.advance(3)
	check(s.capture_progress == 0 and s.roster.A.protection_left == 0,"protected tank never captures during its protection expiry step")
	scene.director.advance(1)
	check(is_equal_approx(s.capture_progress,1.0/12),"expired protection allows subsequent actual in-circle capture")
	for action in ["aim","throttle","steer","fire"]:
		s.roster.A.protection_left = 3.0
		var cmd := VehicleCommand.new()
		match action:
			"aim": cmd.has_aim_point = true; cmd.aim_world_point = Vector3(0,2,-10)
			"throttle": cmd.throttle = 1
			"steer": cmd.steer = 1
			"fire": cmd.fire_requested = true
		a._apply_command_once(cmd,1.0/60)
		check(s.is_protected("A",a.life_id) == (action == "aim"),"real command consumer protection cancellation: "+action)
	var before := {"elapsed":s.elapsed,"progress":s.capture_progress,"tickets":s.tickets.duplicate(),"position":a.tank.global_position}
	scene._pause()
	scene.director.advance(20)
	await frames(6)
	check(s.elapsed == before.elapsed and s.capture_progress == before.progress and s.tickets == before.tickets and a.tank.global_position == before.position,"T016-H05 pause freezes match clock, point, tickets and vehicle")
	scene._resume()
	check(a.gunner.resume_grace > 0 and not paused,"resume restores normal clock with fire grace")
	scene.abandon_vehicle()
	scene.abandon_vehicle()
	scene.director.advance(0.01)
	var old_life := a.life_id
	check(s.tickets[1] == 270 and s.roster.A.deaths == 1 and scene.waiting_panel.visible,"abandon current vehicle commits one actual death and one thirty-ticket charge")
	check(not s.queue_death(a.state.death_record),"T016-03 repeated death record cannot debit twice")
	scene.request_respawn()
	scene.director.advance(7.9)
	check(scene.actor.life_id == old_life and not s.roster.A.respawn_requested,"early respawn request cannot bypass eight-second preparation")
	scene.director.advance(0.11)
	check(scene.actor.life_id == old_life and s.roster.A.waiting_reason == "choose_vehicle","player explicitly chooses redeploy after minimum delay")
	scene.request_respawn()
	scene.director.advance(0.01)
	var replacement := scene.actor
	check(replacement.life_id != old_life and s.roster.A.spawns == 2 and replacement.controller == scene.controller,"one redeploy creates one new life with the sole local controller")
	check(not replacement.state.destroyed and replacement.state.fires.is_empty() and replacement.state.alive_crew_count() == 5 and replacement.gunner.rounds_remaining == 30 and replacement.state.extinguisher_charges == 2,"new life restores actual crew, damage, fire, ammunition and extinguishers")
	check(s.is_protected("A",replacement.life_id) and not s.is_protected("A",old_life) and not s.queue_death(a.state.death_record),"old life cannot inherit new shield or add stale death")
	scene.request_respawn()
	scene.director.advance(0.01)
	check(s.roster.A.spawns == 2 and scene.wrecks.count() == 1,"duplicate redeploy leaves one new vehicle and one physical wreck")
	var wreck_visible := true
	for geometry in a.tank.find_children("*","GeometryInstance3D",true,false): wreck_visible = wreck_visible and geometry.layers&GameConfig.VIS_LAYER_VEHICLE == 0
	check(wreck_visible,"old player wreck remains visible to the new life's gunsight cull mask")
	var bot := s.actor_for("B")
	var bot_life := bot.life_id
	kill(bot)
	scene.director.advance(0.01)
	scene.director.advance(8)
	check(s.actor_for("B").life_id != bot_life and s.roster.B.spawns == 2,"AI automatically respawns once after the same eight-second delay")
	var state_before := s.result.duplicate(true)
	check(state_before.is_empty(),"ordinary deaths and redeploys keep match running")
	# Real collision query fixtures: world obstruction, reserved vehicles, all blocked.
	var candidates: Array[Transform3D] = [Transform3D(Basis.IDENTITY,Vector3(0,0.03,34)),Transform3D(Basis.IDENTITY,Vector3(35,0.03,55))]
	var safe := RespawnService.find_safe(scene.get_world_3d().direct_space_state,candidates,Vector3(2.85,1.68,5.45),[])
	check(safe.ok and safe.transform.origin == candidates[1].origin,"T016-H03 real world blocker selects alternate spawn")
	var occupied: Array[Vector3] = [candidates[1].origin]
	check(not RespawnService.find_safe(scene.get_world_3d().direct_space_state,candidates,Vector3(2.85,1.68,5.45),occupied).ok,"all candidates blocked or reserved yields waiting, never overlap")
	await fresh()
	s = scene.director.state
	s.tickets = {1:30,2:30}
	kill(scene.actor)
	kill(s.actor_for("B"))
	scene.director.advance(0.01)
	check(s.phase == "finished" and s.result.outcome == "draw" and s.finish_count == 1,"T016-H02 same physics-step player/enemy deaths reaching zero settle once as draw")
	var frozen := s.result.duplicate(true)
	var population := scene.combat_actors().size()
	scene.request_respawn()
	scene.director.advance(100)
	check(scene.combat_actors().size() == population and s.result == frozen and not scene.director.finish_once("victory","late"),"finished match rejects late respawns and result replacement")
	var late := scene._apply_projectile_damage({"round_id":scene.get_round_id(),"entity_id":"A2","life_id":s.actor_for("A2").life_id,"kind":"module","module_id":"engine"},120)
	check(not late.ok and s.result == frozen and scene.projectiles.active_count() == 0,"T016-04 finished round rejects damage and cancels active shots")
func projectile_cases() -> void:
	await fresh()
	var s := scene.director.state
	var friend := s.actor_for("A2")
	var enemy := s.actor_for("B")
	friend.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(30,0.03,20))
	enemy.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(30,0.03,12))
	await frames()
	for mode in ["friendly_hull","friendly_track","protected_enemy","wreck"]:
		var target := friend if mode.begins_with("friendly") else enemy
		var layout: VehicleLayoutDefinition = ArmorTrainingTargets.build([{"center":Vector3(0,1,-1),"thickness":10}]).layout
		var module := ModuleVolumeDefinition.new()
		module.id = "test_component"
		module.kind = "track" if mode == "friendly_track" else "engine"
		module.part_id = "hull"
		module.external = mode == "friendly_track"
		module.local_box_transform = Transform3D(Basis.IDENTITY,Vector3(0,1,-2))
		module.size_m = Vector3(1,1,1)
		layout.modules.append(module)
		if module.external: layout.armor_patches.clear()
		target.set_damage_layout(layout)
		if mode == "protected_enemy": s.roster.B.protection_left = 3.0
		if mode == "wreck": kill(target)
		shot += 1
		var spec := {"round_id":scene.get_round_id(),"shooter_id":"A","shooter_life_id":scene.actor.life_id,"shooter_team_id":1,"shot_id":shot,"shell_id":"fixture_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,500)]),"position_world":target.tank.global_position+Vector3(0,1,0),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":100.0}
		var spawned := scene.projectiles.try_spawn(spec)
		check(spawned.ok,"real projectile manager accepts "+mode+" fixture")
		var st := scene.projectiles.get_projectile_state(spawned.projectile_id)
		var snapshots := [QuerySnapshotBuilder.build_from_vehicle(target.tank,layout)]
		if target == friend: snapshots.append(QuerySnapshotBuilder.build_from_vehicle(enemy.tank,enemy.damage_layout_override))
		var target_before := target.state.damage_snapshot()
		var enemy_before := enemy.state.damage_snapshot()
		scene.projectiles.advance_projectile(st,1.0/30,snapshots,scene.get_world_3d().direct_space_state)
		var reason := "friendly_block" if mode.begins_with("friendly") else ("spawn_protected" if mode == "protected_enemy" else "wreck_block")
		check(st.terminal_reason == reason and st.damage_records.is_empty() and target.state.damage_snapshot() == target_before and enemy.state.damage_snapshot() == enemy_before,"T016-05 actual nearest contact stops at "+mode+" without damage to it or enemy behind")
		check(st.position_world.z > target.tank.global_position.z-3,"denied contact stops real flight at first physical surface")
func integration_cases() -> void:
	await fresh(false)
	await frames(120)
	var s := scene.director.state
	var before := {"elapsed":s.elapsed,"capture":s.capture_progress,"tickets":s.tickets.duplicate(),"actors":{}}
	for vehicle in scene.combat_actors():
		before.actors[vehicle.life_id] = {"pose":vehicle.tank.global_transform,"damage":vehicle.state.damage_snapshot(),"cooldown":vehicle.gunner.cooldown_left,"ammo":vehicle.gunner.rounds_remaining,"protection":s.roster[vehicle.entity_id].protection_left}
	scene._pause()
	await frames(60)
	var frozen: bool = s.elapsed == before.elapsed and s.capture_progress == before.capture and s.tickets == before.tickets
	for vehicle in scene.combat_actors():
		var b: Dictionary = before.actors[vehicle.life_id]
		frozen = frozen and vehicle.tank.global_transform == b.pose and vehicle.state.damage_snapshot() == b.damage and vehicle.gunner.cooldown_left == b.cooldown and vehicle.gunner.rounds_remaining == b.ammo and s.roster[vehicle.entity_id].protection_left == b.protection
	check(frozen,"T016-H05 pause freezes eight normally running actors, AI, damage, weapons, protection and clock")
	scene._resume()
	await frames(30)
	check(s.elapsed > before.elapsed,"actual physics resumes match after global pause")
	await fresh()
	s = scene.director.state
	var bot := s.actor_for("B")
	kill(bot)
	scene.director.advance(0.01)
	var normal_spawn := scene.director.respawns.spawn_provider
	scene.director.respawns.spawn_provider = func(_id: String) -> VehicleActor: return null
	scene.director.advance(8)
	scene.director.advance(1)
	check(s.roster.B.spawns == 1 and s.roster.B.waiting_reason == "spawn_blocked" and not s.roster.B.request_sent,"blocked spawn service stays queued without duplicate allocation")
	scene.director.respawns.spawn_provider = normal_spawn
	scene.director.advance(0.01)
	check(s.roster.B.spawns == 2 and s.actor_for("B").life_id != bot.life_id,"clearing a blocked spawn resumes one fresh life")
	await fresh()
	var observer := scene.actor
	var target := scene.director.state.actor_for("B")
	observer.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(35,0.03,10))
	target.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(35,0.03,5))
	observer.turret.set_aim_point(target.tank.global_position+Vector3.UP*2.2)
	observer.turret.snap_to_aim()
	await frames()
	var sensor := AIPerception.new()
	sensor.actor_provider = Callable(scene,"combat_actors")
	var observations := sensor.scan(observer,1)
	var reachable := false
	for observation in observations:
		if observation.entity_id != "B" or not observation.visible: continue
		var d: Vector3 = observation.aim_point-observer.turret.barrel_pivot.global_position
		var pitch := rad_to_deg(atan2(d.y,Vector2(d.x,d.z).length()))
		reachable = pitch >= observer.definition.barrel_pitch_min and pitch <= observer.definition.barrel_pitch_max
	check(reachable,"close enemy observation chooses a visible exterior inside actual gun elevation limits")
	var ai := AITankController.new()
	observer.add_child(ai)
	ai.configure(observer,scene.nav,Callable(scene,"combat_actors"),"normal",1601)
	ai.advance_while_engaged = true
	ai.set_patrol(TeamArena.goal(1,0),TeamArena.candidates(1)[0].origin)
	ai.driver.cancel("fixture_traffic_failure")
	ai.driver._transition("failed","fixture_traffic_failure")
	ai.update_command(0.1)
	check(ai.driver.has_goal and ai.driver.phase != "failed","objective commander retries a bounded failed route using only public goal")
	var damage := {"kind":"module","module_id":"turret_drive","entity_id":observer.entity_id,"life_id":observer.life_id,"event_id":"team_turret_fixture","round_id":scene.get_round_id()}
	observer.apply_projectile_damage(damage,120)
	var command := ai.update_command(0.1)
	check(observer.capabilities().fire and observer.capabilities().turret_speed == 0 and command.repair_requested and command.throttle == 0,"AI repairs disabled turret while breech remains usable and stops for the action")
	# Repeated actual scene transitions exercise ownership and callback cleanup.
	scene.free()
	scene = null
	current_scene = null
	var app := AppFlow.new()
	root.add_child(app)
	await frames()
	var baseline := get_node_count()
	var clean := true
	for i in 20:
		app.enter_laboratory("team")
		await frames()
		var match_scene := app.training as TeamRange
		clean = clean and match_scene != null and match_scene.combat_actors().size() == 8
		match_scene.leave_match()
		await frames(6)
		clean = clean and app.training == null and get_node_count() <= baseline+2
	check(clean,"twenty normal AppFlow enter/leave cycles release actors, cameras, controllers and callbacks")
	app.enter_laboratory("team")
	await frames()
	var previous_id: int = app.training.get_round_id()
	app.restart_match()
	await frames()
	check(app.training is TeamRange and app.training.get_round_id() != previous_id,"restart uses the team scene and fresh match identity")
	app.free()
	await frames()
func _run() -> void:
	root.size = Vector2i(1280,720)
	mathematical_cases()
	await lifecycle_cases()
	await projectile_cases()
	await integration_cases()
	current_scene = null
	await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TEAM_CHECKS_PASS" if failed == 0 else "TEAM_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
