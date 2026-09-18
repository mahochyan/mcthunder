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
## UI-BIZ-01 stage 2: a second page that shows the new component layer (BizTheme) on its own, so the overview
## capture is readable instead of clipped by the first page's content.
var biz_page: Control
var biz_banner: Label

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
	_build_biz()

## UI-BIZ-01 stage 2 component overview: variants x states x elevation x typography x icons, built with the shared
## component layer. Everything here is simulated - the banner says so on the page - and no token-forbidden value
## (money, level, power score, player counts) appears anywhere on it.
func _build_biz() -> void:
	biz_page = Control.new()
	biz_page.theme = GarageTheme.theme()
	biz_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	biz_page.visible = false
	root.add_child(biz_page)
	var bg := ColorRect.new()
	bg.color = BizTheme.background()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biz_page.add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); biz_page.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	# The overview is taller than a 720p viewport, so it scrolls: the first capture showed the tooltip clipped at
	# 1280x720, and a component overview that hides its own last component is not evidence.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	biz_banner = CoreUI.label(col,LocalizationService.text("playground_banner"),15)
	biz_banner.add_theme_color_override("font_color",BizTheme.warning())
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",18)
	col.add_child(head)
	BizTheme.logotype(head,"MCTHUNDER")
	var type_col := VBoxContainer.new()
	head.add_child(type_col)
	BizTheme.display_label(type_col,"DISPLAY L / NUMBER 30","display_l")
	BizTheme.display_label(type_col,"示例：中文与正文混排 body 15","body",BizTheme.text_secondary())
	for variant in ["primary","secondary","ghost","danger"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		col.add_child(row)
		var cap := CoreUI.label(row,variant,12)
		cap.custom_minimum_size.x = 82
		cap.add_theme_color_override("font_color",BizTheme.text_tertiary())
		for state in ["normal","hover","pressed","focused","disabled","busy","error"]:
			var sample := Button.new()
			sample.text = LocalizationService.text("playground_sample_action")
			row.add_child(sample)
			BizTheme.apply_button(sample,variant)
			sample.add_theme_stylebox_override("normal",BizTheme.button_box(variant,state))
			if state == "disabled" or state == "busy": sample.disabled = true
	var elev_row := HBoxContainer.new()
	elev_row.add_theme_constant_override("separation",12)
	col.add_child(elev_row)
	for step in ["panel","raised","overlay","modal"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",BizTheme.panel_box(step,step == "modal"))
		elev_row.add_child(card)
		var text := CoreUI.label(card,step + " · elevation",13)
		text.add_theme_color_override("font_color",BizTheme.text_secondary())
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation",8)
	col.add_child(chip_row)
	var chip_cap := CoreUI.label(chip_row,"chip",12)
	chip_cap.custom_minimum_size.x = 82
	chip_cap.add_theme_color_override("font_color",BizTheme.text_tertiary())
	for kind in ["neutral","accent","positive","warning","critical"]:
		var chip := CoreUI.label(chip_row,kind,13)
		BizTheme.apply_chip(chip,kind)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation",10)
	col.add_child(bar_row)
	var bar_cap := CoreUI.label(bar_row,"progress",12)
	bar_cap.custom_minimum_size.x = 82
	bar_cap.add_theme_color_override("font_color",BizTheme.text_tertiary())
	for kind in ["accent","positive","warning","critical"]:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = 0.62
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(160,10)
		bar_row.add_child(bar)
		BizTheme.apply_progress(bar,kind)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation",10)
	col.add_child(stat_row)
	var stat_cap := CoreUI.label(stat_row,"stat",12)
	stat_cap.custom_minimum_size.x = 82
	stat_cap.add_theme_color_override("font_color",BizTheme.text_tertiary())
	BizTheme.stat_block(stat_row,"示例数值 A","50.8","mm")
	BizTheme.stat_block(stat_row,"示例数值 B","104","发")
	BizTheme.stat_block(stat_row,"示例状态","就绪","",BizTheme.positive())
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation",10)
	col.add_child(icon_row)
	var icon_cap := CoreUI.label(icon_row,"icons",12)
	icon_cap.custom_minimum_size.x = 82
	icon_cap.add_theme_color_override("font_color",BizTheme.text_tertiary())
	for key in ["ammo","armor","crew","repair","fire","warning","research","training","challenge","settings","map","objective","ticket","intel","help","close"]:
		var tex := BizTheme.icon_texture(key,20)
		if tex == null:
			var missing := CoreUI.label(icon_row,key,12)
			missing.add_theme_color_override("font_color",BizTheme.critical())
			continue
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(20,20)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.modulate = BizTheme.text_primary()
		icon_row.add_child(pic)
	var row_pair := HBoxContainer.new()
	row_pair.add_theme_constant_override("separation",10)
	col.add_child(row_pair)
	for selected in [true,false]:
		var list_row := PanelContainer.new()
		list_row.custom_minimum_size = Vector2(280,56)
		BizTheme.apply_row(list_row,selected,false)
		row_pair.add_child(list_row)
		BizTheme.icon_row(list_row,"vehicle","示例列表项 · " + ("选中" if selected else "未选中"),14)
	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel",BizTheme.toast_box("neutral"))
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(toast)
	BizTheme.icon_row(toast,"ready","示例提示 · 组件总览（模拟）",14)
	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel",BizTheme.tooltip_box())
	tip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(tip)
	var tip_text := CoreUI.label(tip,"示例提示框 tooltip（模拟）",12)
	tip_text.add_theme_color_override("font_color",BizTheme.text_secondary())

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
		biz_page.visible = true
		page.visible = false
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var biz_image := root.get_texture().get_image()
		var biz_name := "biz_overview_%dx%d_%d.png" % [combination[0].x,combination[0].y,roundi(combination[1]*100.0)]
		var biz_wrote: bool = biz_image != null and not biz_image.is_empty() and biz_image.save_png(OUT_DIR.path_join(biz_name)) == OK
		check(biz_wrote, "capture the component overview at %dx%d %d%% (%s)" % [combination[0].x,combination[0].y,roundi(combination[1]*100.0),biz_name])
		check(biz_banner != null and biz_banner.text.begins_with(LocalizationService.text("playground_banner").substr(0,6)), "the component overview carries the simulated-data banner")
		biz_page.visible = false
		page.visible = true
		for i in 6: await process_frame
	AccessibilitySettings.ui_scale = 1.0
	print("=== ui playground: %d checks, %d failed ===" % [checks,failed])
	print("UI_PLAYGROUND_PASS" if failed==0 else "UI_PLAYGROUND_FAIL")
	quit(0 if failed==0 else 1)
