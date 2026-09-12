class_name ArmorImpactProfile
extends RefCounted
## Explicit full-caliber game response, separate from measured armor geometry.
const VERSION := "wt012-full-caliber-v1"
const UNIT := "game_rha_equivalent_mm"

static func validate(value: Variant, effect: String, fragment: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary: return ["impact_profile: expected dictionary"]
	if value.is_empty(): return errors # Legacy packets preserve their declared rules.
	if value.get("version") != VERSION: errors.append("impact_profile: unsupported version")
	if not fragment and effect not in ["kinetic","internal_burst"]: errors.append("impact_profile: unsupported effect")
	var family := "fragment" if fragment else ("APHE" if effect=="internal_burst" else "AP")
	if value.get("family") != family: errors.append("impact_profile: family/effect mismatch")
	if value.get("provenance") != "game_rule": errors.append("impact_profile: game provenance required")
	if not value.get("reason") is String or str(value.get("reason", "")).strip_edges().is_empty(): errors.append("impact_profile: explanation required")
	for field in ["normalization_deg","overmatch_ratio","ricochet_deg"]:
		var n: Variant = value.get(field)
		if not (n is int or n is float) or not is_finite(float(n)):
			errors.append("impact_profile."+field+": finite number required")
	if not errors.is_empty(): return errors
	if value.normalization_deg<0 or value.normalization_deg>20: errors.append("impact_profile: normalization outside game bounds")
	if value.overmatch_ratio!=0 and (value.overmatch_ratio<1 or value.overmatch_ratio>100): errors.append("impact_profile: invalid overmatch ratio")
	if value.ricochet_deg<=0 or value.ricochet_deg>=90: errors.append("impact_profile: invalid ricochet angle")
	if fragment and (value.normalization_deg!=0 or value.overmatch_ratio!=0): errors.append("impact_profile: fragments cannot borrow shell diameter/normalization")
	var materials: Variant = value.get("material_coefficients")
	if not materials is Dictionary: errors.append("impact_profile: material table required")
	else:
		if materials.size()!=2 or not materials.has("rolled") or not materials.has("cast"): errors.append("impact_profile: explicit rolled/cast responses required; no unknown substitution")
		for key in materials:
			var coefficient: Variant = materials[key]
			if not (coefficient is int or coefficient is float) or not is_finite(float(coefficient)) or coefficient<=0 or coefficient>10:
				errors.append("impact_profile: invalid material coefficient")
	return errors

static func fragment_profile(parent: Dictionary) -> Dictionary:
	if parent.is_empty(): return {}
	var value := parent.duplicate(true)
	value.family="fragment"; value.normalization_deg=0.0; value.overmatch_ratio=0.0
	return value

static func response(profile: Dictionary, material: String, caliber: float, thickness: float, angle: float) -> Dictionary:
	if not profile.material_coefficients.has(material): return {"ok":false,"reason":"unknown_material"}
	var corrected := maxf(0.0,angle-float(profile.normalization_deg))
	var multiplier := float(profile.material_coefficients[material])
	var resistance := thickness/cos(deg_to_rad(corrected))*multiplier
	if not is_finite(resistance): return {"ok":false,"reason":"invalid"}
	var overmatch: bool = profile.family!="fragment" and float(profile.overmatch_ratio)>0 and thickness>0 and caliber/thickness>=float(profile.overmatch_ratio)
	return {"ok":true,"resistance_mm":resistance,"adjusted_angle_deg":corrected,"material_multiplier":multiplier,
		"overmatch":overmatch,"ricochet":not overmatch and angle>=float(profile.ricochet_deg)-1e-5}
