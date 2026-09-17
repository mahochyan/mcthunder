extends SceneTree
## WT-UI-002 self-test (MCT-UI-FIELDWORK-01): the reissued token file, its design copy and the tokenised themes
## must agree. Run headless; it reads the real files and builds the real Theme objects, so a drifting copy, an
## unused token or a lost colour ruling fails here instead of being asserted in prose.
const CANON := "res://configs/ui/ui_tokens.json"
const DESIGN_COPY := "res://docs/wt/continuation/07_UI_TOKENS.json"
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _run() -> void:
	check(FileAccess.file_exists(CANON), "runtime token source exists: "+CANON)
	check(FileAccess.file_exists(DESIGN_COPY), "design copy exists: "+DESIGN_COPY)
	check(UiTokens.source()=="json", "UiTokens read the file (source=%s)" % UiTokens.source())
	check(UiTokens.ready(), "token file parsed and carries the colour table")
	check(UiTokens.schema_version()==1, "schema_version is 1")
	check(UiTokens.design_status()=="design_proposal_not_installed", "design status is the untouched design value")

	# The reissued file stores 16 flat colour strings, focus included.
	var colors: Dictionary = UiTokens.data().get("colors",{})
	check(colors.size()==16, "colour table carries 16 tokens (got %d)" % colors.size())
	check(UiTokens.color("background")==Color("#10171B"), "background is #10171B")
	check(UiTokens.color("surface")==Color("#182329"), "surface is #182329")
	check(UiTokens.color("surface_raised")==Color("#223139"), "surface_raised is #223139")
	check(UiTokens.color("text_primary")==Color("#ECEDE6"), "text_primary is #ECEDE6")
	check(UiTokens.color("text_secondary")==Color("#A8B6BA"), "text_secondary is #A8B6BA")
	check(UiTokens.color("accent")==Color("#E0B46A"), "accent is #E0B46A")
	check(UiTokens.color("on_accent")==Color("#141A1E"), "on_accent is #141A1E")
	check(UiTokens.color("focus")==Color("#E0B46A"), "focus token is the same warm gold as accent")
	check(UiTokens.color("focus")==UiTokens.color("accent"), "focus and accent are one colour, as ruled")
	check(UiTokens.color("ally")==Color("#7FC9E0") and UiTokens.color("enemy")==Color("#F17C72"), "ally/enemy relation colours come from the table")
	check(UiTokens.color("warning")==Color("#E8BE70") and UiTokens.color("critical")==Color("#FF8A80"), "warning/critical come from the table")
	check(UiTokens.color("positive")==Color("#A0CBA1") and UiTokens.color("disabled_text")==Color("#83969D"), "positive/disabled_text come from the table")
	check(UiTokens.color("critical")!=Color("#E63946"), "the mockup chip colour did not replace the critical token")

	# Type scale keeps the design's own role names.
	check(UiTokens.font_size("vehicle_title")==34, "vehicle_title 34")
	check(UiTokens.font_size("page_title")==28, "page_title 28")
	check(UiTokens.font_size("section")==20, "section 20")
	check(UiTokens.font_size("body")==16, "body 16")
	check(UiTokens.font_size("button")==16, "button 16")
	check(UiTokens.font_size("secondary")==14, "secondary 14")
	check(UiTokens.font_size("hud_number")==24, "hud_number 24")
	check(UiTokens.font_size("critical_notice")==18, "critical_notice 18")
	check(UiTokens.metric("font.body_line_height_ratio")==1.35, "body line height 1.35")
	check(UiTokens.ui_scale_first_delivery()==[1.0,1.25], "first delivery covers 100% and 125% only")

	# Geometry, motion, layouts.
	check(UiTokens.metric("components.radius")==4.0, "component radius 4")
	check(UiTokens.metric("components.border")==1.0, "base border 1")
	check(UiTokens.metric("components.focus_border")==2.0, "focus border 2")
	check(UiTokens.metric("components.primary_button_min_height")==48.0, "primary button min height 48")
	check(UiTokens.metric("components.button_min_height")==40.0, "button min height 40")
	check(UiTokens.metric("components.panel_padding")==16.0, "panel padding 16")
	# Godot's JSON parser yields floats for these integer-looking values, so array assertions compare element-wise
	# as numbers instead of relying on array equality, which is type sensitive.
	var icon_hit: Array = UiTokens.metric_array("components.icon_hitbox_min")
	check(icon_hit.size()==2 and float(icon_hit[0])==40.0 and float(icon_hit[1])==40.0, "icon hitbox minimum is 40x40")
	check(UiTokens.metric("layouts.wide.sidebar")==344.0 and UiTokens.metric("layouts.compact.sidebar")==296.0, "sidebar tokens 344 / 296")
	check(UiTokens.metric("layouts.compact.outer_margin")==16.0, "compact outer margin 16")
	check(UiTokens.metric("layouts.menu_max_width")==1920.0, "menu max width 1920")
	var clear_region: Dictionary = UiTokens.data().get("layouts",{}).get("hud_clear_region_normalized",{})
	check(float(clear_region.get("x_min",0.0))==0.25 and float(clear_region.get("x_max",0.0))==0.75, "HUD clear region x 0.25-0.75")
	var objective_box: Array = UiTokens.metric_array("layouts.hud_wide.objective")
	check(objective_box.size()==2 and float(objective_box[0])==640.0 and float(objective_box[1])==64.0, "HUD wide objective box 640x64")
	var compact_minimap: Array = UiTokens.metric_array("layouts.hud_compact.minimap")
	check(compact_minimap.size()==2 and float(compact_minimap[0])==168.0 and float(compact_minimap[1])==168.0, "HUD compact minimap 168x168")
	check(UiTokens.metric("motion_ms.hover")==100.0 and UiTokens.metric("motion_ms.page")==160.0, "motion hover 100 / page 160")
	check(UiTokens.metric("motion_ms.drawer")==180.0 and UiTokens.metric("motion_ms.toast")==160.0, "motion drawer 180 / toast 160")
	check(UiTokens.metric("motion_ms.tooltip_delay")==350.0, "tooltip delay 350")

	# Policies carried by the file itself.
	check(UiTokens.state_names().size()==7, "seven required component states")
	for required in ["normal","hover","pressed","focused","disabled","busy","error"]:
		check(UiTokens.state_names().has(required), "state %s is declared" % required)
	check(UiTokens.forbidden_static_mock_values().size()==6, "six forbidden static mock value classes are declared")
	check(UiTokens.forbidden_static_mock_values().has("money balances"), "money balances stay forbidden")
	check(UiTokens.performance_policy().begins_with("HOLD_BY_USER"), "performance policy stays HOLD_BY_USER")
	check(UiTokens.metric("contrast_targets.readable_text")==4.5, "readable text contrast target 4.5")

	var canon := FileAccess.open(CANON,FileAccess.READ)
	var copy := FileAccess.open(DESIGN_COPY,FileAccess.READ)
	check(canon!=null and copy!=null, "both the runtime source and the design copy are readable")
	if canon!=null and copy!=null:
		check(canon.get_as_text()==copy.get_as_text(), "runtime token source is byte-identical to the reissued design file")

	# The themes actually consume the tokens.
	var theme := GarageTheme.theme()
	check(theme.default_font_size==roundi(float(UiTokens.font_size("body"))*AccessibilitySettings.ui_scale), "GarageTheme body size follows the token at the current ui_scale")
	var normal := theme.get_stylebox("normal","Button") as StyleBoxFlat
	check(normal!=null and normal.bg_color==UiTokens.color("surface"), "button normal uses the surface token")
	var hover := theme.get_stylebox("hover","Button") as StyleBoxFlat
	check(hover!=null and hover.bg_color==UiTokens.color("surface_raised"), "button hover uses surface_raised and does not impersonate selection")
	var focus := theme.get_stylebox("focus","Button") as StyleBoxFlat
	check(focus!=null and focus.border_color==UiTokens.color("focus"), "focus border uses the focus token")
	check(focus!=null and focus.border_width_left==int(UiTokens.metric("components.focus_border")), "focus border width uses components.focus_border")
	check(focus!=null and focus.content_margin_left==0, "focus ring adds no padding of its own")
	check(theme.get_color("font_color","Button")==UiTokens.color("text_primary"), "button text uses text_primary")
	check(theme.get_color("font_disabled_color","Button")==UiTokens.color("disabled_text"), "disabled text uses disabled_text")
	var panel := theme.get_stylebox("panel","PanelContainer") as StyleBoxFlat
	check(panel!=null and panel.border_color==UiTokens.color("border_decorative"), "panels separate with border_decorative")
	check(panel!=null and panel.content_margin_left==UiTokens.metric("components.panel_padding"), "panel padding uses components.panel_padding")
	check(panel!=null and panel.corner_radius_top_left==int(UiTokens.metric("components.radius")), "panel radius uses components.radius")
	var line := theme.get_stylebox("normal","LineEdit") as StyleBoxFlat
	check(line!=null and line.border_color==UiTokens.color("control_outline"), "input outline uses control_outline")
	var primary_button := Button.new()
	GarageTheme.primary(primary_button)
	check(primary_button.custom_minimum_size.y==UiTokens.metric("components.primary_button_min_height"), "main button height uses components.primary_button_min_height")
	check(primary_button.get_theme_color("font_color")==UiTokens.color("on_accent"), "main button text uses on_accent")
	check(primary_button.get_theme_stylebox("normal").bg_color==UiTokens.color("accent"), "main button fill uses the accent token")
	primary_button.free()
	var base := CoreUI.theme()
	var base_button := base.get_stylebox("normal","Button") as StyleBoxFlat
	check(base_button!=null and base_button.bg_color==UiTokens.color("surface"), "CoreUI base button also uses the surface token")
	check(base.default_font_size==roundi(float(UiTokens.font_size("body"))*AccessibilitySettings.ui_scale), "CoreUI base size follows the body token")
	check(CoreUI.FONT.resource_path=="res://assets/fonts/NotoSansCJKsc-Regular.otf", "the licensed project font is still the one in use, unchanged")

	print("=== ui tokens: %d checks, %d failed ===" % [count,failed])
	print("UI_TOKEN_CHECKS_PASS" if failed==0 else "UI_TOKEN_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
