extends "res://tests/run_drive_player_checks.gd"
var team: TeamRange
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	for i in 6:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	await _click(_find(app.garage,"4 对 4 占点"))
	team = app.training as TeamRange
	_check(team != null and team.team_ready,"normal garage button enters actual eight-vehicle point match")
	if team == null: quit(1); return
	await _capture("01_countdown")
	await _frames(190)
	_check(team.director.state.phase == "playing","real countdown starts match")
	var first_life := team.actor.life_id
	await _tap(KEY_ESCAPE)
	await _capture("02_pause_menu")
	await _click(_find(team.hud,"放弃当前车（扣30票）"))
	_check(team.actor.state.destroyed and team.waiting_panel.visible and team.director.state.tickets[1] == 270,"normal abandon menu produces one thirty-ticket loss and visible wait")
	await _capture("03_wait_and_lineup")
	await _tap(KEY_TAB)
	_check(team.spectator_index == 1 and team.spectator.current,"normal Tab switches friendly spectator view")
	for i in 600:
		if not team.respawn_button.disabled: break
		await physics_frame
	await _capture("04_ready_to_redeploy")
	await _click(team.respawn_button)
	_check(team.actor.life_id != first_life and not team.actor.state.destroyed and team.director.state.roster.A.spawns == 2,"normal redeploy button creates exactly one fresh playable life")
	await _capture("05_spawn_protection")
	await _key(KEY_W,true)
	await _frames(20)
	await _key(KEY_W,false)
	_check(not team.director.state.is_protected("A",team.actor.life_id) and team.actor.tank.forward_speed > 0,"normal driving cancels spawn protection and moves new life")
	# Observe real objective AI, without direct score/clock/position changes.
	for i in 6000:
		if team.director.state.capture_owner != 0 and mini(team.director.state.tickets[1],team.director.state.tickets[2]) < 260: break
		if team.director.state.phase == "finished": break
		await physics_frame
		if i%1200 == 0: print("TEAM_PROGRESS elapsed=",team.director.state.elapsed," capture=",team.director.state.capture_progress," tickets=",team.director.state.tickets)
	_check(team.director.state.capture_owner != 0,"actual objective AI reaches and captures central point")
	_check(mini(team.director.state.tickets[1],team.director.state.tickets[2]) < 260,"real combat and owned objective reduce live ticket totals")
	await _capture("06_live_point_and_tickets")
	print("TEAM_FINAL elapsed=",team.director.state.elapsed," tickets=",team.director.state.tickets," owner=",team.director.state.capture_owner," population=",team.combat_actors().size())
	if team.director.state.phase == "finished": await _click(team.return_button)
	elif team.waiting_panel.visible: await _click(_find(team.waiting_panel,"返回车库"))
	else:
		await _tap(KEY_ESCAPE)
		await _click(team.hud._training_btn)
	_check(app.garage != null and app.training == null,"normal return closes match and restores garage")
	await _capture("07_returned_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("TEAM_PLAYER_CHECKS_PASS" if failed == 0 else "TEAM_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
