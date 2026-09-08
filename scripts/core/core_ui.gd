class_name CoreUI
extends RefCounted
const FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const NAMES := {"engine":"发动机","breech":"炮闩","track_left":"左履带","track_right":"右履带","turret_drive":"炮塔驱动","ammo_rack":"弹药架","transmission":"传动","fuel":"油箱","gunner":"炮手","driver":"驾驶员","loader":"装填手","commander":"车长","assistant_driver":"副驾驶","penetrated":"击穿","stopped":"未击穿","ricochet":"跳弹","unknown":"装甲资料不足","module_destroyed":"部件失能","module_damaged":"部件受损","crew_incapacitated":"乘员失能","repair":"维修","extinguish":"灭火","replace":"替补","hull_front":"车体正面","hull_rear":"车体后部","hull_left":"车体左侧","hull_right":"车体右侧"}

static func word(value: String) -> String:
	return NAMES.get(value,value.replace("_"," "))

static func theme() -> Theme:
	var out := Theme.new()
	out.default_font = FONT
	out.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("17252df2")
	panel.set_content_margin_all(16)
	panel.set_corner_radius_all(5)
	out.set_stylebox("panel","PanelContainer",panel)
	for state in ["normal","hover","pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("33464f") if state == "normal" else Color("47616c")
		box.set_content_margin_all(10)
		box.set_corner_radius_all(3)
		out.set_stylebox(state,"Button",box)
	return out

static func apply(root: Node) -> void:
	if root is Control: root.theme = theme()
	for child in root.get_children(): apply(child)

static func label(parent: Node, text: String, font_size: int = 18) -> Label:
	var out := Label.new()
	out.text = text
	out.add_theme_font_size_override("font_size",font_size)
	parent.add_child(out)
	return out

static func button(parent: Node, text: String, callback: Callable) -> Button:
	var out := Button.new()
	out.text = text
	out.pressed.connect(callback)
	parent.add_child(out)
	return out
