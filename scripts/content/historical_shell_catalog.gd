class_name HistoricalShellCatalog
extends RefCounted
const PATH := "res://configs/shells/historical_loadouts.json"

static func read_packet() -> Dictionary:
	var file := FileAccess.open(PATH,FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func build(vehicle_packet: Dictionary, packet: Dictionary = {}) -> Dictionary:
	if packet.is_empty(): packet = read_packet()
	var errors: Array[String] = []
	if packet.get("schema_version")!=1: errors.append("unsupported shell schema")
	for key in ["sources","shells","vehicles"]:
		if not packet.get(key) is Dictionary: errors.append(key+": missing")
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	if not vehicle_packet.get("id") is String or vehicle_packet.id.is_empty(): return {"ok":false,"errors":["invalid vehicle identity"]}
	var id: String = vehicle_packet.id
	if not packet.vehicles.get(id) is Dictionary: return {"ok":false,"errors":["vehicle has no admitted shell set"]}
	var row: Dictionary = packet.vehicles[id]
	if not row.get("gun") is String or row.gun.is_empty(): return {"ok":false,"errors":["invalid gun identity"]}
	if not vehicle_packet.get("assembly") is Dictionary or row.get("gun","") != vehicle_packet.assembly.get("gun",""): return {"ok":false,"errors":["gun variant mismatch"]}
	if not row.get("shells") is Array or row.shells.size()!=2 or not row.get("default") is String or row.default not in row.shells: return {"ok":false,"errors":["invalid shell set"]}
	var options: Array[ShellDefinition] = []
	var entries: Array[Dictionary] = []
	var unique := {}
	var default_id := ""
	for key in row.shells:
		if not key is String or unique.has(key) or not packet.shells.get(key) is Dictionary: errors.append("invalid shell identity"); continue
		unique[key] = true
		var data: Dictionary = packet.shells[key]
		var strings_valid := true
		for field in ["gun","label","estimate_reason","historical_observations","effect_policy"]:
			if not data.get(field) is String or data[field].is_empty(): strings_valid = false
		if not strings_valid or not _number(data.get("caliber_mm")) or data.caliber_mm<=0: errors.append(key+": malformed shell metadata"); continue
		if data.get("gun","") != row.gun or data.get("caliber_mm",0) != vehicle_packet.assembly.get("caliber_mm",-1): errors.append(key+": weapon incompatibility"); continue
		if data.get("compatibility_status","") != "verified" or data.get("curve_status","") != "estimated" or data.get("effect_status","") != "game_rule": errors.append(key+": evidence status missing"); continue
		if data.get("muzzle_velocity_status","") not in ["verified","estimated"]: errors.append(key+": muzzle velocity status missing"); continue
		if not data.get("source_refs") is Array or data.source_refs.is_empty() or str(data.get("estimate_reason","")).is_empty() or str(data.get("historical_observations","")).is_empty(): errors.append(key+": missing source/estimate explanation"); continue
		for source_id in data.source_refs:
			if not source_id is String: errors.append(key+": malformed source identity"); continue
			if not packet.sources.get(source_id) is Dictionary: errors.append(key+": missing source"); continue
			var source: Dictionary = packet.sources[source_id]
			if source.get("origin")!="historical_primary" or not source.get("title") is String or not source.get("location") is String or source.title.is_empty() or source.location.is_empty(): errors.append(key+": missing source provenance")
			var hash_pattern := RegEx.new(); hash_pattern.compile("^[0-9a-fA-F]{64}$")
			if not source.get("url") is String or not source.url.begins_with("https://") or not source.get("sha256") is String or hash_pattern.search(source.sha256) == null or source.get("read_state","") not in ["text_read","image_and_text_read"]: errors.append(key+": unread/unhashed source")
		if not _number(data.get("muzzle_velocity_mps")) or not data.get("penetration_curve") is Array: errors.append(key+": malformed performance"); continue
		var s := ShellDefinition.new()
		s.id = id+"_shell" if key == row.default else id+"_"+key
		s.display_name = str(data.get("label",key)); s.allowed_vehicle_ids = [id]
		s.caliber_mm = data.caliber_mm; s.muzzle_velocity_mps = data.muzzle_velocity_mps
		s.effect_policy = str(data.get("effect_policy","")); s.armor_policy = "resolve"; s.penetration_curve.clear()
		for point in data.penetration_curve:
			if not point is Array or point.size()!=2 or not _number(point[0]) or not _number(point[1]): errors.append(key+": malformed penetration point"); continue
			s.penetration_curve.append(Vector2(point[0],point[1]))
		s.penetration_mm = s.penetration_curve[0].y if not s.penetration_curve.is_empty() else 0
		s.max_flight_time_s = 12; s.verification = "estimated"; s.source_refs = [PATH+"#"+key]
		for error in s.validate().errors: errors.append(key+": "+error)
		options.append(s); entries.append(data.duplicate(true))
		if key == row.default: default_id = s.id
	return {"ok":errors.is_empty(),"errors":errors,"options":options,"default_id":default_id,"entries":entries,"sources":packet.sources}

static func install(vehicle: VehicleActor, vehicle_packet: Dictionary) -> Dictionary:
	var built := build(vehicle_packet)
	if not built.ok: return built
	var counts := {}
	var total := vehicle.weapon.initial_rounds
	for option in built.options: counts[option.id] = 0
	var alternate := floori(float(total)*0.3)
	for option in built.options: counts[option.id] = total-alternate if option.id == built.default_id else alternate
	if not vehicle.gunner.configure_shell_loadout(built.options,counts,built.default_id): return {"ok":false,"errors":["historical typed loadout rejected"]}
	return built

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
