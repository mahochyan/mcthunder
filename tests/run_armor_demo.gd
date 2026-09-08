extends SceneTree
## Real rendered captures + input fire + natural reload. No direct try_fire or cooldown writes.
var saved := 0
var failed := 0
var shot_dir := "res://docs/evidence/007/demo"
var range_scene: ArmorRange

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1 < args.size():
			shot_dir = args[i+1]
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + message)
	if not ok:
		failed += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(shot_dir.path_join(name + ".png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	_check(err == OK and not img.is_empty(),"captured " + name)
	if err == OK:
		saved += 1
	print("[capture] %s contact=%s active=%d shots=%d ammo=%d" % [
		name, str(range_scene.last_contact), range_scene.projectiles.active_count(),
		range_scene.actor.gunner.shot_id,range_scene.actor.gunner.rounds_remaining])

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(40)
	if not main._paused:
		await _key(KEY_ESCAPE)
	await _frames(4)
	_check(main._paused,"Esc opens actual pause menu")
	var button: Button = main.hud.armor_training_button
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		Input.parse_input_event(click)
		await _frames(2)
	await _frames(12)
	range_scene = current_scene as ArmorRange
	_check(range_scene != null,"real mouse menu click enters Armor Range")
	if range_scene == null:
		quit(1)
		return
	# Input release gate discards the menu click; initial turret tracking is natural.
	await _frames(60)
	_check(range_scene.actor.gunner.shot_id == 0,"menu click did not fire a shot")
	await _capture("00_ready")
	var expected := ["penetrated","stopped","stopped","stopped","ricochet","unknown_armor"]
	for i in 6:
		await _key(KEY_1 + i as Key)
		await _frames(4)
		for wait_i in 240:
			if range_scene.actor.gunner.cooldown_left <= 0 and range_scene.actor.gunner.resume_grace <= 0:
				break
			await process_frame
		var before := range_scene.actor.gunner.shot_id
		# Aim through the same mouse-motion path as a player, with finite turret tracking.
		for aim_pass in 3:
			var cam_pos := range_scene.actor.cam_rig.cam.global_position
			var aim_delta := Vector3(0,2.5,-30) - cam_pos
			var yaw := atan2(-aim_delta.x,-aim_delta.z)
			var pitch := atan2(aim_delta.y,Vector2(aim_delta.x,aim_delta.z).length())
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(
				-(yaw-range_scene.actor.cam_rig.aim_yaw)/GameConfig.MOUSE_SENS,
				-(pitch-range_scene.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
			Input.parse_input_event(motion)
			await _frames(25)
		await _frames(2)
		var fire := InputEventMouseButton.new()
		fire.button_index = MOUSE_BUTTON_LEFT
		fire.pressed = true
		Input.parse_input_event(fire)
		await _frames(3)
		fire = InputEventMouseButton.new()
		fire.button_index = MOUSE_BUTTON_LEFT
		fire.pressed = false
		Input.parse_input_event(fire)
		for wait_i in 240:
			if not range_scene.last_contact.is_empty():
				break
			await process_frame
		_check(range_scene.actor.gunner.shot_id == before+1,"one real input shot for case%d" % (i+1))
		_check(range_scene.last_contact.get("result","") == expected[i],"case%d actual result %s" % [i+1,expected[i]])
		await _frames(2)
		await _capture("%02d_%s" % [i+1,expected[i]])
	_check(range_scene.actor.gunner.rounds_remaining == range_scene.actor.gunner.weapon.initial_rounds-6,"six shots conserved ammunition through case changes")
	print("ARMOR_DEMO saved=%d failures=%d fps=%d" % [saved,failed,Engine.get_frames_per_second()])
	quit(0 if failed == 0 and saved == 7 else 1)
