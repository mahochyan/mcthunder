extends "res://tests/run_drive_player_checks.gd"
var duel: DuelRange

func turn_to(angle: float) -> void:
	var vehicle := duel.source_actor.tank
	for i in 180:
		var diff := wrapf(angle-vehicle.global_rotation.y,-PI,PI)
		if absf(diff)<deg_to_rad(2): break
		await _key(KEY_A if diff>0 else KEY_D,true)
		await _frames(1)
		await _key(KEY_A if diff>0 else KEY_D,false)
	await _frames(5)

func fire_at(point: Vector3, follow: Callable = Callable()) -> void:
	for i in 300:
		if duel.source_actor.gunner.cooldown_left <= 0 or duel.match_director.phase == "finished": break
		await physics_frame
	if duel.match_director.phase != "playing": return
	var scope := InputEventMouseButton.new()
	scope.button_index = MOUSE_BUTTON_RIGHT
	scope.pressed = true
	Input.parse_input_event(scope)
	await _frames(4)
	for i in 100:
		if duel.match_director.phase != "playing": break
		var aim: Vector3 = follow.call() if follow.is_valid() else point
		var origin := duel.source_actor.turret.barrel_pivot.global_position
		var travel := origin.distance_to(aim)/duel.source_actor.gunner.shell.muzzle_velocity_mps
		aim += Vector3.UP*0.5*9.81*travel*travel-duel.source_actor.tank.velocity*travel
		var d := aim-origin
		var yaw := atan2(-d.x,-d.z)
		var pitch := atan2(d.y,Vector2(d.x,d.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-wrapf(yaw-duel.source_actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(pitch-duel.source_actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion)
		await _frames(3)
		if duel.source_actor.turret.barrel_direction().dot((aim-duel.source_actor.turret.muzzle.global_position).normalized())>cos(deg_to_rad(0.2)): break
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await _frames(3)
	await _frames(20)
	scope = InputEventMouseButton.new()
	scope.button_index = MOUSE_BUTTON_RIGHT
	scope.pressed = false
	Input.parse_input_event(scope)
	await _frames(3)

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	for i in 5:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	await _capture("00_duel_garage")
	await _click(_find(app.garage,"1 对 1 歼灭（工程夹具）"))
	duel = app.training as DuelRange
	_check(duel != null and duel.duel_ready,"normal garage opens complete duel")
	if duel == null: quit(1); return
	await _capture("01_countdown")
	await _frames(190)
	_check(duel.match_director.phase == "playing","normal countdown enters real combat")
	for i in 1200:
		if duel.ai.observation.get("visible",false): break
		await physics_frame
	# Aim through real mouse motion at the exposed turret before making the flank run.
	await fire_at(Vector3.ZERO,func() -> Vector3: return duel.target_actor.turret.global_transform*Vector3(-0.46,0.36,-0.2))
	await fire_at(Vector3.ZERO,func() -> Vector3: return duel.target_actor.turret.barrel_pivot.global_position)
	await _capture("01b_frontal_engagement")
	await turn_to(PI/2)
	await _key(KEY_W,true)
	for i in 300:
		if duel.source_actor.tank.global_position.x < -18: break
		await physics_frame
	await turn_to(0)
	for i in 400:
		if duel.source_actor.tank.global_position.z < -8: break
		await physics_frame
	await _key(KEY_W,false)
	await _frames(80)
	print("FLANK player=",duel.source_actor.tank.global_position," enemy=",duel.target_actor.tank.global_position," own=",duel.source_actor.capabilities())
	_check(duel.source_actor.tank.global_position.x < -20 and duel.source_actor.tank.global_position.z < -8,"normal W/A/D drives outside cover onto flank")
	await _capture("02_flank")
	for i in 8:
		if duel.match_director.phase != "playing": break
		await fire_at(Vector3.ZERO,func() -> Vector3: return duel.target_actor.tank.global_transform*Vector3(0.72,1.05,0.55))
		print("SHOT ",i," phase=",duel.match_director.phase," player=",duel.source_actor.tank.global_position," enemy=",duel.target_actor.tank.global_position," last=",duel.source_actor.gunner.last_shot_result," damage_events=",duel.damage_history.size()," own=",duel.source_actor.capabilities())
	_check(duel.match_director.phase == "finished" and duel.match_director.result.outcome == "victory","normal mouse shots from flank produce actual victory")
	await _capture("03_victory_result")
	if duel.match_director.phase != "finished":
		await _tap(KEY_ESCAPE)
		await _click(duel.hud._training_btn)
		print("DUEL_PLAYER_CHECKS_FAIL")
		quit(1)
		return
	_check(duel.result_panel.visible and duel.match_director.result.totals.A.shots > 0 and duel.match_director.result.totals.B.deaths == 1,"result summarizes real shots and unique death")
	var first_life := duel.source_actor.life_id
	await _click(duel.restart_button)
	duel = app.training as DuelRange
	_check(duel != null and duel.source_actor.life_id > first_life and duel.match_director.phase == "countdown","normal result button starts a fresh round")
	await _frames(190)
	await turn_to(-PI/2)
	await _key(KEY_W,true)
	for i in 260:
		if duel.source_actor.tank.global_position.x > 10: break
		await physics_frame
	await _key(KEY_W,false)
	for i in 3600:
		if duel.match_director.phase == "finished": break
		await physics_frame
	_check(duel.match_director.phase == "finished" and duel.match_director.result.outcome == "defeat","sustained exposure lets actual AI shots and fire produce player defeat")
	await _capture("04_defeat_result")
	if duel.match_director.phase == "finished":
		await _click(duel.return_button)
	else:
		await _tap(KEY_ESCAPE)
		await _click(duel.hud._training_btn)
	_check(app.garage != null and app.training == null,"normal return from battle restores garage")
	await _frames(120)
	await _capture("05_returned_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("DUEL_PLAYER_CHECKS_PASS" if failed == 0 else "DUEL_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
