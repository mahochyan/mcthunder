class_name UiTokens
extends RefCounted
## WT-UI-002 (MCT-UI-FIELDWORK-01): the machine-readable visual tokens for the FIELDWORK 01 UI pass.
##
## Source of truth: res://configs/ui/ui_tokens.json, which is byte-identical to the design-traceability copy
## docs/wt/continuation/07_UI_TOKENS.json. The design package's own 07_UI_TOKENS.json was not part of this
## transfer, so that file was transcribed verbatim from the supplied readable design (its colour-token table,
## type scale, geometry, motion, breakpoints and icon rules) and is recorded as such in its provenance block.
##
## This reader never becomes a new failure point: if the file is missing or malformed every accessor falls back
## to the compiled defaults below, so UI construction cannot depend on file I/O succeeding.
const PATH := "res://configs/ui/ui_tokens.json"

const FALLBACK_COLORS := {
	"background":"#10171B", "surface":"#182329", "surface_raised":"#223139",
	"border_decorative":"#35464E", "control_outline":"#697F88",
	"text_primary":"#ECEDE6", "text_secondary":"#A8B6BA",
	"accent":"#E0B46A", "on_accent":"#141A1E",
	"ally":"#7FC9E0", "enemy":"#F17C72", "warning":"#E8BE70",
	"critical":"#FF8A80", "positive":"#A0CBA1", "disabled_text":"#83969D",
}
const FALLBACK_TYPE := {
	"vehicle_title":34, "page_title":28, "group_title":20,
	"body_button_input":16, "secondary_note":14,
	"combat_number":24, "combat_critical":18,
}
const FALLBACK_METRICS := {
	"typography.line_height":1.35,
	"spacing.panel_padding":16.0, "spacing.wide_block_gap":24.0, "spacing.compact_gap":12.0,
	"spacing.focus_border":2.0,
	"components.primary_button.height":48.0,
	"components.primary_button.height_wide":52.0,
	"components.secondary_button.height":40.0,
	"components.icon_hit.min":40.0,
	"components.vehicle_card.width":216.0, "components.vehicle_card.height":96.0,
	"components.vehicle_card.compact_width":188.0, "components.vehicle_card.compact_height":80.0,
	"components.dialog.width_min":480.0, "components.dialog.width_max":640.0,
	"components.tooltip.detail_delay_ms":350.0,
	"motion.hover_ms":100.0, "motion.page_transition_ms":160.0,
	"motion.drawer_ms":180.0, "motion.toast_ms":160.0,
	"responsive.breakpoints.wide.margin":32.0, "responsive.breakpoints.wide.sidebar":344.0,
	"responsive.breakpoints.standard.margin":24.0, "responsive.breakpoints.standard.sidebar":320.0,
	"responsive.breakpoints.compact.margin":16.0, "responsive.breakpoints.compact.sidebar":296.0,
	"icons.viewbox":24.0,
}

static var _data: Dictionary = {}
static var _loaded := false
static var _source := "fallback"

## Reads the token file once. Returns an empty dictionary when the file is absent or invalid.
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

## "json" when the token file was read, "fallback" when the compiled defaults are in use.
static func source() -> String:
	data()
	return _source

static func color(name: String, fallback: String = "") -> Color:
	var section: Variant = data().get("colors", {})
	if section is Dictionary and section.has(name):
		var entry: Variant = section[name]
		if entry is Dictionary and entry.has("value"):
			return Color(str(entry["value"]))
	return Color(FALLBACK_COLORS.get(name, fallback if not fallback.is_empty() else "#000000"))

static func font_size(role: String, fallback: int = 16) -> int:
	var section: Variant = data().get("typography", {})
	if section is Dictionary:
		var scale: Variant = section.get("scale", {})
		if scale is Dictionary and scale.has(role):
			var entry: Variant = scale[role]
			if entry is Dictionary and entry.has("size"):
				return int(entry["size"])
	return int(FALLBACK_TYPE.get(role, fallback))

## Dotted lookup for the numeric geometry/motion/breakpoint values, e.g. "components.primary_button.height".
static func metric(path: String, fallback: float = 0.0) -> float:
	var node: Variant = data()
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			node = null
			break
	if node is float or node is int:
		return float(node)
	if node is Dictionary and node.has("value"):
		return float(node["value"])
	return float(FALLBACK_METRICS.get(path, fallback))

static func state_names() -> Array:
	var section: Variant = data().get("states", {})
	if section is Dictionary:
		var required: Variant = section.get("required", [])
		if required is Array and not required.is_empty():
			return required
	return ["normal", "hover", "pressed", "focused", "disabled", "busy", "error"]

## True when the token file parsed and carries the accent colour; used by the token self-test as evidence.
static func ready() -> bool:
	return source() == "json" and not data().get("colors", {}).is_empty()
