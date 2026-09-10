extends SceneTree
## Natural matches: no injected outcome, damage, tickets or accelerated rule timers.
var checks := 0
var failed := 0
var app: AppFlow
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func idle() -> void:
	for i in 1200:
		await process_frame
		if not app._transitioning: return
	check(false,"bounded transition")
func run() -> void:
	create_timer(1500,true,false,true).timeout.connect(func() -> void: print("NATURAL_MATCH_TIMEOUT"); quit(2))
	app = load("res://scenes/app.tscn").instantiate()
	app.profile = ProfileStore.new("")
	root.add_child(app); current_scene = app; await idle()
	for map_index in 2:
		app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
		app.garage.preparation.mode_choice.select(1); app.garage.preparation._mode_changed(1)
		app.garage.preparation.map_choice.select(map_index)
		app.enter_laboratory("team"); await idle()
		var battle := app.training as TeamRange
		check(battle != null and battle.team_ready,"normal garage starts map %d" % map_index)
		if battle == null: quit(1); return
		var token := app.match_token
		for tick in 36500:
			await physics_frame
			if battle.director.state.phase == "finished": break
			if battle.actor.state.destroyed: battle.request_respawn()
			if tick % 3600 == 0: print("NATURAL_MATCH map=%d frame=%d seconds=%.1f tickets=%s" % [map_index,tick,battle.director.state.elapsed,str(battle.director.state.tickets)])
		await process_frame
		var result := battle.director.state.result.duplicate(true)
		check(battle.director.state.phase == "finished" and result.get("reason","") in ["tickets","time_limit"],"map %d reaches natural rules result" % map_index)
		if result.is_empty(): quit(1); return
		print("NATURAL_RESULT map=%d %s" % [map_index,JSON.stringify(result)])
		check(result.combat_summary == battle.director.report and battle.result_panel.visible,"natural result shows frozen combat summary %d" % map_index)
		var saved := app.profile.snapshot()
		check(saved.receipts.has(token) and saved.pending.is_empty() and app.pending_reward.is_empty(),"natural finish commits one receipt without pending reward %d" % map_index)
		app.progression.apply_result_once(token,result)
		check(app.profile.snapshot() == saved,"retry cannot duplicate natural match reward %d" % map_index)
		app.restart_match(); await idle()
		check(not is_instance_valid(battle) and app.training.team_ready,"natural result restarts a fresh world %d" % map_index)
		app.training.leave_match(); await idle()
		check(app.garage != null and app.training == null and not paused,"restart returns to usable garage %d" % map_index)
	app.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed == 0: print("APP_MATCH_CYCLE_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
