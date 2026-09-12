class_name ArmorLayerProfile
extends RefCounted
## Authored passive composite resistance. Physical thickness/positions stay on each patch.
## This is neither a historical material claim nor consumable reactive armor.
const VERSION := "wt012-passive-composite-v1"
const CHANNELS := ["kinetic", "chemical", "fragment"]

static func validate(value: Variant, material: String) -> Array[String]:
	if not value is Dictionary: return ["response_profile: expected dictionary"]
	if material != "composite":
		return [] if value.is_empty() else ["response_profile: only explicit composite material accepts layer rules"]
	if value.get("version") != VERSION or value.get("provenance") != "game_rule": return ["response_profile: explicit versioned game rule required"]
	if not value.get("reason") is String or str(value.get("reason", "")).strip_edges().is_empty(): return ["response_profile: design explanation required"]
	var table: Variant = value.get("coefficients")
	if not table is Dictionary or table.size() != CHANNELS.size(): return ["response_profile: three separate response channels required"]
	for channel in CHANNELS:
		var n: Variant = table.get(channel)
		if not (n is int or n is float) or not is_finite(float(n)) or n <= 0 or n > 10: return ["response_profile: finite positive bounded " + channel + " coefficient required"]
	for key in value:
		if key not in ["version", "provenance", "reason", "coefficients"]: return ["response_profile: unsupported rule " + str(key)]
	return []

static func response(value: Dictionary, projectile: Dictionary, thickness: float, angle: float) -> Dictionary:
	var channel := "fragment" if projectile.family == "fragment" else ("chemical" if projectile.family == "HEAT" else "kinetic")
	var factor := ArmorImpactProfile._angle_factor(projectile.angle_resistance_curve, angle) if projectile.family == "APFSDS" else 1.0 / cos(deg_to_rad(angle))
	var coefficient := float(value.coefficients[channel])
	# Full-caliber normalization/bore overmatch describe steel, not this composite stack.
	return {"ok":true, "resistance_mm":thickness * factor * coefficient, "adjusted_angle_deg":angle,
		"material_multiplier":coefficient, "angle_multiplier":factor, "overmatch":false,
		"ricochet":channel != "chemical" and angle >= float(projectile.get("ricochet_deg",90)) - 1e-5,
		"layer_profile_version":VERSION, "layer_channel":channel}
