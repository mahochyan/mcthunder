class_name ReferenceEvidenceGate
extends RefCounted
## Engineering evidence for authored game-reference packages. Never certifies history.
const UNITS := {"distance":"m","speed":"m/s","acceleration":"m/s2","angle":"deg","angular_speed":"deg/s","time":"s","mass":"kg","armor":"mm","caliber":"mm"}
const EXTRA_REQUIRED := ["crew.placement","geometry.exterior","geometry.modules","geometry.crew","runtime.simulation","weapon.capacity","mobility.forward_speed_mps"]
const ALLOWED_UNITS := ["text","year","roles","structured","count","ratio","boolean","m","mm","m/s","m/s2","s","deg","deg/s","kg"]

static func finite_tree(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Array:
		for item in value:
			if not finite_tree(item): return false
	if value is Dictionary:
		for key in value:
			if not key is String or not finite_tree(value[key]): return false
	return value == null or value is String or value is bool or value is int or value is float or value is Array or value is Dictionary

static func unit_for(field: String) -> String:
	if field.begins_with("armor."): return "mm"
	if field.begins_with("geometry.") or field == "runtime.simulation": return "structured"
	match field:
		"identity.year": return "year"
		"crew.roles": return "roles"
		"dimensions.width_m", "dimensions.reference_length_m": return "m"
		"mobility.forward_speed_mps": return "m/s"
		"weapon.caliber_mm": return "mm"
		"weapon.capacity": return "count"
		"loading.profile", "equipment.loading", "drive.profile", "optics.profile", "fire_control.profile", "equipment.stabilizer": return "structured"
	return ""

static func check_claim(field: String, value: Variant, packet: Dictionary, expected_unit: String = "") -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary: return [field+": malformed reference claim"]
	var row: Dictionary = value
	# WT-040-R1 (user ruling): the project's status vocabulary admits `design` for values that are project
	# rules rather than estimates of a real figure, and the historical evidence gate already accepts it.
	# This gate accepted only estimated/unknown, so every project-rule claim was rejected as if it were a
	# failed historical verification - which is the opposite of what it is. The status set now matches the
	# ruling; what this line still forbids is a claim that pretends to be historically verified.
	if row.get("status") not in ["estimated","unknown","design"]: errors.append(field+": reference claims cannot be historical verified")
	if row.get("origin") not in ["warthunder_reference","game_rule"]: errors.append(field+": invalid reference/game-rule origin")
	if not row.has("value") or not finite_tree(row.get("value")): errors.append(field+": missing or non-finite claim value")
	if row.get("status") == "unknown":
		if row.get("value") != null: errors.append(field+": unknown must remain null")
	elif row.get("value") == null: errors.append(field+": estimated value is missing")
	if not row.get("note") is String or str(row.get("note","")).strip_edges().is_empty(): errors.append(field+": estimate/design/unknown explanation required")
	if not row.get("location") is String or str(row.get("location","")).strip_edges().is_empty(): errors.append(field+": source field locator required")
	if row.get("unit") not in ALLOWED_UNITS or (not expected_unit.is_empty() and row.get("unit") != expected_unit): errors.append(field+": unit does not match project field")
	if not row.get("source_refs") is Array or row.get("source_refs",[]).is_empty():
		errors.append(field+": source_refs required")
		return errors
	var sources: Dictionary = packet.get("sources",{}) if packet.get("sources") is Dictionary else {}
	for ref in row.source_refs:
		if not ref is String or not sources.get(ref) is Dictionary:
			errors.append(field+": missing referenced source")
			continue
		if sources[ref].get("origin") != row.get("origin"): errors.append(field+": claim/source origin mismatch")
	return errors

static func check(packet: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var notes: Array[String] = ["GAME REFERENCE: engineering admission does not establish historical accuracy"]
	if not packet.get("id") is String or str(packet.get("id","")).strip_edges().is_empty(): errors.append("id: exact project identity required")
	if packet.get("evidence_profile") != "game_reference": errors.append("evidence_profile: expected game_reference")
	if packet.get("admission_status","candidate") not in ["candidate","validated"]: errors.append("admission_status: unsupported")
	if packet.get("admission") == "candidate_only" or packet.get("verification") == "verified" or packet.get("historical_verified",false) != false:
		errors.append("reference source candidates/historical verification cannot be passed as runtime admission")
	if not packet.get("facts") is Dictionary or not packet.get("sources") is Dictionary or not packet.get("source_binding") is Dictionary:
		return {"ok":false,"errors":errors+["reference package requires facts/sources/source_binding"],"notes":notes,"human":"NOT_RUN"}
	var units: Variant = packet.get("unit_contract")
	if not units is Dictionary:
		errors.append("unit_contract: project units required")
	else:
		for key in UNITS:
			if units.get(key) != UNITS[key]: errors.append("unit_contract."+key+": invalid unit")
	var binding: Dictionary = packet.source_binding
	if not binding.get("source_vehicle_id") is String or str(binding.get("source_vehicle_id","")).strip_edges().is_empty(): errors.append("source_binding: exact source vehicle ID required")
	if not binding.get("primary_source") is String or not packet.sources.has(binding.get("primary_source")): errors.append("source_binding: primary source missing")
	if packet.sources.is_empty() or packet.sources.size()>64: errors.append("sources: invalid reference count")
	for key in packet.sources:
		if not packet.sources[key] is Dictionary:
			errors.append("sources: malformed record")
			continue
		var source: Dictionary = packet.sources[key]
		if source.get("origin") not in ["warthunder_reference","game_rule"]: errors.append("sources."+str(key)+": origin must remain reference/game_rule")
		if source.get("source_vehicle_id") != binding.get("source_vehicle_id"): errors.append("sources."+str(key)+": wrong source vehicle identity")
		if not source.get("applies_to_identity_ids") is Array or packet.get("id","") not in source.get("applies_to_identity_ids",[]): errors.append("sources."+str(key)+": source not applicable to project identity")
		if not source.get("excluded_identity_ids",[]) is Array or packet.get("id","") in source.get("excluded_identity_ids",[]): errors.append("sources."+str(key)+": excluded/malformed identity scope")
		var digest := str(source.get("sha256",""))
		if digest.length()!=64 or not digest.is_valid_hex_number(): errors.append("sources."+str(key)+": source hash required")
		if not source.get("artifact") is String or str(source.get("artifact","")).strip_edges().is_empty(): errors.append("sources."+str(key)+": source artifact required")
		if source.get("read_state") not in ["text_read","image_and_text_read","authored"]: errors.append("sources."+str(key)+": unread/unrecorded source")
		if source.get("origin") == "warthunder_reference" and (not source.get("resource_version") is String or str(source.get("resource_version","")).strip_edges().is_empty()): errors.append("sources."+str(key)+": reference resource version required")
	var required: Array = HistoricalEvidenceGate.REQUIRED.duplicate()
	required.append_array(EXTRA_REQUIRED)
	if packet.has("loading_profile"): required.append_array(["loading.profile","equipment.loading"])
	for field in required:
		if not packet.facts.get(field) is Dictionary or packet.facts[field].get("status") == "unknown": errors.append(str(field)+": complete runtime reference field required")
	for field in packet.facts:
		errors.append_array(check_claim(str(field),packet.facts[field],packet,unit_for(str(field))))
	return {"ok":errors.is_empty(),"errors":errors,"notes":notes,"human":"NOT_RUN"}
