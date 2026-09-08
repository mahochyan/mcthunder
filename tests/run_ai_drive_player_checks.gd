extends "res://tests/run_drive_player_checks.gd"
var ai_scene: AIDriveRange

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	await _capture("00_low_poly_garage")
	await _click(_find(app.garage,"转右"))
	await _click(_find(app.garage,"转右"))
	await _capture("00b_low_poly_rear")
	for i in 12:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	var entry := _find(app.garage,"电脑驾驶实验室")
	_check(entry != null and entry.get_global_rect().get_center().y < 660,"normal garage scroll reveals AI laboratory entry")
	await _click(entry)
	ai_scene = app.training as AIDriveRange
	_check(ai_scene != null and ai_scene.ai_ready,"normal mouse click starts real AI driving trial")
	if ai_scene == null: quit(1); return
	_check(ai_scene.overview.current and not ai_scene.target_actor.cam_rig.cam.current,"normal AI spawn keeps intended observer camera")
	await _capture("01_ai_departure")
	for i in 1200:
		if absf(ai_scene.target_actor.tank.global_position.x) > 8: break
		await physics_frame
	_check(absf(ai_scene.target_actor.tank.global_position.x) > 8,"real-time AI physically takes side route around box")
	await _capture("02_ai_corner")
	for i in 2400:
		if not ai_scene.driver.has_goal: break
		await physics_frame
	_check(ai_scene.driver.phase == "arrived" and ai_scene.target_actor.tank.global_position.distance_to(ai_scene.driver.goal) < 2,"real-time route completes by parking at goal")
	await _capture("03_ai_arrived")
	await _tap(KEY_4)
	_check(ai_scene.trial == 3 and ai_scene.driver.phase == "unreachable","normal case key displays actual narrow-road refusal")
	await _capture("04_narrow_rejected")
	await _tap(KEY_5)
	var saw_reverse := false
	for i in 600:
		if ai_scene.driver.phase == "reverse": saw_reverse = true; break
		await physics_frame
	_check(saw_reverse,"actual parked player vehicle makes AI reverse after bounded wait")
	await _capture("05_ai_reverse")
	for i in 2700:
		if not ai_scene.driver.has_goal: break
		await physics_frame
	_check(ai_scene.driver.phase == "arrived" and ai_scene.driver.attempts > 0,"AI replans after reverse and reaches goal without teleport")
	await _capture("06_recovery_arrived")
	await _tap(KEY_TAB)
	_check(not ai_scene.watching and ai_scene.source_actor.cam_rig.cam.current and ai_scene.target_actor.controller == ai_scene.driver,"normal Tab drives player vehicle while AI ownership stays independent")
	var ai_before := ai_scene.target_actor.tank.global_position
	var player_before := ai_scene.source_actor.tank.global_position
	await _key(KEY_W,true)
	await _frames(45)
	await _key(KEY_W,false)
	_check(ai_scene.source_actor.tank.global_position.distance_to(player_before) > 0.5 and ai_scene.target_actor.tank.global_position.distance_to(ai_before) < 0.1,"normal W moves player only after AI has parked")
	await _tap(KEY_ESCAPE)
	_check(paused,"normal menu pauses AI laboratory")
	await _click(ai_scene.hud._training_btn)
	_check(app.garage != null and app.training == null and not paused,"normal return frees AI trial and keeps garage usable")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("AI_DRIVE_PLAYER_CHECKS_PASS" if failed == 0 else "AI_DRIVE_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
