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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_embed_subwindows = true
	var args := OS.get_cmdline_user_args()
	if profile == null:
		var isolated := DisplayServer.get_name() == "headless"
		for flag in ["--export-smoke","--team-play-check","--historical-play-check","--shell-play-check","--garage-play-check","--industrial-play-check","--challenge-play-check"]:
			if args.has(flag): isolated = true
		profile = ProfileStore.new("" if isolated else ProfileStore.DEFAULT_PATH)
		if args.has("--challenge-play-check"): profile = ProfileStore.new("user://tests/challenge_demo024_"+str(Time.get_ticks_usec())+"/commander")
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
	if args.has("--export-smoke"):
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

func _clear_training() -> void:
	get_tree().paused = false
	if is_instance_valid(training):
		if training is BallisticsRange and training.projectiles != null: training.projectiles.cancel_all("cancelled_scene_exit")
		training.free()
	training = null
	if is_instance_valid(result_overlay): result_overlay.free()
	result_overlay = null
	for action in ["fire","aim","move_forward","move_back","turn_left","turn_right"]: Input.action_release(action)

func return_to_garage(result: Dictionary = {}) -> void:
	if _transitioning: return
	_transitioning = true
	call_deferred("_show_garage",result.duplicate(true))

func _show_garage(result: Dictionary) -> void:
	_clear_training()
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
		CoreUI.button(garage.preparation,"重试战后保存",func() -> void:
			if not pending_reward.is_empty(): _settle_match(pending_reward.token,pending_reward.result))
	garage.training_requested.connect(enter_training)
	garage.laboratory_requested.connect(enter_laboratory)
	garage.challenge_requested.connect(enter_challenge)
	if pending_challenge >= 0: _settle_challenge(pending_challenge)
	if pending_challenge >= 0:
		CoreUI.button(garage.preparation,"重试挑战成绩保存",func() -> void: _settle_challenge(pending_challenge))
	if not last_result.is_empty():
		garage.result_label.text = "上次课目：%s · %s · %d炮" % [last_result.title,{"passed":"完成","failed":"未完成","running":"中途返回"}.get(last_result.status,"已结束"),last_result.shots]
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

func _enter_challenge(id: String, level: String) -> void:
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	var scene := ChallengeRange.new(); scene.challenge_id = id; scene.difficulty = level
	training = scene; add_child(scene)
	_transitioning = false
	if not scene.challenge_ready: _show_error("挑战初始化失败，请返回车库重试。"); return
	if not challenges.bind(scene.director):
		scene.director.finish_once(false,"identity_changed")
		scene.save_text.text = "挑战登记失败；成绩未保存，请返回车库重试。"
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
		if is_instance_valid(garage): garage.error_label.text = checked.get("reason","课目不可用")
		return
	settings = checked.loadout
	selected_case = case_index
	_transitioning = true
	call_deferred("_enter_core")

func _enter_core() -> void:
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	var core := CoreRange.new()
	core.loadout = settings.duplicate(true)
	core.lesson = selected_case
	training = core
	add_child(training)
	core.return_requested.connect(return_to_garage)
	core.results_requested.connect(show_results)
	_transitioning = false
	if not core._core_ready: _show_error("训练初始化失败，请返回车库重试。")

func enter_laboratory(id: String) -> void:
	if _transitioning: return
	if not pending_reward.is_empty():
		_settle_match(pending_reward.token,pending_reward.result)
		if not pending_reward.is_empty(): return
	var allowed := {"armor":"res://scenes/training/armor_range.tscn","ballistics":"res://scenes/training/ballistics_range.tscn","recovery":"res://scenes/training/recovery_range.tscn","terrain":"res://scenes/training/terrain_range.tscn","ai_drive":"res://scenes/training/ai_drive_range.tscn","ai_combat":"res://scenes/training/ai_combat_range.tscn","duel":"res://scenes/battle/duel_range.tscn","team":MapRegistry.scene_path("hill_village")}
	allowed["historical"] = "res://scenes/training/ballistics_range.tscn"
	allowed["shells"] = "res://scenes/training/shell_range.tscn"
	if not allowed.has(id): return
	selected_vehicle_id = garage.selected_vehicle_id()
	match_config = null; match_token = ""
	if id in ["team","historical"] and selected_vehicle_id in VehicleCatalog.IDS:
		var configured := garage.preparation.build_match()
		if not configured.ok: garage.error_label.text = configured.reason; return
		var saved := garage.preparation.save_settings()
		if not saved.ok: return
		match_config = configured.config
		if id == "team":
			var registered := progression.register_match(match_config)
			if not registered.ok: garage.error_label.text = registered.reason; return
			match_token = registered.token
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
	if match_config != null and training is TeamRange:
		var registered := progression.register_match(match_config)
		if not registered.ok:
			training.result_text.text += "\n"+str(registered.reason)
			return
		match_token = registered.token
	_transitioning = true
	var path := "res://scenes/battle/team_range.tscn" if training is TeamRange else "res://scenes/battle/duel_range.tscn"
	if training is VillageRange: path = MapRegistry.scene_path(match_config.map_id() if match_config != null else "hill_village")
	call_deferred("_enter_lab",path)

func _enter_lab(path: String) -> void:
	_clear_training()
	if is_instance_valid(garage): garage.free()
	garage = null
	var scene := load(path) as PackedScene
	if scene == null:
		_transitioning = false
		_show_error("实验室资源不可用。")
		return
	training = scene.instantiate()
	if training is TeamRange or path == "res://scenes/training/ballistics_range.tscn":
		training.selected_vehicle_id = selected_vehicle_id
	if training is BallisticsRange: training.prepared_match = match_config
	add_child(training)
	var lab := training as BallisticsRange
	for connection in lab.hud.training_requested.get_connections(): lab.hud.training_requested.disconnect(connection.callable)
	if lab is DuelRange or lab is TeamRange:
		if lab is TeamRange:
			progression.bind_director(match_token,lab.director)
			lab.director.match_finished.connect(func(result: Dictionary) -> void: _settle_match(match_token,result))
		lab.restart_requested.connect(restart_match)
		lab.return_requested.connect(return_to_garage)
		lab.hud.training_requested.connect(lab.leave_match)
	else:
		lab.hud.training_requested.connect(func() -> void: return_to_garage())
	lab.hud._training_btn.text = "返回车库"
	lab.hud.armor_training_button.visible = false
	lab.hud.damage_training_button.visible = false
	lab.hud.recovery_training_button.visible = false
	CoreUI.apply(lab.hud)
	_transitioning = false

func _settle_match(token: String, result: Dictionary) -> void:
	var earned := progression.apply_result_once(token,result)
	last_result = result.duplicate(true)
	last_result.progression = earned
	pending_reward = {} if earned.ok else {"token":token,"result":result.duplicate(true)}
	if training is TeamRange and is_instance_valid(training.result_text): training.result_text.text += "\n"+str(earned.reason)
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
	CoreUI.label(content,"课目结果 / "+result.title,28)
	CoreUI.label(content,{"passed":"完成","failed":"未完成","running":"训练尚在进行"}.get(result.status,"已结束"),23)
	var explanation_scroll := ScrollContainer.new()
	explanation_scroll.custom_minimum_size.y = 180
	explanation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(explanation_scroll)
	var explanation := CoreUI.label(explanation_scroll,result.explanation,17)
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(content,"实际发射记录：%d炮   ·   真人体验验收：待进行" % result.shots,15)
	CoreUI.button(content,"继续观察 / V 查看回放",_resume_training)
	CoreUI.button(content,"重试当前课目",func() -> void: _resume_training(); core.restart_lesson())
	CoreUI.button(content,"返回车库",func() -> void: return_to_garage(last_result))

func _resume_training() -> void:
	if is_instance_valid(result_overlay): result_overlay.queue_free()
	result_overlay = null
	if is_instance_valid(training): training._resume()

func _show_error(message: String) -> void:
	var panel := PanelContainer.new()
	ui_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.theme = CoreUI.theme()
	var box := VBoxContainer.new()
	panel.add_child(box)
	CoreUI.label(box,message)
	CoreUI.button(box,"返回车库",func() -> void: panel.queue_free(); return_to_garage())

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(result_overlay) and event.is_action_pressed("pause"):
		_resume_training()
		get_viewport().set_input_as_handled()
