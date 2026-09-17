class_name AppFlow
extends Node
var garage: GarageShell
var training: Node3D
var ui_layer: CanvasLayer
var result_overlay: Control
var settings := {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":false}
var selected_case := 0
var selected_vehicle_id := "player_tank"
var last_result: Dictionary = {}
var _transitioning := false
var profile: ProfileStore
var progression: ProgressionService
var match_config: MatchConfig
var match_token := ""
var pending_reward: Dictionary = {}
var challenges: ChallengeProgression
var pending_challenge := -1
var loading_overlay: Control
var navigation_overlay: Control
var load_generation := 0
var tutorial_chapter := -1
var tutorial_guide: Node
var tutorial_return_settings: Dictionary = {}

func start_tutorial(chapter: int) -> void:
	if _transitioning or chapter<0 or chapter>=TutorialCatalog.COUNT: return
	var next := profile.snapshot(); next.tutorial.chapter = chapter
	var saved := profile.commit(next)
	if not saved.ok:
		if is_instance_valid(garage): garage.error_label.text = saved.reason
		elif is_instance_valid(tutorial_guide): tutorial_guide.save_error = saved.reason
		return
	if tutorial_chapter < 0: tutorial_return_settings = {"vehicle":selected_vehicle_id,"case":selected_case}
	tutorial_chapter = chapter
	_transitioning = true
	if chapter == 9:
		match_config = null; match_token = ""; selected_vehicle_id = "player_tank"
		call_deferred("_enter_lab","res://scenes/battle/team_range.tscn")
	else:
		selected_case = TutorialCatalog.LESSONS[chapter]
		call_deferred("_enter_core")

func _attach_tutorial() -> void:
	if tutorial_chapter < 0: return
	tutorial_guide = load("res://scripts/core/tutorial_guide.gd").new(); tutorial_guide.chapter = tutorial_chapter
	training.add_child(tutorial_guide)
	tutorial_guide.completed.connect(func(_chapter: int) -> void: _save_tutorial())
	tutorial_guide.next_requested.connect(func(chapter: int) -> void:
		if not _save_tutorial(): return
		if chapter >= TutorialCatalog.COUNT: return_to_garage()
		else: start_tutorial(chapter))

func _save_tutorial() -> bool:
	if not is_instance_valid(tutorial_guide) or tutorial_guide.get_parent() != training or not tutorial_guide.passed: return false
	var next := profile.snapshot()
	if tutorial_chapter in next.tutorial.completed: tutorial_guide.save_error = ""; return true
	next.tutorial.completed.append(tutorial_chapter); next.tutorial.completed.sort()
	next.tutorial.chapter = mini(tutorial_chapter+1,TutorialCatalog.COUNT)
	var saved := profile.commit(next)
	tutorial_guide.save_error = "" if saved.ok else saved.reason
	return saved.ok

func _begin_loading() -> int:
	load_generation += 1
	_transitioning = true
	get_tree().paused = true
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	loading_overlay = AppDialog.show(ui_layer,LocalizationService.text("flow_loading"),LocalizationService.text("flow_loading_body"),"",Callable(),cancel_loading)
	return load_generation

func _end_loading() -> void:
	if is_instance_valid(loading_overlay): loading_overlay.queue_free()
	loading_overlay = null
	get_tree().paused = false
	_transitioning = false

func cancel_loading() -> void:
	if not is_instance_valid(loading_overlay): return
	load_generation += 1
	_end_loading()
	return_to_garage()

func _loading_failed(message: String) -> void:
	_end_loading()
	_clear_training()
	_show_error(message)

func request_leave_match(scene: BallisticsRange) -> void:
	if _transitioning or scene != training or is_instance_valid(navigation_overlay): return
	var finished := false
	if scene is TeamRange: finished = scene.director.state.phase == "finished"
	elif scene is DuelRange: finished = scene.match_director.phase == "finished"
	elif scene is ChallengeRange: finished = scene.director.phase == "finished"
	else: return
	if finished:
		scene.leave_match()
		return
	var was_paused := scene._paused
	scene._pause()
	var reference: WeakRef = weakref(scene)
	var resume := func() -> void:
		var prior := reference.get_ref() as BallisticsRange
		navigation_overlay = null
		if prior != null and prior == training and not was_paused: prior._resume()
	var accept := func() -> void:
		var prior := reference.get_ref() as BallisticsRange
		navigation_overlay = null
		if prior != null and prior == training: prior.leave_match()
	navigation_overlay = AppDialog.show(ui_layer,LocalizationService.text("flow_leave_title"),LocalizationService.text("flow_leave_body"),LocalizationService.text("flow_leave_accept"),accept,resume)

func _wire_leave_buttons(scene: BallisticsRange) -> void:
	for button in scene.hud.find_children("*","Button",true,false):
		for connection in button.pressed.get_connections():
			var callback: Callable = connection.callable
			if callback.get_object() == scene and callback.get_method() == "leave_match":
				button.pressed.disconnect(callback)
				button.pressed.connect(func() -> void: request_leave_match(scene))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_embed_subwindows = true
	var args := OS.get_cmdline_user_args()
	var verify_installation := args.has("--verify-installation")
	var verify_performance := args.has("--verify-performance")
	var verify_player_flow := args.has("--verify-player-flow")
	var verify_modern := args.has("--verify-modern-garage") or args.has("--verify-modern-life") or args.has("--verify-modern-match")
	# WT-UI-003: host for the normal-input UI navigation verifier, following the same flag pattern as the others.
	var verify_ui_nav := args.has("--verify-ui-navigation")
	var isolated_settings := DisplayServer.get_name() == "headless" or verify_installation or verify_performance or verify_player_flow or verify_modern or verify_ui_nav
	for argument in args:
		if argument.ends_with("-check") or argument.ends_with("-demo") or argument == "--autoshot" or argument == "--export-smoke": isolated_settings = true
	InputBindingService.initialize("" if isolated_settings else InputBindingService.PATH)
	if not isolated_settings: DisplaySettings.apply_startup()
	if profile == null:
		var isolated := isolated_settings
		for flag in ["--export-smoke","--team-play-check","--historical-play-check","--shell-play-check","--garage-play-check","--industrial-play-check","--challenge-play-check","--art-play-check","--feedback-play-check"]:
			if args.has(flag): isolated = true
		profile = ProfileStore.new("" if isolated else ProfileStore.DEFAULT_PATH)
		if args.has("--challenge-play-check"): profile = ProfileStore.new("user://tests/challenge_demo024_"+str(Time.get_ticks_usec())+"/commander")
	if verify_installation or verify_performance or verify_player_flow or verify_modern or verify_ui_nav:
		var isolated_path := "user://tests/installation031_%d" % Time.get_ticks_usec()
		InputBindingService.initialized = false; InputBindingService.initialize(isolated_path+"/input.json")
		profile = ProfileStore.new(isolated_path+"/commander")
		if args.has("--verify-modern-match"):
			profile = ProfileStore.new("user://tests/modern_match_current/commander")
	progression = ProgressionService.new(profile)
	challenges = ChallengeProgression.new(profile)
	if profile.snapshot().revision > 0: selected_vehicle_id = profile.snapshot().garage.selected_vehicle_id
	if args.has("--autoshot") or args.has("--inspect-demo") or args.has("--query-demo"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/main.tscn")
		return
	if args.has("--ballistics-demo"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/training/ballistics_range.tscn")
		return
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	return_to_garage()
	if verify_installation or verify_performance or verify_player_flow or verify_modern or verify_ui_nav:
		var verifier_path := "res://scripts/diagnostics/performance_verifier.gd" if verify_performance else "res://scripts/diagnostics/installation_verifier.gd"
		if verify_player_flow: verifier_path="res://scripts/diagnostics/player_flow_verifier.gd"
		if verify_modern:
			verifier_path="res://scripts/diagnostics/modern_life_verifier.gd" if args.has("--verify-modern-life") else "res://scripts/diagnostics/modern_garage_verifier.gd"
			if args.has("--verify-modern-match"): verifier_path="res://scripts/diagnostics/modern_match_verifier.gd"
		if verify_ui_nav: verifier_path="res://scripts/diagnostics/ui_navigation_verifier.gd"
		var verifier_script := load(verifier_path) as GDScript
		if verifier_script==null or not verifier_script.can_instantiate(): get_tree().quit(2); return
		var verifier := verifier_script.new() as Node
		if verifier==null: get_tree().quit(2); return
		add_child(verifier); verifier.call_deferred("run",self)
		return
	# Developer harnesses are excluded from the release package.
	if OS.has_feature("release"): return
	if args.has("--feedback-play-check"):
		var demo:=load("res://tests/run_feedback_player_demo.gd").new() as Node
		add_child(demo); demo.call_deferred("run",self)
	elif args.has("--export-smoke"):
		var smoke := load("res://tests/run_export_checks.gd").new() as Node
		add_child(smoke)
		smoke.call_deferred("run",self)
	elif args.has("--team-play-check"):
		var demo := load("res://tests/run_team_slice_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--historical-play-check"):
		var demo := load("res://tests/run_historical_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--shell-play-check"):
		var demo := load("res://tests/run_shell_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--garage-play-check"):
		var demo := load("res://tests/run_garage_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--industrial-play-check"):
		var demo := load("res://tests/run_industrial_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--challenge-play-check"):
		var demo := load("res://tests/run_challenge_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)
	elif args.has("--art-play-check"):
		var demo := load("res://tests/run_art_player_demo.gd").new() as Node
		add_child(demo)
		demo.call_deferred("run",self)

func _clear_training() -> void:
	if is_instance_valid(navigation_overlay): navigation_overlay.queue_free()
	navigation_overlay = null
	get_tree().paused = false
	if is_instance_valid(training):
		if training is TeamRange and training.director != null and training.director.state.phase in ["countdown","playing"]:
			training.director.finish_once("abandoned","player_returned")
		elif training is ChallengeRange and training.director != null and training.director.phase in ["countdown","playing"]:
			training.director.finish_once(false,"abandoned")
		if training is BallisticsRange and training.projectiles != null: training.projectiles.cancel_all("cancelled_scene_exit")
		training.free()
	training = null
	if is_instance_valid(result_overlay): result_overlay.free()
	result_overlay = null
	for action in ["fire","aim","move_forward","move_back","turn_left","turn_right"]: Input.action_release(action)

func return_to_garage(result: Dictionary = {}) -> void:
	if is_instance_valid(loading_overlay): cancel_loading(); return
	if _transitioning: return
	_transitioning = true
	call_deferred("_show_garage",result.duplicate(true))

func _show_garage(result: Dictionary) -> void:
	_clear_training()
	if not tutorial_return_settings.is_empty():
		selected_vehicle_id = tutorial_return_settings.vehicle; selected_case = tutorial_return_settings.case
		tutorial_return_settings.clear()
	tutorial_chapter = -1; tutorial_guide = null
	InputBindingService.set_context("garage")
	if not result.is_empty():
		var prior := last_result.duplicate(true)
		last_result = result
		if prior.get("match_id",-1) == result.get("match_id",-2) and prior.has("progression"): last_result.progression = prior.progression
		if prior.get("attempt_id",-1) == result.get("attempt_id",-2) and prior.has("progression"): last_result.progression = prior.progression
	if is_instance_valid(garage): garage.free()
	garage = GarageShell.new()
	garage.profile = profile
	garage.initial_loadout = settings.duplicate(true)
	garage.initial_case = selected_case
	garage.initial_vehicle_id = selected_vehicle_id
	ui_layer.add_child(garage)
	if not profile.problem.is_empty(): garage.error_label.text = profile.problem
	if not pending_reward.is_empty(): _settle_match(pending_reward.token,pending_reward.result)
	if not pending_reward.is_empty():
		CoreUI.button(garage.preparation,LocalizationService.text("ui_48219066e2d8"),func() -> void:
			if not pending_reward.is_empty(): _settle_match(pending_reward.token,pending_reward.result))
	garage.training_requested.connect(enter_training)
	garage.laboratory_requested.connect(enter_laboratory)
	garage.challenge_requested.connect(enter_challenge)
	garage.quit_requested.connect(_quit_application)
	garage.tutorial_requested.connect(start_tutorial)
	garage.progress_reset.connect(func() -> void:
		pending_reward.clear(); pending_challenge = -1; last_result.clear()
		progression = ProgressionService.new(profile); challenges = ChallengeProgression.new(profile)
		selected_vehicle_id = profile.snapshot().garage.selected_vehicle_id; selected_case = 0
		call_deferred("return_to_garage"))
	if pending_challenge >= 0: _settle_challenge(pending_challenge)
	if pending_challenge >= 0:
		CoreUI.button(garage.preparation,LocalizationService.text("ui_4a07649a8888"),func() -> void: _settle_challenge(pending_challenge))
	if not last_result.is_empty():
		garage.result_label.text = LocalizationService.text("ui_c3f7b2c28ffe") % [last_result.title,{"passed":LocalizationService.text("ui_c0b3fbff51cc"),"failed":LocalizationService.text("ui_6707de42c29d"),"running":LocalizationService.text("ui_acf148dcff50")}.get(last_result.status,LocalizationService.text("ui_d79b1d0e5c61")),last_result.shots]
		if last_result.has("progression"): garage.result_label.text += "\n"+str(last_result.progression.reason)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_transitioning = false

func enter_challenge(id: String, level: String) -> void:
	if _transitioning or ChallengeCatalog.create(id,level).is_empty(): return
	if pending_challenge >= 0:
		_settle_challenge(pending_challenge)
		if pending_challenge >= 0: return
	if not pending_reward.is_empty():
		_settle_match(pending_reward.token,pending_reward.result)
		if not pending_reward.is_empty(): return
	_transitioning = true
	call_deferred("_enter_challenge",id,level)

func _quit_application() -> void:
	if not pending_reward.is_empty(): _settle_match(pending_reward.token,pending_reward.result)
	if pending_challenge >= 0: _settle_challenge(pending_challenge)
	if not pending_reward.is_empty() or pending_challenge >= 0:
		_show_error(LocalizationService.text("menu_save_retry"))
		return
	get_tree().quit()

func _enter_challenge(id: String, level: String) -> void:
	var generation := _begin_loading()
	await get_tree().process_frame
	if generation != load_generation: return
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	var scene := ChallengeRange.new(); scene.challenge_id = id; scene.difficulty = level
	training = scene; add_child(scene)
	_transitioning = false
	_end_loading()
	if not scene.challenge_ready: _loading_failed(LocalizationService.text("ui_dbc7b91b29e9")); return
	_wire_leave_buttons(scene)
	for connection in scene.hud.training_requested.get_connections(): scene.hud.training_requested.disconnect(connection.callable)
	scene.hud.training_requested.connect(func() -> void: request_leave_match(scene))
	if not challenges.bind(scene.director):
		scene.director.finish_once(false,"identity_changed")
		scene.save_text.text = LocalizationService.text("ui_80e4b384e7ea")
		scene.return_requested.connect(return_to_garage)
		return
	var attempt := scene.director.attempt_id
	scene.director.finished.connect(func(_result: Dictionary) -> void: _settle_challenge(attempt))
	scene.return_requested.connect(return_to_garage)
	scene.restart_requested.connect(func() -> void: enter_challenge(id,level))

func _settle_challenge(attempt: int) -> void:
	if attempt < 0: return
	var earned := challenges.settle(attempt)
	pending_challenge = -1 if earned.ok else attempt
	if training is ChallengeRange and training.director.attempt_id == attempt:
		last_result = training.director.result.duplicate(true)
		last_result.progression = earned
		training.save_text.text = earned.reason
	if is_instance_valid(garage):
		garage.error_label.text = earned.reason
		if is_instance_valid(garage.challenge_selection): garage.challenge_selection.refresh()
	if last_result.get("attempt_id",-1) == attempt: last_result.progression = earned

func enter_training(loadout: Dictionary, case_index: int) -> void:
	if _transitioning: return
	var checked := TrainingLoadout.validate(loadout)
	if not checked.ok or case_index < 0 or case_index >= TrainingDirector.TITLES.size():
		if is_instance_valid(garage): garage.error_label.text = checked.get("reason",LocalizationService.text("ui_5b34da9bf1f6"))
		return
	settings = checked.loadout
	selected_case = case_index
	_transitioning = true
	call_deferred("_enter_core")

func _enter_core() -> void:
	var generation := _begin_loading()
	await get_tree().process_frame
	if generation != load_generation: return
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	var core := CoreRange.new()
	core.loadout = {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":true} if tutorial_chapter>=0 else settings.duplicate(true)
	core.lesson = selected_case
	core.teach_fire_recovery = tutorial_chapter == 6
	training = core
	add_child(training)
	core.return_requested.connect(return_to_garage)
	core.results_requested.connect(show_results)
	_attach_tutorial()
	_transitioning = false
	_end_loading()
	if not core._core_ready: _loading_failed(LocalizationService.text("ui_e44d206f7d84"))

func enter_laboratory(id: String) -> void:
	if _transitioning or not is_instance_valid(garage): return
	if not pending_reward.is_empty():
		_settle_match(pending_reward.token,pending_reward.result)
		if not pending_reward.is_empty(): return
	var allowed := {"armor":"res://scenes/training/armor_range.tscn","ballistics":"res://scenes/training/ballistics_range.tscn","recovery":"res://scenes/training/recovery_range.tscn","terrain":"res://scenes/training/terrain_range.tscn","ai_drive":"res://scenes/training/ai_drive_range.tscn","ai_combat":"res://scenes/training/ai_combat_range.tscn","duel":"res://scenes/battle/duel_range.tscn","team":MapRegistry.scene_path("hill_village")}
	allowed["historical"] = "res://scenes/training/ballistics_range.tscn"
	allowed["shells"] = "res://scenes/training/shell_range.tscn"
	allowed["river_drive"] = "res://scenes/maps/river_junction_range.tscn"
	allowed["river_team"] = MapRegistry.scene_path("river_junction_team")
	if not allowed.has(id): return
	selected_vehicle_id = garage.selected_vehicle_id()
	if id == "river_team" or (id == "team" and VehicleCatalog.is_engineering(selected_vehicle_id)):
		if not VehicleCatalog.is_engineering(selected_vehicle_id):
			garage.error_label.text = "请先选择 T-80B 或豹 2A4，再进入现代河谷。"; return
		for required_id in VehicleCatalog.ENGINEERING_IDS:
			if not profile.service.has_vehicle(required_id):
				garage.error_label.text = "现代河谷缺少必需车辆包："+required_id; return
		id = "river_team"
	match_config = null; match_token = ""
	if id == "river_team" or (id in ["team","historical"] and selected_vehicle_id in VehicleCatalog.IDS):
		var configured := garage.preparation.build_match()
		if not configured.ok: garage.error_label.text = configured.reason; return
		var saved := garage.preparation.save_settings()
		if not saved.ok: return
		match_config = configured.config
	if id == "team": allowed[id] = MapRegistry.scene_path(match_config.map_id() if match_config != null else "hill_village")
	var prepared := garage.build_loadout()
	if prepared.ok: settings = prepared.loadout
	_transitioning = true
	call_deferred("_enter_lab",allowed[id])

func restart_match() -> void:
	if _transitioning or not (training is DuelRange or training is TeamRange): return
	if training is TeamRange and match_config != null and training.director.state.phase != "finished": training.director.finish_once("abandoned","player_returned")
	if not pending_reward.is_empty():
		_settle_match(pending_reward.token,pending_reward.result)
		if not pending_reward.is_empty(): return
	_transitioning = true
	var path := "res://scenes/battle/team_range.tscn" if training is TeamRange else "res://scenes/battle/duel_range.tscn"
	if training is VillageRange: path = MapRegistry.scene_path(match_config.map_id() if match_config != null else "hill_village")
	call_deferred("_enter_lab",path)

func _enter_lab(path: String) -> void:
	var generation := _begin_loading()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	if generation != load_generation: return
	var requested := AppSceneLoader.load_scene(path)
	if not requested.ok: _loading_failed(requested.reason); return
	await get_tree().process_frame
	if generation != load_generation: return
	var scene: PackedScene = requested.scene
	var candidate := scene.instantiate()
	if not candidate is BallisticsRange:
		candidate.free()
		_loading_failed(LocalizationService.text("flow_wrong_scene") % path); return
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	training = candidate
	if training is TeamRange or training is RiverJunctionRange or path == "res://scenes/training/ballistics_range.tscn":
		training.selected_vehicle_id = selected_vehicle_id
	if training is BallisticsRange: training.prepared_match = match_config
	if training is RiverTeamRange and VehicleCatalog.is_engineering(selected_vehicle_id):
		training.opposing_engineering_id = "germ_leopard_2a4" if selected_vehicle_id == "ussr_t_80b" else "ussr_t_80b"
	add_child(training)
	var lab := training as BallisticsRange
	if not lab._initialized or lab.hud == null or (lab is TeamRange and not lab.team_ready):
		_loading_failed(LocalizationService.text("flow_initialization_failed") % path); return
	for connection in lab.hud.training_requested.get_connections(): lab.hud.training_requested.disconnect(connection.callable)
	if lab is DuelRange or lab is TeamRange:
		if lab is TeamRange:
			match_token = ""
			if match_config != null:
				var registered := progression.register_match(match_config)
				if not registered.ok: _loading_failed(registered.reason); return
				match_token = registered.token
			progression.bind_director(match_token,lab.director)
			var token := match_token
			lab.director.match_finished.connect(func(result: Dictionary) -> void:
				if generation == load_generation and lab == training: _settle_match(token,result))
		lab.restart_requested.connect(restart_match)
		lab.return_requested.connect(return_to_garage)
		lab.hud.training_requested.connect(func() -> void: request_leave_match(lab))
		_wire_leave_buttons(lab)
	else:
		lab.hud.training_requested.connect(func() -> void: return_to_garage())
	lab.hud._training_btn.text = LocalizationService.text("ui_6ea101bebe06")
	lab.hud.armor_training_button.visible = false
	lab.hud.damage_training_button.visible = false
	lab.hud.recovery_training_button.visible = false
	CoreUI.apply(lab.hud)
	_attach_tutorial()
	_end_loading()

func _settle_match(token: String, result: Dictionary) -> void:
	var earned := progression.apply_result_once(token,result)
	# Keep the original receipt presentation when the same result is revisited.
	if earned.get("duplicate",false) and last_result.get("match_id",-1) == result.get("match_id",-2) and last_result.get("progression",{}).get("ok",false):
		earned = last_result.progression.duplicate(true)
	last_result = result.duplicate(true)
	last_result.progression = earned
	pending_reward = {} if earned.ok else {"token":token,"result":result.duplicate(true)}
	if training is TeamRange and is_instance_valid(training.result_text): training.result_text.text = training.result_body+"\n"+str(earned.reason)
	if is_instance_valid(garage):
		garage.error_label.text = earned.reason
		garage.preparation._refresh_research()

func show_results(result: Dictionary) -> void:
	if not is_instance_valid(training) or is_instance_valid(result_overlay): return
	last_result = result.duplicate(true)
	var core := training as CoreRange
	core._pause()
	core.hud.show_pause(false)
	result_overlay = Control.new()
	ui_layer.add_child(result_overlay)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.theme = CoreUI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.04,0.05,0.93)
	result_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	result_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 600
	content.add_theme_constant_override("separation",12)
	panel.add_child(content)
	CoreUI.label(content,LocalizationService.text("ui_7bd045755db7")+result.title,28)
	CoreUI.label(content,{"passed":LocalizationService.text("ui_c0b3fbff51cc"),"failed":LocalizationService.text("ui_6707de42c29d"),"running":LocalizationService.text("ui_b2d1898e6ec6")}.get(result.status,LocalizationService.text("ui_d79b1d0e5c61")),23)
	var explanation_scroll := ScrollContainer.new()
	explanation_scroll.custom_minimum_size.y = 180
	explanation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(explanation_scroll)
	var explanation := CoreUI.label(explanation_scroll,result.explanation,17)
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(content,LocalizationService.text("ui_62c939aba273") % result.shots,15)
	CoreUI.button(content,LocalizationService.text("ui_e0fd78bdd191"),_resume_training)
	CoreUI.button(content,LocalizationService.text("ui_e7598cfa241d"),func() -> void: _resume_training(); core.restart_lesson())
	CoreUI.button(content,LocalizationService.text("ui_6ea101bebe06"),func() -> void: return_to_garage(last_result))
	ModalNavigation.attach(result_overlay)

func _resume_training() -> void:
	if is_instance_valid(result_overlay): result_overlay.queue_free()
	result_overlay = null
	if is_instance_valid(training): training._resume()

func _show_error(message: String) -> void:
	if is_instance_valid(navigation_overlay): navigation_overlay.queue_free()
	navigation_overlay = AppDialog.show(ui_layer,LocalizationService.text("flow_error_title"),message,"",Callable(),func() -> void:
		navigation_overlay = null; return_to_garage())

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(result_overlay) and InputBindingService.is_pause(event):
		_resume_training()
		get_viewport().set_input_as_handled()
