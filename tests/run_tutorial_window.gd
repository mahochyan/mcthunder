extends "res://tests/run_localization_window.gd"
## First two chapters use keyboard/mouse input in the real renderer.
func key_state(code: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
	Input.parse_input_event(event)
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: print("TUTORIAL_WINDOW_TIMEOUT"); quit(2))
	shot_dir="res://docs/evidence/028/window-720"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	InputBindingService.initialize("user://tests/tutorial_window_%d/input.json" % Time.get_ticks_usec())
	app=load("res://scenes/app.tscn").instantiate(); app.profile=ProfileStore.new("")
	root.add_child(app); current_scene=app; await frames(30)
	await capture("01_garage_tutorial_entry")
	await activate(find_button(app.garage,LocalizationService.text("tutorial_resume") % [0,TutorialCatalog.COUNT])); await frames(50)
	check(is_instance_valid(app.tutorial_guide) and app.tutorial_guide.chapter==0,"keyboard enters first interactive chapter")
	await capture("02_drive_instruction")
	var core := app.training as CoreRange
	var forward := false
	var reverse := false
	for tick in 1200:
		var distance: float = core.actor.tank.global_position.z-app.tutorial_guide.goal.z
		var speed := core.actor.tank.forward_speed
		var want_forward := distance>1.8 and speed<2.0
		var want_reverse := distance<=1.8 and speed>0.2
		if want_forward!=forward: key_state(KEY_W,want_forward); forward=want_forward
		if want_reverse!=reverse: key_state(KEY_S,want_reverse); reverse=want_reverse
		await physics_frame
		if app.tutorial_guide.passed: break
	key_state(KEY_W,false); key_state(KEY_S,false); await frames(5)
	check(app.tutorial_guide.passed and 0 in app.profile.snapshot().tutorial.completed,"real keyboard driving and braking completes chapter")
	check(core.actor.gunner.shots_fired==0,"tutorial menu navigation does not fire the gun")
	await tap(KEY_ESCAPE); await frames(8)
	check(fits(app.tutorial_guide.next_button),"next chapter control is reachable in pause menu")
	await capture("03_completed_chapter_menu")
	await activate(app.tutorial_guide.next_button); await frames(50)
	check(not is_instance_valid(core) and app.tutorial_guide.chapter==1 and not paused,"next chapter replaces old world and restores play")
	var motion := InputEventMouseMotion.new(); motion.relative=Vector2(200,0); Input.parse_input_event(motion)
	var aim := InputEventMouseButton.new(); aim.button_index=MOUSE_BUTTON_RIGHT; aim.pressed=true; Input.parse_input_event(aim)
	for i in 150: await physics_frame
	aim=InputEventMouseButton.new(); aim.button_index=MOUSE_BUTTON_RIGHT; aim.pressed=false; Input.parse_input_event(aim)
	await frames(5)
	check(app.tutorial_guide.passed,"real mouse motion and sight input complete observation chapter")
	await capture("04_gunsight_chapter")
	await tap(KEY_ESCAPE); await activate(app.training.hud._training_btn); await frames(30)
	check(app.garage!=null and app.tutorial_chapter==-1 and app.profile.snapshot().tutorial.completed.size()==2,"return preserves both completed chapters and clears training context")
	check(LocalizationService.missing.is_empty(),"tutorial window contains no untranslated keys")
	app.free(); await frames(8)
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed==0: print("TUTORIAL_WINDOW_CHECKS_PASS")
	quit(0 if failed==0 else 1)
