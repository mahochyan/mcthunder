class_name UiTokens
extends RefCounted
## WT-UI-002 (MCT-UI-FIELDWORK-01): reads the ORIGINAL design token file.
##
## res://configs/ui/ui_tokens.json is a byte-identical copy of the design package's 07_UI_TOKENS.json, which the
## user reissued on 2026-09-17 (reissue manifest lists sha256 9e429a76cb26409253d22768ce032ced409c6da50f6a8627631f7466987f1be7).
## The design's own structure is used as-is: flat colour strings, font.sizes_at_ui_scale_1, components.*,
## layouts.*, motion_ms.*. Nothing is renamed and nothing is re-derived from the readable design.
##
## Colour ruling (user, 2026-09-17): the token table governs; focus and accent are the same warm gold #E0B46A;
## the earlier mockup's chip strip is atmosphere reference only and must not replace these tokens or turn the
## ordinary deploy button red.
##
## This reader never becomes a new failure point: if the file is missing or malformed, every accessor falls back
## to the values copied from that same original file, so UI construction cannot depend on file IO succeeding.
const PATH := "res://configs/ui/ui_tokens.json"
## UI-BIZ-01 (this pass): an ADDITIVE overlay beside the original. The original file above stays the governing
## source and not one of its keys is redefined here; the overlay only adds depth, glow, type-scale, motion and
## icon-policy tokens. If it is missing or malformed, every overlay accessor falls back to the caller's default, so
## it can never become a new failure point either - the same promise the original reader makes.
const BIZ_PATH := "res://configs/ui/ui_tokens_biz.json"

const FALLBACK_COLORS := {
	"background":"#10171B", "surface":"#182329", "surface_raised":"#223139",
	"border_decorative":"#35464E", "control_outline":"#697F88",
	"text_primary":"#ECEDE6", "text_secondary":"#A8B6BA",
	"accent":"#E0B46A", "on_accent":"#141A1E", "focus":"#E0B46A",
	"ally":"#7FC9E0", "enemy":"#F17C72", "warning":"#E8BE70",
	"critical":"#FF8A80", "positive":"#A0CBA1", "disabled_text":"#83969D",
}
const FALLBACK_SIZES := {
	"vehicle_title":34, "page_title":28, "section":20, "body":16,
	"button":16, "secondary":14, "hud_number":24, "critical_notice":18,
}
const FALLBACK_METRICS := {
	"font.body_line_height_ratio":1.35,
	"components.radius":4.0, "components.border":1.0, "components.focus_border":2.0,
	"components.primary_button_min_height":48.0, "components.button_min_height":40.0,
	"components.panel_padding":16.0,
	"layouts.wide.outer_margin":32.0, "layouts.wide.sidebar":344.0, "layouts.wide.gap":24.0,
	"layouts.standard.outer_margin":24.0, "layouts.standard.sidebar":320.0, "layouts.standard.gap":16.0,
	"layouts.compact.outer_margin":16.0, "layouts.compact.sidebar":296.0, "layouts.compact.gap":12.0,
	"layouts.menu_max_width":1920.0,
	"motion_ms.hover":100.0, "motion_ms.page":160.0, "motion_ms.drawer":180.0,
	"motion_ms.toast":160.0, "motion_ms.tooltip_delay":350.0,
	"contrast_targets.readable_text":4.5, "contrast_targets.essential_non_text":3.0,
	"contrast_targets.high_contrast_body":7.0,
}

## The seven required component states come from the readable design's section 4; the token file itself does not
## carry them, so this list is the one place they are restated and it is asserted by the token self-test.
const REQUIRED_STATES := ["normal", "hover", "pressed", "focused", "disabled", "busy", "error"]

static var _data: Dictionary = {}
static var _biz: Dictionary = {}
static var _loaded := false
static var _biz_loaded := false
static var _source := "fallback"

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

static func _read_biz() -> Dictionary:
	if not FileAccess.file_exists(BIZ_PATH):
		return {}
	var file := FileAccess.open(BIZ_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

static func biz_data() -> Dictionary:
	if not _biz_loaded:
		_biz_loaded = true
		_biz = _read_biz()
	return _biz

## "json" when the overlay was read, "absent" when this build runs on the original tokens alone.
static func biz_source() -> String:
	biz_data()
	return "json" if not _biz.is_empty() else "absent"

static func biz_ready() -> bool:
	return biz_source() == "json"

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		_data = _read()
		_source = "json" if not _data.is_empty() else "fallback"
	return _data

## "json" when the reissued token file was read, "fallback" when the compiled defaults are in use.
static func source() -> String:
	data()
	return _source

static func schema_version() -> int:
	return int(data().get("schema_version", 1))

static func design_status() -> String:
	return str(data().get("status", "design_proposal_not_installed"))

## Flat colour strings, exactly as the design file stores them.
static func color(name: String, fallback: String = "") -> Color:
	var section: Variant = data().get("colors", {})
	if section is Dictionary and section.has(name):
		return Color(str(section[name]))
	return Color(str(FALLBACK_COLORS.get(name, fallback if not fallback.is_empty() else "#000000")))

static func font_size(role: String, fallback: int = 16) -> int:
	var section: Variant = data().get("font", {})
	if section is Dictionary:
		var sizes: Variant = section.get("sizes_at_ui_scale_1", {})
		if sizes is Dictionary and sizes.has(role):
			return int(sizes[role])
	return int(FALLBACK_SIZES.get(role, fallback))

static func _lookup(path: String) -> Variant:
	return _lookup_in(data(),path)

## Dotted lookup inside any parsed token dictionary, so the overlay uses the same traversal as the original.
static func _lookup_in(node_in: Variant, path: String) -> Variant:
	var node: Variant = node_in
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return null
	return node

## Dotted lookup for numeric values, e.g. "components.focus_border" or "motion_ms.hover".
static func metric(path: String, fallback: float = 0.0) -> float:
	var node: Variant = _lookup(path)
	if node is float or node is int:
		return float(node)
	return float(FALLBACK_METRICS.get(path, fallback))

## Dotted lookup for array values, e.g. "components.icon_hitbox_min" or "layouts.hud_wide.objective".
static func metric_array(path: String, fallback: Array = []) -> Array:
	var node: Variant = _lookup(path)
	if node is Array:
		return node
	return fallback

static func state_names() -> Array:
	return REQUIRED_STATES.duplicate()

static func forbidden_static_mock_values() -> Array:
	var out: Variant = data().get("forbidden_static_mock_values", [])
	return out if out is Array else []

static func performance_policy() -> String:
	return str(data().get("performance_policy", "HOLD_BY_USER; no benchmarking or claimed FPS improvement"))

static func ui_scale_first_delivery() -> Array:
	var section: Variant = data().get("font", {})
	if section is Dictionary:
		var scales: Variant = section.get("ui_scale_first_delivery", [])
		if scales is Array and not scales.is_empty():
			return scales
	return [1.0, 1.25]

## True when the reissued token file parsed and carries the colour table.
static func ready() -> bool:
	return source() == "json" and data().get("colors", {}) is Dictionary and not data().get("colors", {}).is_empty()

## --- UI-BIZ-01 overlay accessors (additive; the original accessors above are untouched) -------------------------

## Overlay colour, e.g. "surface_sunken" or "accent_line". Falls back to the caller's string when absent.
static func biz_color(name: String, fallback: String = "") -> Color:
	var section: Variant = biz_data().get("palette_additions", {})
	if section is Dictionary and section.has(name):
		return Color(str(section[name]))
	if fallback.is_empty():
		return UiTokens.color(name,"#FF00FF")
	return Color(fallback)

## Dotted overlay lookup for numbers, e.g. "elevation.panel_blur" or "motion.page_ms".
static func biz_metric(path: String, fallback: float = 0.0) -> float:
	var node: Variant = _lookup_in(biz_data(),path)
	if node is float or node is int:
		return float(node)
	return fallback

static func biz_metric_array(path: String, fallback: Array = []) -> Array:
	var node: Variant = _lookup_in(biz_data(),path)
	if node is Array:
		return node
	return fallback

## Overlay type scale, e.g. "display_l", "number_m", "logotype".
static func biz_type_size(role: String, fallback: int = 16) -> int:
	var node: Variant = _lookup_in(biz_data(),"type_scale."+role)
	if node is float or node is int:
		return int(node)
	return fallback

## Overlay motion duration in milliseconds, e.g. "panel_in_ms" or "state_ms".
static func biz_motion(ms_name: String, fallback: float = 120.0) -> float:
	return biz_metric("motion."+ms_name, fallback)

## Overlay easing curve name, e.g. "ease_standard".
static func biz_ease(ease_name: String, fallback: String = "ease_out") -> String:
	var node: Variant = _lookup_in(biz_data(),"motion."+ease_name)
	return str(node) if node is String and not str(node).is_empty() else fallback

## Elevation step as a dictionary {offset_y, blur, alpha}, resolved from the overlay's flat keys.
static func biz_elevation(step: String) -> Dictionary:
	var prefix := step + "_"
	return {
		"offset_y": biz_metric("elevation."+prefix+"offset_y", 0.0),
		"blur": biz_metric("elevation."+prefix+"blur", 0.0),
		"alpha": biz_metric("elevation."+prefix+"alpha", 0.0),
	}
