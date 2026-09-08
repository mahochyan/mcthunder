extends "res://tests/run_drive_player_checks.gd"
var village: VillageRange
var held := {KEY_W:false,KEY_A:false,KEY_D:false}
func key_state(code: Key, pressed: bool) -> void:
	if held[code] == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func release_drive() -> void:
	for key in held: key_state(key,false)
func drive_to(point: Vector3, seconds: float = 25) -> bool:
	var reached := false
	for i in int(seconds*60):
		if village.actor.state.destroyed or village.director.state.phase != "playing": break
		var p := village.actor.tank.global_position
		var offset := (point-p)*Vector3(1,0,1)
		if offset.length()<3.5: reached = true; break
		var forward := VehiclePose.flat_forward(village.actor.tank.global_basis)
		var angle := wrapf(atan2(-offset.x,-offset.z)-atan2(-forward.x,-forward.z),-PI,PI)
		key_state(KEY_A,angle>deg_to_rad(2))
		key_state(KEY_D,angle<deg_to_rad(-2))
		key_state(KEY_W,absf(angle)<deg_to_rad(12))
		await physics_frame
	release_drive()
	await _frames(40)
	print("[normal keyboard route] target=",point," actual=",village.actor.tank.global_position," time=",village.director.state.elapsed," reached=",reached," destroyed=",village.actor.state.destroyed)
	return reached
func look(yaw: float, pitch: float = -0.12) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(wrapf(village.actor.cam_rig.aim_yaw-yaw,-PI,PI),village.actor.cam_rig.aim_pitch-pitch)/GameConfig.MOUSE_SENS
	Input.parse_input_event(motion)
	await _frames(15)
func enter() -> void:
	for i in 6:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	await _click(_find(app.garage,"4 对 4 占点"))
	village = app.training as VillageRange
	_check(village != null,"normal garage click enters the authored hill village")
	await _frames(190)
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	await enter()
	await _capture("01_village_spawn")
	_check(await drive_to(Vector3(-72,0,116)),"normal keyboard leaves spawn for west gate")
	await look(0)
	_check(await drive_to(Vector3(-72,0,67)),"normal front-route drive passes the visible spawn screen")
	await _capture("02_front_140m_lane")
	await drive_to(Vector3(-72,0,50),10)
	await drive_to(Vector3(-42,0,20),12)
	await look(-0.7)
	await _capture("03_front_approach_or_combat_loss")
	await _tap(KEY_ESCAPE)
	await _click(village.hud._training_btn)
	_check(app.garage != null,"normal front-route session returns through pause menu")
	await enter()
	_check(await drive_to(Vector3(-72,0,116)),"second normal match starts from a new spawn")
	_check(await drive_to(Vector3(-120,0,65)),"keyboard chooses the longer western flank")
	await look(0)
	await _capture("04_flank_hill_approach")
	var climbed := await drive_to(Vector3(-120,0,0),25)
	_check(climbed and village.actor.tank.global_position.y>6,"normal player command chain climbs the 6.8m western hill")
	await look(-PI/2,-0.08)
	await _capture("05_hill_overlooks_village")
	root.size = Vector2i(1920,1080)
	await _frames(8)
	await _capture("06_hill_1080p")
	await look(0)
	await drive_to(Vector3(-120,0,-65),25)
	await _capture("07_far_flank_or_combat_loss")
	await _tap(KEY_ESCAPE)
	await _click(village.hud._training_btn)
	_check(app.garage != null and app.training == null,"flank session returns through actual scene cleanup")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("VILLAGE_PLAYER_CHECKS_PASS" if failed == 0 else "VILLAGE_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
