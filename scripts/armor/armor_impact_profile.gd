class_name ArmorImpactProfile
extends RefCounted
## Explicit full-caliber game response, separate from measured armor geometry.
const VERSION := "wt012-full-caliber-v1"
const LONG_ROD_VERSION := "wt012-long-rod-v1"
const CHEMICAL_VERSION := "wt012-chemical-v1"
const UNIT := "game_rha_equivalent_mm"

static func validate(value: Variant, effect: String, fragment: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary: return ["impact_profile: expected dictionary"]
	if value.is_empty():
		if effect in ["long_rod","chemical"]: errors.append("impact_profile: modern terminal effect requires explicit rules")
		return errors
	if value.get("version")==LONG_ROD_VERSION: return _validate_long_rod(value,effect,fragment)
	if value.get("version")==CHEMICAL_VERSION: return _validate_chemical(value,effect,fragment)
	if value.get("version") != VERSION: errors.append("impact_profile: unsupported version")
	if not fragment and effect not in ["kinetic","internal_burst","he_blast"]: errors.append("impact_profile: unsupported effect")
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
	# Long-rod fragments must receive a separately authored profile when spall is implemented.
	if parent.get("version")==LONG_ROD_VERSION: return {}
	var value := parent.duplicate(true)
	value.family="fragment"; value.normalization_deg=0.0; value.overmatch_ratio=0.0
	return value

static func response(profile: Dictionary, material: String, caliber: float, thickness: float, angle: float) -> Dictionary:
	if not profile.material_coefficients.has(material): return {"ok":false,"reason":"unknown_material"}
	if profile.get("version")==CHEMICAL_VERSION:
		var multiplier := float(profile.material_coefficients[material])
		return {"ok":true,"resistance_mm":thickness/cos(deg_to_rad(angle))*multiplier,"adjusted_angle_deg":angle,
			"material_multiplier":multiplier,"overmatch":false,"ricochet":false}
	if profile.get("version")==LONG_ROD_VERSION:
		var factor := _angle_factor(profile.angle_resistance_curve,angle)
		var material_factor := float(profile.material_coefficients[material])
		return {"ok":true,"resistance_mm":thickness*factor*material_factor,"adjusted_angle_deg":angle,
			"material_multiplier":material_factor,"angle_multiplier":factor,"overmatch":false,
			"ricochet":angle>=float(profile.ricochet_deg)-1e-5}
	var corrected := maxf(0.0,angle-float(profile.normalization_deg))
	var multiplier := float(profile.material_coefficients[material])
	var resistance := thickness/cos(deg_to_rad(corrected))*multiplier
	if not is_finite(resistance): return {"ok":false,"reason":"invalid"}
	var overmatch: bool = profile.family!="fragment" and float(profile.overmatch_ratio)>0 and thickness>0 and caliber/thickness>=float(profile.overmatch_ratio)
	return {"ok":true,"resistance_mm":resistance,"adjusted_angle_deg":corrected,"material_multiplier":multiplier,
		"overmatch":overmatch,"ricochet":not overmatch and angle>=float(profile.ricochet_deg)-1e-5}

static func _validate_long_rod(value: Dictionary, effect: String, fragment: bool) -> Array[String]:
	var errors: Array[String]=[]
	if effect!="long_rod" or fragment or value.get("family")!="APFSDS": errors.append("impact_profile: long-rod family/effect mismatch")
	if value.get("provenance")!="game_rule" or not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): errors.append("impact_profile: explicit game-rule reason required")
	# Gun bore diameter does not become penetrator diameter. Full-caliber rules are forbidden.
	if value.has("normalization_deg") or value.has("overmatch_ratio"): errors.append("impact_profile: full-caliber normalization/overmatch forbidden for long rods")
	var threshold: Variant=value.get("ricochet_deg")
	if not _number(threshold) or threshold<=0 or threshold>=90: errors.append("impact_profile: invalid ricochet angle")
	var curve: Variant=value.get("angle_resistance_curve")
	if not curve is Array or curve.size()<2 or curve.size()>16: errors.append("impact_profile: explicit bounded angle curve required")
	else:
		var prior_angle := -1.0
		var prior_factor := 0.0
		for point in curve:
			if not point is Array or point.size()!=2 or not _number(point[0]) or not _number(point[1]):
				errors.append("impact_profile: invalid angle curve point"); continue
			if point[0]<0 or point[0]>90 or point[0]<=prior_angle or point[1]<1 or point[1]>100 or point[1]<prior_factor: errors.append("impact_profile: angle curve must increase with positive resistance")
			prior_angle=float(point[0]); prior_factor=float(point[1])
		if errors.is_empty() and (curve[0][0]!=0 or curve[0][1]!=1 or curve.back()[0]!=90): errors.append("impact_profile: angle curve must cover 0..90 degrees with normal resistance1")
	var materials: Variant=value.get("material_coefficients")
	if not materials is Dictionary or materials.size()!=2 or not materials.has("rolled") or not materials.has("cast"): errors.append("impact_profile: explicit rolled/cast responses required")
	else:
		for coefficient in materials.values():
			if not _number(coefficient) or coefficient<=0 or coefficient>10: errors.append("impact_profile: invalid material coefficient")
	return errors

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _validate_chemical(value: Dictionary, effect: String, fragment: bool) -> Array[String]:
	var errors: Array[String]=[]
	if effect!="chemical" or fragment or value.get("family")!="HEAT": errors.append("impact_profile: chemical family/effect mismatch")
	if value.get("provenance")!="game_rule" or not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): errors.append("impact_profile: chemical game-rule explanation required")
	for field in ["normalization_deg","overmatch_ratio","ricochet_deg"]:
		if value.has(field): errors.append("impact_profile: chemical ray cannot inherit kinetic "+field)
	var materials: Variant=value.get("material_coefficients")
	if not materials is Dictionary or materials.size()!=2 or not materials.has("rolled") or not materials.has("cast"): errors.append("impact_profile: explicit chemical rolled/cast response required")
	else:
		for coefficient in materials.values():
			if not _number(coefficient) or coefficient<=0 or coefficient>10: errors.append("impact_profile: invalid chemical material coefficient")
	return errors

static func _angle_factor(curve: Array, angle: float) -> float:
	for index in range(1,curve.size()):
		if angle<=float(curve[index][0]):
			var previous: Array=curve[index-1]
			var next: Array=curve[index]
			return lerpf(float(previous[1]),float(next[1]),(angle-float(previous[0]))/(float(next[0])-float(previous[0])))
	return float(curve.back()[1])
