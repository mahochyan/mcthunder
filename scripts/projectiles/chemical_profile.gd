class_name ChemicalProfile
extends RefCounted
## Authored constant chemical budget and finite instantaneous terminal ray.
const VERSION := "wt013-chemical-jet-v1"
const MAX_CONTACTS := 16

static func validate(value: Variant, effect: String) -> Array[String]:
	var errors: Array[String]=[]
	if not value is Dictionary: return ["chemical_profile: dictionary required"]
	if value.is_empty():
		if effect=="chemical": errors.append("chemical_profile: explicit terminal rules required")
		return errors
	if effect!="chemical" or value.get("version")!=VERSION: errors.append("chemical_profile: unsupported effect/version")
	if value.get("provenance")!="game_rule" or not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): errors.append("chemical_profile: game-rule explanation required")
	for key in ["penetration_mm","range_m","path_loss_mm_per_m"]:
		if not _number(value.get(key)): errors.append("chemical_profile: finite "+key+" required")
	if not errors.is_empty(): return errors
	if value.penetration_mm<=0 or value.penetration_mm>2000 or value.range_m<=0 or value.range_m>8 or value.path_loss_mm_per_m<0 or value.path_loss_mm_per_m>1000: errors.append("chemical_profile: values outside authored game bounds")
	return errors

static func matches_curve(profile: Dictionary, curve: PackedVector2Array) -> bool:
	if profile.is_empty(): return true
	if not _number(profile.get("penetration_mm")): return false
	if not PenetrationCurve.validate(curve): return false
	for point in curve:
		if absf(point.y-float(profile.penetration_mm))>0.0001: return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
