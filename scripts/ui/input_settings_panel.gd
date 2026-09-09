class_name InputSettingsPanel
extends Control
signal closed
var pending_action := ""
var status: Label
var rows: Dictionary = {}
var close_button: Button
var _capturing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindingService.initialize()
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02,0.03,0.04,0.94)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	var box := VBoxContainer.new()
	margin.add_child(box)
	CoreUI.label(box,"按键与鼠标",25)
	status = CoreUI.label(box,"选择动作后按新键；Esc取消改绑或返回。",16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not InputBindingService.problem.is_empty(): status.text = InputBindingService.problem
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	CoreUI.label(contents,"鼠标灵敏度",17)
	var slider := HSlider.new()
	slider.name = "MouseSensitivity"
	slider.min_value = 0.1; slider.max_value = 3; slider.step = 0.1
	slider.value = AccessibilitySettings.mouse_sensitivity
	contents.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.mouse_sensitivity = value; InputBindingService.save())
	var invert := CheckButton.new()
	invert.text = "反转鼠标Y轴"
	invert.button_pressed = AccessibilitySettings.invert_y
	contents.add_child(invert)
	invert.toggled.connect(func(value: bool) -> void: AccessibilitySettings.invert_y = value; InputBindingService.save())
	for action in InputBindingService.ACTIONS:
		var row := HBoxContainer.new()
		contents.add_child(row)
		var label := CoreUI.label(row,str(InputBindingService.ACTIONS[action][0]),17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := CoreUI.button(row,InputBindingService.hint(action),func() -> void: begin_capture(action))
		button.custom_minimum_size.x = 200
		button.name = "Bind_"+action
		rows[action] = button
	var footer := HBoxContainer.new()
	box.add_child(footer)
	CoreUI.button(footer,"恢复默认按键",func() -> void:
		pending_action = ""; _capturing = false
		InputBindingService.restore_defaults()
		refresh(); status.text = "已恢复默认按键。")
	close_button = CoreUI.button(footer,"返回 / Esc",finish)
	close_button.grab_focus()

func begin_capture(action: String) -> void:
	pending_action = action
	status.text = "正在改绑："+str(InputBindingService.ACTIONS[action][0])+"。按新键，Esc取消。"
	# Ignore the click/key edge that activated the row.
	_capturing = false
	call_deferred("_arm_capture")

func _arm_capture() -> void:
	_capturing = not pending_action.is_empty()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not pending_action.is_empty():
			pending_action = ""; _capturing = false
			status.text = "已取消，原按键保持不变。"
		else: finish()
		return
	if not _capturing or not event.is_pressed() or event.is_echo(): return
	if not (event is InputEventKey or event is InputEventMouseButton): return
	get_viewport().set_input_as_handled()
	var error := InputBindingService.apply_binding(pending_action,InputBindingService.code_for(event))
	if not error.is_empty():
		status.text = error+" 请按其他键，或Esc取消。"
		return
	status.text = "改绑已生效："+str(InputBindingService.ACTIONS[pending_action][0])+" → "+InputBindingService.hint(pending_action)
	pending_action = ""; _capturing = false
	refresh()

func refresh() -> void:
	for action in rows: rows[action].text = InputBindingService.hint(action)

func finish() -> void:
	closed.emit()
	queue_free()
