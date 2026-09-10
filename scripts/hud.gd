class_name HUD
extends CanvasLayer
## 界面（职责：显示与暂停菜单）。使用随工程分发的Noto CJK字体。

signal resume_requested
signal armor_training_requested
var armor_training_button: Button
signal damage_training_requested
var damage_training_button: Button
signal recovery_training_requested
var recovery_training_button: Button
signal replay_toggle_requested
var replay_toggle_button: Button
signal inspect_requested   # 004-c：暂停菜单"车辆检视"按钮
signal training_requested  # 006：暂停菜单"弹道训练"入口（训练场中为"返回靶场"）

const CJK_PROBE := 0x4E2D   # '中'

var speed_label: Label
var reload_label: Label
var hits_label: Label
var blocked_label: Label
var control_label: Label      # 003：当前控制车
var result_label: Label       # 003：最后射击结果
var trial_label: Label        # 003：试射目标
var ammo_label: Label         # 006：剩余弹数
var projectiles_label: Label  # 006：在飞弹丸数
var impact_label: Label       # 006：最近撞击结果
var gunline_label: Label      # 006：炮线标注（非弹道落点预测）
var hint_label: Label
var crosshair: Label
var debug_label: Label
var resume_btn: Button           # 002-R1：真实鼠标事件点击测试使用
var font_cjk := false
var S := {}
var _pause_root: Control
var _training_btn: Button

func _ready() -> void:
	font_cjk = CoreUI.FONT.has_char(CJK_PROBE)
	S = _strings(font_cjk)
	_build()
	CoreUI.apply(self)

func _strings(zh: bool) -> Dictionary:
	if zh:
		return {
			"speed": LocalizationService.text("ui_0e14d148b46b"),
			"ready": LocalizationService.text("ui_50e984b63fb0"),
			"reloading": LocalizationService.text("ui_249ae176c659"),
			"hits": LocalizationService.text("ui_393df9bb13ea"),
			"blocked": LocalizationService.text("ui_59b0243bb63a"),
			"control": LocalizationService.text("ui_2fbbf2a482ba"),
			"result": LocalizationService.text("ui_ac6786a13dc4"),
			"trial": LocalizationService.text("ui_9311d6b43c3d"),
			"trial_done": LocalizationService.text("ui_7e4134c581d6"),
			"hint": LocalizationService.text("ui_a04adb4823e0"),
			"paused": LocalizationService.text("ui_eb0c326b60ae"),
			"resume": LocalizationService.text("ui_7c9691192f1b"),
			"ammo": LocalizationService.text("ui_5a8114a4b332"),
			"projectiles": LocalizationService.text("ui_41b9e34ca7a6"),
			"impact": LocalizationService.text("ui_875d9f524261"),
			"gunline": LocalizationService.text("ui_178e540452ec"),
			"training": LocalizationService.text("ui_935252ec7cd0"),
			"return_range": LocalizationService.text("ui_589d9d346e91"),
		}
	return {
		"speed": LocalizationService.text("ui_c372fee9b456"),
		"ready": LocalizationService.status("READY"),
		"reloading": LocalizationService.text("ui_4d3cd743ee35"),
		"hits": LocalizationService.text("ui_8a043f55ef38"),
		"blocked": LocalizationService.text("ui_3d485428a30d"),
		"control": LocalizationService.text("ui_5896a75e66b6"),
		"result": LocalizationService.text("ui_915b97c07db8"),
		"trial": LocalizationService.text("ui_d9ae4b617204"),
		"trial_done": LocalizationService.text("ui_865e40a96688"),
		"hint": LocalizationService.text("ui_c1ee21bd9089"),
		"paused": LocalizationService.status("PAUSED"),
		"resume": LocalizationService.text("ui_d640c7421da0"),
		"ammo": LocalizationService.status("AMMO"),
		"projectiles": LocalizationService.status("PROJECTILES"),
		"impact": LocalizationService.text("ui_6291cbdd5174"),
		"gunline": LocalizationService.text("ui_c591ebf2eeb2"),
		"training": LocalizationService.text("ui_4c1b0c7f3cb9"),
		"return_range": LocalizationService.text("ui_ad5a7cdd31ad"),
	}

func _mk_label(pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	add_child(l)
	return l

func _build() -> void:
	speed_label = _mk_label(Vector2(16, 12), 20)
	reload_label = _mk_label(Vector2(16, 40), 20)
	hits_label = _mk_label(Vector2(16, 68), 20)
	blocked_label = _mk_label(Vector2(16, 96), 20)
	blocked_label.modulate = Color(1.0, 0.5, 0.3)
	control_label = _mk_label(Vector2(16, 124), 20)
	control_label.modulate = Color(0.4, 1.0, 0.4)
	result_label = _mk_label(Vector2(16, 152), 20)
	trial_label = _mk_label(Vector2(16, 180), 20)
	trial_label.modulate = Color(1.0, 0.85, 0.3)
	# 006：弹药/在飞/最近撞击/炮线标注（弹道训练信息）
	ammo_label = _mk_label(Vector2(16, 208), 20)
	projectiles_label = _mk_label(Vector2(16, 236), 20)
	impact_label = _mk_label(Vector2(16, 264), 20)
	impact_label.modulate = Color(0.7, 0.9, 1.0)
	gunline_label = _mk_label(Vector2(16, 292), 15)
	gunline_label.modulate = Color(0.8, 0.8, 0.8)
	gunline_label.text = S.gunline
	hint_label = _mk_label(Vector2(16, 630), 17)
	hint_label.text = S.hint
	# 底部左锚定（002 §2.4）：720p/1080p/窗口拉伸时提示始终贴底
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -92.0
	hint_label.offset_bottom = -16.0
	hint_label.offset_right = 640.0
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# 开发调试显示（F3 切换，右上角；默认关闭）
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	add_child(debug_label)
	debug_label.anchor_left = 1.0
	debug_label.anchor_right = 1.0
	debug_label.offset_left = -460.0
	debug_label.offset_right = -16.0
	debug_label.offset_top = 12.0
	debug_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug_label.visible = false
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 30)
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.visible = false
	_pause_root = Control.new()
	add_child(_pause_root)
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	_pause_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	var center := CenterContainer.new()
	_pause_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(vb)
	var title := Label.new()
	title.text = S.paused
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var btn := Button.new()
	btn.text = S.resume
	btn.custom_minimum_size = Vector2(160, 44)
	btn.pressed.connect(func() -> void: resume_requested.emit())
	vb.add_child(btn)
	resume_btn = btn
	# 004-c：车辆检视入口（暂停菜单 -> 独立检视窗口，真实返回流程）
	var inspect_btn := Button.new()
	inspect_btn.text = LocalizationService.text("ui_48fbf5cf003e")
	inspect_btn.custom_minimum_size = Vector2(160, 44)
	inspect_btn.pressed.connect(func() -> void: inspect_requested.emit())
	vb.add_child(inspect_btn)
	# 006：弹道训练入口（训练场中由 set_training_button_text 改为"返回靶场"）
	_training_btn = Button.new()
	_training_btn.text = S.training
	_training_btn.custom_minimum_size = Vector2(160, 44)
	_training_btn.pressed.connect(func() -> void: training_requested.emit())
	vb.add_child(_training_btn)
	armor_training_button = Button.new()
	armor_training_button.text = LocalizationService.text("ui_7ed2fa53c985")
	armor_training_button.custom_minimum_size = Vector2(160,44)
	armor_training_button.pressed.connect(func() -> void: armor_training_requested.emit())
	vb.add_child(armor_training_button)
	damage_training_button = Button.new()
	damage_training_button.text = LocalizationService.text("ui_428db8dbded7")
	damage_training_button.custom_minimum_size = Vector2(160,44)
	damage_training_button.pressed.connect(func() -> void: damage_training_requested.emit())
	vb.add_child(damage_training_button)
	recovery_training_button = Button.new()
	recovery_training_button.text = LocalizationService.text("ui_4461b2709fe0")
	recovery_training_button.custom_minimum_size = Vector2(160,44)
	recovery_training_button.pressed.connect(func() -> void: recovery_training_requested.emit())
	vb.add_child(recovery_training_button)
	replay_toggle_button = Button.new()
	replay_toggle_button.text = LocalizationService.text("ui_d5bd90bfeaa1")
	replay_toggle_button.custom_minimum_size = Vector2(190,44)
	replay_toggle_button.pressed.connect(func() -> void: replay_toggle_requested.emit())
	vb.add_child(replay_toggle_button)
	ModalNavigation.attach(_pause_root)

func set_training_button_text(training: bool) -> void:
	# 006：训练场中按钮语义 = 返回靶场
	_training_btn.text = S.training if training else S.return_range

func show_pause(p: bool) -> void:
	_pause_root.visible = p

func update_hud(speed_mps: float, reload_left: float, blocked: String, hits: Array, sight_on: bool, control_text: String, result_text: String, trial_text: String, ammo_text: String = "", projectiles_text: String = "", impact_text: String = "") -> void:
	speed_label.text = "%s: %.1f m/s" % [S.speed, speed_mps]
	if reload_left > 0.0:
		reload_label.text = S.reloading % reload_left
	else:
		reload_label.text = S.ready
	var parts: Array[String] = []
	for i in hits.size():
		parts.append("%s %d: %d" % [S.hits, i + 1, hits[i]])
	hits_label.text = " | ".join(parts)
	blocked_label.text = S.blocked if blocked == "barrel_occluded" else ""
	control_label.text = control_text
	result_label.text = result_text
	trial_label.text = trial_text
	ammo_label.text = ammo_text
	projectiles_label.text = projectiles_text
	impact_label.text = impact_text
	crosshair.visible = sight_on

func set_debug_visible(v: bool) -> void:
	debug_label.visible = v

func update_debug(fps: int, speed_mps: float, turret_yaw_deg: float, barrel_pitch_deg: float, reload_left: float) -> void:
	# 开发显示（002 §2.5）：FPS / 车速 / 炮塔角 / 炮管俯仰 / 装填剩余
	if not debug_label.visible:
		return
	debug_label.text = LocalizationService.text("ui_7b10eb75441c") % [fps, speed_mps, turret_yaw_deg, barrel_pitch_deg, reload_left]
