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
	dim.color = Color(0.035,0.055,0.065,1)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	var box := VBoxContainer.new()
	margin.add_child(box)
	CoreUI.label(box,LocalizationService.text("ui_51970094c3bf"),25)
	status = CoreUI.label(box,LocalizationService.text("ui_796e398d4123"),16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not InputBindingService.problem.is_empty(): status.text = InputBindingService.problem
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	CoreUI.label(contents,LocalizationService.text("ui_fb1a6280294d"),17)
	var slider := HSlider.new()
	slider.name = "MouseSensitivity"
	slider.min_value = 0.1; slider.max_value = 3; slider.step = 0.1
	slider.value = AccessibilitySettings.mouse_sensitivity
	contents.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.mouse_sensitivity = value; InputBindingService.save())
	var invert := CheckButton.new()
	invert.text = LocalizationService.text("ui_f00008176b3e")
	invert.button_pressed = AccessibilitySettings.invert_y
	contents.add_child(invert)
	invert.toggled.connect(func(value: bool) -> void: AccessibilitySettings.invert_y = value; InputBindingService.save())
	_build_accessibility(contents)
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
	CoreUI.button(footer,LocalizationService.text("ui_80899646e2a2"),func() -> void:
		pending_action = ""; _capturing = false
		InputBindingService.restore_defaults()
		refresh(); status.text = LocalizationService.text("ui_5b1f188a6993"))
	close_button = CoreUI.button(footer,LocalizationService.text("ui_67a940be6b93"),finish)
	ModalNavigation.attach(self,Callable(),func() -> bool: return not pending_action.is_empty())

func _build_accessibility(contents: VBoxContainer) -> void:
	# The garage exposes the same persisted options as the battle pause menu.
	for entry in [["CombatVolume","ui_ff685a1768df","audio_volume"],["MechanicalVolume","ui_59bcbe1288a1","mechanical_volume"],["EffectsVolume","ui_384cca984750","effects_volume"]]:
		CoreUI.label(contents,LocalizationService.text(entry[1]),17)
		var volume := HSlider.new()
		volume.name = entry[0]
		volume.min_value = 0; volume.max_value = 1; volume.step = 0.05
		volume.value = AccessibilitySettings.snapshot()[entry[2]]
		contents.add_child(volume)
		volume.value_changed.connect(func(value: float) -> void:
			AccessibilitySettings.restore({entry[2]:value}); _save_options())
	for entry in [["ui_6f063b0a223b","subtitles_enabled"],["ui_a89776152642","reduce_flashes"],["ui_b3106127e18b","stable_camera"],["ui_94589333b07b","high_contrast"]]:
		var toggle := CheckButton.new()
		toggle.text = LocalizationService.text(entry[0])
		toggle.button_pressed = AccessibilitySettings.snapshot()[entry[1]]
		contents.add_child(toggle)
		toggle.toggled.connect(func(value: bool) -> void:
			AccessibilitySettings.restore({entry[1]:value}); _save_options())
	CoreUI.label(contents,LocalizationService.text("ui_d398ffda1ee6"),17)
	var quality := OptionButton.new()
	quality.name = "EffectQuality"
	for key in ["ui_3fd47edce45b","ui_e3521db829da","ui_6bea77acefb3"]: quality.add_item(LocalizationService.text(key))
	quality.select(AccessibilitySettings.fx_level)
	contents.add_child(quality)
	quality.item_selected.connect(func(index: int) -> void: AccessibilitySettings.fx_level = index; _save_options())
	var scale_choice := OptionButton.new()
	scale_choice.name = "TextScale"
	for key in ["ui_25f82a808a30","ui_05046146bc94","ui_17e33eec1234"]: scale_choice.add_item(LocalizationService.text(key))
	scale_choice.select([1.0,1.15,1.25].find(AccessibilitySettings.ui_scale))
	contents.add_child(scale_choice)
	scale_choice.item_selected.connect(func(index: int) -> void:
		AccessibilitySettings.ui_scale = [1.0,1.15,1.25][index]; _save_options())

func _save_options() -> void:
	var error := InputBindingService.save()
	if not error.is_empty(): status.text = error
	AccessibilitySettings.apply(self)

func begin_capture(action: String) -> void:
	pending_action = action
	status.text = LocalizationService.text("ui_65734d90f6ec")+str(InputBindingService.ACTIONS[action][0])+LocalizationService.text("ui_6684b146e5b0")
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
			status.text = LocalizationService.text("ui_5cbaecc8408a")
		else: finish()
		return
	if not _capturing or not event.is_pressed() or event.is_echo(): return
	if not (event is InputEventKey or event is InputEventMouseButton): return
	get_viewport().set_input_as_handled()
	var error := InputBindingService.apply_binding(pending_action,InputBindingService.code_for(event))
	if not error.is_empty():
		status.text = error+LocalizationService.text("ui_2062040a16bd")
		return
	status.text = LocalizationService.text("ui_adeeab130fa9")+str(InputBindingService.ACTIONS[pending_action][0])+" → "+InputBindingService.hint(pending_action)
	pending_action = ""; _capturing = false
	refresh()

func refresh() -> void:
	for action in rows: rows[action].text = InputBindingService.hint(action)

func finish() -> void:
	AccessibilitySettings.apply(get_tree().root)
	closed.emit()
	queue_free()
