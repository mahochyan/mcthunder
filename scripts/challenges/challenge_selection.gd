class_name ChallengeSelection
extends Control
signal chosen(id: String, difficulty: String)
var profile: ProfileStore
var task_choice: OptionButton
var level_choice: OptionButton
var description: Label
var best_label: Label
var start_button: Button
var close_button: Button
func _ready() -> void:
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0.025,0.04,0.05,0.96); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var fit_panel := func() -> void:
		var extent := Vector2(minf(size.x-48,660),minf(size.y-48,800))/2
		panel.offset_left = -extent.x; panel.offset_right = extent.x
		panel.offset_top = -extent.y; panel.offset_bottom = extent.y
	resized.connect(fit_panel); fit_panel.call()
	var content := VBoxContainer.new(); panel.add_child(content)
	content.add_theme_constant_override("separation",12)
	CoreUI.label(content,LocalizationService.text("ui_c3ab63a9cee7"),28)
	task_choice = OptionButton.new(); content.add_child(task_choice)
	for id in ChallengeCatalog.IDS: task_choice.add_item(ChallengeCatalog.create(id).title)
	level_choice = OptionButton.new(); content.add_child(level_choice)
	level_choice.add_item(LocalizationService.text("ui_6bea77acefb3")); level_choice.add_item(LocalizationService.text("ui_ea4e4be5a43f"))
	var scroll := ScrollContainer.new(); content.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	description = CoreUI.label(scroll,"",18); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best_label = CoreUI.label(content,"",18)
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = CoreUI.button(content,LocalizationService.text("ui_b55e53cfa123"),func() -> void: chosen.emit(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected]))
	close_button = CoreUI.button(content,LocalizationService.text("ui_a1e90bb769ee"),queue_free)
	task_choice.item_selected.connect(func(_i: int) -> void: refresh())
	level_choice.item_selected.connect(func(_i: int) -> void: refresh())
	refresh()
	ModalNavigation.attach(self,queue_free)
func refresh() -> void:
	var c := ChallengeCatalog.create(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected])
	description.text = (LocalizationService.text("ui_d1badea77d0f") if c.vehicle == ChallengeCatalog.M36 else LocalizationService.text("ui_353a0b778237"))+MapRegistry.ENTRIES[c.map].title+"\n"+ChallengeCatalog.rules_text(c)
	best_label.text = ChallengeScore.describe_best(profile.snapshot().challenge_bests.get(ChallengeCatalog.key(c),{}))
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
