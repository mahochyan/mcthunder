class_name VehicleContentPipeline
extends RefCounted

static func validate_package(packet: Dictionary) -> Dictionary:
	var shape_errors := check_shape(packet)
	if not shape_errors.is_empty(): return {"ok":false,"errors":shape_errors,"notes":[]}
	var evidence := HistoricalEvidenceGate.check(packet)
	var compatibility := VariantCompatibility.check(packet)
	var errors: Array[String] = []
	errors.append_array(evidence.errors); errors.append_array(compatibility.errors)
	for field in ["id","display_name","geometry","runtime","armor","modules","crew","license"]:
		if not packet.has(field): errors.append(field+": missing content component")
	if not errors.is_empty(): return {"ok":false,"errors":errors,"notes":evidence.notes}
	var g: Dictionary = packet.geometry
	for field in ["hull_rings","turret_origin","gun_origin","turret_outline","turret_bottom","turret_top","turret_taper","ring_half","open_top","mantlet_half_width","mantlet_half_height","barrel_length","wheel_count","track_width","wheel_radius"]:
		if not g.has(field): errors.append("geometry."+field+": missing")
	for field in ["forward_max_speed","reverse_max_speed","acceleration","hull_turn_speed","reload_time","rounds","pitch_min","pitch_max","muzzle_velocity","penetration_curve"]:
		if not packet.runtime.has(field): errors.append("runtime."+field+": missing")
	var zones := ["hull_front_upper","hull_front_lower","hull_sides_front","hull_sides_rear","hull_sides_lower","hull_rear_upper","hull_rear_lower","hull_roof_front","hull_roof_rear","hull_floor_front","hull_floor_rear","turret_front","turret_sides","turret_rear","turret_roof","gun_shield"]
	zones.append("hull_sides_lower_rear")
	if g.get("separate_rotor_shield",false): zones.append("rotor_shield")
	for zone in zones:
		if not packet.armor.has(zone): errors.append("armor."+zone+": missing zone"); continue
		var armor: Dictionary = packet.armor[zone]
		if not packet.facts.has(armor.get("fact","")): errors.append("armor."+zone+": missing evidence")
		if armor.has("local_mm") and (not armor.local_mm is float and not armor.local_mm is int or float(armor.local_mm) <= 0 or str(armor.get("estimate_reason","")).is_empty()):
			errors.append("armor."+zone+": local estimate requires a positive value and explanation")
	if not errors.is_empty(): return {"ok":false,"errors":errors,"notes":evidence.notes}
	if g.hull_rings.size() != 3 or g.turret_outline.size() < 8 or g.turret_outline.size() > 32:
		errors.append("geometry: requires three hull levels and an 8–32 vertex turret outline")
	if not errors.is_empty(): return {"ok":false,"errors":errors,"notes":evidence.notes}
	var width: float = HistoricalEvidenceGate.value(packet,"dimensions.width_m")
	var length: float = HistoricalEvidenceGate.value(packet,"dimensions.reference_length_m")
	var mesh_width := 0.0; var mesh_length := 0.0
	for ring in g.hull_rings:
		mesh_width = maxf(mesh_width,2*float(ring[1])+2*float(g.track_width))
		mesh_length = maxf(mesh_length,float(ring[3])-float(ring[2]))
	if absf(mesh_width-width)/width > 0.16: errors.append("geometry.width: reconstructed envelope differs >16% from reference")
	if absf(mesh_length-length)/length > 0.16: errors.append("geometry.length: hull envelope differs >16% from reference hull/travel length")
	var layout := HistoricalVehicleGeometry.build(packet)
	var validation := LayoutValidator.validate(layout,PackedStringArray(packet.facts.keys()),layout_evidence(packet,layout))
	for err in validation.errors: errors.append(err)
	for warning in validation.warnings: evidence.notes.append(warning)
	for overlap in validation.suspicious_overlaps:
		if str(overlap).begins_with("SUSPICIOUS"): errors.append(overlap)
		else: evidence.notes.append(overlap)
	var definitions := definitions_for(packet,layout)
	var shell_set := HistoricalShellCatalog.build(packet)
	for error in shell_set.errors: errors.append(error)
	for definition in [definitions.vehicle,definitions.weapon,definitions.shell]:
		for error in definition.validate().errors: errors.append(str(definition.id)+": "+error)
	return {"ok":errors.is_empty(),"errors":errors,"notes":evidence.notes,"layout":layout,"definitions":definitions,"packet":packet}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func vector(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size: return false
	for n in value:
		if not number(n): return false
	return true

static func check_shape(packet: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["facts","sources","assembly","geometry","runtime","armor"]:
		if not packet.get(key) is Dictionary: errors.append(key+": expected dictionary")
	for key in ["modules","crew","compatible_shells"]:
		if not packet.get(key) is Array: errors.append(key+": expected array")
	for key in ["id","display_name","license"]:
		if not packet.get(key) is String or str(packet[key]).is_empty(): errors.append(key+": expected nonempty string")
	if not errors.is_empty(): return errors
	for field in ["variant","suspension","gun","mount","shell"]:
		if not packet.assembly.get(field) is String or str(packet.assembly.get(field,"")).is_empty(): errors.append("assembly."+field+": expected nonempty string")
	for field in ["year","caliber_mm"]:
		if not number(packet.assembly.get(field)): errors.append("assembly."+field+": expected finite number")
	for shell in packet.compatible_shells:
		if not shell is String: errors.append("compatible_shells: expected strings")
	for source_id in packet.sources:
		var source: Variant = packet.sources[source_id]
		if not source is Dictionary: errors.append("sources: malformed source"); continue
		for field in ["applies_to_identity_ids","excluded_identity_ids"]:
			if not source.get(field,[]) is Array: errors.append("sources."+str(source_id)+"."+field+": expected array")
	for field in ["crew.roles","dimensions.width_m","dimensions.reference_length_m","mobility.forward_speed_mps","weapon.capacity"]:
		var value: Variant = HistoricalEvidenceGate.value(packet,field)
		if field == "crew.roles":
			if not value is Array: errors.append(field+": expected array")
			else:
				for role in value:
					if not role is String: errors.append(field+": expected string roles")
		elif not number(value) or float(value) <= 0: errors.append(field+": expected positive number")
	var g: Dictionary = packet.geometry
	for key in ["turret_origin","gun_origin"]:
		if not vector(g.get(key),3): errors.append("geometry."+key+": invalid point")
	for key in ["hull_rings","turret_outline"]:
		if not g.get(key) is Array: errors.append("geometry."+key+": expected array"); continue
		for row in g[key]:
			if not vector(row,4 if key == "hull_rings" else 2): errors.append("geometry."+key+": invalid row")
	for key in ["turret_bottom","turret_top","turret_taper","ring_half","mantlet_half_width","mantlet_half_height","barrel_length","wheel_count","track_width","wheel_radius"]:
		if not number(g.get(key)) or float(g[key]) <= 0: errors.append("geometry."+key+": must be finite positive")
	if not g.get("open_top") is bool: errors.append("geometry.open_top: expected boolean")
	for field in ["separate_rotor_shield","muzzle_brake"]:
		if g.has(field) and not g[field] is bool: errors.append("geometry."+field+": expected boolean")
	for key in ["forward_max_speed","reverse_max_speed","acceleration","hull_turn_speed","reload_time","rounds","muzzle_velocity"]:
		if not number(packet.runtime.get(key)) or float(packet.runtime[key]) <= 0: errors.append("runtime."+key+": must be finite positive")
	for key in ["pitch_min","pitch_max"]:
		if not number(packet.runtime.get(key)): errors.append("runtime."+key+": must be finite")
	for key in ["yaw_min","yaw_max","turret_yaw_speed","turret_pitch_speed"]:
		if packet.runtime.has(key) and not number(packet.runtime[key]): errors.append("runtime."+key+": must be finite")
	if not packet.runtime.get("penetration_curve") is Array: errors.append("runtime.penetration_curve: expected array")
	else:
		for pair in packet.runtime.penetration_curve:
			if not vector(pair,2): errors.append("runtime.penetration_curve: invalid pair")
	for key in ["modules","crew"]:
		if packet[key].is_empty() or packet[key].size() > 48: errors.append(key+": invalid count")
		for row in packet[key]:
			if not row is Dictionary: errors.append(key+": malformed entry"); continue
			for field in ["id","part",("kind" if key == "modules" else "role")]:
				if not row.get(field) is String: errors.append(key+"."+field+": expected string")
			for field in ["position","size"]:
				if not vector(row.get(field),3): errors.append(key+"."+field+": invalid vector")
			if row.has("external") and not row.external is bool: errors.append(key+".external: expected boolean")
	for zone in packet.armor:
		var row: Variant = packet.armor[zone]
		if not row is Dictionary or not row.get("fact") is String: errors.append("armor."+zone+": malformed mapping"); continue
		var source: Variant = packet.facts.get(row.fact,{})
		if not source is Dictionary: continue # Reported with the malformed facts below.
		var value: Variant = source.get("value")
		if source.get("status") == "unknown":
			if row.has("local_mm"): errors.append("armor."+zone+": unknown thickness cannot have a numeric substitute")
		elif value is Array:
			if not vector(value,2) or value[0] <= 0 or value[1] < value[0]: errors.append("armor."+zone+": invalid documented range")
			elif not number(row.get("local_mm")) or row.local_mm < value[0] or row.local_mm > value[1]: errors.append("armor."+zone+": local estimate must lie within documented range")
		elif not number(value) or float(value) <= 0: errors.append("armor."+zone+": expected positive thickness")
		if row.has("local_mm") and not number(row.local_mm): errors.append("armor."+zone+": invalid local thickness")
	for field in packet.facts:
		if not packet.facts[field] is Dictionary: errors.append("facts."+field+": expected dictionary")
	if not errors.is_empty(): return errors
	if g.wheel_count < 2 or int(g.wheel_count) != g.wheel_count: errors.append("geometry.wheel_count: expected whole wheel count >= 2")
	if int(packet.runtime.rounds) != packet.runtime.rounds: errors.append("runtime.rounds: expected whole round count")
	if g.hull_rings.size() == 3:
		if not (g.hull_rings[0][0] < g.hull_rings[1][0] and g.hull_rings[1][0] < g.hull_rings[2][0]): errors.append("geometry.hull_rings: levels must ascend")
	if g.turret_top <= g.turret_bottom or g.wheel_count > 12: errors.append("geometry: invalid height/count")
	for pair in [["geometry","geometry.exterior"],["runtime","runtime.simulation"],["modules","geometry.modules"],["crew","geometry.crew"]]:
		if packet[pair[0]] != HistoricalEvidenceGate.value(packet,pair[1]): errors.append(pair[0]+": actual content differs from field record")
	for pair in [["forward_max_speed","mobility.forward_speed_mps"],["rounds","weapon.capacity"]]:
		if packet.runtime[pair[0]] != HistoricalEvidenceGate.value(packet,pair[1]): errors.append("runtime."+pair[0]+": conflicts with historical record")
	for zone in ["hull_front_upper","hull_sides_front","gun_shield"]:
		if packet.armor.get(zone,{}).get("fact","") != "armor."+zone: errors.append("armor."+zone+": wrong evidence mapping")
	var rack_capacity := 0
	for module in packet.modules:
		if module.kind == "ammo":
			if not number(module.get("ammo_capacity")) or int(module.ammo_capacity) <= 0 or int(module.ammo_capacity) != module.ammo_capacity: errors.append("modules."+str(module.id)+": missing or fractional ammunition capacity")
			else: rack_capacity += int(module.ammo_capacity)
	if rack_capacity != int(packet.runtime.rounds): errors.append("modules.ammo_capacity: initial historical load must match total stowage")
	return errors

static func layout_evidence(packet: Dictionary, layout: VehicleLayoutDefinition) -> Dictionary:
	var doc := {"evidence_keys":[],"fields":[]}
	for key in packet.facts:
		var row: Dictionary = packet.facts[key]
		doc.evidence_keys.append({"key":key,"origin":row.origin,"applies_to_identity_ids":[packet.id],"source_refs":row.get("source_refs",[])})
	for patch in layout.armor_patches:
		if patch.thickness_status == "unknown": continue
		doc.fields.append({"field_path":"armor_patches."+patch.id+".thickness_mm","status":patch.thickness_status,"source_refs":[patch.evidence_keys[0]]})
	for crew in layout.crew_stations:
		for spec in [["role_placement",crew.role_placement_status,"crew.placement"],["local_box_transform",crew.position_status,"geometry.crew"],["size_m",crew.volume_status,"geometry.crew"]]:
			doc.fields.append({"field_path":"crew_stations."+crew.id+"."+spec[0],"status":spec[1],"source_refs":[spec[2]]})
	return doc

static func definitions_for(packet: Dictionary, layout: VehicleLayoutDefinition) -> Dictionary:
	var v := VehicleDefinition.new(); var w := WeaponDefinition.new(); var s := ShellDefinition.new()
	v.id = packet.id; v.display_name_key = packet.display_name; v.layout_id = layout.id
	v.content_tier = "production"; v.verification = "verified" # Identity admission; field estimates remain in packet.
	v.source_refs = ["res://configs/vehicles/historical/"+str(packet.id)+".json: field evidence"]
	v.weapon_id = packet.id+"_gun"; w.id = v.weapon_id; w.shell_id = packet.id+"_shell"; s.id = w.shell_id
	var r: Dictionary = packet.runtime
	v.forward_max_speed = r.forward_max_speed; v.reverse_max_speed = r.reverse_max_speed
	v.forward_accel = r.acceleration; v.reverse_accel = r.acceleration*0.65
	v.hull_turn_speed = r.hull_turn_speed; v.turret_yaw_speed = r.get("turret_yaw_speed",24.0)
	v.turret_pitch_speed = r.get("turret_pitch_speed",10.0)
	v.barrel_pitch_min = r.pitch_min; v.barrel_pitch_max = r.pitch_max
	v.turret_yaw_min = r.get("yaw_min",-180.0); v.turret_yaw_max = r.get("yaw_max",180.0)
	var g: Dictionary = packet.geometry
	var length: float = g.hull_rings[1][3]-g.hull_rings[1][2]
	v.drive_collision_size = Vector3(HistoricalEvidenceGate.value(packet,"dimensions.width_m"),float(g.hull_rings[2][0]),length)
	v.drive_collision_center = Vector3(0,v.drive_collision_size.y*0.5,(float(g.hull_rings[1][3])+float(g.hull_rings[1][2]))*0.5)
	v.follow_camera_distance = maxf(9.5,length*1.8); v.follow_camera_height = 4.2
	w.reload_time = r.reload_time; w.initial_rounds = r.rounds; w.gun_range = 2500
	w.barrel_pitch_min = r.pitch_min; w.barrel_pitch_max = r.pitch_max
	w.verification = "estimated"; w.source_refs = v.source_refs.duplicate()
	s.caliber_mm = packet.assembly.caliber_mm; s.muzzle_velocity_mps = r.muzzle_velocity
	s.penetration_curve.clear()
	for pair in r.penetration_curve: s.penetration_curve.append(Vector2(pair[0],pair[1]))
	s.penetration_mm = s.penetration_curve[0].y; s.max_flight_time_s = 12
	s.verification = "estimated"; s.source_refs = v.source_refs.duplicate()
	var current_shells := HistoricalShellCatalog.build(packet)
	if current_shells.ok:
		for option in current_shells.options:
			if option.id == current_shells.default_id: s = option
	return {"vehicle":v,"weapon":w,"shell":s}
