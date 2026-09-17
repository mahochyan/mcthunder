class_name GarageTheme
extends RefCounted
## WT-UI-002 (MCT-UI-FIELDWORK-01): the theme sources its colours, type sizes and component geometry from
## UiTokens, i.e. from the design's own reissued 07_UI_TOKENS.json (res://configs/ui/ui_tokens.json ≡
## docs/wt/continuation/07_UI_TOKENS.json), so the dark instrument look is governed by one machine-readable file
## instead of values scattered inline.
##
## Public surface is unchanged on purpose: box(), theme(), primary() and text() keep their signatures, and
## INK / PAPER / MUTED / ACCENT remain available under their old names, so no existing call site has to change.
## Every value below is either a token lookup or a shade derived from a named token and listed in
## derived_shades() with its source, so nothing here is an invented colour.

static var INK: Color = UiTokens.color("on_accent","#141A1E")
static var PAPER: Color = UiTokens.color("text_primary","#ECEDE6")
static var MUTED: Color = UiTokens.color("text_secondary","#A8B6BA")
static var ACCENT: Color = UiTokens.color("accent","#E0B46A")

static func background() -> Color: return UiTokens.color("background","#10171B")
static func surface() -> Color: return UiTokens.color("surface","#182329")
static func surface_raised() -> Color: return UiTokens.color("surface_raised","#223139")
static func border_decorative() -> Color: return UiTokens.color("border_decorative","#35464E")
static func control_outline() -> Color: return UiTokens.color("control_outline","#697F88")
static func focus_color() -> Color: return UiTokens.color("focus","#E0B46A")
static func disabled_text() -> Color: return UiTokens.color("disabled_text","#83969D")

## Shades the token table does not name, each derived from one named token.
static func derived_shades() -> Dictionary:
	return {
		"button_hover": surface_raised(),
		"button_pressed": surface_raised().darkened(0.18),
		"button_normal": surface(),
		"button_disabled": background(),
		"menu_hover": surface(),
		"panel_scrim": Color(background(), 0.93),
	}

static func box(color: Color, border: Color = Color.TRANSPARENT, padding: int = 12, border_width: int = -1) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color=color; out.border_color=border
	# WT-UI-002: the border width is a parameter so the focused state can use components.focus_border while every
	# pre-existing three-argument call site keeps the token's base border width.
	out.set_border_width_all(border_width if border_width >= 0 else int(UiTokens.metric("components.border",1.0)))
	out.set_content_margin_all(padding)
	out.set_corner_radius_all(int(UiTokens.metric("components.radius",4.0)))
	return out

static func theme() -> Theme:
	var out := CoreUI.theme()
	var shades := derived_shades()
	var pad := int(UiTokens.metric("components.panel_padding",16.0))
	out.default_font_size=roundi(float(UiTokens.font_size("body",16))*AccessibilitySettings.ui_scale)
	out.set_color("font_color","Label",PAPER)
	out.set_stylebox("panel","PanelContainer",box(shades.panel_scrim,border_decorative(),pad))
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled"]:
			var fill: Color = shades.button_normal
			if state=="hover": fill=shades.button_hover
			if state=="pressed": fill=shades.button_pressed
			if state=="disabled": fill=shades.button_disabled
			var edge: Color = border_decorative()
			if state=="hover": edge=control_outline()
			out.set_stylebox(state,type,box(fill,edge,6 if type=="OptionButton" else 10))
		# focus is a token in the reissued file and shares the warm gold with accent.
		out.set_stylebox("focus",type,box(Color.TRANSPARENT,focus_color(),0,int(UiTokens.metric("components.focus_border",2.0))))
		out.set_color("font_color",type,PAPER); out.set_color("font_hover_color",type,Color.WHITE)
		out.set_color("font_disabled_color",type,disabled_text())
	out.set_stylebox("normal","LineEdit",box(background(),control_outline(),8))
	out.set_stylebox("focus","LineEdit",box(background(),focus_color(),8,int(UiTokens.metric("components.focus_border",2.0))))
	out.set_stylebox("panel","PopupMenu",box(surface_raised(),border_decorative(),10))
	out.set_stylebox("hover","PopupMenu",box(shades.menu_hover))
	out.set_color("font_color","PopupMenu",PAPER)
	out.set_constant("v_separation","PopupMenu",12)
	return out

static func primary(button: Button) -> void:
	for state in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,box(ACCENT.lightened(0.12) if state=="hover" else ACCENT,Color.TRANSPARENT,14))
		button.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),INK)
	button.add_theme_color_override("font_focus_color",INK)
	# Token: components.primary_button_min_height (48). The wide-layout bump belongs to the layout pass.
	button.custom_minimum_size.y=UiTokens.metric("components.primary_button_min_height",48.0)

static func text(parent: Node, value: String, size: int = 16, color: Color = PAPER) -> Label:
	var label := CoreUI.label(parent,value,size); label.add_theme_color_override("font_color",color)
	return label
