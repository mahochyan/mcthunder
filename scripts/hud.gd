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
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 30)
	add_child(crosshair)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.visible = false
	_pause_root = Control.new()
	add_child(_pause_root)
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	_pause_root.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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