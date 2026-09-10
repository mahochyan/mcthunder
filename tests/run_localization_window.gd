extends SceneTree
## Real renderer and normal InputEvent routes. The last result layout uses an
## explicitly abandoned fixture; it is not a played victory or a performance run.
var app: AppFlow
var checks := 0
var failed := 0
var shot_dir := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(count: int = 4) -> void:
	for i in count: await process_frame
func tap(code: Key, shift: bool = false) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = down; event.shift_pressed = shift
		Input.parse_input_event(event)
		await frames(2)
func focus_control(control: Control) -> bool:
	if not is_instance_valid(control): check(false,"requested control exists"); return false
	for i in 180:
		if root.gui_get_focus_owner() == control: return true
		await tap(KEY_TAB)
	check(false,"keyboard can reach "+str(control.name))
	return false
func activate(control: Control) -> void:
	if await focus_control(control): await tap(KEY_ENTER)
	await frames(8)
func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := find_button(child,title)
		if found != null: return found
	return null
func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var bitmap := root.get_texture().get_image()
	check(not bitmap.is_empty() and bitmap.save_png(shot_dir.path_join(id+".png")) == OK,"rendered screenshot "+id)
func fits(control: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(control.get_global_rect())

func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: print("LOCALIZATION_WINDOW_TIMEOUT"); quit(2))
	for i in OS.get_cmdline_user_args().size():
		var args := OS.get_cmdline_user_args()
		if args[i] == "--shot-dir" and i+1 < args.size(): shot_dir = args[i+1]
	if shot_dir.is_empty() or DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	InputBindingService.initialize("user://tests/localization_window_%d/input.json" % Time.get_ticks_usec())
	app = load("res://scenes/app.tscn").instantiate()
	app.profile = ProfileStore.new("")
	root.add_child(app); current_scene = app
	await frames(30)
	check(app.garage != null,"normal main scene opens garage")
	var glyphs_missing := {}
	for value in LocalizationService.all_strings().values():
		for index in str(value).length():
			var code := str(value).unicode_at(index)
			if code >= 0x3400 and code <= 0x9fff and not CoreUI.FONT.has_char(code): glyphs_missing[code] = true
	check(glyphs_missing.is_empty(),"bundled font covers every Chinese translation glyph")
	await capture("01_garage")
	await activate(find_button(app.garage,LocalizationService.text("menu_credits")))
	var dialog := app.garage.get_node_or_null("ApplicationDialog")
	var license_text := dialog.find_child("DialogBody",true,false) as RichTextLabel if dialog != null else null
	check(license_text != null and "SIL OPEN FONT LICENSE" in license_text.text,"credits expose bundled font license")
	await capture("01b_credits")
	await tap(KEY_ESCAPE); await frames(8)
	await activate(find_button(app.garage,LocalizationService.text("menu_quit")))
	check(app.garage.get_node_or_null("ApplicationDialog") != null,"exit opens a reversible confirmation")
	await tap(KEY_ESCAPE); await frames(8)
	check(app.garage.get_node_or_null("ApplicationDialog") == null,"Esc cancels exit and keeps application running")
	var opener := find_button(app.garage,LocalizationService.text("ui_eb9bb060c217"))
	await activate(opener)
	var panel := app.garage.find_child("*",true,false) as InputSettingsPanel
	for child in app.garage.get_children():
		if child is InputSettingsPanel: panel = child
	check(panel != null,"keyboard opens garage settings")
	if panel == null: quit(1); return
	var trapped := true
	for i in 70:
		await tap(KEY_TAB)
		var focused := root.gui_get_focus_owner()
		trapped = trapped and focused != null and panel.is_ancestor_of(focused)
	check(trapped,"Tab stays in settings through a complete binding list")
	var volume := panel.find_child("CombatVolume",true,false) as HSlider
	if await focus_control(volume): await tap(KEY_HOME)
	check(AccessibilitySettings.audio_volume == 0,"garage volume changes through keyboard slider")
	if await focus_control(volume): await tap(KEY_END)
	var scale_choice := panel.find_child("TextScale",true,false) as OptionButton
	if await focus_control(scale_choice): await tap(KEY_SPACE)
	check(scale_choice.get_popup().visible,"keyboard opens text size popup")
	await tap(KEY_DOWN); await tap(KEY_DOWN); await tap(KEY_ENTER); await frames(10)
	check(AccessibilitySettings.ui_scale == 1.25,"largest text size selected through real popup")
	check(fits(panel.close_button),"settings close action fits viewport at 125 percent text")
	await capture("02_settings_large")
	await tap(KEY_ESCAPE); await frames(10)
	check(not is_instance_valid(panel) and root.gui_get_focus_owner() == opener,"Esc restores focus to garage settings opener")
	await activate(app.garage.challenge_button)
	check(is_instance_valid(app.garage.challenge_selection),"keyboard opens challenge selection")
	check(fits(app.garage.challenge_selection.close_button) and fits(app.garage.challenge_selection.start_button),"challenge actions fit 125 percent text layout")
	await capture("03_challenges")
	await tap(KEY_ESCAPE); await frames(10)
	check(not is_instance_valid(app.garage.challenge_selection),"Esc closes challenge selection without opening battle")
	await activate(app.garage.start_button); await frames(90)
	var core := app.training as CoreRange
	check(core != null,"keyboard starts selected real training lesson")
	if core == null: quit(1); return
	await capture("04_training")
	await tap(KEY_ESCAPE); await frames(10)
	check(core._paused and root.gui_get_focus_owner() != null,"pause supplies keyboard focus")
	await capture("05_pause")
	await activate(core.hud._training_btn); await frames(25)
	check(app.training == null and app.garage != null and not paused,"keyboard returns from training to garage and clears pause")
	await capture("06_returned_garage")
	await activate(find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a")))
	await frames(220)
	var battle := app.training as TeamRange
	check(battle != null and battle.team_ready and battle.combat_actors().size() == 8,"keyboard opens eight-vehicle map from garage")
	if battle == null: quit(1); return
	await tap(KEY_ESCAPE); await frames(8)
	await activate(battle.battle_ui.settings_button)
	check(battle.battle_ui.overlay.settings_root.visible,"battle pause opens display settings")
	await capture("07_battle_settings")
	await tap(KEY_ESCAPE); await frames(8)
	await activate(battle.hud._training_btn); await frames(25)
	check(is_instance_valid(app.navigation_overlay) and paused and app.training == battle,"live battle return opens confirmation before ending match")
	await capture("08_leave_confirmation")
	await tap(KEY_ESCAPE); await frames(8)
	check(not is_instance_valid(app.navigation_overlay) and battle._paused and paused,"cancel leave restores the existing pause menu")
	await activate(battle.hud._training_btn); await frames(8)
	await activate(find_button(app.navigation_overlay,LocalizationService.text("flow_leave_accept"))); await frames(25)
	check(app.training == null and app.garage != null and not paused,"battle return releases map and restores garage")
	await activate(find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a"))); await frames(220)
	battle = app.training as TeamRange
	if battle == null: check(false,"result fixture starts actual map"); quit(1); return
	battle.director.finish_once("abandoned","player_returned"); await frames(10)
	check(battle.result_panel.visible and fits(battle.restart_button) and fits(battle.return_button),"result buttons fit at largest text scale")
	check(battle.result_text.text.contains("命中") and battle.result_text.text.contains("据点驻守"),"result presents actual cumulative report")
	await capture("09_abandoned_result_fixture")
	await activate(battle.restart_button); await frames(100)
	check(not is_instance_valid(battle) and app.training is TeamRange,"keyboard restarts from result panel")
	check(LocalizationService.missing.is_empty(),"real UI route has no missing translation keys")
	app.queue_free(); await frames(8)
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed == 0: print("LOCALIZATION_WINDOW_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
