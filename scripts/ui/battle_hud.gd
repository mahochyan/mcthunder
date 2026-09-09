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
var crew_label: Label
var module_grid: GridContainer
var module_labels: Dictionary = {}
var speed_label: Label
var weapon_label: Label
var ammo_label: Label
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
var aim_visible := false
var aim_allowed := false
var notice := ""
var input_settings: InputSettingsPanel
var _last_roster := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = CoreUI.theme()
	_build()
	AccessibilitySettings.apply(self)

func _label(parent: Node, value: String, font_size: int = 16) -> Label:
	var label := CoreUI.label(parent,value,roundi(font_size*AccessibilitySettings.ui_scale))
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
	style.bg_color = Color(0.055,0.09,0.11,0.86)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel
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
	header = _panel(stack)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation",24)
	header.add_child(top)
	var objective := _column(top,3)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.size_flags_stretch_ratio = 1.4
	title_label = _label(objective,"占领据点 A",22)
	point_label = _label(objective,"驶入圆圈，并守住据点",15)
	var totals := _column(top,3)
	totals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticket_label = _label(totals,"△ 友方 300   ◆ 敌方 300",22)
	ticket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_bar = _bar(totals)
	capture_fill = StyleBoxFlat.new()
	capture_fill.bg_color = Color("72c9ee")
	capture_bar.add_theme_stylebox_override("fill",capture_fill)
	clock_label = _label(top,"10:00",25)
	clock_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	clock_label.custom_minimum_size.x = 100
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	crew_label = _label(own,"乘员 5 / 5",18)
	module_grid = GridContainer.new()
	module_grid.columns = 2
	module_grid.add_theme_constant_override("h_separation",12)
	module_grid.add_theme_constant_override("v_separation",3)
	module_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.add_child(module_grid)
	drive_label = _label(own,"动力正常",15)
	weapon_panel = _panel(bottom)
	weapon_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	weapon_panel.custom_minimum_size.x = 330
	weapon_panel.size_flags_stretch_ratio = 1.25
	var gun := _column(weapon_panel,5)
	var gun_row := HBoxContainer.new()
	gun_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun.add_child(gun_row)
	weapon_label = _label(gun_row,"可开火",20)
	speed_label = _label(gun_row,"0 km/h",17)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _label(gun,"AP120  ·  30 发",17)
	reload_bar = _bar(gun)
	reason_label = _label(gun,"",15)
	fire_label = _label(gun,"F 灭火 × 2",16)
	action_label = _label(gun,"T 维修   C 替补   G 取消动作",15)
	action_bar = _bar(gun)
	feedback_label = _label(gun,"",14)
	map_panel = _panel(bottom)
	map_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	map_panel.custom_minimum_size.x = 238
	var map_column := _column(map_panel,3)
	map_title = _label(map_column,"战术地图  ↑ 北",15)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap = MinimapPresenter.new()
	map_column.add_child(minimap)
	_label(map_column,"▲ 自己/友军  ◆ 目击敌人\n◇? 最后位置（最多6秒）",12)
	footer = _label(stack,"W/S A/D 驾驶 · 右键炮镜 · 左键开火 · Tab 战况 · Esc 菜单",14)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard = _modal()
	scoreboard_panel = _modal_panel(scoreboard,Vector2(760,0))
	var board := _column(scoreboard_panel,12)
	_label(board,"战况 · 比赛仍在继续",24)
	_label(board,"△ 友军    ◆ 敌军    仅展示公开出局次数",16)
	board_rows = GridContainer.new()
	board_rows.columns = 3
	board_rows.add_theme_constant_override("h_separation",32)
	board_rows.add_theme_constant_override("v_separation",5)
	board.add_child(board_rows)
	board_close_button = _button(board,"关闭战况 / Tab",func() -> void: board_closed.emit())
	settings_root = _modal()
	settings_panel = _modal_panel(settings_root,Vector2(550,0))
	var settings_scroll:=ScrollContainer.new()
	settings_scroll.custom_minimum_size=Vector2(0,460)
	settings_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(settings_scroll)
	var settings := _column(settings_scroll,8)
	settings.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_label(settings,"显示与辅助",25)
	_button(settings,"按键与鼠标设置",func() -> void:
		if is_instance_valid(input_settings): return
		input_settings = InputSettingsPanel.new()
		add_child(input_settings))
	_label(settings,"HUD 字号",17)
	scale_choice = OptionButton.new()
	for label in ["标准 100%","较大 115%","大字 125%"]: scale_choice.add_item(label)
	scale_choice.select([1.0,1.15,1.25].find(AccessibilitySettings.ui_scale))
	settings.add_child(scale_choice)
	scale_choice.item_selected.connect(func(index: int) -> void: AccessibilitySettings.ui_scale = [1.0,1.15,1.25][index]; _changed())
	flashes_toggle = _toggle(settings,"减少炮口闪光",AccessibilitySettings.reduce_flashes,func(on: bool) -> void: AccessibilitySettings.reduce_flashes = on)
	camera_toggle = _toggle(settings,"稳定镜头（关闭射击震动）",AccessibilitySettings.stable_camera,func(on: bool) -> void: AccessibilitySettings.stable_camera = on)
	replay_toggle = _toggle(settings,"允许结算后查看实弹回放",AccessibilitySettings.replay_enabled,func(on: bool) -> void: AccessibilitySettings.replay_enabled = on)
	contrast_toggle = _toggle(settings,"高对比标记（形状区分友敌）",AccessibilitySettings.high_contrast,func(on: bool) -> void: AccessibilitySettings.high_contrast = on)
	_label(settings,"战斗音量",17)
	var audio_slider:=HSlider.new(); audio_slider.name="CombatVolume"
	audio_slider.min_value=0; audio_slider.max_value=1; audio_slider.step=0.05; audio_slider.value=AccessibilitySettings.audio_volume
	settings.add_child(audio_slider)
	audio_slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.audio_volume=value; _changed())
	for group in ["mechanical","effects"]:
		_label(settings,"发动机与机械音量" if group == "mechanical" else "射击与战斗事件音量",17)
		var group_slider := HSlider.new()
		group_slider.name = "MechanicalVolume" if group == "mechanical" else "EffectsVolume"
		group_slider.min_value = 0; group_slider.max_value = 1; group_slider.step = 0.05
		group_slider.value = AccessibilitySettings.mechanical_volume if group == "mechanical" else AccessibilitySettings.effects_volume
		settings.add_child(group_slider)
		group_slider.value_changed.connect(func(value: float) -> void:
			if group == "mechanical": AccessibilitySettings.mechanical_volume = value
			else: AccessibilitySettings.effects_volume = value
			_changed())
	_toggle(settings,"附近战斗声音字幕",AccessibilitySettings.subtitles_enabled,func(on: bool) -> void: AccessibilitySettings.subtitles_enabled = on)
	_label(settings,"特效数量",17)
	var effect_choice:=OptionButton.new(); effect_choice.name="EffectQuality"
	for label in ["关闭","较少","标准"]: effect_choice.add_item(label)
	effect_choice.select(AccessibilitySettings.fx_level); settings.add_child(effect_choice)
	effect_choice.item_selected.connect(func(index: int) -> void: AccessibilitySettings.fx_level=index; _changed())
	_label(settings,"震动强度（取消稳定镜头后生效）",17)
	var shake_slider:=HSlider.new(); shake_slider.name="ShakeStrength"
	shake_slider.min_value=0; shake_slider.max_value=1; shake_slider.step=0.05; shake_slider.value=AccessibilitySettings.shake_strength
	settings.add_child(shake_slider)
	shake_slider.value_changed.connect(func(value: float) -> void: AccessibilitySettings.shake_strength=value; _changed())
	_label(settings,"这些选项不改变弹道、装填与车辆性能。",14)
	settings_close_button = _button(settings,"返回暂停菜单",func() -> void: settings_closed.emit())
	replay_controls = Control.new()
	add_child(replay_controls)
	replay_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_controls.offset_left = -130
	replay_controls.offset_right = 130
	replay_controls.offset_top = 20
	replay_controls.offset_bottom = 70
	replay_close_button = _button(replay_controls,"关闭回放 / V",func() -> void: replay_close_requested.emit())
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
	if info.phase == "countdown": point_label.text = "%d秒后开始交战"%ceili(info.countdown)
	ticket_label.text = info.tickets_text
	capture_bar.visible = info.get("team_mode",false)
	capture_bar.value = absf(float(info.get("capture_progress",0)))
	capture_fill.bg_color = Color("72c9ee") if float(info.get("capture_progress",0))>=0 else Color("ffc47e")
	crew_label.text = "乘员 %d / %d"%[model.crew_alive,model.crew.size()]
	var missing: Array[String] = []
	for person in model.crew:
		if not person.available: missing.append(person.name+"空缺")
	if not missing.is_empty(): crew_label.text += "\n"+" · ".join(missing)
	for module in model.modules:
		if not module_labels.has(module.id): module_labels[module.id] = _label(module_grid,"",14)
		var label: Label = module_labels[module.id]
		label.text = ("× " if module.fraction <= 0 else ("! " if module.fraction < 1 else "· "))+module.name+" "+module.status
		label.modulate = Color("ffca80") if module.fraction < 1 else Color("d7e2dc")
	drive_label.text = "动力正常" if model.drive_text.is_empty() else "驾驶受限："+model.drive_text
	if model.destroyed: drive_label.text = "车辆已阵亡 · 请查看再出击选项"
	speed_label.text = "%.0f km/h"%model.speed_kph
	weapon_label.text = model.weapon_status
	weapon_label.modulate = Color("a6deb5") if model.ready else Color("ffcf8f")
	ammo_label.text = "%s · %d 发  |  膛内 %d"%[model.shell,model.ammo,model.chamber]
	if model.has("next_shell"):
		ammo_label.text += "\n下次："+str(model.next_shell)+" · "+InputBindingService.hint("shell_1")+"/"+InputBindingService.hint("shell_2")+" 切换"
		if not str(model.get("carrying_shell","")).is_empty(): ammo_label.text += "\n正在装填："+str(model.carrying_shell)
	if not str(model.get("supply_status","")).is_empty(): ammo_label.text += "\n"+str(model.supply_status)
	reload_bar.value = clampf(1-float(model.cooldown)/maxf(0.01,float(model.reload_time)),0,1)
	reason_label.text = model.weapon_text
	reason_label.visible = not reason_label.text.is_empty()
	fire_label.text = ("▲ 起火！立即按 "+InputBindingService.hint("extinguish")+" 灭火" if model.fire else InputBindingService.hint("extinguish")+" 灭火")+" · 剩余 %d 次"%model.extinguishers
	if model.protection > 0: fire_label.text = "◇ 出生保护 %.1f秒 · 驾驶/开火取消"%model.protection
	action_label.text = model.action if not model.action.is_empty() else InputBindingService.recovery_hint()
	action_bar.visible = model.action_duration > 0
	action_bar.value = float(model.action_progress)/maxf(0.01,float(model.action_duration))
	feedback_label.text = "\n".join([model.shot_feedback,model.recovery_feedback]).strip_edges()
	feedback_label.visible = not feedback_label.text.is_empty()
	minimap.present_observations(intel,int(info.get("owner",0)))
	footer.text = notice if not notice.is_empty() else InputBindingService.driving_hint()+" · "+InputBindingService.hint("scoreboard")+" 战况 · "+InputBindingService.hint("pause")+" 菜单"
	board_close_button.text = "关闭战况 / "+InputBindingService.hint("scoreboard")
	replay_close_button.text = "关闭回放 / "+InputBindingService.hint("replay_toggle")
	var summary := str(roster)
	if summary != _last_roster:
		_last_roster = summary
		for child in board_rows.get_children(): child.queue_free()
		for heading in ["车组","队伍","出局次数"]: _label(board_rows,heading,17)
		for row in roster:
			_label(board_rows,row.id+("（自己）" if row.id == model.entity_id else ""),16)
			_label(board_rows,"△ 友方" if row.friendly else "◆ 敌方",16)
			_label(board_rows,str(row.deaths),16)
		AccessibilitySettings.apply(board_rows)
	aim_visible = not model.destroyed and info.phase == "playing" and is_instance_valid(camera) and not camera.is_position_behind(model.actual_point)
	if aim_visible: actual_screen_point = camera.unproject_position(model.actual_point)
	queue_redraw()
func _draw() -> void:
	if not aim_allowed or not aim_visible or not main_margin.visible or scoreboard.visible or settings_root.visible: return
	var center := size/2
	draw_line(center+Vector2(-7,0),center+Vector2(7,0),Color(1,1,1,0.65),1.5,true)
	draw_line(center+Vector2(0,-7),center+Vector2(0,7),Color(1,1,1,0.65),1.5,true)
	if Rect2(Vector2.ZERO,size).has_point(actual_screen_point):
		var color := Color("b5edba") if view_model.get("ready",false) else Color("ffd492")
		draw_arc(actual_screen_point,11,0,TAU,40,color,2,true)
		draw_circle(actual_screen_point,2,color)
