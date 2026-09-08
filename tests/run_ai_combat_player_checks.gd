extends "res://tests/run_drive_player_checks.gd"
var combat: AICombatRange
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	for i in 15:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	await _capture("00_combat_entry")
	await _click(_find(app.garage,"电脑交战实验室"))
	combat = app.training as AICombatRange
	_check(combat != null and combat.combat_ready,"normal garage button enters combat laboratory")
	if combat == null: quit(1); return
	await _tap(KEY_1)
	_check(combat.level == "easy" and combat.target_actor.controller == combat.ai,"normal difficulty key restarts actual AI")
	await _capture("01_hidden_start")
	_check(combat.ai.observation.is_empty() and combat.target_actor.gunner.shots_fired == 0,"normal hidden start has no target lock or shots")
	var player := combat.source_actor
	await _key(KEY_D,true)
	for i in 100:
		if absf(wrapf(player.tank.global_rotation.y,-PI,PI)) > deg_to_rad(87): break
		await physics_frame
	await _key(KEY_D,false)
	var saw_visible := false
	for attempt in 55:
		await _key(KEY_W,true)
		await _frames(9)
		await _key(KEY_W,false)
		await _frames(15)
		if combat.ai.observation.get("visible",false): saw_visible = true; break
	_check(saw_visible,"AI sees normally driven exposed hull")
	await _capture("02_exposed_observed")
	await _key(KEY_S,true)
	for i in 300:
		if absf(player.tank.global_position.x) < 1: break
		await physics_frame
	await _key(KEY_S,false)
	await _frames(30)
	_check(absf(player.tank.global_position.x) < 3,"normal reverse returns player behind cover")
	_check(not combat.ai.observation.get("visible",false),"AI loses line of sight after normal retreat")
	await _capture("04_hidden_search")
	await _key(KEY_W,true)
	for i in 300:
		if absf(player.tank.global_position.x) > 12: break
		await physics_frame
	await _key(KEY_W,false)
	for i in 900:
		if combat.target_actor.gunner.shots_fired > 0: break
		await physics_frame
	_check(combat.target_actor.gunner.shots_fired > 0,"sustained normal exposure makes AI fire actual gun")
	await _capture("05_ai_shot")
	var lifetime_shots := combat.target_actor.gunner.shots_fired
	await _tap(KEY_R)
	_check(combat.target_actor.gunner.shots_fired == lifetime_shots and combat.ai.observation.is_empty() and combat.round_shots_start == lifetime_shots,"normal restart clears memory and round count while preserving lifetime launch identity")
	await _tap(KEY_ESCAPE)
	_check(paused,"normal menu pauses combat")
	await _click(combat.hud._training_btn)
	_check(app.garage != null and app.training == null and not paused,"normal return releases combat actors")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("AI_COMBAT_PLAYER_CHECKS_PASS" if failed == 0 else "AI_COMBAT_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
