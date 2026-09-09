class_name CombatSubtitles
extends CanvasLayer
const CAPTIONS := {"shot":"炮声","flyby":"炮弹掠过","reload":"装填完成","non_penetration":"装甲撞击","ricochet":"跳弹","penetrated":"穿透撞击","explosion":"殉爆","destroyed":"车辆毁坏","world":"弹着撞击"}
var label: Label
var recent: Array[Dictionary] = []

func _ready() -> void:
	layer = 4
	label = Label.new()
	label.theme = CoreUI.theme()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size",5)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.anchor_top = 0.64; label.anchor_bottom = 0.64
	label.offset_left = -230; label.offset_right = 230
	label.offset_top = 0; label.offset_bottom = 70

func present(kind: String, point: Vector3) -> void:
	if not AccessibilitySettings.subtitles_enabled or not CAPTIONS.has(kind): return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(point) > 80: return
	# Captions give no identity, direction or exact range beyond an audible event.
	recent.append({"text":"["+str(CAPTIONS[kind])+"]","ttl":2.0})
	while recent.size() > 3: recent.pop_front()

func _process(delta: float) -> void:
	if not AccessibilitySettings.subtitles_enabled: recent.clear()
	var lines: Array[String] = []
	for item in recent: item.ttl -= delta
	recent = recent.filter(func(item: Dictionary) -> bool: return item.ttl > 0)
	for item in recent: lines.append(str(item.text))
	label.text = "\n".join(lines)
	label.visible = not lines.is_empty() and not get_tree().paused
