extends SceneTree
var count := 0
var failed := 0
var app: AppFlow
var scene: TerrainRange
var shot_dir := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--shot-dir")
	if index >= 0 and index+1 < args.size(): shot_dir = args[index+1]
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frames(3)
func _tap(code: Key) -> void:
	await _key(code,true)
	await _key(code,false)
func _click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(4)
	await _frames(12)
func _find(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := _find(child,text)
		if found != null: return found
	return null
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(shot_dir.path_join(name+".png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(not image.is_empty() and image.save_png(path) == OK,"actual window capture "+name)
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(25)
	await _capture("01_m4_garage")
	await _click(_find(app.garage,"转右"))
	await _click(_find(app.garage,"转右"))
	await _capture("01b_m4_rear_quarter")
	await _click(_find(app.garage,"转左"))
	await _capture("01c_m4_side")
	# Reach lower laboratory controls through normal wheel scrolling.
	for i in 9:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await _frames(2)
	var button := _find(app.garage,"地形")
	_check(button != null and button.get_global_rect().get_center().y < 660,"terrain laboratory control reachable by scrolling")
	await _click(button)
	scene = app.training as TerrainRange
	_check(scene != null and scene.ready_drive,"normal garage click enters actual terrain laboratory")
	if scene == null: quit(1); return
	await _capture("02_route_start")
	await _key(KEY_W,true)
	await _frames(190)
	await _key(KEY_W,false)
	await _frames(180)
	var tank := scene.actor.tank
	print("[normal10] position=",tank.global_position," slope=",tank.ground_state.slope_deg)
	_check(tank.global_position.y > 0.5 and tank.ground_state.slope_deg > 5,"normal W climbs and coasts to rest on 10-degree ramp")
	await _capture("03_ten_degree")
	var stopped := tank.global_position
	await _frames(120)
	_check(tank.global_position.distance_to(stopped)<0.08,"normal released keys leave tank stationary on slope")
	await _key(KEY_S,true)
	await _frames(180)
	await _key(KEY_S,false)
	_check(tank.global_position.z > stopped.z+5,"normal S reverses down slope")
	await _tap(KEY_3)
	_check(scene.route == 2 and scene.source_actor.state.module_states.engine.integrity == 100,"normal route key starts explicit fresh 30-degree lesson")
	await _key(KEY_W,true)
	await _frames(250)
	await _key(KEY_W,false)
	_check(scene.actor.tank.global_position.z > -14.5 and scene.actor.tank.global_position.y < 1.5,"normal W cannot climb 30-degree rejection slope")
	await _capture("04_thirty_degree_block")
	await _tap(KEY_2)
	await _tap(KEY_TAB)
	_check(scene.actor == scene.target_actor,"normal Tab takes actual slope target control")
	await _frames(60)
	_check(scene.actor.tank.ground_state.slope_deg > 15,"controlled target remains supported by actual 20-degree ramp")
	await _capture("05_twenty_degree_target")
	await _tap(KEY_ESCAPE)
	_check(paused,"normal Escape pauses terrain physics")
	var pose := scene.actor.tank.global_transform
	await _frames(30)
	_check(scene.actor.tank.global_transform == pose,"pause freezes slope posture")
	await _click(scene.hud._training_btn)
	_check(app.garage != null and app.training == null and not paused,"normal menu returns from terrain to garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("[render] fps=%d"%Engine.get_frames_per_second())
	print("DRIVE_PLAYER_CHECKS_PASS" if failed == 0 else "DRIVE_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
