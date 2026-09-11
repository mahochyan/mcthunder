extends "res://tests/run_drive_player_checks.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1280,720)
	scene=load("res://scenes/training/terrain_range.tscn").instantiate()
	root.add_child(scene); current_scene=scene
	await _frames(20)
	_check(scene.ready_drive,"actual terrain laboratory ready")
	# Explicit physical ledge fixture; subsequent driving uses real keyboard input.
	TerrainFixtures.box(scene,Vector3(0,0.5,4),Vector3(12,1,10))
	scene.source_actor.reset_vehicle()
	scene.source_actor.tank.global_position=Vector3(0,1.05,4)
	await _frames(20)
	var tank := scene.source_actor.tank
	_check(tank.is_on_floor(),"vehicle supported on physical one-metre ledge")
	await _capture("01_ledge_start")
	await _key(KEY_W,true)
	var airborne := false
	var bounced := false
	var captured := false
	for tick in 360:
		await physics_frame
		if not tank.is_on_floor() and tank.global_position.z < -1: airborne=true
		if airborne and tank.landing.impacts>0 and tank.velocity.y>0:
			bounced=true
			await _capture("02_actual_landing_rebound")
			captured=true
			break
	await _key(KEY_W,false)
	_check(airborne and bounced and captured,"normal W drives off ledge and actual impact produces upward movement")
	await _frames(180)
	_check(tank.is_on_floor() and tank.landing.impacts==1 and absf(tank.velocity.y)<0.01,"landing settles without repeated impacts")
	await _capture("03_landing_settled")
	await _tap(KEY_ESCAPE)
	var pose := tank.global_transform
	await _frames(20)
	_check(paused and tank.global_transform==pose,"pause freezes post-impact vehicle")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("LANDING_PLAYER_CHECKS_PASS" if failed==0 else "LANDING_PLAYER_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
