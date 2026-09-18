class_name CoreUI
extends RefCounted
## WT-UI-002 (MCT-UI-FIELDWORK-01): the base theme and the component factories now read their type sizes,
## spacing and colours from UiTokens (the design's own reissued 07_UI_TOKENS.json), so CoreUI and GarageTheme
## agree on one token source instead of carrying separate literals.
##
## FONT is deliberately unchanged: the design says to reuse the licensed project CJK font
## (res://assets/fonts/NotoSansCJKsc-Regular.otf) and adds no font binary, so nothing is replaced, downloaded or
## redistributed here.
const FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
static var NAMES := {"engine":LocalizationService.text("ui_5a0d47438ef5"),"breech":LocalizationService.text("ui_ae1c78c50a64"),"track_left":LocalizationService.text("ui_7fdf3ebc2bbe"),"track_right":LocalizationService.text("ui_6f3229c73f2a"),"turret_drive":LocalizationService.text("ui_b5b491b0ce95"),"ammo_rack":LocalizationService.text("ui_84fab106158e"),"transmission":LocalizationService.text("ui_fb1e9fe6cd2e"),"fuel":LocalizationService.text("ui_bfcff0c001f2"),"gunner":LocalizationService.text("ui_5d3e840fb781"),"driver":LocalizationService.text("ui_a339602c59eb"),"loader":LocalizationService.text("ui_0f1cc40b8cd8"),"commander":LocalizationService.text("ui_988a80f569fb"),"assistant_driver":LocalizationService.text("ui_df863d11304a"),"penetrated":LocalizationService.text("ui_ec354f1bd800"),"stopped":LocalizationService.text("ui_693194096f2b"),"ricochet":LocalizationService.text("ui_ccc03fd96808"),"unknown":LocalizationService.text("ui_e82545c94af2"),"module_destroyed":LocalizationService.text("ui_e1e63b6022ec"),"module_damaged":LocalizationService.text("ui_3ce1d20c1b42"),"crew_incapacitated":LocalizationService.text("ui_d9e20a806ef3"),"repair":LocalizationService.text("ui_fede1630f0f8"),"extinguish":LocalizationService.text("ui_e00a264128bd"),"replace":LocalizationService.text("ui_2be43d64ba78"),"hull_front":LocalizationService.text("ui_ca979bae173f"),"hull_rear":LocalizationService.text("ui_59d3995d9b49"),"hull_left":LocalizationService.text("ui_452a57a7366d"),"hull_right":LocalizationService.text("ui_3eb8d798a89a")}

static func word(value: String) -> String:
	if value == "unknown_material": return LocalizationService.text("armor_unknown_material")
	if value == "autoloader": return LocalizationService.text("loading_automatic_module")
	if value == "assistant_driver_bow_gunner": return LocalizationService.text("ui_df863d11304a")
	if value == "ammo_floor_left": return LocalizationService.text("ui_7bbde2f3fc4b")
	if value == "ammo_floor_right": return LocalizationService.text("ui_1054d528b204")
	if value == "ammo_ready": return LocalizationService.text("ui_3e0d8062d861")
	return NAMES.get(value,AI_WORDS.get(value,value.replace("_"," ")))

static var AI_WORDS := {"idle":LocalizationService.text("ui_1a474c3207ed"),"following":LocalizationService.text("ui_840206d70d52"),"yielding":LocalizationService.text("ui_a58651c26546"),"reverse":LocalizationService.text("ui_e4fd7b75abec"),"turn_recovery":LocalizationService.text("ui_c2aa0a6dc826"),"arrived":LocalizationService.text("ui_434c6ad59d72"),"unreachable":LocalizationService.text("ui_33cf8e259e85"),"failed":LocalizationService.text("ui_ec1a2fbcb28f"),"disabled":LocalizationService.text("ui_e525d8be4dab"),"destroyed":LocalizationService.text("ui_a8fa60d92311"),"path_ready":LocalizationService.text("ui_b47e4e1d8250"),"physical_obstacle":LocalizationService.text("ui_5f3277d7fe69"),"obstacle_cleared":LocalizationService.text("ui_443eb5c460de"),"insufficient_actual_progress":LocalizationService.text("ui_94ea1ebe9c92"),"reverse_complete":LocalizationService.text("ui_330d2af24c8a"),"goal_reached":LocalizationService.text("ui_a4f576a34dc2"),"unreachable_or_insufficient_width":LocalizationService.text("ui_df72e5ac2852"),"recovery_limit":LocalizationService.text("ui_6e43bfe6b6a5"),"drive_capability":LocalizationService.text("ui_74013256bb30"),"drive_recovered":LocalizationService.text("ui_a1c29fae8bc1"),"generation_changed":LocalizationService.text("ui_b957afbf74fc"),"detached":LocalizationService.text("ui_c3db2b51e931"),"reset":LocalizationService.text("ui_44223ec59a50"),"new_goal":LocalizationService.text("ui_3cecc651752f")}

static func _styled(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color = bg
	out.border_color = border
	out.set_border_width_all(int(UiTokens.metric("components.border",1.0)))
	out.set_content_margin_all(padding)
	out.set_corner_radius_all(int(UiTokens.metric("components.radius",4.0)))
	return out

static func theme() -> Theme:
	# UI-BIZ-01 stage 3 (whole-style pass): the theme is now built once in BizTheme from the original tokens plus the
	# additive overlay, and every screen that asks CoreUI or GarageTheme for a theme gets that one skin. Geometry still
	# comes from the original token file (border 1, focus 2, corner 4, panel padding 16), which the token self-test
	# measures against the real styleboxes, so the new look cannot drift the metrics the design fixed.
	return BizTheme.theme()

static func apply(root: Node) -> void:
	if root is Control: root.theme = theme()
	for child in root.get_children(): apply(child)

static func label(parent: Node, text: String, font_size: int = 18) -> Label:
	var out := Label.new()
	out.text = text
	out.set_meta("hud_font_size",font_size)
	out.add_theme_font_size_override("font_size",roundi(float(font_size) * AccessibilitySettings.ui_scale))
	parent.add_child(out)
	return out

static func button(parent: Node, text: String, callback: Callable) -> Button:
	var out := Button.new()
	out.text = text
	out.pressed.connect(callback)
	# Token role "button" (16 at ui_scale 1) replaces the previous literal 17.
	var size := UiTokens.font_size("button",16)
	out.set_meta("hud_font_size",size)
	out.add_theme_font_size_override("font_size",roundi(float(size) * AccessibilitySettings.ui_scale))
	parent.add_child(out)
	return out
