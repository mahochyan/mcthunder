class_name ReactiveArmorProfile
extends RefCounted
## Single-use, geometry-local ERA design rule; independent of passive material thickness.
const VERSION := "wt012-reactive-v1"
const CHANNELS := ["kinetic","chemical","fragment"]

static func validate(value: Variant) -> Array[String]:
	if not value is Dictionary: return ["reactive_profile: expected dictionary"]
	if value.is_empty(): return []
	if value.get("version")!=VERSION or value.get("provenance")!="game_rule": return ["reactive_profile: versioned game rule required"]
	if not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): return ["reactive_profile: design reason required"]
	var angle: Variant=value.get("max_trigger_angle_deg")
	if not _number(angle) or angle<=0 or angle>=90: return ["reactive_profile: bounded trigger angle required"]
	var channels: Variant=value.get("channels")
	if not channels is Dictionary or channels.size()!=3: return ["reactive_profile: independent three-channel rules required"]
	for channel in CHANNELS:
		var rule: Variant=channels.get(channel)
		if not rule is Dictionary or rule.size()!=2: return ["reactive_profile: explicit channel threshold and reduction required"]
		for key in ["trigger_min_mm","reduction_mm"]:
			var n: Variant=rule.get(key)
			if not _number(n) or n<0 or n>2000: return ["reactive_profile: invalid "+channel+" "+key]
	for key in value:
		if key not in ["version","provenance","reason","max_trigger_angle_deg","channels"]: return ["reactive_profile: unsupported field "+str(key)]
	return []

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.size()>VehicleArmorLayers.MAX_LAYERS: return false
	for id in value:
		if not id is String or id.length()>128 or not id.is_valid_identifier(): return false
		var charge: Variant=value[id]
		if not _number(charge) or (charge!=0 and charge!=1): return false
	return true

static func response(profile: Dictionary, before: int, family: String, residual: float, angle: float, inward: bool, ricochet: bool) -> Dictionary:
	var channel := "chemical" if family=="HEAT" else ("fragment" if family=="fragment" else "kinetic")
	var rule: Dictionary=profile.channels[channel]
	var triggered := before==1 and inward and not ricochet and residual>0.00001 and residual>=float(rule.trigger_min_mm) and float(rule.reduction_mm)>0 and angle<=float(profile.max_trigger_angle_deg)
	return {"reactive_version":VERSION,"reactive_before":before,"reactive_after":0 if triggered else before,
		"reactive_triggered":triggered,"reactive_channel":channel,"reactive_bonus_mm":float(rule.reduction_mm) if triggered else 0.0}
