extends SceneTree
# GPT-required validator scenarios for TrafficTelemetry itself (step 3 gate):
# (1) a legitimate hold is never congestion; (2) a stalled movement task IS
# recorded with attribution; (3) a stall unrecovered at the end counts as
# open_at_end, never as a recovered success.
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
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	await frames(5)
	var bot := scene.target_actor
	bot.set_controller(scene.ai)
	var tm := TrafficTelemetry.new()
	var key := bot.entity_id+":"+str(bot.life_id)
	# (1) holding at the assigned objective = legitimate hold, never congestion
	var here := bot.tank.global_position
	scene.ai.set_patrol(here,here)
	for i in 20: tm.step([bot],0.3)
	var snap: Dictionary = tm.snapshot()
	var life: Dictionary = snap.per_life[key]
	_check(life.episodes.is_empty() and float(life.holds.get("at_objective",0.0)) > 4.0,"vehicle holding at its objective is a legitimate hold, never congestion")
	# (2) a pending movement task with no progress opens and closes with attribution
	scene.ai.set_patrol(here+Vector3(0,0,300),here+Vector3(0,0,300))
	scene.ai.driver.cancel("measure")
	scene.ai.driver.phase = "idle"
	for i in 12: tm.step([bot],0.3)
	bot.state.fires["hull_fire"] = {"source":{},"tick_left":0.0,"crew_exposure":{}}
	tm.step([bot],0.3)
	bot.state.fires.clear()
	snap = tm.snapshot()
	life = snap.per_life[key]
	var opened: Array = life.episodes.filter(func(e: Dictionary) -> bool: return e.outcome == "state:fire")
	_check(opened.size() == 1 and float(opened[0].duration_s) >= 1.0 and opened[0].has("blocker") and opened[0].has("ai_phase"),"stalled movement task is recorded with duration, blocker class, driver phase and ai phase")
	# (3) stall still open at the end = open_at_end, not a recovered success
	for i in 12: tm.step([bot],0.3)
	snap = tm.snapshot()
	life = snap.per_life[key]
	var open_eps: Array = life.episodes.filter(func(e: Dictionary) -> bool: return e.outcome == "open_at_end")
	_check(open_eps.size() == 1 and int(life.open_at_end) == 1,"stall unrecovered at end is recorded as open_at_end, never as success")
	print("=== done: %d checks, %d failed ==="%[count,failed])
	print("TELEMETRY_MEASURES_PASS" if failed == 0 else "TELEMETRY_MEASURES_FAIL")
	scene.free()
	quit(1 if failed else 0)
