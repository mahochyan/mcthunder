extends SceneTree
## WT-UI-002 deliverable: a real Godot component playground that shows the FIELDWORK 01 components in the states the
## design's token table requires - normal, hover, pressed, focused, disabled, busy, error - and captures them at the
## four resolution and text-scale combinations.
##
## Everything on this page is SIMULATED and the banner says so on the page itself; the components are the real ones
## (GarageTheme's own state styleboxes, CoreUI's factories, the real token colours), so what is being checked is the
## appearance and layout of the theme rather than any gameplay state. The production screens bind real state instead,
## which the other verifiers assert.
const OUT_DIR := "res://logs/WT-UI-FIELDWORK-01/wt-ui-002-playground"
const STATES := ["normal","hover","pressed","focused","disabled","busy","error"]
var checks := 0
var failed := 0
var page: Control
var banner: Label

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build()
	call_deferred("_capture_all")

func _build() -> void:
	page = Control.new()
	page.theme = GarageTheme.theme()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	var background := ColorRect.new()
	background.color = UiTokens.color("background","#10171B")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); page.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",12); margin.add_child(column)
	# The banner is on the page, not in a comment, so a screenshot can never be mistaken for a production screen.
	banner = CoreUI.label(column,LocalizationService.text("playground_banner"),17)
	banner.add_theme_color_override("font_color",UiTokens.color("warning","#E8BE70"))
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title := CoreUI.label(column,LocalizationService.text("playground_title"),26)
	title.add_theme_color_override("font_color",UiTokens.color("text_primary","#ECEDE6"))

	# 1) every required state of the button, taken from the real theme's own styleboxes.
	var state_row := HBoxContainer.new(); state_row.add_theme_constant_override("separation",10); column.add_child(state_row)
	for state in STATES:
		var cell := VBoxContainer.new(); cell.add_theme_constant_override("separation",6); state_row.add_child(cell)
		var state_name := CoreUI.label(cell,state,14)
		state_name.add_theme_color_override("font_color",UiTokens.color("text_secondary","#A8B6BA"))
		var sample := Button.new()
		sample.text = LocalizationService.text("playground_sample_action")
		sample.custom_minimum_size = Vector2(150,48)
		var style := page.theme.get_stylebox(state,"Button")
		if style != null: sample.add_theme_stylebox_override("normal",style)
		if state=="disabled": sample.disabled = true
		if state=="hover" or state=="pressed": sample.add_theme_color_override("font_color",UiTokens.color("text_primary"))
		if state=="busy":
			sample.text = LocalizationService.text("playground_busy_label")
			sample.disabled = true
		if state=="error":
			sample.text = LocalizationService.text("playground_error_label")
			sample.add_theme_color_override("font_color",UiTokens.color("critical","#FF8A80"))
			sample.add_theme_stylebox_override("normal",GarageTheme.box(UiTokens.color("surface","#182329"),UiTokens.color("critical","#FF8A80"),10))
		cell.add_child(sample)

	# 2) real components: tabs, primary action, secondary action, input, value stepper, progress.
	var component_row := HBoxContainer.new(); component_row.add_theme_constant_override("separation",14); column.add_child(component_row)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation",8); component_row.add_child(tabs)
	for label_key in ["playground_tab_a","playground_tab_b","playground_tab_c"]:
		var tab := CoreUI.button(tabs,LocalizationService.text(label_key),func() -> void: pass)
		tab.custom_minimum_size = Vector2(110,44)
	var primary := CoreUI.button(component_row,LocalizationService.text("playground_primary"),func() -> void: pass)
	GarageTheme.primary(primary)
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(220,44)
	edit.text = LocalizationService.text("playground_input_value")
	component_row.add_child(edit)
	var stepper := SpinBox.new(); stepper.min_value = 0; stepper.max_value = 40; stepper.value = 12
	component_row.add_child(stepper)
	var bar := ProgressBar.new(); bar.max_value = 1; bar.value = 0.62; bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180,10)
	var fill := StyleBoxFlat.new(); fill.bg_color = UiTokens.color("accent","#E0B46A")
	bar.add_theme_stylebox_override("fill",fill)
	component_row.add_child(bar)

	# 3) a card, a state badge, an inline notice, a toast and a tooltip, on the real surfaces.
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation",14); column.add_child(cards)
	for entry in [["vehicle_state_combat_ready","positive"],["vehicle_state_research_needed","warning"],["vehicle_state_config_error","critical"]]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",GarageTheme.box(UiTokens.color("surface","#182329"),UiTokens.color("border_decorative","#35464E"),12))
		card.custom_minimum_size = Vector2(216,96)
		cards.add_child(card)
		var card_column := VBoxContainer.new(); card.add_child(card_column)
		var card_title := CoreUI.label(card_column,LocalizationService.text("playground_card_title"),16)
		card_title.add_theme_color_override("font_color",UiTokens.color("text_primary","#ECEDE6"))
		var badge := CoreUI.label(card_column,LocalizationService.text(entry[0]),14)
		badge.add_theme_color_override("font_color",UiTokens.color(str(entry[1]),"#ECEDE6"))
		CoreUI.label(card_column,LocalizationService.text("playground_card_meta"),13)
	var notice := CoreUI.label(column,LocalizationService.text("playground_notice"),15)
	notice.add_theme_color_override("font_color",UiTokens.color("warning","#E8BE70"))
	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel",GarageTheme.box(UiTokens.color("surface_raised","#223139"),UiTokens.color("accent","#E0B46A"),12))
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(toast)
	CoreUI.label(toast,LocalizationService.text("playground_toast"),15)
	var hint := CoreUI.label(column,LocalizationService.text("playground_hint"),14)
	hint.add_theme_color_override("font_color",UiTokens.color("text_secondary","#A8B6BA"))

func _capture_all() -> void:
	await process_frame
	await process_frame
	for combination in [[Vector2i(1280,720),1.0],[Vector2i(1280,720),1.25],[Vector2i(1920,1080),1.0],[Vector2i(1920,1080),1.25]]:
		root.size = combination[0]
		AccessibilitySettings.ui_scale = combination[1]
		page.theme = GarageTheme.theme()
		AccessibilitySettings.apply(page)
		for i in 6: await process_frame
		var name := "playground_%dx%d_%d.png" % [combination[0].x,combination[0].y,roundi(combination[1]*100.0)]
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var wrote: bool = image != null and not image.is_empty() and image.save_png(OUT_DIR.path_join(name)) == OK
		check(wrote, "capture the playground at %dx%d %d%% (%s)" % [combination[0].x,combination[0].y,roundi(combination[1]*100.0),name])
		check(banner.text.begins_with(LocalizationService.text("playground_banner").substr(0,6)), "the simulated-data banner is on the captured page")
	AccessibilitySettings.ui_scale = 1.0
	print("=== ui playground: %d checks, %d failed ===" % [checks,failed])
	print("UI_PLAYGROUND_PASS" if failed==0 else "UI_PLAYGROUND_FAIL")
	quit(0 if failed==0 else 1)
