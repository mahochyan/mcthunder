class_name ResearchReferenceProfiles
extends RefCounted
## Exact-ID access to compact research data. These values come from game-reference
## snapshots and never imply historical verification or combat admission.

const PATH := "res://assets/research/research_runtime_profiles.json"
static var _loaded:=false
static var _catalog_cache: Dictionary={}
static var _profiles_by_id: Dictionary={}

static func catalog() -> Dictionary:
	if _loaded: return _catalog_cache
	_loaded=true
	if not FileAccess.file_exists(PATH): return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary: return {}
	_catalog_cache=parsed
	if parsed.get("schema_version")==2 and parsed.get("gameplay_mode")=="arcade" and parsed.get("profiles") is Array:
		for row in parsed.profiles:
			if row is Dictionary: _profiles_by_id[str(row.get("id",""))]=row
	return _catalog_cache

static func profile(vehicle_id: String) -> Dictionary:
	catalog()
	return _profiles_by_id.get(vehicle_id,{})

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>0.0

static func _nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0.0

static func mobility_for(row: Dictionary) -> Dictionary:
	var vehicle_id:=str(row.get("id",""))
	if vehicle_id.is_empty(): return {"ok":false,"error":"missing_vehicle_id"}
	var combat: Variant=row.get("combat_package")
	if combat is Dictionary:
		var path:=str(combat.get("path",""))
		var expected:=str(combat.get("sha256",""))
		if path.is_empty() or expected.is_empty() or not FileAccess.file_exists(path): return {"ok":false,"error":"combat_packet_missing"}
		if FileAccess.get_sha256(path)!=expected: return {"ok":false,"error":"combat_packet_hash_mismatch"}
		var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not packet is Dictionary or str(packet.get("id",""))!=vehicle_id or not packet.get("runtime") is Dictionary:
			return {"ok":false,"error":"combat_packet_identity_mismatch"}
		if packet.get("gameplay_mode")!="arcade": return {"ok":false,"error":"combat_packet_not_arcade"}
		var runtime: Dictionary=packet.runtime
		for key in ["forward_max_speed","reverse_max_speed","acceleration","hull_turn_speed"]:
			if not _positive(runtime.get(key)): return {"ok":false,"error":"combat_runtime_invalid_"+key}
		var tuning: Variant=packet.get("arcade_tuning")
		if not tuning is Dictionary: return {"ok":false,"error":"combat_arcade_tuning_missing"}
		if not _positive(tuning.get("base_acceleration_mps2")) or not _positive(tuning.get("arcade_power_multiplier_applied")):
			return {"ok":false,"error":"combat_arcade_tuning_invalid"}
		if not is_equal_approx(float(runtime.acceleration),float(tuning.base_acceleration_mps2)*float(tuning.arcade_power_multiplier_applied)):
			return {"ok":false,"error":"combat_arcade_acceleration_mismatch"}
		return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"arcade_combat_packet","source_sha256":expected,
			"forward_max_speed":float(runtime.forward_max_speed),"reverse_max_speed":float(runtime.reverse_max_speed),
			"acceleration":float(runtime.acceleration),"hull_turn_speed":float(runtime.hull_turn_speed),
			"gameplay_mode":"arcade","arcade_power_multiplier":float(tuning.arcade_power_multiplier_applied),
			"design_fallbacks":(["arcade_power_multiplier"] if tuning.get("resolution_state")=="arcade_design_fallback" else [])}
	var data:=profile(vehicle_id)
	if data.is_empty(): return {"ok":false,"error":"reference_profile_missing"}
	if data.get("gameplay_mode")!="arcade": return {"ok":false,"error":"reference_profile_not_arcade"}
	var source: Dictionary=data.get("source",{})
	if str(source.get("sha256",""))!=str(row.get("source_sha256","")): return {"ok":false,"error":"reference_profile_hash_mismatch"}
	var snapshot:=str(source.get("snapshot",""))
	if snapshot.is_empty() or not FileAccess.file_exists(snapshot): return {"ok":false,"error":"reference_snapshot_missing"}
	if FileAccess.get_sha256(snapshot)!=str(source.get("sha256","")): return {"ok":false,"error":"reference_snapshot_hash_mismatch"}
	var mobility: Dictionary=data.get("mobility",{})
	for key in ["forward_max_mps","reverse_max_mps","hull_turn_deg_s"]:
		var field: Variant=mobility.get(key)
		if not field is Dictionary: return {"ok":false,"error":"reference_mobility_unresolved_"+key}
		var valid_value:=_nonnegative(field.get("value")) if key in ["forward_max_mps","reverse_max_mps"] else _positive(field.get("value"))
		if field.get("resolution_state")!="explicit_reference_candidate" or not valid_value:
			return {"ok":false,"error":"reference_mobility_unresolved_"+key}
	var acceleration: Variant=mobility.get("trial_acceleration_mps2")
	if not acceleration is Dictionary or acceleration.get("resolution_state") not in ["derived_arcade_reference","arcade_design_fallback"] or not _positive(acceleration.get("value")):
		return {"ok":false,"error":"trial_acceleration_unresolved"}
	var multiplier: Variant=mobility.get("arcade_power_multiplier")
	if not multiplier is Dictionary or not _positive(acceleration.get("base_value")) or not _positive(acceleration.get("arcade_power_multiplier_applied")):
		return {"ok":false,"error":"arcade_multiplier_unresolved"}
	if not is_equal_approx(float(acceleration.value),float(acceleration.base_value)*float(acceleration.arcade_power_multiplier_applied)):
		return {"ok":false,"error":"arcade_acceleration_mismatch"}
	if acceleration.get("resolution_state")=="derived_arcade_reference":
		if multiplier.get("resolution_state")!="explicit_reference_candidate" or not _positive(multiplier.get("value")) or not is_equal_approx(float(multiplier.value),float(acceleration.arcade_power_multiplier_applied)):
			return {"ok":false,"error":"arcade_reference_multiplier_mismatch"}
	elif multiplier.get("value")!=null or not is_equal_approx(float(acceleration.arcade_power_multiplier_applied),1.0):
		return {"ok":false,"error":"arcade_fallback_multiplier_mismatch"}
	return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"arcade_reference","source_sha256":source.sha256,
		"forward_max_speed":float(mobility.forward_max_mps.value),"reverse_max_speed":float(mobility.reverse_max_mps.value),
		"acceleration":float(acceleration.value),"hull_turn_speed":float(mobility.hull_turn_deg_s.value),
		"gameplay_mode":"arcade","arcade_power_multiplier":float(acceleration.arcade_power_multiplier_applied),
		"design_mass_kg":mobility.get("design_mass_kg",{}).get("value"),
		"design_fallbacks":(["acceleration","arcade_power_multiplier"] if acceleration.get("resolution_state")=="arcade_design_fallback" else ["acceleration_base"])}

static func weapon_motion_for(row: Dictionary) -> Dictionary:
	var identity:=mobility_for(row)
	if not identity.get("ok",false): return identity
	var vehicle_id:=str(row.get("id",""))
	if row.get("combat_package") is Dictionary:
		var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(row.combat_package.path)))
		if not packet is Dictionary or not packet.get("runtime") is Dictionary: return {"ok":false,"error":"combat_weapon_runtime_missing"}
		var runtime: Dictionary=packet.runtime
		for key in ["turret_yaw_speed","turret_pitch_speed"]:
			if not _positive(runtime.get(key)): return {"ok":false,"error":"combat_weapon_runtime_invalid_"+key}
		var yaw_min:=float(runtime.get("yaw_min",-180.0)); var yaw_max:=float(runtime.get("yaw_max",180.0))
		var pitch_min:=float(runtime.get("pitch_min",-8.0)); var pitch_max:=float(runtime.get("pitch_max",20.0))
		if yaw_min>=yaw_max or pitch_min>=pitch_max: return {"ok":false,"error":"combat_weapon_limits_invalid"}
		return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"combat_packet",
			"yaw_speed":float(runtime.turret_yaw_speed),"pitch_speed":float(runtime.turret_pitch_speed),
			"yaw_min":yaw_min,"yaw_max":yaw_max,"pitch_min":pitch_min,"pitch_max":pitch_max,"design_fallbacks":[]}
	var data:=profile(vehicle_id)
	var traverse: Variant=data.get("primary_weapon",{}).get("traverse_deg_s")
	if not traverse is Dictionary or traverse.get("resolution_state") not in ["explicit_reference_candidate","explicit_reference_duplicate_consistent"]:
		return {"ok":false,"error":"reference_weapon_traverse_unresolved"}
	var value: Variant=traverse.get("value")
	if not value is Dictionary or not _positive(value.get("yaw")) or not _positive(value.get("pitch")):
		return {"ok":false,"error":"reference_weapon_traverse_invalid"}
	return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"warthunder_reference",
		"yaw_speed":float(value.yaw),"pitch_speed":float(value.pitch),
		"yaw_min":-180.0,"yaw_max":180.0,"pitch_min":-8.0,"pitch_max":20.0,
		"design_fallbacks":["yaw_limits","pitch_limits"]}
