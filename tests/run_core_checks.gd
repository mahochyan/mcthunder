extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var app: AppFlow = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames()
	_check(is_instance_valid(app.garage) and app.training == null,"default startup opens usable garage")
	for character in "车库配弹训练击穿履带维修回放结果":
		_check(CoreUI.FONT.has_char(character.unicode_at(0)),"bundled font covers "+character)
	var loadout := app.garage.build_loadout()
	_check(loadout.ok and loadout.loadout.rounds == 10,"garage builds actual initial loadout")
	var invalid: Dictionary = loadout.loadout.duplicate(true)
	invalid.rounds = 0
	app.enter_training(invalid,0)
	_check(app.training == null and not app.garage.error_label.text.is_empty(),"invalid loadout keeps recoverable garage error")
	invalid.rounds = 31
	_check(not TrainingLoadout.validate(invalid).ok,"capacity limit rejects 31 rounds")
	invalid.rounds = 10
	invalid.shell_id = "unimplemented_heat"
	_check(not TrainingLoadout.validate(invalid).ok,"unimplemented shell cannot be selected")
	for mode in 3:
		app.garage._inspect()
	_check(app.garage.build_loadout() == loadout,"preview modes preserve loadout")
	var config := {"vehicle_id":"test_vehicle","shell_id":"ap70","rounds":3,"infinite":true}
	app.enter_training(config,2)
	await _frames(8)
	var scene := app.training as CoreRange
	_check(scene != null and scene._core_ready,"garage creates integrated production training")
	if scene == null: quit(1); return
	_check(scene.source_actor.gunner.shell.id == "training_ap70" and scene.source_actor.gunner.rounds_remaining == 3,"selected shell and count reach actual gunner")
	_check(scene.source_actor.gunner.training_resupply and not scene.target_actor.gunner.training_resupply,"infinite option isolated to training player")
	await _frames(25)
	var before_shots := scene.source_actor.gunner.shots_fired
	scene.source_actor.gunner.try_fire()
	_check(scene.source_actor.gunner.shots_fired == before_shots+1 and scene.source_actor.gunner.inventory.conserved(),"real gunner uses explicit resupply without losing conservation")
	var actual_ammo := scene.source_actor.gunner.inventory.snapshot()
	scene.source_actor.gunner.try_fire()
	_check(scene.source_actor.gunner.shots_fired == before_shots+1 and scene.source_actor.gunner.inventory.snapshot() == actual_ammo,"infinite mode still rejects immediate second shot without supply")
	scene.restart_lesson()
	var inventory := scene.source_actor.gunner.inventory
	inventory.consume_chamber()
	inventory.supply_round(1,"ammo_rack")
	inventory.begin_transfer()
	_check(inventory.conserved() and inventory.supplied == 4 and inventory.fired == 1,"explicit training resupply preserves conservation ledger")
	_check(inventory.chamber == 0 and inventory.in_transfer == 1,"resupply does not skip chamber transfer")
	_check(not inventory.supply_round(1,"missing") and not inventory.supply_round(-1,"ammo_rack"),"invalid supply cannot mutate stock")
	var round_before := scene.get_round_id()
	var old_generation := scene.target_actor.state.generation
	scene.xray = true
	scene.restart_lesson()
	_check(scene.get_round_id() == round_before+1 and scene.target_actor.state.generation > old_generation,"retry advances round and target generation")
	_check(scene.xray and scene.loadout == config and scene.source_actor.gunner.rounds_remaining == 3,"retry preserves chosen settings while applying explicit initial ammo")
	_check(scene.projectiles.active_count() == 0 and scene.projectiles.shot_records.count() == 0 and scene.target_actor.state.fires.is_empty(),"retry clears flights replay and fire")
	_check(scene.director.status == "running" and scene.director.last_record.is_empty(),"retry clears old result")
	var wrong := {"identity":{"round_id":round_before,"shooter_id":"A","shooter_life_id":scene.source_actor.life_id}}
	_check(not scene.director.accept_record(wrong,scene.target_actor),"previous round record cannot finish current lesson")
	wrong.identity.round_id = scene.get_round_id()
	wrong.identity.shooter_life_id += 1
	_check(not scene.director.accept_record(wrong,scene.target_actor),"wrong shooter lifetime rejected")
	app.show_results(scene.director.finish())
	_check(paused and is_instance_valid(app.result_overlay),"results expose actual running state and pause simulation")
	var shots := scene.source_actor.gunner.shots_fired
	app._resume_training()
	await _frames()
	_check(not paused and scene.source_actor.gunner.shots_fired == shots,"closing results cannot create a shot")
	app.return_to_garage(scene.director.finish())
	await _frames()
	_check(app.training == null and app.garage.initial_loadout == config,"return frees simulation and retains selected loadout")
	_check(AcceptanceChecklist.collect().human == "PENDING","automated checks do not sign human acceptance")
	for index in TrainingDirector.TITLES.size():
		app.enter_training(config,index)
		await _frames(5)
		scene = app.training
		_check(scene.director.case_index == index and scene.target_point().is_finite(),"lesson %d builds actual target and aim guide" % index)
		_check(absf(scene.target_actor.tank.global_position.z+30)<0.01,"lesson %d target remains at intended world range ahead of backstop" % index)
		if index == 4: _check(scene.target_actor.gunner.inventory.total_available() == 0,"empty-rack lesson starts actually empty")
		app.return_to_garage()
		await _frames()
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,failed])
	print("CORE_CHECKS_PASS" if failed == 0 else "CORE_CHECKS_FAIL")
	app.free()
	quit(0 if failed == 0 else 1)
