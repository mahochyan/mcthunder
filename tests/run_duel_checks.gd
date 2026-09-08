extends SceneTree
var count := 0
var failed := 0
var scene: DuelRange
var event_sequence := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func new_match() -> void:
	if is_instance_valid(scene): scene.free()
	scene = DuelRange.new()
	root.add_child(scene)
	current_scene = scene
	await frames(190)
func damage_fixture(vehicle: VehicleActor, id: String, kind: String) -> void:
	event_sequence += 1
	var event := {"kind":kind,"entity_id":vehicle.entity_id,"life_id":vehicle.life_id,"target_generation":vehicle.state.generation,"event_id":"duel_fixture_%d"%event_sequence,"round_id":scene.get_round_id(),"shooter_id":"B" if vehicle.entity_id == "A" else "A","shooter_life_id":scene.target_actor.life_id if vehicle.entity_id == "A" else scene.source_actor.life_id,"shot_id":event_sequence,"projectile_id":event_sequence}
	event["module_id" if kind == "module" else "crew_id"] = id
	var result := scene._apply_projectile_damage(event,120)
	var record := event.duplicate(true)
	record.merge(result,true)
	vehicle.present_damage_record(record)
func lethal_fixture(vehicle: VehicleActor) -> void:
	for station in vehicle.state.station_roles:
		damage_fixture(vehicle,station,"crew")
		if vehicle.state.destroyed: break
func _run() -> void:
	await new_match()
	check(scene.duel_ready and scene.match_director.phase == "playing","three-second real countdown starts a valid duel")
	check(scene.source_actor.gunner.shell.penetration_curve == scene.target_actor.gunner.shell.penetration_curve and scene.source_actor.definition.forward_max_speed == scene.target_actor.definition.forward_max_speed,"both combatants share gun and vehicle performance")
	check(scene.ai.observation.is_empty() and scene.target_actor.gunner.shots_fired == 0,"covered spawns prevent opening direct fire")
	check(not scene.replay.allowed_record.call({}) and not scene.replay.auto_replay,"playing duel hides inspection replay and automatic replay")
	var generation := scene.source_actor.state.generation
	scene._reset_range()
	check(scene.source_actor.state.generation == generation,"formal duel does not allow free R reset")
	var stats_before := scene.match_director.totals.duplicate(true)
	scene.match_director.on_damage({"round_id":scene.get_round_id(),"shooter_id":"A","shooter_life_id":-99,"event_id":"stale-life","kind":"module","before":{"integrity":100},"after":{"integrity":0}})
	scene.match_director.on_finished_projectile({"round_id":scene.get_round_id(),"shooter_id":"A","shooter_life_id":-99,"projectile_id":99,"contacts":[{}],"reason":"armor_stopped"})
	check(scene.match_director.totals == stats_before,"stale shooter lifetime cannot add damage or contact statistics")
	scene.match_director.on_damage({"round_id":scene.get_round_id(),"shooter_id":"A","shooter_life_id":scene.source_actor.life_id,"event_id":"no-effective-damage","kind":"module","before":{"integrity":0},"after":{"integrity":0}})
	check(scene.match_director.totals == stats_before,"hitting an already destroyed component does not inflate effective damage count")
	damage_fixture(scene.source_actor,"engine","module")
	lethal_fixture(scene.target_actor)
	var record := scene.target_actor.state.death_record.duplicate(true)
	check(not scene.match_director.on_vehicle_destroyed(record),"duplicate destruction signal is ignored before adjudication")
	await frames()
	check(scene.match_director.result.outcome == "victory" and scene.match_director.finish_count == 1,"T015-01 real damage state produces one player victory")
	check(scene.match_director.totals.B.deaths == 1,"T015-04 enemy death is recorded exactly once")
	check(scene.result_panel.visible and scene.replay.allowed_record.call({}),"finished duel exposes result panel and replay permission")
	check(not scene.source_actor.is_physics_processing() and not scene.target_actor.is_physics_processing() and scene.projectiles.active_count() == 0,"finished duel freezes actor damage clocks and cancels in-flight projectiles")
	var before := scene.source_actor.state.damage_snapshot()
	var late := scene._apply_projectile_damage({"kind":"module","module_id":"engine","entity_id":"A","life_id":scene.source_actor.life_id,"event_id":"late","round_id":scene.get_round_id()},120)
	check(not late.ok and scene.source_actor.state.damage_snapshot() == before,"late damage callback cannot change finished vehicle state")
	var ammo := scene.source_actor.gunner.rounds_remaining
	scene.source_actor.gunner.cooldown_left = 0
	check(not scene.source_actor.gunner.try_fire() and scene.source_actor.gunner.rounds_remaining == ammo,"finished manager rejects late launch without ammunition loss")
	check(not scene.match_director.finish_once("defeat","late") and scene.match_director.result.outcome == "victory","terminal result cannot be overwritten")
	var frozen_fires := scene.source_actor.state.fires.duplicate(true)
	var frozen_damage := scene.source_actor.state.damage_snapshot()
	await frames(120)
	check(not frozen_fires.is_empty() and scene.source_actor.state.fires == frozen_fires and scene.source_actor.state.damage_snapshot() == frozen_damage,"active fire stops applying damage and exposure after match ends")
	await new_match()
	lethal_fixture(scene.source_actor)
	await frames()
	check(scene.match_director.result.outcome == "defeat","T015-01 player loss has normal final state")
	await new_match()
	lethal_fixture(scene.source_actor)
	lethal_fixture(scene.target_actor)
	await frames()
	check(scene.match_director.result.outcome == "draw" and scene.match_director.result.reason == "simultaneous_destruction" and scene.match_director.finish_count == 1,"both deaths in one physics step become one draw")
	await new_match()
	scene.match_director.advance(MatchDirector.TIME_LIMIT_SECONDS)
	check(scene.match_director.result.outcome == "draw" and scene.match_director.result.reason == "time_limit","ten-minute timeout is a deterministic draw")
	await new_match()
	# Position fixtures test actual disabled AI commands; normal window driving is separate.
	scene.source_actor.set_controller(null)
	scene.source_actor.tank.global_position = Vector3(12,0.03,6)
	scene.target_actor.tank.global_position = Vector3(12,0.03,-34)
	scene.ai.configure(scene.target_actor,scene.nav,Callable(scene,"combat_actors"),"hard",1501)
	scene.target_actor.turret.set_aim_point(scene.source_actor.tank.global_position+Vector3.UP*1.2)
	scene.target_actor.turret.snap_to_aim()
	damage_fixture(scene.target_actor,"engine","module")
	var parked := scene.target_actor.tank.global_position
	var shots := scene.target_actor.gunner.shots_fired
	for i in 400:
		await physics_frame
		if scene.target_actor.gunner.shots_fired > shots: break
	check(scene.target_actor.gunner.shots_fired > shots and not scene.target_actor.capabilities().drive,"T015-03 AI engine loss still allows actual counterfire")
	var offset := scene.target_actor.tank.global_position-parked
	offset.y = 0
	check(offset.length() < 0.15 and scene.target_actor.state.recovery_action == "repair","disabled AI repairs while firing without translating")
	await frames(30)
	lethal_fixture(scene.target_actor)
	await frames()
	var frozen_result := scene.match_director.result.duplicate(true)
	frozen_damage = scene.source_actor.state.damage_snapshot()
	check(scene.replay.show_history(0),"finished real counterfire round can be replayed")
	await frames(90)
	check(scene.match_director.result == frozen_result and scene.source_actor.state.damage_snapshot() == frozen_damage,"T015-04 replay animation cannot alter battle outcome or damage")
	shots = scene.target_actor.gunner.shots_fired
	await frames(180)
	check(scene.target_actor.gunner.shots_fired == shots,"dead AI cannot continue firing")
	scene.free()
	scene = null
	var app := AppFlow.new()
	root.add_child(app)
	current_scene = app
	await frames()
	var stable_count := get_node_count()
	var previous_life := -1
	var stable := true
	for i in 20:
		app.enter_laboratory("duel")
		await frames()
		var duel := app.training as DuelRange
		stable = stable and duel != null and duel.source_actor.life_id > previous_life
		previous_life = duel.source_actor.life_id
		stable = stable and duel.combat_actors().size() == 2 and duel.match_director.match_finished.get_connections().size() == 1
		duel.leave_match()
		await frames()
		stable = stable and app.training == null and app.garage != null and get_node_count() == stable_count
	check(stable,"T015-H03 twenty actual AppFlow starts/returns leave stable nodes and one callback")
	app.enter_laboratory("duel")
	await frames()
	var old: DuelRange = app.training
	var old_life := old.source_actor.life_id
	old.match_director.abandon()
	app.restart_match()
	await frames()
	check(not is_instance_valid(old) and app.training is DuelRange and app.training.source_actor.life_id > old_life,"AppFlow restart frees prior round and spawns unique new lives")
	app.training.leave_match()
	await frames()
	check(app.last_result.outcome == "abandoned" and app.training == null,"active return commits abandoned summary and reaches garage")
	app.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("DUEL_CHECKS_PASS" if failed == 0 else "DUEL_CHECKS_FAIL")
	quit(1 if failed else 0)
