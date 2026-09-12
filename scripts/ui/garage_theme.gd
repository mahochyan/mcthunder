class_name GarageTheme
extends RefCounted
const INK := Color("101519")
const PAPER := Color("e8e7de")
const MUTED := Color("95a1a5")
const ACCENT := Color("e2b66b")

static func box(color: Color, border: Color = Color.TRANSPARENT, padding: int = 12) -> StyleBoxFlat:
	var out := StyleBoxFlat.new(); out.bg_color=color; out.border_color=border
	out.set_border_width_all(1); out.set_content_margin_all(padding)
	return out

static func theme() -> Theme:
	var out := CoreUI.theme()
	out.default_font_size=roundi(16*AccessibilitySettings.ui_scale)
	out.set_color("font_color","Label",PAPER)
	out.set_stylebox("panel","PanelContainer",box(Color("151c20ed"),Color("303a3e"),18))
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled"]:
			var fill := Color("202a30") if state=="hover" else Color("171f24")
			if state=="pressed": fill=Color("394037")
			if state=="disabled": fill=Color("12181c")
			out.set_stylebox(state,type,box(fill,Color("3b474b") if state=="hover" else Color("2a3439"),6 if type=="OptionButton" else 10))
		out.set_stylebox("focus",type,box(Color.TRANSPARENT,ACCENT,0))
		out.set_color("font_color",type,PAPER); out.set_color("font_hover_color",type,Color.WHITE)
		out.set_color("font_disabled_color",type,Color("657278"))
	out.set_stylebox("normal","LineEdit",box(Color("10171b"),Color("344148"),8))
	out.set_stylebox("focus","LineEdit",box(Color("10171b"),ACCENT,8))
	out.set_stylebox("panel","PopupMenu",box(Color("171f24"),Color("4d5a5e"),10))
	out.set_stylebox("hover","PopupMenu",box(Color("394037")))
	out.set_color("font_color","PopupMenu",PAPER)
	out.set_constant("v_separation","PopupMenu",12)
	return out

static func primary(button: Button) -> void:
	for state in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,box(ACCENT.lightened(0.12) if state=="hover" else ACCENT,Color.TRANSPARENT,14))
		button.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),INK)
	button.add_theme_color_override("font_focus_color",INK)
	button.custom_minimum_size.y=52

static func text(parent: Node, value: String, size: int = 16, color: Color = PAPER) -> Label:
	var label := CoreUI.label(parent,value,size); label.add_theme_color_override("font_color",color)
	return label
