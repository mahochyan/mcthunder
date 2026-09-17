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
static var _loaded := false
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
	var node: Variant = data()
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
