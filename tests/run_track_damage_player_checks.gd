extends "res://tests/run_drive_player_checks.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1280,720)
	app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app); current_scene=app
	await _frames(25)
	await _click(_find(app.garage,"4 对 4 占点"))
	var team := app.training as TeamRange
	_check(team!=null,"normal garage click enters actual battle")
	if team==null: quit(1); return
	team.unattended_diagnostic=true
	for tick in 300:
		if team.director.state.phase=="playing" and team.controller.commands_enabled: break
		await _frames(1)
	_check(team.director.state.phase=="playing" and team.controller.commands_enabled,"normal pre-battle countdown enables controls")
	var actor := team.actor
	# Explicit damage event fixture; this test does not claim keyboard-directed aim/hit.
	var result := actor.apply_projectile_damage({"kind":"module","module_id":"track_left","entity_id":actor.entity_id,"life_id":actor.life_id,"event_id":"track_window","round_id":team.get_round_id()},120)
	_check(result.get("ok",false) and actor.state.module_states.track_left.integrity==0,"production damage fixture breaks player left track")
	await _frames(3)
	_check(team.battle_ui.overlay.view_model.drive_text.contains("低速调整车头"),"actual HUD displays single-track instruction")
	var start_yaw := actor.tank.global_rotation.y
	await _key(KEY_D,true); await _frames(90); await _key(KEY_D,false)
	_check(absf(angle_difference(start_yaw,actor.tank.global_rotation.y))>0.1 and absf(actor.tank.tracks.left_speed)<0.00001,"normal D changes heading with broken side stopped")
	await _capture("01_single_track_pivot")
	await _tap(KEY_T)
	_check(actor.state.recovery_action=="repair","normal T starts actual track repair")
	await _capture("02_track_repair")
	await _frames(730)
	_check(actor.state.module_states.track_left.integrity==50 and actor.capabilities().drive,"normal repair timer restores player mobility")
	_check(not team.battle_ui.overlay.view_model.drive_text.contains("低速调整车头"),"HUD removes restricted steering instruction after repair")
	await _key(KEY_W,true); await _frames(45); await _key(KEY_W,false)
	_check(actor.tank.forward_speed>0.5,"normal W accelerates after repaired track")
	await _capture("03_repaired_mobility")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TRACK_DAMAGE_PLAYER_CHECKS_PASS" if failed==0 else "TRACK_DAMAGE_PLAYER_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
