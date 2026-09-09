extends SceneTree
# Cross-state regressions for AI recovery (001-026 audit finding):
# dry ammo + immobile + healthy gunnery must never swallow the repair request.
# Matrix per audit: ammo/no-ammo x mobile/immobile x crew complete/missing x fire/no-fire x patrol/no-patrol.
var count := 0
var failed := 0
var scene: AICombatRange
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func kill_track(bot) -> void:
	for id in bot.state.module_states:
		if str(bot.state.module_states[id].get("kind","")) == "track":
			bot.state.module_states[id].integrity = 0
			return
func heal_all(bot) -> void:
	for id in bot.state.module_states:
		bot.state.module_states[id].integrity = bot.state.module_states[id].max_integrity
func kill_role(bot, role: String) -> void:
	bot.state.crew_states[bot.state.crew_assignments[role]].alive = false
func revive_all(bot) -> void:
	for person in bot.state.crew_states:
		bot.state.crew_states[person].alive = true
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	await frames(5)
	_check(scene.combat_ready,"combat laboratory loads for recovery matrix")
	var bot := scene.target_actor
	scene.source_actor.set_controller(null)
	bot.set_physics_process(false)
	scene.ai.configure(bot,scene.nav,Callable(scene,"combat_actors"),"hard",1401)
	scene.ai.set_patrol(Vector3(0,0,6),Vector3(0,0,-42))
	scene.source_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,60))
	scene.ai.sensor.clear()
	scene.ai.observation = {}
	bot.state.recovery_enabled = true
	var cmd: VehicleCommand
	# C1 THE audit failure combo: dry + immobile + healthy gunnery + patrol goal.
	bot.gunner.rounds_remaining = 0
	kill_track(bot)
	cmd = scene.ai.update_command(0.3)
	_check(cmd.repair_requested and not cmd.fire_requested and scene.ai.phase == "repair","dry+immobile AI still delivers repair request instead of swallowed retreat command")
	# C2 drive restored -> retreat resumes with the fallback goal (no re-aim drift).
	heal_all(bot)
	cmd = scene.ai.update_command(0.3)
	_check(scene.ai.phase == "retreat" and scene.ai.driver.goal == scene.ai.retreat_goal and not cmd.repair_requested,"retreat resumes with fallback goal once drive returns; repair not re-issued after heal")
	# C3 dry + mobile was already retreat-only behaviour (C2 asserts it).
	# C4 fire present wins over everything else even when dry+immobile.
	bot.state.fires["hull_fire"] = {"source":{},"tick_left":0.0,"crew_exposure":{}}
	kill_track(bot)
	cmd = scene.ai.update_command(0.3)
	_check(cmd.extinguish_requested and not cmd.repair_requested,"live fire gets extinguish request, not repair")
	bot.state.fires.clear()
	# C5 missing gunner -> crew replacement request, still delivered (not swallowed).
	kill_role(bot,"gunner")
	cmd = scene.ai.update_command(0.3)
	_check(cmd.replace_crew_requested and not cmd.repair_requested,"dry+immobile+missing gunner requests legal replacement")
	revive_all(bot)
	# C6 missing driver while dry+immobile also reaches replacement path.
	kill_role(bot,"driver")
	cmd = scene.ai.update_command(0.3)
	_check(cmd.replace_crew_requested,"dry+immobile+missing driver requests legal replacement")
	revive_all(bot)
	# C7 dry + immobile + NO patrol goal still repairs (observation-empty branch).
	scene.ai.has_patrol = false
	cmd = scene.ai.update_command(0.3)
	_check(cmd.repair_requested and not cmd.fire_requested,"dry+immobile without patrol goal repairs rather than idling")
	scene.ai.has_patrol = true
	# C8 recovery disabled by rule -> never fabricates requests, and never wanders.
	bot.state.recovery_enabled = false
	cmd = scene.ai.update_command(0.3)
	_check(not cmd.repair_requested and not cmd.fire_requested and cmd.throttle == 0.0,"recovery-disabled vehicle holds instead of wandering or fabricating repair")
	bot.state.recovery_enabled = true
	# C9 regression: ammo + immobile repairs exactly as before (pre-existing path).
	bot.gunner.rounds_remaining = 10
	cmd = scene.ai.update_command(0.3)
	_check(cmd.repair_requested and scene.ai.phase == "repair","ammo+immobile repair regression holds")
	# C10 dry + mobile + turret broken: mobility is the retreat-critical capability -> retreat, do not stall on turret repair.
	heal_all(bot)
	for id in bot.state.module_states:
		if str(bot.state.module_states[id].get("kind","")) == "turret_drive":
			bot.state.module_states[id].integrity = 0
	bot.gunner.rounds_remaining = 0
	cmd = scene.ai.update_command(0.3)
	_check(scene.ai.phase == "retreat" and not cmd.repair_requested,"dry+mobile vehicle retreats for resupply rather than stalling on non-critical repair")
	heal_all(bot)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AI_RECOVERY_CHECKS_PASS" if failed == 0 else "AI_RECOVERY_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
