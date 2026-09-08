extends Node
var count := 0
var failed := 0
var app: AppFlow
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame
func run(flow: AppFlow) -> void:
	app = flow
	get_tree().root.size = Vector2i(1280,720)
	check(not OS.has_feature("editor"),"T019-H02 executable is an actual export template, not the editor")
	check(not FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("project.godot")),"independent executable directory has no source project fallback")
	var license_path := OS.get_executable_path().get_base_dir().path_join("GODOT_LICENSES.txt")
	var license_file := FileAccess.open(license_path,FileAccess.WRITE)
	if license_file != null:
		license_file.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
		license_file.close()
	check(license_file != null,"candidate includes engine copyright and third-party license notices")
	await frames(8)
	check(app.garage != null and CoreUI.FONT.has_char(0x4E2D),"export loads ordinary garage and bundled Chinese glyphs")
	app.enter_laboratory("team")
	await frames(195)
	var scene := app.training as VillageRange
	check(scene != null and scene.team_ready and scene.combat_actors().size() == 8,"export dynamically loads village and eight actors")
	if scene == null: finish(); return
	check(scene.nav.valid and scene.actor.gunner.shell.id == "team_ap120" and scene.actor.gunner.rounds_remaining == 30,"bundled navigation, shell and loadout are present")
	var p := scene.actor.tank.global_position
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_W
		event.physical_keycode = KEY_W
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(20)
	check(scene.actor.tank.global_position.distance_to(p)>0.5 and scene.actor.controller == scene.controller and scene.actor.cam_rig.cam.current,"export consumes ordinary input with only the player's live vehicle camera")
	var user_path := "user://smoke_019_%d.tmp"%Time.get_ticks_usec()
	var file := FileAccess.open(user_path,FileAccess.WRITE)
	var saved := file != null
	if file != null: file.store_string("PixelArmor export path check"); file.close()
	check(saved and FileAccess.get_file_as_string(user_path) == "PixelArmor export path check","export has a writable application user-data directory")
	if saved: DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path))
	print("[user data] ",OS.get_user_data_dir())
	var original := scene.get_round_id()
	app.restart_match()
	await frames(8)
	check(app.training is VillageRange and app.training.get_round_id()!=original,"export can start another independent village match")
	app.return_to_garage()
	await frames(8)
	check(app.training == null and app.garage != null,"export returns to normal garage and frees battle")
	finish()
func finish() -> void:
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("EXPORT_CHECKS_PASS" if failed == 0 else "EXPORT_CHECKS_FAIL")
	get_tree().quit(0 if failed == 0 else 1)
