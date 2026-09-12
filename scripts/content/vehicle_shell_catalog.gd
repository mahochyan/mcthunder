class_name VehicleShellCatalog
extends RefCounted
## Shared inventory interface. Reference shells use only actually implemented effects.
const MAX_SHELLS := 8
const FAMILIES := {"AP":{"source":"ap_tank","effect":"kinetic"},"APHE":{"source":"aphe_tank","effect":"internal_burst"}}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func build(vehicle_packet: Dictionary) -> Dictionary:
	var profile: Variant = vehicle_packet.get("evidence_profile","historical_verified")
	if profile == "historical_verified": return HistoricalShellCatalog.build(vehicle_packet)
	if profile != "game_reference": return {"ok":false,"errors":["evidence_profile: unsupported shell source"]}
	var admitted := ReferenceEvidenceGate.check(vehicle_packet)
	if not admitted.ok: return admitted
	var errors: Array[String] = []
	if not vehicle_packet.get("assembly") is Dictionary or not vehicle_packet.get("compatible_shells") is Array:
		return {"ok":false,"errors":["shell package: assembly/compatible_shells required"]}
	for compatible in vehicle_packet.compatible_shells:
		if not compatible is String: return {"ok":false,"errors":["compatible_shells: IDs must be strings"]}
	var packet: Variant = vehicle_packet.get("shell_catalog")
	if not packet is Dictionary or packet.get("schema_version") != 1 or not packet.get("shells") is Array:
		return {"ok":false,"errors":["shell_catalog: malformed or unsupported schema"]}
	if packet.shells.size()<1 or packet.shells.size()>MAX_SHELLS or not packet.get("default") is String:
		return {"ok":false,"errors":["shell_catalog: requires 1..8 shells and default ID"]}
	var options: Array[ShellDefinition] = []
	var entries: Array[Dictionary] = []
	var unique := {}
	var runtime_ids := {}
	var default_id := ""
	for value in packet.shells:
		if not value is Dictionary:
			errors.append("shell_catalog: malformed shell")
			continue
		var data: Dictionary = value
		var start_errors := errors.size()
		for key in ["id","label","gun","family","source_bullet_type","effect_policy"]:
			if not data.get(key) is String or str(data.get(key,"")).strip_edges().is_empty(): errors.append("shell."+key+": nonempty string required")
		if errors.size()!=start_errors: continue
		if unique.has(data.id): errors.append("shell.id: duplicate"); continue
		unique[data.id]=true
		if data.family not in FAMILIES:
			errors.append("shell.family: unsupported; HEAT/APFSDS and future families cannot fall back to AP")
			continue
		if data.source_bullet_type != FAMILIES[data.family].source or data.effect_policy != FAMILIES[data.family].effect:
			errors.append("shell.family: source family/effect mismatch; no relabeling unsupported modern ammunition")
		if data.get("verification") == "verified" or data.get("historical_verified",false) != false: errors.append("shell.verification: reference is not historical verified")
		if data.gun != vehicle_packet.assembly.get("gun"): errors.append("shell.gun: vehicle weapon mismatch")
		for key in ["caliber_mm","muzzle_velocity_mps","gravity_scale","max_flight_time_s"]:
			if not number(data.get(key)): errors.append("shell."+key+": finite number required")
		if data.get("caliber_mm") != vehicle_packet.assembly.get("caliber_mm"): errors.append("shell.caliber_mm: incompatible weapon")
		if not data.get("penetration_curve") is Array: errors.append("shell.penetration_curve: complete implemented curve required")
		else:
			for point in data.penetration_curve:
				if not point is Array or point.size()!=2 or not number(point[0]) or not number(point[1]): errors.append("shell.penetration_curve: invalid distance/mm point")
		if not data.get("evidence") is Dictionary:
			errors.append("shell.evidence: identity/ballistics/effect claims required")
		else:
			var identity := {"id":data.id,"gun":data.gun,"family":data.family,"source_bullet_type":data.source_bullet_type,"caliber_mm":data.get("caliber_mm")}
			var ballistics := {"muzzle_velocity_mps":data.get("muzzle_velocity_mps"),"penetration_curve":data.get("penetration_curve"),"gravity_scale":data.get("gravity_scale"),"max_flight_time_s":data.get("max_flight_time_s")}
			for claim in [["identity",identity,"structured"],["ballistics",ballistics,"structured"],["effect",data.effect_policy,"text"]]:
				errors.append_array(ReferenceEvidenceGate.check_claim("shell."+data.id+"."+claim[0],data.evidence.get(claim[0]),vehicle_packet,claim[2]))
				if not data.evidence.get(claim[0]) is Dictionary or data.evidence[claim[0]].get("value") != claim[1]: errors.append("shell."+data.id+": actual values differ from evidence record")
			if data.has("fuze_policy"):
				errors.append_array(ReferenceEvidenceGate.check_claim("shell."+data.id+".fuze",data.evidence.get("fuze"),vehicle_packet,"structured"))
				if not data.evidence.get("fuze") is Dictionary or data.evidence.fuze.get("value") != data.fuze_policy:
					errors.append("shell."+data.id+": fuze differs from separate design evidence")
		if errors.size()!=start_errors: continue
		var shell := ShellDefinition.new()
		var fuze: Variant = data.get("fuze_policy", {})
		var fuze_errors := ShellFuze.validate(fuze, data.effect_policy)
		if not fuze_errors.is_empty(): errors.append_array(fuze_errors); continue
		shell.fuze_policy = fuze.duplicate(true)
		shell.id = str(vehicle_packet.id)+("_shell" if data.id==packet.default else "_"+data.id)
		if runtime_ids.has(shell.id): errors.append("shell.id: runtime ID collision"); continue
		runtime_ids[shell.id]=true
		shell.display_name=data.label; shell.allowed_vehicle_ids.assign([str(vehicle_packet.id)])
		shell.caliber_mm=float(data.caliber_mm); shell.muzzle_velocity_mps=float(data.muzzle_velocity_mps)
		shell.gravity_scale=float(data.gravity_scale); shell.max_flight_time_s=float(data.max_flight_time_s)
		shell.effect_policy=data.effect_policy; shell.armor_policy="resolve"; shell.verification="estimated"
		shell.source_refs.assign(["game_reference:"+str(vehicle_packet.id)+"#shells/"+str(data.id)])
		shell.penetration_curve.clear()
		for point in data.penetration_curve: shell.penetration_curve.append(Vector2(float(point[0]),float(point[1])))
		shell.penetration_mm=shell.penetration_curve[0].y if not shell.penetration_curve.is_empty() else 0
		for error in shell.validate().errors: errors.append("shell."+data.id+": "+error)
		options.append(shell); entries.append(data.duplicate(true))
		if data.id==packet.default: default_id=shell.id
	if not unique.has(packet.default) or default_id.is_empty(): errors.append("shell_catalog.default: missing or rejected shell")
	if vehicle_packet.assembly.get("shell") != packet.default: errors.append("shell_catalog.default: assembly default mismatch")
	var declared: Array = vehicle_packet.compatible_shells.duplicate()
	var actual: Array = unique.keys()
	declared.sort(); actual.sort()
	if declared != actual: errors.append("compatible_shells: must exactly match admitted catalog IDs")
	return {"ok":errors.is_empty(),"errors":errors,"options":options,"default_id":default_id,"entries":entries,"sources":vehicle_packet.sources}

static func install(vehicle: VehicleActor, vehicle_packet: Dictionary) -> Dictionary:
	if vehicle_packet.get("evidence_profile","historical_verified") == "historical_verified": return HistoricalShellCatalog.install(vehicle,vehicle_packet)
	var built := build(vehicle_packet)
	if not built.ok: return built
	if vehicle == null or vehicle.definition.id != vehicle_packet.get("id"): return {"ok":false,"errors":["shell install: vehicle identity mismatch"]}
	var counts := {}
	var total: int = vehicle.weapon.initial_rounds
	var alternate := floori(float(total)*0.3) if built.options.size()>1 else 0
	var remaining := alternate
	var nondefault: int = built.options.size()-1
	for option in built.options:
		if option.id==built.default_id: counts[option.id]=total-alternate
		else:
			var share := ceili(float(remaining)/float(nondefault))
			counts[option.id]=share; remaining-=share; nondefault-=1
	if not vehicle.gunner.configure_shell_loadout(built.options,counts,built.default_id): return {"ok":false,"errors":["reference typed loadout rejected"]}
	return built
