extends SceneTree
## External harness: intentionally excluded from the distributed PCK/ZIP.
var checks := 0
var failed := 0
var app: AppFlow
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int=8) -> void:
	for i in n: await physics_frame
	await process_frame
func idle() -> void:
	for i in 1200:
		await process_frame
		if not app._transitioning: return
	check(false,"bounded transition")
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: print("RELEASE_CHECK_TIMEOUT"); quit(2))
	check(OS.has_feature("release") and not OS.has_feature("editor"),"T031-01 actual Windows release template")
	var install := OS.get_executable_path().get_base_dir()
	check(not FileAccess.file_exists(install.path_join("project.godot")),"T031-01 independent installation has no source fallback")
	for forbidden in ["res://tests/run_release_checks.gd","res://tests/run_checks.gd","res://AGENTS.md","res://docs/PROJECT_PROGRESS.json","res://authoring/vehicles/us_m4a3_75w_vvss_1944.blend"]:
		check(not FileAccess.file_exists(forbidden),"T031-02 excluded development file: "+forbidden)
	check(FileAccess.file_exists("res://assets/fonts/OFL.txt") and CoreUI.FONT.has_char(0x4e2d),"T031-01 Chinese glyphs and font license present")
	check(FileAccess.file_exists(install.path_join("GODOT_LICENSES.txt")) and FileAccess.file_exists(install.path_join("FONT_OFL.txt")),"T031-02 engine and font notices beside executable")
	var defs:=VehicleDefs.new(); defs.load_defaults()
	check(VehicleCatalog.new().load_all(defs).ok,"T031-01 four historical content packages admitted")
	for id in VehicleCatalog.IDS: check(AssetManifestValidator.vehicle(id).ok,"T031-01 relative GLB and palette: "+id)
	var audio: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	var audio_ok := audio.clips.size()==13
	for clip in audio.clips.values(): audio_ok = audio_ok and load(clip.path) is AudioStreamWAV
	check(audio_ok,"T031-01 all thirteen sound streams load")
	var user_folder := "user://tests/release031_%d" % Time.get_ticks_usec()
	InputBindingService.initialize(user_folder+"/input.json")
	app=load("res://scenes/app.tscn").instantiate(); app.profile=ProfileStore.new(user_folder+"/commander")
	root.add_child(app); current_scene=app; await idle(); await frames()
	check(app.garage!=null,"T031-01 default application opens usable garage")
	check(InputBindingService.apply_binding("fire",KEY_K).is_empty(),"T031-01 settings write into independent user directory")
	for index in MapRegistry.IDS.size():
		app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
		app.garage.preparation.map_choice.select(index)
		app.enter_laboratory("team"); await idle(); await frames(200)
		var battle := app.training as TeamRange
		check(battle!=null and battle.team_ready and battle.combat_actors().size()==8,"T031-01 garage enters complete map "+str(index))
		if battle==null: break
		var start := battle.actor.tank.global_position
		for pressed in [true,false]:
			var event:=InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=pressed; Input.parse_input_event(event); await frames(25)
		check(battle.actor.tank.global_position.distance_to(start)>0.5,"T031-01 ordinary keyboard drives live actor "+str(index))
		var shots := battle.actor.gunner.shots_fired
		for pressed in [true,false]:
			var event:=InputEventKey.new(); event.keycode=KEY_K; event.physical_keycode=KEY_K; event.pressed=pressed; Input.parse_input_event(event); await frames(4)
		check(battle.actor.gunner.shots_fired==shots+1,"T031-01 remapped key fires actual gun "+str(index))
		if DisplayServer.get_name()!="headless" and index==1:
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image()
			var captured:=picture.save_png(user_folder+"/release_battle.png")==OK
			check(captured,"T031-01 real release render captured")
			# Only the harness emits this controlled artifact path for the build script.
			if captured: print("RELEASE_CAPTURE="+ProjectSettings.globalize_path(user_folder+"/release_battle.png"))
		battle.leave_match(); await idle(); await frames()
		check(app.garage!=null and app.training==null,"T031-01 battle returns through normal navigation")
	for id in ChallengeCatalog.IDS:
		app.enter_challenge(id,"normal"); await idle(); await frames(10)
		check(app.training is ChallengeRange and app.training.challenge_ready,"T031-01 authored challenge opens: "+id)
		if app.training is ChallengeRange: app.training.leave_match(); await idle(); await frames()
	app.start_tutorial(0); await idle(); await frames(20)
	check(is_instance_valid(app.tutorial_guide) and not app.tutorial_guide.passed,"T031-01 real tutorial guide loaded without fabricated completion")
	app.return_to_garage(); await idle(); await frames()
	check(ProfileStore.new(user_folder+"/commander").snapshot().tutorial.chapter==0,"T031-01 chapter checkpoint reopens from actual disk")
	check(LocalizationService.missing.is_empty(),"T031-01 rendered paths contain no missing translation keys")
	app.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed==0: print("RELEASE_CHECKS_PASS")
	quit(0 if failed==0 else 1)
