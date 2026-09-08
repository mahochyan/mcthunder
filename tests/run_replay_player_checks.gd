extends SceneTree
var scene: BallisticsRange
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
	print("[capture] %s record=%s highlight=%s point=%s" % [name,scene.replay.view.record.get("record_id",""),scene.replay.view.highlighted_items,scene.replay.view.current_position])

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("REPLAY_PLAYER_CHECKS requires a window")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(20)
	if not main._paused: await _key(KEY_ESCAPE)
	await _click(main.hud.armor_training_button)
	scene = current_scene as ArmorRange
	_check(scene != null,"actual pause menu enters armor replay lesson")
	if scene == null:
		quit(1)
		return
	var record := await _fire(Vector3(0,2.5,-30))
	_check(not record.is_empty() and record.contacts[0].result == "penetrated","normal thin-plate shot records actual penetration")
	await _key(KEY_N)
	_check(scene.replay.view.selected_event == 0,"N selects the actual contact")
	await _capture("01_penetrated")
	await _key(KEY_2)
	record = await _fire(Vector3(0,2.5,-30))
	_check(record.contacts[0].result == "stopped" and record.damage.is_empty(),"normal thick-plate shot records stop without internal damage")
	await _key(KEY_N)
	_check(scene.replay.view.current_position.distance_to(record.contacts[0].impact_point)<0.001,"unpenetrated replay stops at real armor contact")
	await _capture("02_stopped")
	await _key(KEY_5)
	record = await _fire(Vector3(0,2.5,-30))
	_check(record.contacts[0].result == "ricochet","normal sloped shot records ricochet")
	await _key(KEY_V)
	await _key(KEY_V)
	await _frames(185)
	_check(scene.replay.view.visible and scene.replay.view.current_position.distance_to(record.path.back().point_world)<0.001,"manual replay reaches actual reflected endpoint")
	await _capture("03_ricochet")
	_check(scene.actor.gunner.rounds_remaining == 27,"replay interactions and case selection do not replenish three spent rounds")
	await _key(KEY_ESCAPE)
	await _click(scene.hud.damage_training_button)
	scene = current_scene as DamageRange
	_check(scene != null and scene.projectiles.shot_records.count() == 0,"scene switch clears previous shot history")
	if scene == null:
		quit(1)
		return
	record = await _fire(Vector3(0,0.95,-29))
	_check(record.damage.size() == 1 and record.damage[0].item_id == "engine","normal vehicle shot records engine and no invented crew hit")
	for i in scene.replay.view.events.size():
		await _key(KEY_N)
		if scene.replay.view.events[scene.replay.view.selected_event].kind == "module": break
	_check(scene.replay.view.highlighted_items == ["module:engine"],"selected replay highlights actual damaged engine")
	await _capture("04_engine_selected")
	var frozen: Transform3D = record.frames[0].part_world_transforms.turret
	await _key(KEY_TAB)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-220,0)
	Input.parse_input_event(motion)
	await _frames(90)
	var damage_scene := scene as DamageRange
	_check(not damage_scene.target_actor.turret.global_transform.is_equal_approx(frozen),"normal mouse input rotates live target turret after hit")
	await _key(KEY_V)
	for i in scene.replay.view.events.size():
		await _key(KEY_N)
		if scene.replay.view.events[scene.replay.view.selected_event].kind == "module": break
	_check(scene.replay.view.record.frames[0].part_world_transforms.turret == frozen,"reopened replay retains hit-time target pose")
	await _capture("05_frozen_after_turret_moves")
	for i in 240:
		if damage_scene.source_actor.gunner.cooldown_left<=0: break
		await physics_frame
	var before := damage_scene.target_actor.state.damage_snapshot()
	var ammo := damage_scene.source_actor.gunner.inventory.snapshot()
	for i in 10:
		await _key(KEY_V)
		await _key(KEY_V)
	_check(before == damage_scene.target_actor.state.damage_snapshot() and ammo == damage_scene.source_actor.gunner.inventory.snapshot(),"ten normal open/replay cycles cannot change damage or ammunition")
	await _key(KEY_J)
	_check(scene.replay.last_export.get("ok",false),"J exports actual selected shot JSON")
	if scene.replay.last_export.get("ok",false):
		var decoded := ShotRecordCodec.decode(FileAccess.get_file_as_string(scene.replay.last_export.path))
		_check(decoded.ok and decoded.record.record_id == record.record_id,"exported record roundtrips to same shot identity")
	await _key(KEY_R)
	_check(scene.projectiles.shot_records.count() == 0 and scene.replay.view.record.is_empty() and not scene.replay.view.visible,"R clears replay buffer and generated display")
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,failed])
	print("[render] fps=%d physics_tps=%d" % [Engine.get_frames_per_second(),Engine.physics_ticks_per_second])
	print("REPLAY_PLAYER_CHECKS_PASS" if failed == 0 else "REPLAY_PLAYER_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
