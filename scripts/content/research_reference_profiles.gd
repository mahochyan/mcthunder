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
	if parsed.get("schema_version")==1 and parsed.get("profiles") is Array:
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
		var runtime: Dictionary=packet.runtime
		for key in ["forward_max_speed","reverse_max_speed","acceleration","hull_turn_speed"]:
			if not _positive(runtime.get(key)): return {"ok":false,"error":"combat_runtime_invalid_"+key}
		return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"combat_packet","source_sha256":expected,
			"forward_max_speed":float(runtime.forward_max_speed),"reverse_max_speed":float(runtime.reverse_max_speed),
			"acceleration":float(runtime.acceleration),"hull_turn_speed":float(runtime.hull_turn_speed),
			"design_fallbacks":[]}
	var data:=profile(vehicle_id)
	if data.is_empty(): return {"ok":false,"error":"reference_profile_missing"}
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
	if not acceleration is Dictionary or acceleration.get("resolution_state")!="project_design_fallback" or not _positive(acceleration.get("value")):
		return {"ok":false,"error":"trial_acceleration_unresolved"}
	return {"ok":true,"vehicle_id":vehicle_id,"source_kind":"warthunder_reference","source_sha256":source.sha256,
		"forward_max_speed":float(mobility.forward_max_mps.value),"reverse_max_speed":float(mobility.reverse_max_mps.value),
		"acceleration":float(acceleration.value),"hull_turn_speed":float(mobility.hull_turn_deg_s.value),
		"design_mass_kg":mobility.get("design_mass_kg",{}).get("value"),"design_fallbacks":["acceleration"]}
