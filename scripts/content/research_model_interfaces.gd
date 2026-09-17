class_name ResearchModelInterfaces
extends RefCounted
## Hash-bound node contract for the model actually shown in research trial mode.

const PATH := "res://assets/research/research_model_interfaces.json"
static var _loaded:=false
static var _catalog: Dictionary={}
static var _by_id: Dictionary={}

static func catalog() -> Dictionary:
	if _loaded: return _catalog
	_loaded=true
	if not FileAccess.file_exists(PATH): return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary: return {}
	_catalog=parsed
	if parsed.get("schema_version")==2 and parsed.get("interfaces") is Array:
		for row in parsed.interfaces:
			if row is Dictionary: _by_id[str(row.get("id",""))]=row
	return _catalog

static func interface_for(row: Dictionary) -> Dictionary:
	catalog()
	var vehicle_id:=str(row.get("id",""))
	var interface: Variant=_by_id.get(vehicle_id)
	if not interface is Dictionary: return {"ok":false,"error":"model_interface_missing"}
	var selected: Variant=row.get("model")
	if row.get("combat_package") is Dictionary: selected=row.combat_package.get("runtime_model")
	if not selected is Dictionary: return {"ok":false,"error":"selected_model_missing"}
	var record: Dictionary=interface.get("model",{})
	var path:=str(record.get("path",""))
	var expected:=str(record.get("sha256",""))
	if path!=str(selected.get("path","")) or expected!=str(selected.get("sha256","")):
		return {"ok":false,"error":"model_interface_selection_mismatch"}
	if path.is_empty() or not FileAccess.file_exists(path): return {"ok":false,"error":"model_interface_file_missing"}
	if FileAccess.get_sha256(path)!=expected: return {"ok":false,"error":"model_interface_hash_mismatch"}
	if not bool(interface.get("trial_rig_ready",false)) or not interface.get("nodes") is Dictionary:
		return {"ok":false,"error":"trial_rig_not_ready"}
	if interface.get("locomotion") not in ["tracked","wheeled"]:
		return {"ok":false,"error":"locomotion_interface_invalid"}
	var weapon_control:=str(interface.get("weapon_control",""))
	if weapon_control not in ["yaw_pitch","unavailable_nonstandard","none"]:
		return {"ok":false,"error":"weapon_interface_invalid"}
	if bool(interface.get("weapon_rig_ready",false))!=(weapon_control=="yaw_pitch"):
		return {"ok":false,"error":"weapon_interface_readiness_mismatch"}
	var out: Dictionary=interface.duplicate(true)
	out["ok"]=true
	return out
