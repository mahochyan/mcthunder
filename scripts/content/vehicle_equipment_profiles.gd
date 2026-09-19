class_name VehicleEquipmentProfiles
extends RefCounted
## Fully authored JSON profiles. No resource paths or inferred equipment capabilities.
const FIELDS := {
	"drive": ["power_falloff","shift_seconds","shift_power","gear_count","downshift_hysteresis","grade_acceleration","brake_scale","coast_scale","turn_speed_falloff","turn_drag_per_second","track_spacing_m","neutral_turn","damaged_track_turn_scale","pitch_degrees_per_acceleration","pitch_limit_degrees","pitch_response_rate","landing_min_speed","landing_restitution","landing_max_rebound","suspension_enabled","suspension_compression_m","suspension_extension_m","suspension_response_rate","suspension_impact_scale","suspension_angle_limit_degrees","suspension_point_speed_limit","suspension_contact_margin_m","recoil_speed_mps","recoil_max_mps"],
	"optics": ["sight_fovs","sight_offset","binocular_fov","binocular_offset","rangefinder_min_m","rangefinder_max_m","rangefinder_resolution_m","measurement_time_s","measurement_valid_s","zeroing_step_m","zeroing_max_m"],
	"fire_control": ["provenance","pitch_accel_deg_s2","yaw_accel_deg_s2","pitch_brake_deg_s2","yaw_brake_deg_s2","response_time_s","stabilizer_mode","speed_limit_mps","speed_hysteresis_mps"]
}

## CD11: a kind may gain a field that packets written earlier do not carry. Listing a new name in FIELDS alone makes it
## MANDATORY for every envelope ever written, which retroactively invalidates packets that were valid when they were authored -
## and that is exactly what broke an in-memory packet built by another suite. This set names fields a packet MAY declare
## without being required to, so the gate stays strict about what it already knows while a new capability can be added.
const OPTIONAL := {
	"drive": ["recoil_speed_mps","recoil_max_mps"]
}

static func from_packet(kind: String, envelope: Variant) -> Dictionary:
	var errors: Array[String]=[]
	if not FIELDS.has(kind): return {"ok":false,"errors":["equipment: unknown profile kind"]}
	var prefix := kind+"_profile"
	if not envelope is Dictionary: return {"ok":false,"errors":[prefix+": expected dictionary"]}
	if not (envelope.get("schema_version") is int or envelope.get("schema_version") is float) or envelope.get("schema_version")!=1:
		errors.append(prefix+": unsupported schema")
	if envelope.get("origin")!="game_rule" or not envelope.get("note") is String or str(envelope.get("note","")).strip_edges().is_empty():
		errors.append(prefix+": explicit game_rule origin and explanation required")
	for key in envelope:
		if key not in ["schema_version","origin","note","values"]: errors.append(prefix+": unknown envelope field "+str(key))
	if not envelope.get("values") is Dictionary: return {"ok":false,"errors":errors+[prefix+": values must be a dictionary"]}
	var values: Dictionary=envelope.values
	var optional: Array = OPTIONAL.get(kind,[])
	for key in FIELDS[kind]:
		if not values.has(key) and not (key in optional): errors.append(prefix+"."+key+": explicit value required")
	var profile: Resource
	match kind:
		"drive": profile=DriveProfile.new()
		"optics": profile=OpticsProfile.new()
		"fire_control": profile=FireControlProfile.new()
	for key in values:
		if key not in FIELDS[kind]: errors.append(prefix+": unknown field "+str(key)); continue
		var value: Variant=values[key]
		var expected: Variant=profile.get(key)
		var valid := true
		match typeof(expected):
			TYPE_BOOL: valid=value is bool
			TYPE_STRING: valid=value is String
			TYPE_INT: valid=_number(value) and float(value)==floorf(float(value)) and absf(float(value))<100000
			TYPE_FLOAT: valid=_number(value)
			TYPE_VECTOR3:
				valid=_numbers(value,3,3)
				if valid: value=Vector3(value[0],value[1],value[2])
			TYPE_PACKED_FLOAT32_ARRAY:
				valid=_numbers(value,1,4)
				if valid: value=PackedFloat32Array(value)
			_: valid=false
		if not valid: errors.append(prefix+"."+key+": wrong type, shape or nonfinite value")
		else: profile.set(key,value)
	if kind=="fire_control" and values.get("provenance")!="game_rule": errors.append(prefix+": authored tuning cannot claim documented equipment")
	if errors.is_empty(): errors.append_array(profile.validate())
	return {"ok":errors.is_empty(),"errors":errors,"profile":profile}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _numbers(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size()<minimum or value.size()>maximum: return false
	for item in value:
		if not _number(item): return false
	return true

static func stabilizer_equipment(packet: Dictionary) -> Dictionary:
	var ids: Array[String]=[]
	for module in packet.get("modules",[]):
		if module is Dictionary and module.get("kind")=="stabilizer" and module.get("id") is String: ids.append(module.id)
	ids.sort()
	var mode: String=packet.get("fire_control_profile",{}).get("values",{}).get("stabilizer_mode","none")
	return {"mode":mode,"module_ids":ids}

static func check(packet: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	for kind in FIELDS:
		var key: String=kind+"_profile"
		if not packet.has(key): continue # Legacy packages retain their existing profiles.
		var parsed := from_packet(kind,packet[key])
		errors.append_array(parsed.errors)
		var fact: String=kind+".profile"
		errors.append_array(_evidence(packet,fact,packet[key]))
		if kind=="fire_control" and parsed.ok:
			var equipment := stabilizer_equipment(packet)
			errors.append_array(_evidence(packet,"equipment.stabilizer",equipment))
			if equipment.mode!="none" and equipment.module_ids.is_empty(): errors.append("equipment.stabilizer: enabled capability requires damageable module geometry")
	return errors

static func _evidence(packet: Dictionary, field: String, value: Variant) -> Array[String]:
	var claim: Variant=packet.get("facts",{}).get(field)
	var errors := ReferenceEvidenceGate.check_claim(field,claim,packet,"structured")
	if not claim is Dictionary: return errors
	if claim.get("status")!="estimated" or claim.get("origin")!="game_rule": errors.append(field+": explicit independent game design evidence required")
	if claim.get("value")!=value: errors.append(field+": actual profile/equipment differs from evidence")
	return errors

static func apply(packet: Dictionary, definition: VehicleDefinition) -> void:
	for kind in FIELDS:
		var key: String=kind+"_profile"
		if not packet.has(key): continue
		var parsed := from_packet(kind,packet[key])
		if parsed.ok: definition.set(key,parsed.profile)
