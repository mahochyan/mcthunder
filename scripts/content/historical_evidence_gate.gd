class_name HistoricalEvidenceGate
extends RefCounted
## Checks the recorded evidence and its applicability. It cannot certify a historical document's truth.
const REQUIRED := ["identity.variant","identity.year","identity.suspension","weapon.gun","weapon.mount","weapon.caliber_mm","weapon.ammunition","crew.roles","dimensions.width_m","dimensions.reference_length_m","armor.hull_front_upper","armor.hull_sides_front","armor.turret_front"]
const ORIGINS := ["historical_primary","historical_secondary","game_rule","test_fixture","warthunder_reference"]

static func check(packet: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var notes: Array[String] = []
	if not packet.get("facts") is Dictionary or not packet.get("sources") is Dictionary:
		return {"ok":false,"errors":["evidence: facts and sources must be dictionaries"],"notes":notes}
	var identity := str(packet.get("id",""))
	var facts: Dictionary = packet.get("facts",{})
	var sources: Dictionary = packet.get("sources",{})
	for field in REQUIRED:
		if not facts.has(field): errors.append(field+": missing critical evidence")
	for field in facts:
		var row: Variant = facts[field]
		if not row is Dictionary: errors.append(str(field)+": malformed evidence"); continue
		var status := str(row.get("status",""))
		var origin := str(row.get("origin",""))
		if status not in ["verified","estimated","unknown"] or origin not in ORIGINS:
			errors.append(str(field)+": invalid status/origin"); continue
		if status == "unknown":
			if row.get("value") != null: errors.append(str(field)+": unknown must not contain a numeric substitute")
			notes.append(str(field)+": UNKNOWN")
			if field in REQUIRED: errors.append(str(field)+": critical field is unknown")
			continue
		if not row.has("value") or row.value == null: errors.append(str(field)+": missing value")
		if status == "verified" and origin not in ["historical_primary","historical_secondary"]:
			errors.append(str(field)+": historical verification cannot come from gameplay or fixture data")
		if field in REQUIRED and (status != "verified" or origin not in ["historical_primary","historical_secondary"]):
			errors.append(str(field)+": critical identity/data requires historical evidence")
		if not row.get("source_refs",[]) is Array: errors.append(str(field)+": source_refs must be an array"); continue
		var refs: Array = row.get("source_refs",[])
		if refs.is_empty(): errors.append(str(field)+": missing source references")
		for reference in refs:
			if not sources.has(reference): errors.append(str(field)+": missing source "+str(reference)); continue
			if not sources[reference] is Dictionary: errors.append(str(field)+": malformed source"); continue
			var source: Dictionary = sources[reference]
			if identity not in source.get("applies_to_identity_ids",[]) or identity in source.get("excluded_identity_ids",[]):
				errors.append(str(field)+": source belongs to another variant")
			if origin.begins_with("historical"):
				if str(source.get("origin","")) != origin: errors.append(str(field)+": primary/secondary provenance mismatch")
				var digest := str(source.get("sha256",""))
				if not str(source.get("url","")).begins_with("https://") or digest.length() != 64 or not digest.is_valid_hex_number():
					errors.append(str(field)+": source needs a retrievable URL and file hash")
				if source.get("read_state","") not in ["text_read","image_and_text_read"]:
					errors.append(str(field)+": source has not been read")
				if str(row.get("location","")).is_empty(): errors.append(str(field)+": missing page/table locator")
		if status == "estimated" or origin == "historical_secondary": notes.append(str(field)+": "+status+" / "+origin)
	return {"ok":errors.is_empty(),"errors":errors,"notes":notes,"human":"NOT_RUN"}

static func value(packet: Dictionary, path: String, fallback: Variant = null) -> Variant:
	var facts: Variant = packet.get("facts",{})
	if not facts is Dictionary: return fallback
	var row: Variant = facts.get(path,{})
	return row.get("value",fallback) if row is Dictionary else fallback
