extends SceneTree
var checks := 0
var failed := 0
var app: AppFlow
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await process_frame
func idle() -> void:
	for i in 1200:
		await process_frame
		if not app._transitioning: await frames(3); return
	check(false,"transition completed within bounded wait")
func tap(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = down
		Input.parse_input_event(event); await frames()
func run() -> void:
	create_timer(240,true,false,true).timeout.connect(func() -> void: print("APP_FLOW_TIMEOUT"); quit(2))
	app = load("res://scenes/app.tscn").instantiate()
	app.profile = ProfileStore.new("")
	root.add_child(app); current_scene = app; await idle()
	var initial := app.profile.snapshot()
	app._enter_lab("res://scenes/missing_030.tscn")
	await idle()
	check(is_instance_valid(app.navigation_overlay) and app.training == null and not paused,"missing resource opens recoverable error without paused black screen")
	await tap(KEY_ESCAPE); await idle()
	check(app.garage != null and app.profile.snapshot() == initial,"error return preserves profile and playable garage")
	app._enter_lab("res://scenes/app.tscn"); await idle()
	check(app.training == null and is_instance_valid(app.navigation_overlay),"wrong scene root is rejected before entering tree")
	await tap(KEY_ESCAPE); await idle()
	for attempt in 3:
		app._enter_lab(MapRegistry.scene_path("hill_village"))
		app.cancel_loading(); await idle(); await frames(10)
		check(app.training == null and app.garage != null and not paused,"cancelled load never resurrects old battle %d" % attempt)
	for cycle in 10:
		app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
		app.garage.preparation.mode_choice.select(1); app.garage.preparation._mode_changed(1)
		app.garage.preparation.map_choice.select(cycle % 2)
		for click in 3: app.enter_laboratory("team")
		await idle()
		var battle := app.training as TeamRange
		check(battle != null and battle.team_ready and battle.combat_actors().size() == 8,"rapid start creates one complete battle %d" % cycle)
		if battle == null: quit(1); return
		check(battle.definition.id == MapRegistry.definition(MapRegistry.IDS[cycle % 2]).id,"selected map reaches actual world %d" % cycle)
		var match_id: int = battle.director.state.match_id
		var token := app.match_token
		var prior_profile := app.profile.snapshot()
		app.request_leave_match(battle); await frames()
		check(paused and is_instance_valid(app.navigation_overlay) and battle.director.state.phase != "finished","live leave waits for confirmation %d" % cycle)
		await tap(KEY_ESCAPE)
		check(app.training == battle and battle.director.state.phase != "finished" and not paused and app.profile.snapshot() == prior_profile,"cancel leave changes no result or progress %d" % cycle)
		# Explicit lifecycle fixture through the player's production abandon action.
		for step in 240:
			if battle.director.state.phase == "playing": break
			await physics_frame
		battle.abandon_vehicle(); await frames(4)
		check(battle.waiting_panel.visible and battle.director.report.deaths == 1,"player death enters redeploy selection %d" % cycle)
		app.request_leave_match(battle); await frames()
		check(paused and is_instance_valid(app.navigation_overlay),"dead player return is also confirmed %d" % cycle)
		await tap(KEY_ESCAPE)
		check(battle.waiting_panel.visible and not paused and battle.director.state.phase == "playing","cancel dead-player exit restores selection %d" % cycle)
		# Production finish entry is an integration fixture, not a claimed played victory.
		battle.director.finish_once("abandoned","player_returned")
		var result := battle.director.state.result.duplicate(true)
		var saved := app.profile.snapshot()
		var shown := battle.result_text.text
		check(result.combat_summary == battle.director.report and saved.receipts.has(token),"authoritative result and receipt are frozen together %d" % cycle)
		app._settle_match(token,result)
		check(app.profile.snapshot() == saved,"duplicate result cannot grant another reward %d" % cycle)
		check(battle.result_text.text == shown,"retry does not append duplicate settlement text %d" % cycle)
		for click in 3: app.restart_match()
		await idle()
		check(not is_instance_valid(battle) and app.training.director.state.match_id != match_id and app.training.combat_actors().size() == 8,"rapid restart frees old actors and opens one new match %d" % cycle)
		app.training.leave_match(); await idle()
		check(app.training == null and app.garage != null and not paused and app.pending_reward.is_empty(),"return releases world, pause and pending reward %d" % cycle)
	check(app.profile.snapshot().pending.is_empty(),"all started matches leave settled receipts, no dangling pending tokens")
	app.free(); await frames(10)
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed == 0: print("APP_FLOW_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
