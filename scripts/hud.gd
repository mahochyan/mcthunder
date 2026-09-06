class_name HUD
extends CanvasLayer
## 界面（职责：显示与暂停菜单）。中文优先；若默认字体缺中文字形则自动切换英文
## （工作单 §E：不随意下载/分发字体；中文操作说明固定写在 开始试玩.txt）。

signal resume_requested

const CJK_PROBE := 0x4E2D   # '中'

var speed_label: Label
var reload_label: Label
var hits_label: Label
var blocked_label: Label
var hint_label: Label
var crosshair: Label
var debug_label: Label
var font_cjk := false
var S := {}
var _pause_root: Control

func _ready() -> void:
	font_cjk = ThemeDB.fallback_font != null and ThemeDB.fallback_font.has_char(CJK_PROBE)
	S = _strings(font_cjk)
	_build()

func _strings(zh: bool) -> Dictionary:
	if zh:
		return {
			"speed": "速度",
			"ready": "已装填",
			"reloading": "装填中 %.1f s",
			"hits": "命中",
			"blocked": "炮管被遮挡，无法开火",
			"hint": "W/S 前进/后退   A/D 车体转向\n鼠标 瞄准   右键(按住) 炮镜   左键 开炮\nR 重置   Esc 暂停",
			"paused": "已暂停",
			"resume": "继续",
		}
	return {
		"speed": "Speed",
		"ready": "READY",
		"reloading": "RELOADING %.1fs",
		"hits": "Hit",
		"blocked": "BARREL BLOCKED",
		"hint": "W/S forward/back  A/D turn\nMouse aim  RMB(hold) sight  LMB fire\nR reset  Esc pause",
		"paused": "PAUSED",
		"resume": "Resume",
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
	_pause_root.add_child(vb)
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
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func show_pause(p: bool) -> void:
	_pause_root.visible = p

func update_hud(speed_mps: float, reload_left: float, blocked: String, hits: Array, sight_on: bool) -> void:
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
	crosshair.visible = sight_on

func set_debug_visible(v: bool) -> void:
	debug_label.visible = v

func update_debug(fps: int, speed_mps: float, turret_yaw_deg: float, barrel_pitch_deg: float, reload_left: float) -> void:
	# 开发显示（002 §2.5）：FPS / 车速 / 炮塔角 / 炮管俯仰 / 装填剩余
	if not debug_label.visible:
		return
	debug_label.text = "FPS %d | Speed %.2f m/s\nTurretYaw %.1f deg | BarrelPitch %.1f deg\nReload %.2f s" % [fps, speed_mps, turret_yaw_deg, barrel_pitch_deg, reload_left]