extends SceneTree
## WT-UI-002 self-test (MCT-UI-FIELDWORK-01): the canonical token file, its design-traceability copy and the
## extended theme must agree. This is a real check, run headless: it builds the actual Theme object and reads the
## actual files, so a drifting copy or an unused token fails here instead of being asserted in prose.
const CANON := "res://configs/ui/ui_tokens.json"
const COPY := "res://docs/wt/continuation/07_UI_TOKENS.json"
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _run() -> void:
	check(FileAccess.file_exists(CANON), "canonical token file exists: "+CANON)
	check(UiTokens.source()=="json", "UiTokens actually read the file (source=%s)" % UiTokens.source())
	check(UiTokens.ready(), "token file parsed and carries the colour table")
	var raw: Dictionary = UiTokens.data()
	check(int(raw.get("schema",0))==1, "token schema is 1")
	var colors: Dictionary = raw.get("colors",{})
	var accent_entry: Dictionary = colors.get("accent",{})
	check(str(accent_entry.get("value",""))=="#E0B46A", "accent token value is #E0B46A")
	check(UiTokens.color("accent")==Color("#E0B46A"), "UiTokens.color(accent) resolves to the token")
	check(UiTokens.color("background")==Color("#10171B"), "background token is #10171B")
	check(UiTokens.color("on_accent")==Color("#141A1E"), "on_accent token is #141A1E")
	check(UiTokens.color("disabled_text")==Color("#83969D"), "disabled_text token is #83969D")
	check(UiTokens.font_size("vehicle_title")==34, "vehicle title size is 34")
	check(UiTokens.font_size("page_title")==28, "page title size is 28")
	check(UiTokens.font_size("group_title")==20, "group title size is 20")
	check(UiTokens.font_size("body_button_input")==16, "body/button size is 16")
	check(UiTokens.font_size("secondary_note")==14, "secondary note size is 14")
	check(UiTokens.font_size("combat_number")==24, "combat number size is 24")
	check(UiTokens.metric("components.primary_button.height")==48.0, "primary button height token is 48")
	check(UiTokens.metric("components.vehicle_card.width")==216.0, "vehicle card width token is 216")
	check(UiTokens.metric("spacing.focus_border")==2.0, "focus border token is 2")
	check(UiTokens.metric("spacing.panel_padding")==16.0, "panel padding token is 16")
	check(UiTokens.metric("responsive.breakpoints.compact.sidebar")==296.0, "compact sidebar token is 296")
	check(UiTokens.state_names().size()==7, "seven required component states are declared")
	check(UiTokens.state_names().has("busy") and UiTokens.state_names().has("error"), "busy and error states are declared")

	var canon := FileAccess.open(CANON,FileAccess.READ)
	var copy := FileAccess.open(COPY,FileAccess.READ)
	check(canon!=null and copy!=null, "both the canonical file and the traceability copy are readable")
	if canon!=null and copy!=null:
		check(canon.get_as_text()==copy.get_as_text(), "traceability copy is byte-identical to the canonical token file")

	var theme := GarageTheme.theme()
	check(theme.default_font_size==roundi(float(UiTokens.font_size("body_button_input"))*AccessibilitySettings.ui_scale), "theme default size follows the token at the current ui_scale")
	var normal := theme.get_stylebox("normal","Button") as StyleBoxFlat
	check(normal!=null and normal.bg_color==GarageTheme.surface(), "button normal background uses the surface token")
	var hover := theme.get_stylebox("hover","Button") as StyleBoxFlat
	check(hover!=null and hover.bg_color==GarageTheme.surface_raised(), "button hover uses the surface_raised token and does not impersonate selection")
	var focus := theme.get_stylebox("focus","Button") as StyleBoxFlat
	check(focus!=null and focus.border_color==GarageTheme.ACCENT, "focus border uses the accent token")
	check(focus!=null and focus.border_width_left==int(UiTokens.metric("spacing.focus_border")), "focus border width uses the token")
	check(theme.get_color("font_color","Button")==GarageTheme.PAPER, "button text uses the text_primary token")
	check(theme.get_color("font_disabled_color","Button")==GarageTheme.disabled_text(), "disabled text uses the disabled_text token")
	var panel := theme.get_stylebox("panel","PanelContainer") as StyleBoxFlat
	check(panel!=null and panel.border_color==GarageTheme.border_decorative(), "panels separate with the border_decorative token")
	check(panel!=null and panel.content_margin_left==UiTokens.metric("spacing.panel_padding"), "panel padding uses the token")
	var line := theme.get_stylebox("normal","LineEdit") as StyleBoxFlat
	check(line!=null and line.border_color==GarageTheme.control_outline(), "input outline uses the control_outline token")
	var primary_button := Button.new()
	GarageTheme.primary(primary_button)
	check(primary_button.custom_minimum_size.y==UiTokens.metric("components.primary_button.height"), "main button height uses the token instead of a hard-coded value")
	check(primary_button.get_theme_color("font_color")==INK_FOR_TEST, "main button text uses on_accent")
	primary_button.free()
	check(GarageTheme.ACCENT==UiTokens.color("accent"), "the legacy ACCENT name still resolves to the accent token")
	check(GarageTheme.PAPER==UiTokens.color("text_primary") and GarageTheme.MUTED==UiTokens.color("text_secondary"), "legacy PAPER/MUTED names map to the text tokens")
	print("=== ui tokens: %d checks, %d failed ===" % [count,failed])
	print("UI_TOKEN_CHECKS_PASS" if failed==0 else "UI_TOKEN_CHECKS_FAIL")
	quit(0 if failed==0 else 1)

const INK_FOR_TEST := Color("#141A1E")
