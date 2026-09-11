extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 4) -> void:
	for i in n: await physics_frame
	await process_frame
func action(name: String, down: bool) -> void:
	var e := InputEventAction.new(); e.action = name; e.pressed = down
	Input.parse_input_event(e)
	await frames()
func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("FREE_LOOK_CHECKS requires a real window for captured mouse input")
		quit(1); return
	InputBindingService.initialize()
	var scene := AICombatRange.new()
	root.add_child(scene); current_scene = scene
	scene.target_actor.set_controller(null)
	await frames(30)
	var actor := scene.source_actor
	var cam := actor.cam_rig
	var aim := Vector2(cam.aim_yaw,cam.aim_pitch)
	await action("free_look",true)
	var turret_angle := actor.turret.rotation.y
	var pitch := actor.turret.barrel_pivot.rotation.x
	var camera_basis := cam.cam.global_basis
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new(); motion.relative = Vector2(160,-40)
	Input.parse_input_event(motion)
	await frames(30)
	check(cam.free_look and not cam.cam.global_basis.is_equal_approx(camera_basis),"real observation input rotates the camera")
	check(is_equal_approx(actor.turret.rotation.y,turret_angle) and is_equal_approx(actor.turret.barrel_pivot.rotation.x,pitch),"observation keeps both turret axes stationary")
	check(actor.gunner.shots_fired==0,"looking around does not fire")
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var shot_path := args[0] if not args.is_empty() else "res://logs/rc3-free-look.png"
	check(root.get_texture().get_image().save_png(shot_path)==OK,"actual observation screenshot is saved")
	await action("aim",true)
	check(not cam.sight,"free observation takes precedence over held gun sight")
	await action("free_look",false)
	check(not cam.free_look and cam.sight and Vector2(cam.aim_yaw,cam.aim_pitch).is_equal_approx(aim),"release restores original aim and held gun sight")
	await action("aim",false)
	await action("free_look",true)
	scene.controller.commands_enabled = false
	await frames()
	check(not cam.free_look,"opening a modal cancels observation")
	await action("free_look",false)
	scene.controller.commands_enabled = true
	await action("free_look",true)
	actor.reset_vehicle()
	check(not cam.free_look,"vehicle reset clears observation immediately")
	await action("free_look",false)
	# Exercise the actual old-settings reader, isolated from user preferences.
	var path := "user://tests/free-look-settings-"+str(Time.get_ticks_usec())+".json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var old := InputBindingService.bindings.duplicate()
	old.erase("free_look")
	old.fire = KEY_B
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":2,"bindings":old,"accessibility":AccessibilitySettings.DEFAULTS,"display":InputBindingService.DISPLAY_DEFAULT,"language":"zh_CN"})); file.close()
	var loaded := InputBindingService.read_settings(path)
	check(loaded.ok and loaded.data.bindings.fire==KEY_B and loaded.data.bindings.free_look!=KEY_B,"old settings migrate without stealing an occupied key")
	DirAccess.remove_absolute(path)
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("FREE_LOOK_CHECKS_PASS" if failed==0 else "FREE_LOOK_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
