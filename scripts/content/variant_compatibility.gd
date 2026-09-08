class_name VariantCompatibility
extends RefCounted
## Variant identity, weapon, mount and ammunition are checked together at assembly boundaries.
static func check(packet: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if not packet.get("assembly") is Dictionary or not packet.get("facts") is Dictionary or not packet.get("crew") is Array:
		return {"ok":false,"errors":["compatibility: malformed assembly, facts or crew"]}
	var assembly: Dictionary = packet.get("assembly",{})
	for pair in [["variant","identity.variant"],["year","identity.year"],["suspension","identity.suspension"],["gun","weapon.gun"],["mount","weapon.mount"],["caliber_mm","weapon.caliber_mm"],["shell","weapon.ammunition"]]:
		if not assembly.has(pair[0]) or assembly[pair[0]] != HistoricalEvidenceGate.value(packet,pair[1]):
			errors.append("assembly."+pair[0]+": conflicts with the recorded variant")
	var declared_roles: Variant = HistoricalEvidenceGate.value(packet,"crew.roles",[])
	if not declared_roles is Array: return {"ok":false,"errors":["crew.roles: expected array"]}
	var roles: Array = declared_roles
	var actual: Array = []
	for station in packet.get("crew",[]):
		if not station is Dictionary: errors.append("crew: malformed station"); continue
		actual.append(station.get("role",""))
	roles = roles.duplicate()
	roles.sort(); actual.sort()
	if roles != actual: errors.append("crew: roster does not match documented configuration")
	if assembly.get("shell","") not in packet.get("compatible_shells",[]): errors.append("shell: incompatible ammunition")
	return {"ok":errors.is_empty(),"errors":errors}
