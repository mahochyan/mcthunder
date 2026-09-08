extends SceneTree
## Actual menu, mouse aim, firing, control switch and reset; optional rendered evidence.
var failed := 0
var count := 0
var shot_dir := ""
var range_scene: DamageRange

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1 < args.size():
			shot_dir = args[i+1]
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] ") + message)
	if not ok: failed += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame

func _capture(name: String) -> void:
	if shot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(shot_dir.path_join(name+".png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(img.save_png(path) == OK and not img.is_empty(),"real capture " + name)
	print("[capture] %s state=%s damage=%s" % [name,range_scene.target_actor.state.damage_snapshot(),range_scene.damage_history])

func _key(code: Key, held: int = 2) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(held if pressed else 2)

func _fire_at(point: Vector3) -> void:
	var vehicle := range_scene.actor
	for i in 250:
		if vehicle.gunner.cooldown_left <= 0 and vehicle.gunner.resume_grace <= 0:
			break
		await physics_frame
	for i in 4:
		var d := point - vehicle.cam_rig.cam.global_position
		var yaw := atan2(-d.x,-d.z)
		var pitch := atan2(d.y,Vector2(d.x,d.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-(yaw-vehicle.cam_rig.aim_yaw)/GameConfig.MOUSE_SENS,
			-(pitch-vehicle.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion)
		await _frames(25)
	var before := vehicle.gunner.shot_id
	for pressed in [true,false]:
		var fire := InputEventMouseButton.new()
		fire.button_index = MOUSE_BUTTON_LEFT
		fire.pressed = pressed
		Input.parse_input_event(fire)
		await _frames(3)
	await _frames(30)
	_check(vehicle.gunner.shot_id == before+1,"mouse fire creates one actual projectile")
	print("[shot] point=%s damage=%s impact=%s" % [point,range_scene.damage_history,range_scene._last_impact])

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DAMAGE_PLAYER_CHECKS requires a window: captured mouse motion is unavailable headless; use run_damage_checks.gd for headless checks.")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(20)
	if not main._paused: await _key(KEY_ESCAPE)
	_check(main._paused,"Esc opens actual menu")
	var button: Button = main.hud.damage_training_button
	var pos := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		Input.parse_input_event(click)
		await _frames(2)
	await _frames(30)
	range_scene = current_scene as DamageRange
	_check(range_scene != null,"real menu click enters Damage Range")
	if range_scene == null:
		quit(1)
		return
	_check(range_scene.actor.gunner.shot_id == 0,"menu click cannot become a shot")
	await _capture("00_ready")
	await _fire_at(Vector3(-1.25,0.4,-28.1))
	_check(range_scene.target_actor.state.module_states.track_left.integrity == 0,"actual player shot destroys external left track")
	var ammo := range_scene.source_actor.gunner.rounds_remaining
	await _key(KEY_TAB)
	_check(range_scene.actor == range_scene.target_actor,"Tab transfers actual controller and camera to B")
	var pos_before := range_scene.actor.tank.global_position
	await _key(KEY_W,30)
	_check(range_scene.actor.tank.global_position.distance_to(pos_before)<0.01,"damaged B cannot drive with real held W")
	_check(range_scene.source_actor.gunner.rounds_remaining == ammo,"control switch conserves source ammo")
	await _capture("01_track_disabled_control_B")
	await _key(KEY_TAB)
	await _fire_at(Vector3(0,0.95,-29))
	_check(range_scene.target_actor.state.module_states.engine.integrity == 0,"real penetrated player shot reaches engine")
	await _capture("02_engine")
	await _fire_at(Vector3(0,1.57,-30.35))
	_check(range_scene.target_actor.state.module_states.breech.integrity == 0,"real aimed player shot destroys breech")
	await _key(KEY_TAB)
	var rounds := range_scene.actor.gunner.rounds_remaining
	await _frames(20)
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")
	_check(range_scene.actor.gunner.rounds_remaining == rounds and range_scene.actor.gunner.blocked_reason == "vehicle_disabled","damaged B rejects actual fire without spending ammo")
	await _capture("03_breech_control_B")
	await _key(KEY_ESCAPE)
	_check(paused,"damage training pauses")
	var snapshot := range_scene.target_actor.state.damage_snapshot()
	await _frames(10)
	_check(snapshot == range_scene.target_actor.state.damage_snapshot(),"pause leaves damage unchanged")
	await _key(KEY_ESCAPE)
	await _key(KEY_R)
	_check(range_scene.target_actor.state.module_states.engine.integrity == 100 and range_scene.target_actor.capabilities().fire,"R restores both actual vehicles")
	_check(range_scene.projectiles.active_count() == 0 and range_scene.damage_history.is_empty(),"R clears projectiles and damage feedback")
	await _capture("04_reset")
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,failed])
	print("DAMAGE_PLAYER_CHECKS_PASS" if failed == 0 else "DAMAGE_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
