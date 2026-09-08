class_name GarageShell
extends Control
signal training_requested(loadout: Dictionary, case_index: int)
signal laboratory_requested(id: String)
var shell_choice: OptionButton
var rounds: SpinBox
var infinite: CheckBox
var case_choice: OptionButton
var start_button: Button
var inspect_button: Button
var error_label: Label
var preview: VehiclePreviewModel
var result_label: Label
var _view_mode := 0
var initial_loadout := {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":false}
var initial_case := 0

func _ready() -> void:
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("10191f")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation",12)
	margin.add_child(vertical)
	CoreUI.label(vertical,"MCTHUNDER   /   低多边形装甲",30)
	CoreUI.label(vertical,"核心训练候选 0.1  ·  M4A3 外形工程样车  ·  性能参数为训练设计值",15)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",24)
	vertical.add_child(columns)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 360
	columns.add_child(left_panel)
	var scroll := ScrollContainer.new()
	left_panel.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",8)
	scroll.add_child(controls)
	CoreUI.label(controls,"战前准备",24)
	var vehicle := OptionButton.new()
	vehicle.add_item("M4A3 外形样车 · 可驾驶")
	controls.add_child(vehicle)
	CoreUI.label(controls,"弹种 / 游戏设计穿深",16)
	shell_choice = OptionButton.new()
	shell_choice.add_item("AP70 · 70 mm")
	shell_choice.add_item("AP120 · 120 mm")
	shell_choice.select(0 if initial_loadout.shell_id == "ap70" else 1)
	controls.add_child(shell_choice)
	var ammo_row := HBoxContainer.new()
	controls.add_child(ammo_row)
	CoreUI.label(ammo_row,"携弹量",16)
	rounds = SpinBox.new()
	rounds.min_value = 1
	rounds.max_value = 30
	rounds.value = initial_loadout.rounds
	ammo_row.add_child(rounds)
	infinite = CheckBox.new()
	infinite.text = "无限训练弹（仍需自然装填）"
	infinite.button_pressed = initial_loadout.infinite
	controls.add_child(infinite)
	CoreUI.label(controls,"选择课目",16)
	case_choice = OptionButton.new()
	for title in TrainingDirector.TITLES: case_choice.add_item(title)
	case_choice.select(initial_case)
	controls.add_child(case_choice)
	var goal := CoreUI.label(controls,TrainingDirector.GOALS[initial_case],15)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(300,58)
	case_choice.item_selected.connect(func(index: int) -> void: goal.text = TrainingDirector.GOALS[index])
	start_button = CoreUI.button(controls,"进入训练",_start)
	error_label = CoreUI.label(controls,"",14)
	error_label.modulate = Color("ffc282")
	CoreUI.label(controls,"专项实验室",16)
	var labs := HBoxContainer.new()
	controls.add_child(labs)
	for item in [["armor","装甲"],["ballistics","弹道"],["recovery","恢复"],["terrain","地形"]]:
		CoreUI.button(labs,item[1],func() -> void: laboratory_requested.emit(item[0]))
	CoreUI.button(controls,"电脑驾驶实验室",func() -> void: laboratory_requested.emit("ai_drive"))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(350,260)
	right.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760,400)
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)
	preview = VehiclePreviewModel.new()
	viewport.add_child(preview)
	var layout := M4EngineeringProfile.layout()
	for patch in layout.armor_patches:
		if patch.id == "hull_front": patch.thickness_mm = 240
	preview.setup(layout)
	_apply_preview_mode()
	for extra in preview._extra_nodes.duplicate():
		if not extra.name.begins_with("Wire_"):
			preview._extra_nodes.erase(extra)
			extra.queue_free()
	M4LowPolyDetails.build(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,1)
	_collect_preview_extras(preview)
	var camera := Camera3D.new()
	camera.fov = 38
	camera.position = Vector3(5.3,3.8,-6.4)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,1.2,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-25,0)
	sun.light_energy = 1.8
	viewport.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("25363b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("aab9b1")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	CoreVehicleVisual.box(preview,Vector3(0,-0.06,0),Vector3(7,0.1,7),Color("40514c"))
	var view_controls := HBoxContainer.new()
	right.add_child(view_controls)
	CoreUI.button(view_controls,"转左",func() -> void: preview.rotation.y -= PI/4)
	inspect_button = CoreUI.button(view_controls,"查看：外观 → 装甲 → 内构",_inspect)
	inspect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CoreUI.button(view_controls,"转右",func() -> void: preview.rotation.y += PI/4)
	var note := CoreUI.label(right,"M4A3(75)W / VVSS 轮廓研究：斜车体、铸造炮塔、三组悬挂。\n模型尺寸为估算；正面240、其他20 mm为训练设计值。\n外观 / 装甲 / 内构预览不消耗弹药。",15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label = CoreUI.label(right,"尚无本次会话训练结果。",16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(vertical,"W/S 驾驶  ·  A/D 转向  ·  鼠标瞄准  ·  左键开炮  ·  Esc 暂停与返回",15)

func build_loadout() -> Dictionary:
	return TrainingLoadout.validate({"vehicle_id":"test_vehicle","shell_id":"ap70" if shell_choice.selected == 0 else "ap120","rounds":int(rounds.value),"infinite":infinite.button_pressed})

func _start() -> void:
	var value := build_loadout()
	if not value.ok: error_label.text = value.reason
	else: training_requested.emit(value.loadout,case_choice.selected)

func _inspect() -> void:
	_view_mode = (_view_mode+1)%3
	_apply_preview_mode()
	inspect_button.text = "当前："+["外观","装甲（暖色为设计值）","内构（仅检视）"][_view_mode]+" · 点击切换"

func _apply_preview_mode() -> void:
	preview.set_mode(["appearance","armor","interior"][_view_mode])
	for id in preview._patch_nodes:
		var mesh: MeshInstance3D = preview._patch_nodes[id]
		if _view_mode == 0: mesh.material_override.albedo_color = Color("667653")
		else: preview._restore_patch_color(mesh,id)

func _collect_preview_extras(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D and child.name.begins_with("Cosmetic"): preview._extra_nodes.append(child)
		_collect_preview_extras(child)
