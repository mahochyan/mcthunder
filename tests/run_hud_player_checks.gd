extends "res://tests/run_drive_player_checks.gd"
var team: TeamRange
func choose(option: OptionButton, index: int) -> void:
	await _click(option)
	var popup := option.get_popup()
	var point := Vector2(popup.position)+Vector2(popup.size.x*0.5,4+(popup.size.y-8.0)/option.item_count*(index+0.5))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		for i in 3: await process_frame
	await _frames(6)
func shoot() -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		for i in 2: await process_frame
func fits(ui: BattleHUD) -> bool:
	var viewport := Rect2(Vector2.ZERO,Vector2(root.size))
	var panels := [ui.header,ui.own_panel,ui.weapon_panel,ui.map_panel]
	for i in panels.size():
		if not viewport.encloses(panels[i].get_global_rect()): return false
		for j in range(i+1,panels.size()):
			if panels[i].get_global_rect().intersects(panels[j].get_global_rect()): return false
	return true
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
	_check(team != null and team.battle_ui != null,"normal garage entry builds the formal battle HUD")
	if team == null: quit(1); return
	var ui := team.battle_ui.overlay
	await _capture("01_hud_720p")
	_check(fits(ui),"720p main panels fit without overlap")
	await _frames(190)
	await shoot()
	await RenderingServer.frame_post_draw
	_check(team.actor.gunner.shots_fired == 1 and ui.view_model.ammo == team.actor.gunner.rounds_remaining,"normal mouse fire updates actual ammunition readout")
	_check(ui.view_model.cooldown == team.actor.gunner.cooldown_left and ui.aim_visible,"real reload and actual barrel marker are presented")
	await _capture("02_reload_and_barrel_marker")
	var fired := team.actor.gunner.shots_fired
	await _tap(KEY_TAB)
	_check(ui.scoreboard.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not team.controller.commands_enabled,"normal Tab opens battle status with visible cursor and no combat intent")
	await _capture("03_battle_status")
	await _click(ui.board_close_button)
	_check(not ui.scoreboard.visible and team.actor.gunner.shots_fired == fired and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"closing scoreboard by mouse cannot fire and restores capture")
	await _tap(KEY_ESCAPE)
	await _click(team.battle_ui.settings_button)
	await _click(ui.flashes_toggle)
	await _click(ui.contrast_toggle)
	await _click(ui.replay_toggle)
	await choose(ui.scale_choice,2)
	_check(AccessibilitySettings.ui_scale == 1.25 and AccessibilitySettings.reduce_flashes and AccessibilitySettings.high_contrast and not AccessibilitySettings.replay_enabled,"normal settings controls change large text, flash, contrast and replay preferences")
	await _capture("04_accessibility_settings")
	await _click(ui.settings_close_button)
	root.size = Vector2i(1920,1080)
	for i in 6: await process_frame
	await _click(team.hud.resume_btn)
	_check(fits(ui),"1080p large-font HUD remains inside the resized actual window")
	await _capture("05_hud_1080p_large")
	await _tap(KEY_ESCAPE)
	root.size = Vector2i(1280,720)
	for i in 6: await process_frame
	await _click(team.hud.resume_btn)
	_check(fits(ui),"returning to 720p preserves large-font layout")
	await _capture("06_hud_720p_large")
	await _tap(KEY_V)
	_check(not team.replay.view.visible and ui.notice.contains("关闭"),"disabled replay gives normal HUD feedback without opening an overlay")
	await _tap(KEY_ESCAPE)
	await _click(_find(team.hud,"放弃当前车（扣30票）"))
	_check(team.waiting_panel.visible and team.battle_ui.focus.mode == "respawn" and not team.controller.commands_enabled,"normal death opens lineup with correct input focus")
	await _capture("07_large_lineup")
	await _tap(KEY_TAB)
	_check(ui.scoreboard.visible and not team.waiting_panel.visible,"battle status replaces lineup instead of stacking clickable panels")
	await _capture("08_spectator_status")
	await _click(ui.board_close_button)
	await _tap(KEY_E)
	_check(team.waiting_panel.visible and team.spectator_index == 1,"closing status restores lineup and E changes friendly observation")
	for i in 600:
		if not team.respawn_button.disabled: break
		await physics_frame
	await _click(team.respawn_button)
	_check(not team.actor.state.destroyed and team.actor.gunner.shots_fired == 0 and team.battle_ui.focus.mode == "playing","normal redeploy restores new-life controls without a mouse-click shot")
	await _capture("09_redeployed_hud")
	await _tap(KEY_ESCAPE)
	await _click(team.hud._training_btn)
	_check(app.garage != null and app.training == null,"normal return cleans HUD and restores garage")
	await _capture("10_returned_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("HUD_PLAYER_CHECKS_PASS" if failed == 0 else "HUD_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
