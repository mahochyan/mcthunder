extends SceneTree
var scene: CoreRange
var app: AppFlow
var count := 0
var failed := 0
var shot_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1<args.size(): shot_dir = args[i+1]
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)

func _frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame

func _key(code: Key) -> void:
	for pressed in [true,false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		await _frames(2)

func _click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		Input.parse_input_event(click)
		await _frames(2)
	await _frames(20)

func _fire(point: Vector3) -> Dictionary:
	for i in 240:
		if scene.actor.gunner.cooldown_left<=0 and scene.actor.gunner.resume_grace<=0: break
		await physics_frame
	for i in 4:
		var d := point-scene.actor.cam_rig.cam.global_position
		var yaw := atan2(-d.x,-d.z)
		var pitch := atan2(d.y,Vector2(d.x,d.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-(yaw-scene.actor.cam_rig.aim_yaw)/GameConfig.MOUSE_SENS,-(pitch-scene.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion)
		await _frames(25)
	var shots := scene.actor.gunner.shot_id
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await _frames(3)
	await _frames(30)
	_check(scene.actor.gunner.shot_id == shots+1,"one normal mouse shot creates one projectile")
	_check(scene.replay.view.visible,"actual completed shot opens corner replay")
	return scene.projectiles.shot_records.get_record(scene.projectiles.shot_records.count()-1)

func _capture(name: String) -> void:
	if shot_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(shot_dir.path_join(name+".png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(image.save_png(path) == OK and not image.is_empty(),"real replay capture "+name)
	print("[capture] "+name)


func _choose(option: OptionButton, index: int) -> void:
	await _click(option)
	var popup := option.get_popup()
	var position := Vector2(popup.position)+Vector2(popup.size.x*0.5,4+(popup.size.y-8.0)/option.item_count*(index+0.5))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(5)
	print("[popup choice] requested=%d selected=%d visible=%s" % [index,option.selected,popup.visible])
func _button_text(node: Node, value: String) -> Button:
	if node is Button and node.text == value: return node
	for child in node.get_children():
		var found := _button_text(child,value)
		if found != null: return found
	return null

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	await _frames(30)
	_check(app.garage != null,"normal project start opens Chinese garage")
	await _capture("01_garage")
	await _click(app.garage.inspect_button)
	_check(app.garage.preview.mode == "armor","real preview button shows actual armor")
	await _capture("02_armor_inspection")
	await _click(app.garage.inspect_button)
	_check(app.garage.preview.mode == "interior","real preview button shows modules and crew")
	await _choose(app.garage.shell_choice,0)
	_check(app.garage.shell_choice.selected == 0,"normal selector chooses AP70")
	var spin_rect := app.garage.rounds.get_global_rect()
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = spin_rect.position+Vector2(spin_rect.size.x-8,spin_rect.size.y*0.25)
		click.pressed = pressed
		Input.parse_input_event(click)
		await _frames(2)
	_check(app.garage.rounds.value == 11,"normal spinbox changes carried ammunition")
	for index in 7:
		await _choose(app.garage.case_choice,index)
		await _click(app.garage.start_button)
		scene = app.training as CoreRange
		_check(scene != null and scene.lesson == index,"normal garage entry starts lesson %d" % index)
		if scene == null: quit(1); return
		_check(scene.source_actor.gunner.shell.id == "training_ap70" and scene.source_actor.gunner.rounds_remaining == 11,"actual loadout retained across entry")
		var record := await _fire(scene.target_point())
		if index == 5:
			_check(scene.target_actor.state.module_states.track_left.integrity == 0 and scene.director.status == "running","repair lesson waits for actual repair after hit")
			await _key(KEY_TAB)
			await _key(KEY_T)
			await _frames(120)
			_check(scene.actor.state.recovery_action == "repair","normal T begins stationary repair")
			await _capture("08_repair_progress")
			for i in 900:
				if scene.director.status != "running": break
				await physics_frame
		_check(scene.director.status == "passed","lesson %d completes from actual shot/state: %s" % [index,scene.director.status])
		_check(not record.is_empty() and scene.director.last_record.record_id == record.record_id,"explanation cites the actual completed projectile")
		print("[lesson %d] %s" % [index,scene.director.explanation])
		if index != 5:
			await _key(KEY_N)
			await _capture("%02d_lesson_%d_replay" % [index+3,index])
		await _key(KEY_ENTER)
		_check(app.result_overlay != null and paused,"Enter opens Chinese result screen with paused world")
		if index == 2: await _capture("06_result_engine")
		var back := _button_text(app.result_overlay,"返回车库")
		_check(back != null,"result has reachable return-to-garage control")
		await _click(back)
		_check(app.garage != null and app.training == null and not paused,"return to garage fully releases training")
		_check(app.garage.shell_choice.selected == 0 and app.garage.case_choice.selected == index,"garage preserves loadout and lesson selection")
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,failed])
	print("[render] fps=%d physics_tps=%d" % [Engine.get_frames_per_second(),Engine.physics_ticks_per_second])
	print("CORE_PLAYER_CHECKS_PASS" if failed == 0 else "CORE_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

