class_name ChallengeSelection
extends Control
signal chosen(id: String, difficulty: String)
var profile: ProfileStore
var task_choice: OptionButton
var level_choice: OptionButton
var description: Label
## WT-UI-011 (S08): rules, the recorded best and the limited-ammunition note are separate statements.
var rules_label: Label
var current_label: Label
var rounds_label: Label
var best_label: Label
var start_button: Button
var close_button: Button
func _ready() -> void:
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = BizTheme.dialog_scrim(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); add_child(panel)
	panel.add_theme_stylebox_override("panel",BizTheme.dialog_box("modal"))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var fit_panel := func() -> void:
		var extent := Vector2(minf(size.x-48,660),minf(size.y-48,800))/2
		panel.offset_left = -extent.x; panel.offset_right = extent.x
		panel.offset_top = -extent.y; panel.offset_bottom = extent.y
	resized.connect(fit_panel); fit_panel.call()
	var content := VBoxContainer.new(); panel.add_child(content)
	content.add_theme_constant_override("separation",12)
	var heading := BizTheme.display_label(content,LocalizationService.text("ui_c3ab63a9cee7"),"display_m")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = BizTheme.hairline()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)
	task_choice = OptionButton.new(); content.add_child(task_choice)
	for id in ChallengeCatalog.IDS: task_choice.add_item(ChallengeCatalog.create(id).title)
	level_choice = OptionButton.new(); content.add_child(level_choice)
	level_choice.add_item(LocalizationService.text("ui_6bea77acefb3")); level_choice.add_item(LocalizationService.text("ui_ea4e4be5a43f"))
	var scroll := ScrollContainer.new(); content.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	description = BizTheme.display_label(scroll,"","subtitle",BizTheme.text_primary()); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# WT-UI-011 (S08): the rules, the recorded best and the current-attempt note are three separate lines, and the
	# ammunition the challenge pins is stated with the config's own round count.
	rules_label = CoreUI.label(scroll,"",UiTokens.biz_type_size("body",15)); rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.add_theme_color_override("font_color",BizTheme.text_secondary())
	rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounds_label = CoreUI.label(scroll,"",UiTokens.biz_type_size("label",13)); rounds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rounds_label.add_theme_color_override("font_color",BizTheme.warning())
	current_label = CoreUI.label(content,"",UiTokens.biz_type_size("caption",11)); current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_label.add_theme_color_override("font_color",BizTheme.text_tertiary())
	best_label = CoreUI.label(content,"",UiTokens.biz_type_size("subtitle",18))
	best_label.add_theme_color_override("font_color",BizTheme.accent())
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = CoreUI.button(content,LocalizationService.text("ui_b55e53cfa123"),func() -> void: chosen.emit(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected]))
	BizTheme.apply_button(start_button,"primary","challenge")
	close_button = CoreUI.button(content,LocalizationService.text("ui_a1e90bb769ee"),queue_free)
	BizTheme.apply_button(close_button,"ghost","back")
	task_choice.item_selected.connect(func(_i: int) -> void: refresh())
	level_choice.item_selected.connect(func(_i: int) -> void: refresh())
	refresh()
	ModalNavigation.attach(self,queue_free)
	BizTheme.fade_in(self,"panel_in_ms")
func refresh() -> void:
	var c := ChallengeCatalog.create(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected])
	description.text = (LocalizationService.text("ui_d1badea77d0f") if c.vehicle == ChallengeCatalog.M36 else LocalizationService.text("ui_353a0b778237"))+MapRegistry.ENTRIES[c.map].title
	# WT-UI-011 (S08): the rules come from the catalogue's own rules text, the pinned ammunition from the config's own
	# round count, and the current attempt is stated honestly as not stored - the profile records best scores only,
	# while the attempt's own receipt is shown when it settles.
	rules_label.text = LocalizationService.text("challenge_rules")+"\n"+ChallengeCatalog.rules_text(c)
	rounds_label.text = LocalizationService.text("challenge_rounds") % int(c.rounds)
	current_label.text = LocalizationService.text("challenge_current_note")
	best_label.text = ChallengeScore.describe_best(profile.snapshot().challenge_bests.get(ChallengeCatalog.key(c),{}))
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
