extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1
	print(("[PASS] " if value else "[FAIL] ")+label)
func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event)
	await frames(3)
func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
	Input.parse_input_event(event)
	await frames(3)
func run() -> void:
	var path := "user://tests/input027_"+str(Time.get_ticks_usec())+"/settings.json"
	InputBindingService.initialize(path)
	check(InputBindingService.hint("fire") == "鼠标左键","default fire hint uses actual service mapping")
	check(not InputBindingService.apply_binding("fire",KEY_W).is_empty(),"driving/fire conflict rejected")
	check(not InputBindingService.apply_binding("fire",KEY_ESCAPE).is_empty(),"Esc cannot be consumed by firing")
	check(not InputBindingService.apply_binding("fire",0).is_empty(),"invalid key rejected")
	check(InputBindingService.apply_binding("fire",KEY_K).is_empty(),"new fire key saved")
	InputBindingService.initialized = false
	InputBindingService.initialize(path)
	check(InputBindingService.bindings.fire == KEY_K and InputBindingService.problem.is_empty(),"saved bindings restore through production loader")
	var scene := ChallengeRange.new()
	root.add_child(scene); current_scene = scene
	await frames(220)
	check(scene.challenge_ready and scene.actor.gunner.shots_fired == 0,"real challenge starts without accidental menu shot")
	await mouse(true); await mouse(false)
	check(scene.actor.gunner.shots_fired == 0,"old mouse fire key no longer fires")
	await key(KEY_K,true); await key(KEY_K,false)
	check(scene.actor.gunner.shots_fired == 1,"new key fires exactly one real projectile")
	await frames(420)
	scene._pause()
	var panel := InputSettingsPanel.new()
	scene.hud.add_child(panel)
	panel.begin_capture("fire")
	await frames(2)
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(is_instance_valid(panel) and panel.pending_action.is_empty() and InputBindingService.bindings.fire == KEY_K,"Esc cancels capture without changing existing binding")
	check(scene._paused and scene.actor.gunner.shots_fired == 1,"cancel stays in paused settings without firing")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not is_instance_valid(panel) and scene._paused,"Esc closes input panel without resuming battle")
	InputBindingService.restore_defaults()
	check(InputMap.action_get_events("fire")[0] is InputEventMouseButton,"restore default reinstates mouse binding")
	scene._resume(); await frames(10)
	await key(KEY_K,true); await key(KEY_K,false)
	check(scene.actor.gunner.shots_fired == 1,"restored mapping removes custom key")
	await mouse(true); await mouse(false)
	check(scene.actor.gunner.shots_fired == 2,"default mouse fires real gun after restoration")
	scene.free(); await frames(3)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken"); file.close()
	InputBindingService.initialized = false
	InputBindingService.initialize(path)
	check(not InputBindingService.problem.is_empty() and InputBindingService.bindings.fire == -1,"corrupt settings restore safe defaults with visible error")
	OS.delay_msec(100)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("INPUT_BINDING_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
