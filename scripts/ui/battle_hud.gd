class_name BattleHUD
extends Control
signal board_closed
signal settings_closed
signal settings_changed
signal replay_close_requested
var view_model: Dictionary = {}
var main_margin: MarginContainer
var header: PanelContainer
var own_panel: PanelContainer
var weapon_panel: PanelContainer
var map_panel: PanelContainer
var map_title: Label
var title_label: Label
var clock_label: Label
var ticket_label: Label
var point_label: Label
var capture_bar: ProgressBar
var capture_fill: StyleBoxFlat
var objective_strip: HBoxContainer
var objective_cards: Array[Dictionary] = []
var crew_label: Label
var module_grid: GridContainer
var module_labels: Dictionary = {}
var speed_label: Label
var weapon_label: Label
var optics_label: Label
var ammo_label: Label
## WT-UI-007 (S04): chambered round, carried round, next-round choice and total stock are four separate lines.
var chamber_label: Label
var carrying_label: Label
var next_label: Label
var stock_label: Label
## Which token layout row was applied, recorded so a reviewer can read it instead of inferring it.
var layout_token_source := ""
var reload_bar: ProgressBar
var drive_label: Label
var reason_label: Label
var fire_label: Label
var action_label: Label
var feedback_label: Label
var action_bar: ProgressBar
var footer: Label
var minimap: MinimapPresenter
var scoreboard: Control
var scoreboard_panel: PanelContainer
var board_rows: GridContainer
var board_close_button: Button
var settings_root: Control
var settings_panel: PanelContainer
var settings_close_button: Button
var scale_choice: OptionButton
var flashes_toggle: CheckButton
var camera_toggle: CheckButton
var replay_toggle: CheckButton
var contrast_toggle: CheckButton
var replay_controls: Control
var replay_close_button: Button
var actual_screen_point := Vector2.ZERO
var intent_screen_point := Vector2.ZERO
var intent_visible := false
var aim_visible := false
var aim_allowed := false
var notice := ""
## WT-UI-008 (S05): at most one key prompt near the centre, secondary notices queued in a corner, repeats merged.
var notice_center: Label
var notice_corner: VBoxContainer
var notices: Array[Dictionary] = []
var _last_notice := ""
var _last_hit := ""
var input_settings: InputSettingsPanel
var _last_roster := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = CoreUI.theme()
	_build()
	apply_layout_tokens()
	resized.connect(apply_layout_tokens)
	AccessibilitySettings.apply(self)

func _label(parent: Node, value: String, font_size: int = 16) -> Label:
	var label := CoreUI.label(parent,value,font_size)
	label.set_meta("hud_font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
func _column(parent: Node, separation: int = 5) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box
func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# WT-UI-007: HUD panels take the token surface with a decorative edge, the token radius and the token padding.
	style.bg_color = Color(UiTokens.color("surface","#182329"),0.88)
	style.border_color = UiTokens.color("border_decorative","#35464E")
	style.set_border_width_all(int(UiTokens.metric("components.border",1.0)))
	style.set_content_margin_all(int(UiTokens.metric("components.panel_padding",16.0)))
	style.set_corner_radius_all(int(UiTokens.metric("components.radius",4.0)))
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

## WT-UI-007 (S04): the panel initial sizes come from the design tokens, choosing the compact or wide row from the
## effective UI width. Sizes stay initial values - a panel that needs more room still grows.
func apply_layout_tokens() -> void:
	var width := get_viewport_rect().size.x
	var compact := width < float(UiTokens.metric("layouts.standard.minimum_width",1360.0))
	var prefix := "hud_compact" if compact else "hud_wide"
	var objective_box := UiTokens.metric_array("layouts."+prefix+".objective",[640.0,64.0])
	var own_box := UiTokens.metric_array("layouts."+prefix+".own_vehicle",[280.0,184.0])
	var ammo_box := UiTokens.metric_array("layouts."+prefix+".ammo",[360.0,104.0])
	var map_box := UiTokens.metric_array("layouts."+prefix+".minimap",[224.0,224.0])
	if objective_box.size()==2 and header != null:
		header.custom_minimum_size = Vector2(float(objective_box[0]),float(objective_box[1]))
	if own_box.size()==2 and own_panel != null:
		own_panel.custom_minimum_size = Vector2(float(own_box[0]),float(own_box[1]))
	if ammo_box.size()==2 and weapon_panel != null:
		weapon_panel.custom_minimum_size = Vector2(float(ammo_box[0]),float(ammo_box[1]))
	if map_box.size()==2 and map_panel != null:
		map_panel.custom_minimum_size = Vector2(float(map_box[0]),float(map_box[1]))
	if map_box.size()==2 and minimap != null:
		minimap.custom_minimum_size = Vector2(float(map_box[0]),float(map_box[1]))
	layout_token_source = prefix
func _bar(parent: Node) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar
func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := CoreUI.button(parent,label,callback)
	button.set_meta("hud_font_size",17)
	return button

func _build() -> void:
	main_margin = MarginContainer.new()
	add_child(main_margin)
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","right","top","bottom"]: main_margin.add_theme_constant_override("margin_"+side,16)
	var stack := _column(main_margin,10)
	# WT-UI-007 (S04): the objective bar is a top-centre panel rather than a full-width strip, so the centre of the
	# screen stays clear; the side expanders keep it centred.
	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header_row)
	var header_left := Control.new(); header_left.mouse_filter = Control.MOUSE_FILTER_IGNORE; header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header_row.add_child(header_left)
	header = _panel(header_row)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var header_right := Control.new(); header_right.mouse_filter = Control.MOUSE_FILTER_IGNORE; header_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header_row.add_child(header_right)
	# WT-UI-008 (S05): one transient key prompt near the centre - the design's clear-region rule exempts a short
	# essential message, and it stays hidden whenever there is nothing to say - plus a corner queue for secondary
	# notices, placed outside the centre clear region.
	notice_center = _label(self,"",18)
	notice_center.set_anchors_preset(Control.PRESET_CENTER)
	notice_center.offset_left = -320.0
	notice_center.offset_right = 320.0
	notice_center.offset_top = 30.0
	notice_center.offset_bottom = 60.0
	notice_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_center.visible = false
	notice_corner = VBoxContainer.new()
	notice_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_corner.add_theme_constant_override("separation",4)
	notice_corner.alignment = BoxContainer.ALIGNMENT_END
	add_child(notice_corner)
	notice_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notice_corner.offset_left = -330.0
	notice_corner.offset_top = 104.0
	notice_corner.offset_right = -20.0
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation",24)
	header.add_child(top)
	var objective := _column(top,3)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.size_flags_stretch_ratio = 1.4
	title_label = _label(objective,LocalizationService.text("ui_242f2e9387de"),22)
	# WT-UI-007: the token size is an INITIAL size, so the top-centre panel grows to its content instead of wrapping
	# the objective or the ticket line; these labels keep single lines and widen the panel.
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	point_label = _label(objective,LocalizationService.text("ui_bf262136b7c6"),15)
	point_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var totals := _column(top,3)
	totals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticket_label = _label(totals,LocalizationService.text("ui_799ec9f66823"),22)
	ticket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	capture_bar = _bar(totals)
	capture_fill = StyleBoxFlat.new()
	capture_fill.bg_color = Color("72c9ee")
	capture_bar.add_theme_stylebox_override("fill",capture_fill)
	clock_label = _label(top,"10:00",25)
	clock_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	clock_label.custom_minimum_size.x = 100
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_strip = HBoxContainer.new()
	objective_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_strip.add_theme_constant_override("separation",8)
	objective_strip.visible = false
	stack.add_child(objective_strip)
	for i in BattleObjectives.MAX_POINTS:
		var panel := _panel(objective_strip)
		var column := _column(panel,3)
		var label := _label(column,"",15)
		var bar := _bar(column)
		var fill := StyleBoxFlat.new()
		bar.add_theme_stylebox_override("fill",fill)
		objective_cards.append({"panel":panel,"label":label,"bar":bar,"fill":fill})
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(space)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation",12)
	stack.add_child(bottom)
	own_panel = _panel(bottom)
	own_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	own_panel.custom_minimum_size.x = 330
	own_panel.size_flags_stretch_ratio = 1.05
	var own := _column(own_panel,7)
	crew_label = _label(own,LocalizationService.text("ui_169d49f4accf"),18)
	module_grid = GridContainer.new()
	module_grid.columns = 2
	module_grid.add_theme_constant_override("h_separation",12)
	module_grid.add_theme_constant_override("v_separation",3)
	module_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.add_child(module_grid)
	drive_label = _label(own,LocalizationService.text("ui_8642a98dce3b"),15)
	weapon_panel = _panel(bottom)
	weapon_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	weapon_panel.custom_minimum_size.x = 330
	weapon_panel.size_flags_stretch_ratio = 1.25
	var gun := _column(weapon_panel,5)
	var gun_row := HBoxContainer.new()
	gun_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun.add_child(gun_row)
	weapon_label = _label(gun_row,LocalizationService.text("ui_491169f99fb7"),20)
	speed_label = _label(gun_row,"0 km/h",17)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# WT-UI-007: the overview shares the weapon row instead of taking a line of its own, which keeps this panel
	# inside the bottom band the token layout reserves (the four separate semantics below carry the detail).
	ammo_label = _label(gun_row,LocalizationService.text("ui_d80df5f8d545"),15)
	# WT-UI-007 (S04): the four ammunition semantics stay separate but compact - a two-column grid keeps each one
	# clearly labelled while holding the panel inside the bottom band the token layout reserves for it.
	var ammo_grid := GridContainer.new()
	ammo_grid.columns = 2
	ammo_grid.add_theme_constant_override("h_separation",12)
	ammo_grid.add_theme_constant_override("v_separation",2)
	ammo_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun.add_child(ammo_grid)
	chamber_label = _label(ammo_grid,"",16)
	carrying_label = _label(ammo_grid,"",14)
	next_label = _label(ammo_grid,"",14)
	stock_label = _label(ammo_grid,"",14)
	reload_bar = _bar(gun)
	reason_label = _label(gun,"",15)
	optics_label = _label(gun,"",15)
	optics_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	optics_label.custom_minimum_size.x=300
	# WT-UI-007 (S05): the recovery actions belong to this vehicle, so they sit in the own-vehicle panel; the shot
	# feedback stays with the weapon because it is a weapon result. This also keeps the centre-bottom panel inside
	# the bottom band the token layout reserves, instead of growing up into the clear region.
	fire_label = _label(own,LocalizationService.text("ui_a9f80686bf4a"),16)
	action_label = _label(own,LocalizationService.text("ui_ae2b01ef58c0"),15)
	action_bar = _bar(own)
	feedback_label = _label(gun,"",14)
	map_panel = _panel(bottom)
	map_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	map_panel.custom_minimum_size.x = 238
	var map_column := _column(map_panel,3)
	map_title = _label(map_column,LocalizationService.text("ui_c6bcea634489"),15)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap = MinimapPresenter.new()
	map_column.add_child(minimap)
	_label(map_column,LocalizationService.text("ui_0ade9822239e"),12)
	footer = _label(stack,LocalizationService.text("ui_294a2983f4f9"),14)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard = _modal()
	scoreboard_panel = _modal_panel(scoreboard,Vector2(760,0))
	var board := _column(scoreboard_panel,12)
	_label(board,LocalizationService.text("ui_24dbbe5b10bb"),24)
	_label(board,LocalizationService.text("ui_d8e12030a6ee"),16)
	board_rows = GridContainer.new()
	board_rows.columns = 3
	board_rows.add_theme_constant_override("h_separation",32)
	board_rows.add_theme_constant_override("v_separation",5)
	board.add_child(board_rows)
	board_close_button = _button(board,LocalizationService.text("ui_c5a1df8d6cbb"),func() -> void: board_closed.emit())
	# Tab remains the scoreboard toggle; use native focus on its close button.
	scoreboard.visibility_changed.connect(func() -> void:
		if scoreboard.is_visible_in_tree(): board_close_button.call_deferred("grab_focus"))
	settings_root = _modal()
	settings_panel = _modal_panel(settings_root,Vector2(550,0))
	var settings_scroll:=ScrollContainer.new()
	settings_scroll.follow_focus = true
	settings_scroll.custom_minimum_size=Vector2(0,460)
	settings_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(settings_scroll)
	var settings := _column(settings_scroll,8)
	settings.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_label(settings,LocalizationService.text("ui_7a35569d9e07"),25)
	_button(settings,LocalizationService.text("ui_eb9bb060c217"),func() -> void:
		if is_instance_valid(input_settings): return
		input_settings = InputSettingsPanel.new()
		add_child(input_settings))
	_label(settings,LocalizationService.text("ui_b6d09fd8dd56"),17)
	scale_choice = OptionButton.new()
	for label in [LocalizationService.text("ui_25f82a808a30"),LocalizationService.text("ui_05046146bc94"),LocalizationService.text("ui_17e33eec1234")]: scale_choice.add_item(label)
	scale_choice.select([1.0,1.15,1.25].find(AccessibilitySettings.ui_scale))
	settings.add_child(scale_choice)
	scale_choice.item_selected.connect(func(index: int) -> void: AccessibilitySettings.ui_scale = [1.0,1.15,1.25][index]; _changed())
	flashes_toggle = _toggle(settings,LocalizationService.text("ui_a89776152642"),AccessibilitySettings.reduce_flashes,func(on: bool) -> void: AccessibilitySettings.reduce_flashes = on)
	camera_toggle = _toggle(settings,LocalizationService.text("ui_b3106127e18b"),AccessibilitySettings.stable_camera,func(on: bool) -> void: AccessibilitySettings.stable_camera = on)
	replay_toggle = _toggle(settings,LocalizationService.text("ui_c271e464624b"),AccessibilitySettings.replay_enabled,func(on: bool) -> void: AccessibilitySettings.replay_enabled = on)
	contrast_toggle = _toggle(settings,LocalizationService.text("ui_94589333b07b"),AccessibilitySettings.high_contrast,func(on: bool) -> void: AccessibilitySettings.high_contrast = on)
	_label(settings,LocalizationService.text("ui_ff685a1768df"),17)
	var audio_slider:=HSlider.new(); audio_slider.name="CombatVolume"
	audio_slider.min_value=0; audio_slider.max_value=1; audio_slider.step=0.05; audio_slider.value=AccessibilitySettings.audio_volume
	settings.add_child(audio_slider)
	audio_slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.audio_volume=value; _changed())
	for group in ["mechanical","effects"]:
		_label(settings,LocalizationService.text("ui_59bcbe1288a1") if group == "mechanical" else LocalizationService.text("ui_384cca984750"),17)
		var group_slider := HSlider.new()
		group_slider.name = "MechanicalVolume" if group == "mechanical" else "EffectsVolume"
		group_slider.min_value = 0; group_slider.max_value = 1; group_slider.step = 0.05
		group_slider.value = AccessibilitySettings.mechanical_volume if group == "mechanical" else AccessibilitySettings.effects_volume
		settings.add_child(group_slider)
		group_slider.value_changed.connect(func(value: float) -> void:
			if group == "mechanical": AccessibilitySettings.mechanical_volume = value
			else: AccessibilitySettings.effects_volume = value
			_changed())
	_toggle(settings,LocalizationService.text("ui_6f063b0a223b"),AccessibilitySettings.subtitles_enabled,func(on: bool) -> void: AccessibilitySettings.subtitles_enabled = on)
	_label(settings,LocalizationService.text("ui_d398ffda1ee6"),17)
	var effect_choice:=OptionButton.new(); effect_choice.name="EffectQuality"
	for label in [LocalizationService.text("ui_3fd47edce45b"),LocalizationService.text("ui_e3521db829da"),LocalizationService.text("ui_6bea77acefb3")]: effect_choice.add_item(label)
	effect_choice.select(AccessibilitySettings.fx_level); settings.add_child(effect_choice)
	effect_choice.item_selected.connect(func(index: int) -> void: AccessibilitySettings.fx_level=index; _changed())
	_label(settings,LocalizationService.text("ui_0fd5388e76d2"),17)
	var shake_slider:=HSlider.new(); shake_slider.name="ShakeStrength"
	shake_slider.min_value=0; shake_slider.max_value=1; shake_slider.step=0.05; shake_slider.value=AccessibilitySettings.shake_strength
	settings.add_child(shake_slider)
	shake_slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.shake_strength=value; _changed())
	_label(settings,LocalizationService.text("ui_fe590be7165b"),14)
	settings_close_button = _button(settings,LocalizationService.text("ui_342631f09db9"),func() -> void: settings_closed.emit())
	ModalNavigation.attach(settings_root)
	replay_controls = Control.new()
	add_child(replay_controls)
	replay_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_controls.offset_left = -130
	replay_controls.offset_right = 130
	replay_controls.offset_top = 20
	replay_controls.offset_bottom = 70
	replay_close_button = _button(replay_controls,LocalizationService.text("ui_02623cd034c6"),func() -> void: replay_close_requested.emit())
	replay_close_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_controls.visible = false

func _toggle(parent: Node, label: String, initial: bool, setter: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = label
	button.button_pressed = initial
	button.set_meta("hud_font_size",17)
	parent.add_child(button)
	button.toggled.connect(func(on: bool) -> void: setter.call(on); _changed())
	return button
## WT-UI-008 (S05): one key prompt at a time near the centre, secondary notices in the corner queue, and a repeated
## key merges into the existing line with a count instead of stacking. A critical notice never expires.
func push_notice(text: String, key: String, ttl: float = 4.0, critical: bool = false) -> void:
	if text.is_empty(): return
	for item in notices:
		if str(item.key) != key: continue
		item.count = int(item.count)+1
		item.text = text if int(item.count) <= 1 else "%s  ×%d" % [text,int(item.count)]
		item.remaining = maxf(float(item.remaining),ttl)
		if critical: item.critical = true
		_refresh_notices()
		return
	notices.append({"key":key,"text":text,"remaining":ttl,"critical":critical,"count":1})
	_refresh_notices()

func _refresh_notices() -> void:
	if notice_center == null: return
	var center_text := ""
	for item in notices:
		if not str(item.text).is_empty(): center_text = str(item.text); break
	notice_center.text = center_text
	notice_center.visible = not center_text.is_empty()
	if notice_corner == null: return
	for child in notice_corner.get_children(): child.free()
	var shown := 0
	for index in notices.size():
		if index == 0: continue
		if shown >= 4: break
		var row := GarageTheme.text(notice_corner,str(notices[index].text),13,GarageTheme.MUTED)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shown += 1

func _tick_notices(delta: float) -> void:
	if notices.is_empty(): return
	var kept: Array[Dictionary] = []
	for item in notices:
		if bool(item.critical): kept.append(item); continue
		item.remaining = float(item.remaining)-delta
		if float(item.remaining) > 0.0: kept.append(item)
	if kept.size() != notices.size():
		notices = kept
		_refresh_notices()

func _changed() -> void:
	InputBindingService.save()
	AccessibilitySettings.apply(self)
	minimap.high_contrast = AccessibilitySettings.high_contrast
	settings_changed.emit()
func _modal() -> Control:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.04,0.05,0.78)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	return root
func _modal_panel(parent: Control, minimum: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	center.add_child(panel)
	return panel

func present(model: Dictionary, intel: Dictionary, camera: Camera3D, roster: Array) -> void:
	if model.is_empty(): return
	view_model = model.duplicate(true)
	var info: Dictionary = model.match
	title_label.text = info.title
	clock_label.text = "%02d:%02d"%[int(info.remaining)/60,int(info.remaining)%60]
	point_label.text = info.objective
	if info.phase == "countdown": point_label.text = LocalizationService.text("ui_d3578b3e7f8c")%ceili(info.countdown)
	ticket_label.text = info.tickets_text
	var points: Array = info.get("objectives",[])
	objective_strip.visible = points.size() > 1
	for i in objective_cards.size():
		var card := objective_cards[i]
		card.panel.visible = i < points.size()
		if i >= points.size(): continue
		var row: Dictionary = points[i]
		var owner: int = int(row.owner)
		var label: String = "争夺中" if row.contested else {0:"中立",1:"友军控制",2:"敌军控制"}[owner]
		card.label.text = "%s  ·  %s  %d%%"%[row.id,label,roundi(absf(row.progress)*100)]
		card.label.modulate = Color("ffe135") if row.contested else RiverObjectiveHUD.COLORS[owner]
		card.bar.value = absf(row.progress)
		card.fill.bg_color = RiverObjectiveHUD.COLORS[1 if row.progress >= 0 else 2]
	capture_bar.visible = info.get("team_mode",false) and not objective_strip.visible
	capture_bar.value = absf(float(info.get("capture_progress",0)))
	capture_fill.bg_color = Color("72c9ee") if float(info.get("capture_progress",0))>=0 else Color("ffc47e")
	crew_label.text = LocalizationService.text("ui_b80473d17af7")%[model.crew_alive,model.crew.size()]
	var missing: Array[String] = []
	for person in model.crew:
		if not person.available: missing.append(person.name+LocalizationService.text("ui_7c0037eb0d6e"))
	if not missing.is_empty(): crew_label.text += "\n"+" · ".join(missing)
	for module in model.modules:
		if not module_labels.has(module.id): module_labels[module.id] = _label(module_grid,"",14)
		var label: Label = module_labels[module.id]
		# Keep the driving view clear; damage appears immediately and the full
		# component list remains available while the battle overview is open.
		label.visible = module.fraction < 1.0 or scoreboard.visible
		label.text = ("× " if module.fraction <= 0 else ("! " if module.fraction < 1 else "· "))+module.name+" "+module.status
		label.modulate = Color("ffca80") if module.fraction < 1 else Color("d7e2dc")
	drive_label.text = LocalizationService.text("ui_8642a98dce3b") if model.drive_text.is_empty() else LocalizationService.text("ui_2646035954a7")+model.drive_text
	if model.destroyed: drive_label.text = LocalizationService.text("ui_21777ac7fa81")
	speed_label.text = "%.0f km/h"%model.speed_kph
	weapon_label.text = model.weapon_status
	weapon_label.modulate = Color("a6deb5") if model.ready else Color("ffcf8f")
	var error := float(model.get("aim_error_degrees",0))
	var optics: String=model.get("optics_text","")
	if not model.get("observing",false):
		var tracking := LocalizationService.text("optics_tracking")%error if error>0.5 else LocalizationService.text("optics_aligned")
		optics=(optics+" · " if not optics.is_empty() else "")+tracking
	optics_label.text=optics
	optics_label.modulate=Color("ffcf8f") if error>0.5 else Color("d7e2dc")
	# WT-UI-007 (S04): chambered round, carried round, next-round choice and remaining stock are four separate lines,
	# all fed by real AmmoInventory state (chamber_shell / transfer_shell / selected_shell / shell_counts).
	var chamber_id := str(model.get("chamber_shell_label",""))
	chamber_label.text = LocalizationService.text("hud_chamber_line")%(chamber_id if not chamber_id.is_empty() else LocalizationService.text("ui_609f061f5455"))
	var carrying_id := str(model.get("carrying_shell_label",""))
	carrying_label.text = LocalizationService.text("hud_carrying_line")%carrying_id if not carrying_id.is_empty() else LocalizationService.text("hud_carrying_none")
	var next_id := str(model.get("next_shell_label",""))
	if next_id.is_empty():
		next_label.text = ""
	else:
		var quick_keys := InputBindingService.hint("shell_1")
		if int(model.get("shell_option_count",2)) > 1: quick_keys += "/"+InputBindingService.hint("shell_2")
		next_label.text = LocalizationService.text("hud_next_line")%[next_id,quick_keys]
	stock_label.text = LocalizationService.text("hud_stock_line")%[model.ammo,model.chamber]
	ammo_label.text = LocalizationService.text("hud_ammo_overview")%[model.shell,model.ammo]
	if not str(model.get("supply_status","")).is_empty(): stock_label.text += "  ·  "+str(model.supply_status)
	# WT-UI-008 (S05): the footer notice becomes one key prompt near the centre, repeats merge, and the immediate hit
	# feedback is pushed the same way so it can never stack up with older lines.
	if not notice.is_empty() and notice != _last_notice:
		push_notice(notice,"notice",4.0,false)
		_last_notice = notice
	var hit_text := str(model.get("hit_feedback_text",""))
	if not hit_text.is_empty() and hit_text != _last_hit:
		push_notice(hit_text,"hit",2.5,false)
		_last_hit = hit_text
	_tick_notices(get_process_delta_time())
	reload_bar.value = clampf(1-float(model.cooldown)/maxf(0.01,float(model.reload_time)),0,1)
	reason_label.text = model.weapon_text
	reason_label.visible = not reason_label.text.is_empty()
	fire_label.text = (LocalizationService.text("ui_73f499124c16")+InputBindingService.hint("extinguish")+LocalizationService.text("ui_78301da205f2") if model.fire else InputBindingService.hint("extinguish")+LocalizationService.text("ui_78301da205f2"))+LocalizationService.text("ui_b0961cda3a16")%model.extinguishers
	if model.protection > 0: fire_label.text = LocalizationService.text("ui_d5214972f31e")%model.protection
	action_label.text = model.action if not model.action.is_empty() else InputBindingService.recovery_hint()
	action_bar.visible = model.action_duration > 0
	action_bar.value = float(model.action_progress)/maxf(0.01,float(model.action_duration))
	feedback_label.text = str(model.get("hit_feedback_text","")) if not str(model.get("hit_feedback_text","")).is_empty() else "\n".join([model.shot_feedback,model.recovery_feedback]).strip_edges()
	feedback_label.visible = not feedback_label.text.is_empty()
	minimap.present_observations(intel,int(info.get("owner",0)),points)
	footer.text = notice if not notice.is_empty() else InputBindingService.driving_hint()+" · "+InputBindingService.hint("scoreboard")+LocalizationService.text("ui_496113d4c2a8")+InputBindingService.hint("pause")+LocalizationService.text("ui_4414425d80fe")
	board_close_button.text = LocalizationService.text("ui_9c9ad4457fc6")+InputBindingService.hint("scoreboard")
	replay_close_button.text = LocalizationService.text("ui_24788e717f91")+InputBindingService.hint("replay_toggle")
	var summary := str(roster)
	if summary != _last_roster:
		_last_roster = summary
		for child in board_rows.get_children(): child.queue_free()
		for heading in [LocalizationService.text("ui_0ca70852746f"),LocalizationService.text("ui_1053fbb75f9a"),LocalizationService.text("ui_86158e1abfe4")]: _label(board_rows,heading,17)
		for row in roster:
			_label(board_rows,row.id+(LocalizationService.text("ui_0eda416b0416") if row.id == model.entity_id else ""),16)
			_label(board_rows,LocalizationService.text("ui_589de4ba883b") if row.friendly else LocalizationService.text("ui_2935afb61a4b"),16)
			_label(board_rows,str(row.deaths),16)
		AccessibilitySettings.apply(board_rows)
	aim_visible = not model.destroyed and info.phase == "playing" and is_instance_valid(camera) and not camera.is_position_behind(model.actual_point)
	if aim_visible: actual_screen_point = camera.unproject_position(model.actual_point)
	intent_visible=is_instance_valid(camera) and model.has("intent_point") and not camera.is_position_behind(model.intent_point)
	if intent_visible: intent_screen_point=camera.unproject_position(model.intent_point)
	queue_redraw()
func _draw() -> void:
	if not aim_allowed or not main_margin.visible or scoreboard.visible or settings_root.visible: return
	var center := size/2
	draw_line(center+Vector2(-7,0),center+Vector2(7,0),Color(1,1,1,0.65),1.5,true)
	draw_line(center+Vector2(0,-7),center+Vector2(0,7),Color(1,1,1,0.65),1.5,true)
	if view_model.get("observing",false): return
	if intent_visible and Rect2(Vector2.ZERO,size).has_point(intent_screen_point): draw_arc(intent_screen_point,7,0,TAU,32,Color(1,1,1,0.7),1.5,true)
	if aim_visible and Rect2(Vector2.ZERO,size).has_point(actual_screen_point):
		var color := Color("b5edba") if view_model.get("ready",false) and float(view_model.get("aim_error_degrees",0))<=0.5 else Color("ffd492")
		draw_arc(actual_screen_point,11,0,TAU,40,color,2,true)
		draw_circle(actual_screen_point,2,color)
