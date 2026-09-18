class_name BizTheme
extends RefCounted
## UI-BIZ-01 stage 2: the unified component layer for the commercial-client pass.
##
## Everything here reads tokens - the original design file through UiTokens, plus the additive UI-BIZ-01 overlay
## (configs/ui/ui_tokens_biz.json) for elevation, glow, type scale and motion. Not one business value is read,
## written or recomputed: this file only turns tokens into styleboxes, type and motion so that every screen in
## stage 3 can share one look instead of re-inventing panels per file.
##
## Icon policy: viewBox 24, 1.75 stroke, monochrome white, tinted with modulate. The pre-existing generated set
## lives in res://assets/ui/icons (icon_<key>.svg) and is never replaced; the set added this pass lives in
## res://assets/ui/biz/icons (lucide_<name>.svg). icon_texture() tries both, in that order.
const ICON_ORIGINAL := "res://assets/ui/icons/icon_%s.svg"
const ICON_ADDED := "res://assets/ui/biz/icons/lucide_%s.svg"
const FONT_LATIN := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const FONT_LATIN_BOLD := preload("res://assets/fonts/Rajdhani-Bold.ttf")

## UI keys used by the screens, mapped to a file name in one of the two icon directories. Only names that really
## exist are mapped; anything absent simply has no icon rather than a guessed one.
const ICON_KEYS := {
	"battle":"crosshair", "vehicle":"truck", "ammo":"ammo", "armor":"armor", "crew":"users",
	"repair":"wrench", "fire":"flame", "extinguish":"extinguish", "warning":"triangle-alert",
	"research":"flask-conical", "training":"graduation-cap", "challenge":"flag", "settings":"settings",
	"search":"search", "lock":"lock", "nation":"nation", "back":"arrow-left", "next":"arrow-right",
	"map":"map", "objective":"target", "ticket":"chart-column", "intel":"radio", "time":"clock",
	"kill":"siren", "destroyed":"circle-x", "ready":"circle-check", "help":"info", "close":"x",
	"plus":"plus", "minus":"minus", "dropdown":"chevron-down", "expand":"chevrons-right",
	"reset":"rotate-ccw", "save":"save", "replay":"play", "pause":"pause", "trophy":"trophy",
	"star":"star", "gauge":"gauge", "shield":"shield", "layers":"layers", "package":"package",
	"paint":"paintbrush", "monitor":"monitor", "audio":"volume-2", "keys":"keyboard",
	"access":"sliders-horizontal", "terrain":"mountain", "supply":"box", "sight":"scan",
	"compass":"compass", "speed":"zap", "fuel":"fuel", "heart":"heart-pulse", "list":"list",
	"history":"rotate-cw", "book":"book-open", "external":"external-link", "maximize":"maximize-2",
	"view":"eye", "dot":"circle-dot", "square":"square", "cog":"cog", "activity":"activity",
}
static var _icon_cache: Dictionary = {}

# --- colour -----------------------------------------------------------------------------------------------------

static func background() -> Color: return UiTokens.color("background","#10171B")
static func sunken() -> Color: return UiTokens.biz_color("surface_sunken","#131C21")
static func surface() -> Color: return UiTokens.color("surface","#182329")
static func surface_raised() -> Color: return UiTokens.color("surface_raised","#223139")
static func overlay_surface() -> Color: return UiTokens.biz_color("surface_overlay","#1B262CD9")
static func hairline() -> Color: return UiTokens.biz_color("hairline","#2A3A42")
static func hairline_strong() -> Color: return UiTokens.biz_color("hairline_strong","#3E535D")
static func decorative() -> Color: return UiTokens.color("border_decorative","#35464E")
static func text_primary() -> Color: return UiTokens.color("text_primary","#ECEDE6")
static func text_secondary() -> Color: return UiTokens.color("text_secondary","#A8B6BA")
static func text_tertiary() -> Color: return UiTokens.biz_color("text_tertiary","#8A9AA1")
static func disabled_text() -> Color: return UiTokens.color("disabled_text","#83969D")
static func accent() -> Color: return UiTokens.color("accent","#E0B46A")
static func accent_soft() -> Color: return UiTokens.biz_color("accent_soft","#E0B46A33")
static func accent_line() -> Color: return UiTokens.biz_color("accent_line","#E0B46A66")
static func on_accent() -> Color: return UiTokens.color("on_accent","#141A1E")
static func critical() -> Color: return UiTokens.color("critical","#FF8A80")
static func critical_soft() -> Color: return UiTokens.biz_color("critical_soft","#FF8A8033")
static func warning() -> Color: return UiTokens.color("warning","#E8BE70")
static func positive() -> Color: return UiTokens.color("positive","#A0CBA1")
static func scrim() -> Color: return UiTokens.biz_color("scrim","#0B1013CC")
static func shadow_colour() -> Color: return UiTokens.biz_color("shadow","#05090B")

# --- boxes: elevation, glow, states ------------------------------------------------------------------------------

## A panel box at one of the overlay's elevation steps ("panel", "raised", "overlay", "modal").
static func box(bg: Color, border: Color, padding: int, elevation: String = "panel", radius: int = -1) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color = bg
	out.border_color = border
	out.set_border_width_all(int(UiTokens.metric("components.border",1.0)))
	out.set_content_margin_all(padding)
	out.set_corner_radius_all(radius if radius >= 0 else int(UiTokens.metric("components.radius",4.0)))
	var step := UiTokens.biz_elevation(elevation)
	var blur := float(step.get("blur",0.0))
	var alpha := float(step.get("alpha",0.0))
	if blur > 0.0 and alpha > 0.0:
		out.shadow_color = Color(shadow_colour(),alpha)
		out.shadow_size = int(blur)
		out.shadow_offset = Vector2(0.0,float(step.get("offset_y",0.0)))
	return out

static func panel_box(elevation: String = "panel", active: bool = false) -> StyleBoxFlat:
	var padding := int(UiTokens.metric("components.panel_padding",16.0))
	var bg: Color = surface() if elevation == "panel" else surface_raised()
	if elevation == "overlay" or elevation == "modal": bg = overlay_surface()
	return box(bg,accent_line() if active else decorative(),padding,elevation)

## A 1px highlight strip along the top edge of a control: the "instrument glass" cue, drawn as a real child rather
## than faked inside the stylebox.
static func add_top_highlight(control: Control, colour: Color = Color.TRANSPARENT) -> ColorRect:
	var strip := ColorRect.new()
	strip.color = colour if colour.a > 0.0 else accent_line()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(strip)
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 1.0
	return strip

## Button variants: primary (the one gold action), secondary, ghost, danger. States follow the design's own set.
static func button_box(kind: String, state: String) -> StyleBoxFlat:
	var bg := surface()
	var border := decorative()
	var padding := 12
	match kind:
		"primary":
			bg = accent(); border = accent()
			if state == "hover": bg = accent().lightened(0.08)
			if state == "pressed": bg = accent().darkened(0.12)
			if state == "disabled": bg = Color(accent(),0.35); border = Color(decorative(),0.5)
			if state == "busy": bg = Color(accent(),0.45); border = Color(accent(),0.5)
			if state == "error": bg = critical_soft(); border = critical()
		"danger":
			bg = critical_soft(); border = critical()
			if state == "hover": bg = Color(critical(),0.32)
			if state == "pressed": bg = Color(critical(),0.42)
			if state == "disabled": bg = sunken(); border = decorative()
		"ghost":
			bg = Color(0,0,0,0); border = Color(0,0,0,0)
			if state == "hover": bg = Color(surface_raised(),0.7); border = hairline()
			if state == "pressed": bg = Color(surface_raised(),0.9); border = hairline_strong()
			if state == "disabled": bg = Color(0,0,0,0); border = Color(0,0,0,0)
		_:
			bg = surface(); border = decorative()
			if state == "hover": bg = surface_raised(); border = hairline_strong()
			if state == "pressed": bg = surface_raised().darkened(0.18); border = accent_line()
			if state == "disabled": bg = background(); border = Color(decorative(),0.6)
	var out := box(bg,border,padding,"panel" if state != "focused" else "raised")
	if state == "focused":
		out.border_color = UiTokens.color("focus","#E0B46A")
		out.set_border_width_all(int(UiTokens.metric("components.focus_border",2.0)))
		out.shadow_color = Color(accent(),float(UiTokens.biz_metric("glow.focus_outer_alpha",0.28)))
		out.shadow_size = int(UiTokens.biz_metric("glow.accent_halo_blur",10.0))
	return out

## Dress a Button with a variant, its state boxes, focus ring, minimum height and an optional icon key.
static func apply_button(button: Button, kind: String = "secondary", icon_key: String = "", icon_size: int = 18) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,button_box(kind,state))
	for state in ["busy","error"]:
		button.add_theme_stylebox_override(state,button_box(kind,state))
	var ink: Color = on_accent() if kind == "primary" else text_primary()
	if kind == "danger": ink = critical()
	button.add_theme_color_override("font_color",ink)
	button.add_theme_color_override("font_hover_color",ink)
	button.add_theme_color_override("font_pressed_color",ink)
	button.add_theme_color_override("font_disabled_color",disabled_text())
	var min_h := int(UiTokens.metric("components.button_min_height",40.0))
	if kind == "primary": min_h = int(UiTokens.metric("components.primary_button_min_height",48.0))
	button.custom_minimum_size.y = float(min_h)
	if not icon_key.is_empty():
		var tex := icon_texture(icon_key,icon_size)
		if tex != null:
			button.icon = tex
			button.add_theme_constant_override("h_separation",8)
			button.add_theme_color_override("icon_normal_color",ink)
			button.add_theme_color_override("icon_hover_color",ink)

## A tab in the top navigation row.
static func apply_tab(button: Button, active: bool) -> void:
	var bg := accent_soft() if active else Color(0,0,0,0)
	var border := accent_line() if active else Color(0,0,0,0)
	button.add_theme_stylebox_override("normal",box(bg,border,10,"panel"))
	button.add_theme_stylebox_override("hover",box(accent_soft(),accent_line(),10,"panel"))
	button.add_theme_stylebox_override("pressed",box(accent_soft(),accent(),10,"panel"))
	button.add_theme_stylebox_override("focus",button_box("ghost","focused"))
	button.add_theme_color_override("font_color",accent() if active else text_secondary())
	button.add_theme_color_override("font_hover_color",text_primary())
	var min_h := int(UiTokens.biz_metric("components_biz.tab_min_height",40.0))
	button.custom_minimum_size.y = float(min_h)

## A chip/badge label (state terms, counts, tags).
static func apply_chip(label: Label, kind: String = "neutral") -> void:
	var ink := text_secondary()
	var bg := Color(surface_raised(),0.8)
	var border := hairline()
	match kind:
		"positive": ink = positive(); bg = UiTokens.biz_color("positive_soft","#A0CBA133"); border = Color(positive(),0.45)
		"warning": ink = warning(); bg = UiTokens.biz_color("warning_soft","#E8BE7033"); border = Color(warning(),0.45)
		"critical": ink = critical(); bg = critical_soft(); border = Color(critical(),0.5)
		"accent": ink = accent(); bg = accent_soft(); border = accent_line()
	label.add_theme_stylebox_override("normal",box(bg,border,6,"panel",3))
	label.add_theme_color_override("font_color",ink)

## A list/card row, selected or hovered.
static func row_box(selected: bool, hover: bool) -> StyleBoxFlat:
	var bg := surface()
	if hover: bg = surface_raised()
	if selected: bg = Color(surface_raised(),1.0)
	var border := decorative()
	if hover: border = hairline_strong()
	if selected: border = accent_line()
	var out := box(bg,border,12,"raised" if selected else "panel")
	if selected:
		out.border_width_left = 2
	return out

static func apply_row(panel: PanelContainer, selected: bool, hover: bool) -> void:
	panel.add_theme_stylebox_override("panel",row_box(selected,hover))

## Progress / capacity / ticket bars.
static func apply_progress(bar: ProgressBar, kind: String = "accent") -> void:
	var fill := accent()
	if kind == "positive": fill = positive()
	if kind == "warning": fill = warning()
	if kind == "critical": fill = critical()
	if kind == "ally": fill = UiTokens.color("ally","#7FC9E0")
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(2)
	var b := StyleBoxFlat.new()
	b.bg_color = sunken()
	b.border_color = hairline()
	b.set_border_width_all(1)
	b.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill",f)
	bar.add_theme_stylebox_override("background",b)

static func dialog_box(kind: String = "modal") -> StyleBoxFlat:
	return box(overlay_surface(),critical() if kind == "danger" else accent_line(),int(UiTokens.metric("components.panel_padding",16.0)),"modal")

static func toast_box(kind: String = "neutral") -> StyleBoxFlat:
	var border := accent_line()
	if kind == "warning": border = Color(warning(),0.6)
	if kind == "critical": border = critical()
	return box(overlay_surface(),border,12,"overlay")

static func tooltip_box() -> StyleBoxFlat:
	return box(Color(background(),0.96),hairline_strong(),8,"raised")

# --- typography ---------------------------------------------------------------------------------------------------

static func is_latin(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) > 0x2500: return false
	return true

## A display-scale label. Latin text and numerals use the OFL Rajdhani face added this pass; anything containing CJK
## keeps the project's OFL CJK font, so Chinese never falls back to a missing glyph.
static func display_label(parent: Node, text: String, role: String = "display_m", colour: Color = Color.TRANSPARENT) -> Label:
	var size := UiTokens.biz_type_size(role,24)
	var out := CoreUI.label(parent,text,size)
	if is_latin(text):
		out.add_theme_font_override("font",FONT_LATIN)
	out.add_theme_color_override("font_color",colour if colour.a > 0.0 else text_primary())
	return out

static func logotype(parent: Node, text: String) -> Label:
	var out := CoreUI.label(parent,text,UiTokens.biz_type_size("logotype",40))
	out.add_theme_font_override("font",FONT_LATIN_BOLD)
	out.add_theme_color_override("font_color",text_primary())
	return out

## A number block: value in display type, unit small, label above. Only ever fed real fields by the screens.
static func stat_block(parent: Node, caption: String, value: String, unit: String = "", colour: Color = Color.TRANSPARENT) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",box(sunken(),hairline(),10,"panel"))
	var min_w := int(UiTokens.biz_metric("components_biz.stat_block_min_width",96.0))
	card.custom_minimum_size.x = float(min_w)
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",2)
	card.add_child(column)
	var cap := CoreUI.label(column,caption,UiTokens.biz_type_size("caption",11))
	cap.add_theme_color_override("font_color",text_tertiary())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	column.add_child(row)
	var big := display_label(row,value,"number_m",colour if colour.a > 0.0 else text_primary())
	if not unit.is_empty():
		var unit_label := display_label(row,unit,"caption",text_secondary())
		unit_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return card

static func section_header(parent: Node, title: String, subtitle: String = "") -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",2)
	parent.add_child(column)
	var head := CoreUI.label(column,title,UiTokens.biz_type_size("subtitle",18))
	head.add_theme_color_override("font_color",text_primary())
	if not subtitle.is_empty():
		var sub := CoreUI.label(column,subtitle,UiTokens.biz_type_size("caption",11))
		sub.add_theme_color_override("font_color",text_tertiary())
	return column

# --- icons -------------------------------------------------------------------------------------------------------

## Texture for a UI icon key, trying the generated set first and then the added Lucide set. Null when neither has it.
static func icon_texture(key: String, size: int = 20) -> Texture2D:
	var name := str(ICON_KEYS.get(key,key))
	var cache_key := name + "@" + str(size)
	if _icon_cache.has(cache_key): return _icon_cache[cache_key]
	var candidates: Array[String] = [ICON_ORIGINAL % name,ICON_ADDED % name]
	for path in candidates:
		if ResourceLoader.exists(path):
			var loaded: Variant = load(path)
			if loaded is Texture2D:
				_icon_cache[cache_key] = loaded
				return loaded
	_icon_cache[cache_key] = null
	return null

## An icon-only button with the design's minimum hit box.
static func icon_button(parent: Node, key: String, callback: Callable, size: int = 20, kind: String = "ghost") -> Button:
	var out := Button.new()
	out.text = ""
	out.pressed.connect(callback)
	parent.add_child(out)
	var hit := UiTokens.metric_array("components.icon_hitbox_min",[40,40])
	out.custom_minimum_size = Vector2(float(hit[0]) if hit.size() > 0 else 40.0,float(hit[1]) if hit.size() > 1 else 40.0)
	var tex := icon_texture(key,size)
	if tex != null:
		out.icon = tex
	apply_button(out,kind)
	return out

## An icon plus text row (the pattern the HUD, cards and list rows all use).
static func icon_row(parent: Node, key: String, text: String, size: int = 16, colour: Color = Color.TRANSPARENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	var tex := icon_texture(key,size)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(float(size),float(size))
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.modulate = colour if colour.a > 0.0 else text_secondary()
		row.add_child(pic)
	var label := CoreUI.label(row,text,size)
	label.add_theme_color_override("font_color",colour if colour.a > 0.0 else text_primary())
	return row

# --- motion ------------------------------------------------------------------------------------------------------

## Fade-and-rise entrance using the overlay's motion tokens. Skipped entirely when the player asked for fewer
## flashes, so the preference always wins; no transition ever blocks input.
static func animate_in(control: Control, kind: String = "panel_in", rise: float = 6.0) -> void:
	if control == null: return
	if AccessibilitySettings.reduce_flashes:
		control.modulate = Color(1,1,1,1)
		return
	var ms := UiTokens.biz_motion(kind + "_ms",UiTokens.biz_motion("state_ms",90.0))
	var start := control.position
	control.modulate = Color(1,1,1,0)
	control.position = start + Vector2(0.0,rise)
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control,"modulate",Color(1,1,1,1),ms / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control,"position",start,ms / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## A brief highlight pulse, e.g. when a value changes or an action lands.
static func pulse(control: Control, colour: Color = Color.TRANSPARENT) -> void:
	if control == null or AccessibilitySettings.reduce_flashes: return
	var tint := colour if colour.a > 0.0 else accent()
	var ms := UiTokens.biz_motion("notice_ms",200.0)
	var tween := control.create_tween()
	tween.tween_property(control,"modulate",Color(tint.r,tint.g,tint.b,1.0),ms / 2000.0)
	tween.tween_property(control,"modulate",Color(1,1,1,1),ms / 1000.0)

# --- the global theme --------------------------------------------------------------------------------------------
#
# UI-BIZ-01 stage 3 (whole-style pass): this is the single lever that re-skins the application. Every screen already
# builds its controls through CoreUI/GarageTheme, and both of those now return this theme, so buttons, inputs,
# panels, popups, scroll bars, sliders, progress bars, separators and tooltips change together instead of screen by
# screen. Geometry stays on the original design tokens (border 1, focus 2, corner 4, panel padding 16), which is what
# the token self-test measures, so the new skin cannot drift the metrics the design fixed.

static func _state_fill(kind: String, state: String) -> Color:
	match kind:
		"primary":
			if state == "hover": return accent().lightened(0.08)
			if state == "pressed": return accent().darkened(0.12)
			if state == "disabled": return Color(accent(),0.35)
			return accent()
		_:
			if state == "hover": return surface_raised()
			if state == "pressed": return surface_raised().darkened(0.18)
			if state == "disabled": return background()
			return surface()

## The full application theme, built from the original tokens plus the UI-BIZ-01 overlay.
static func theme() -> Theme:
	var out := Theme.new()
	out.default_font = CoreUI.FONT
	out.default_font_size = roundi(float(UiTokens.font_size("body",16)) * AccessibilitySettings.ui_scale)
	var pad := int(UiTokens.metric("components.panel_padding",16.0))

	# Panels: the raised surface with a real shadow, so a page reads as layers rather than one flat sheet.
	out.set_stylebox("panel","PanelContainer",panel_box("panel"))
	out.set_stylebox("panel","Panel",panel_box("panel"))
	out.set_stylebox("panel","PopupPanel",panel_box("overlay"))
	out.set_stylebox("panel","TooltipPanel",tooltip_box())

	# Buttons and option buttons: the design's own state set, with the focus ring carrying the glow.
	for type in ["Button","OptionButton","CheckBox","CheckButton"]:
		out.set_stylebox("normal",type,button_box("secondary","normal"))
		out.set_stylebox("hover",type,button_box("secondary","hover"))
		out.set_stylebox("pressed",type,button_box("secondary","pressed"))
		out.set_stylebox("disabled",type,button_box("secondary","disabled"))
		# The focus ring is a ring and nothing else: the design's token test measures that it adds no padding of its
		# own, so it is a zero-margin box with the two-pixel focus token border plus the halo.
		var ring := box(Color.TRANSPARENT,UiTokens.color("focus","#E0B46A"),0,"raised")
		ring.set_border_width_all(int(UiTokens.metric("components.focus_border",2.0)))
		ring.shadow_color = Color(accent(),float(UiTokens.biz_metric("glow.focus_outer_alpha",0.28)))
		ring.shadow_size = int(UiTokens.biz_metric("glow.accent_halo_blur",10.0))
		ring.set_content_margin_all(0)
		out.set_stylebox("focus",type,ring)
		out.set_color("font_color",type,text_primary())
		out.set_color("font_hover_color",type,Color.WHITE)
		out.set_color("font_pressed_color",type,accent())
		out.set_color("font_focus_color",type,text_primary())
		out.set_color("font_disabled_color",type,disabled_text())
		out.set_color("icon_normal_color",type,text_secondary())
		out.set_color("icon_hover_color",type,text_primary())
		out.set_color("icon_disabled_color",type,disabled_text())
	out.set_constant("h_separation","Button",8)
	# A plain label never draws a plate; the ink is the primary text token.
	out.set_color("font_color","Label",text_primary())
	out.set_color("font_shadow_color","Label",Color(shadow_colour(),0.6))

	# Inputs sit lower than the surface they are on, which is what makes a form read as a form. The outline stays the
	# design's own control_outline token; only the fill is deepened to the overlay's sunken surface.
	out.set_stylebox("normal","LineEdit",box(sunken(),control_outline_check(),8,"panel"))
	out.set_stylebox("focus","LineEdit",box(sunken(),UiTokens.color("focus","#E0B46A"),8,"raised"))
	out.set_stylebox("read_only","LineEdit",box(background(),control_outline_check(),8,"panel"))
	out.set_color("font_color","LineEdit",text_primary())
	out.set_color("font_placeholder_color","LineEdit",text_tertiary())
	out.set_color("caret_color","LineEdit",accent())
	out.set_color("selection_color","LineEdit",accent_soft())
	out.set_stylebox("normal","TextEdit",box(sunken(),control_outline_check(),8,"panel"))
	out.set_color("font_color","TextEdit",text_primary())

	# Progress: a sunken track with a coloured fill, so capacity and tickets read at a glance.
	var track := StyleBoxFlat.new()
	track.bg_color = sunken()
	track.border_color = hairline()
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent()
	fill.set_corner_radius_all(2)
	out.set_stylebox("background","ProgressBar",track)
	out.set_stylebox("fill","ProgressBar",fill)
	out.set_color("font_color","ProgressBar",text_secondary())

	# Sliders: hairline track, accent grabber - the settings panel inherits this without a single line of its own.
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = sunken()
	slider_track.border_color = hairline()
	slider_track.set_border_width_all(1)
	slider_track.set_corner_radius_all(2)
	slider_track.set_content_margin_all(2)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = accent()
	grabber.set_corner_radius_all(3)
	grabber.set_content_margin_all(4)
	out.set_stylebox("slider","HSlider",slider_track)
	out.set_stylebox("grabber_area","HSlider",slider_track)
	out.set_stylebox("grabber_area_highlight","HSlider",slider_track)
	for name in ["grabber","grabber_highlight","grabber_pressed"]:
		var box_variant := grabber.duplicate() as StyleBoxFlat
		if name != "grabber": box_variant.bg_color = accent().lightened(0.12)
		out.set_stylebox(name,"HSlider",box_variant)

	# Scroll bars: thin, quiet, accent on hover - the garage, the research tree and every list share them.
	for type in ["VScrollBar","HScrollBar"]:
		var quiet := StyleBoxFlat.new()
		quiet.bg_color = Color(background(),0.35)
		quiet.set_corner_radius_all(3)
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color(control_outline_check(),0.55)
		grip.set_corner_radius_all(3)
		var grip_hot := StyleBoxFlat.new()
		grip_hot.bg_color = Color(accent(),0.75)
		grip_hot.set_corner_radius_all(3)
		out.set_stylebox("scroll",type,quiet)
		out.set_stylebox("grabber",type,grip)
		out.set_stylebox("grabber_highlight",type,grip_hot)
		out.set_stylebox("grabber_pressed",type,grip_hot)
	out.set_stylebox("panel","ScrollContainer",StyleBoxEmpty.new())

	# Popups and tooltips: overlay elevation, accent hover, quiet separators.
	out.set_stylebox("panel","PopupMenu",panel_box("overlay"))
	out.set_stylebox("hover","PopupMenu",box(accent_soft(),accent_line(),8,"panel"))
	out.set_stylebox("separator","PopupMenu",box(hairline(),Color.TRANSPARENT,1,"panel",0))
	out.set_color("font_color","PopupMenu",text_primary())
	out.set_color("font_hover_color","PopupMenu",accent())
	out.set_color("font_disabled_color","PopupMenu",disabled_text())
	out.set_color("font_separator_color","PopupMenu",text_tertiary())
	out.set_constant("v_separation","PopupMenu",10)
	out.set_constant("item_start_padding","PopupMenu",10)
	out.set_constant("item_end_padding","PopupMenu",10)
	out.set_color("font_color","TooltipLabel",text_secondary())
	out.set_font_size("font_size","TooltipLabel",UiTokens.biz_type_size("caption",11))

	# Separators carry the hairline rather than a default grey.
	out.set_stylebox("separator","HSeparator",box(hairline(),Color.TRANSPARENT,0,"panel",0))
	out.set_stylebox("separator","VSeparator",box(hairline(),Color.TRANSPARENT,0,"panel",0))
	out.set_color("default_color","RichTextLabel",text_secondary())
	out.set_stylebox("normal","RichTextLabel",StyleBoxEmpty.new())
	return out

## The control outline token, read once so the scroll bars can derive a translucent grip from it.
static func control_outline_check() -> Color:
	return UiTokens.color("control_outline","#697F88")

# --- atmosphere --------------------------------------------------------------------------------------------------

static var _vignette_cache: Dictionary = {}

## A layered page background: the base colour, a procedural vignette that darkens the corners, and a soft glow along
## the top edge. Both gradients are generated at runtime from the tokens, so the atmosphere costs no external asset
## and cannot introduce a licence question. Returns the container so a caller can put its content above it.
static func atmosphere(parent: Node, level: String = "page") -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = background() if level == "page" else sunken()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette := TextureRect.new()
	vignette.texture = _radial_texture("vignette")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow := TextureRect.new()
	glow.texture = _top_glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = 220.0
	return holder

## 256x256 radial gradient, dark at the edges, fully transparent in the middle.
static func _radial_texture(key: String) -> ImageTexture:
	if _vignette_cache.has(key): return _vignette_cache[key]
	var size := 256
	var image := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var centre := Vector2(float(size) * 0.5,float(size) * 0.42)
	var max_distance := centre.length()
	for y in size:
		for x in size:
			var d := Vector2(float(x),float(y)).distance_to(centre) / max_distance
			var a := clampf((d - 0.35) / 0.65,0.0,1.0)
			image.set_pixel(x,y,Color(shadow_colour(),a * 0.55))
	var texture := ImageTexture.create_from_image(image)
	_vignette_cache[key] = texture
	return texture

## 8x256 vertical gradient: a faint accent wash at the top edge fading to nothing.
static func _top_glow_texture() -> ImageTexture:
	var key := "top_glow"
	if _vignette_cache.has(key): return _vignette_cache[key]
	var height := 256
	var image := Image.create(8,height,false,Image.FORMAT_RGBA8)
	for y in height:
		var a := pow(1.0 - float(y) / float(height),2.0) * 0.10
		for x in 8: image.set_pixel(x,y,Color(accent(),a))
	var texture := ImageTexture.create_from_image(image)
	_vignette_cache[key] = texture
	return texture
