class_name AppFlow
extends Node
var garage: GarageShell
var training: Node3D
var ui_layer: CanvasLayer
var result_overlay: Control
var settings := {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":false}
var selected_case := 0
var last_result: Dictionary = {}
var _transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_embed_subwindows = true
	var args := OS.get_cmdline_user_args()
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

func _clear_training() -> void:
	get_tree().paused = false
	if is_instance_valid(training):
		if training is BallisticsRange: training.projectiles.cancel_all("cancelled_scene_exit")
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
	if not result.is_empty(): last_result = result
	if is_instance_valid(garage): garage.free()
	garage = GarageShell.new()
	garage.initial_loadout = settings.duplicate(true)
	garage.initial_case = selected_case
	ui_layer.add_child(garage)
	garage.training_requested.connect(enter_training)
	garage.laboratory_requested.connect(enter_laboratory)
	if not last_result.is_empty():
		garage.result_label.text = "上次课目：%s · %s · %d炮" % [last_result.title,{"passed":"完成","failed":"未完成","running":"中途返回"}.get(last_result.status,"已结束"),last_result.shots]
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_transitioning = false

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
	var allowed := {"armor":"res://scenes/training/armor_range.tscn","ballistics":"res://scenes/training/ballistics_range.tscn","recovery":"res://scenes/training/recovery_range.tscn"}
	if not allowed.has(id): return
	var prepared := garage.build_loadout()
	if prepared.ok: settings = prepared.loadout
	_transitioning = true
	call_deferred("_enter_lab",allowed[id])

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
	add_child(training)
	var lab := training as BallisticsRange
	for connection in lab.hud.training_requested.get_connections(): lab.hud.training_requested.disconnect(connection.callable)
	lab.hud.training_requested.connect(func() -> void: return_to_garage())
	lab.hud._training_btn.text = "返回车库"
	lab.hud.armor_training_button.visible = false
	lab.hud.damage_training_button.visible = false
	lab.hud.recovery_training_button.visible = false
	CoreUI.apply(lab.hud)
	_transitioning = false

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
	var explanation := CoreUI.label(content,result.explanation,17)
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
