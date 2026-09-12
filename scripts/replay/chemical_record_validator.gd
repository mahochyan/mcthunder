class_name ChemicalRecordValidator
extends RefCounted
## Validates a single actual terminal ray and its ordered shared budget ledger.
static func validate(record: Dictionary) -> Dictionary:
	var effect: Variant=record.get("chemical_effect",{})
	var profile: Dictionary=record.launch.get("chemical_profile",{})
	if not effect is Dictionary: return _bad("invalid_chemical_effect")
	if effect.is_empty():
		return _bad("missing_chemical_effect") if record.terminal.reason=="chemical_detonation" else {"ok":true}
	if profile.is_empty() or record.launch.get("effect_policy")!="chemical" or effect.get("rules_version")!=ChemicalProfile.VERSION: return _bad("unexpected_chemical_effect")
	if not effect.get("point_world") is Vector3 or not effect.point_world.is_finite() or effect.point_world.distance_to(record.terminal.impact_point)>0.0001: return _bad("invalid_chemical_origin")
	if not effect.get("direction") is Vector3 or not effect.direction.is_finite() or absf(effect.direction.length()-1)>0.0001: return _bad("invalid_chemical_direction")
	var carrier_velocity: Variant=record.terminal.get("impact_velocity")
	if not carrier_velocity is Vector3 or not carrier_velocity.is_finite() or carrier_velocity.length_squared()<1e-12 or effect.direction.distance_to(carrier_velocity.normalized())>0.0001: return _bad("chemical_carrier_direction_mismatch")
	if not _same(effect.get("time_s"),record.terminal.flight_time_s) or not effect.get("complete") is bool: return _bad("invalid_chemical_time")
	if record.complete and not effect.complete: return _bad("incomplete_chemical_effect")
	if effect.get("trigger_kind") not in ["vehicle","world","damage"] or not effect.get("reason") is String: return _bad("invalid_chemical_trigger")
	if not _number(effect.get("trigger_frame")) or int(effect.trigger_frame)!=effect.trigger_frame: return _bad("invalid_chemical_trigger_frame")
	if effect.trigger_kind=="world":
		if effect.trigger_frame!=-1: return _bad("invalid_chemical_world_frame")
	elif effect.trigger_frame<0 or effect.trigger_frame>=record.frames.size(): return _bad("invalid_chemical_trigger_frame")
	if not effect.get("path") is Array or effect.path.is_empty() or effect.path.size()>ChemicalProfile.MAX_CONTACTS+1: return _bad("chemical_path_limits")
	var distance := 0.0
	for point in effect.path:
		if not point is Vector3 or not point.is_finite(): return _bad("invalid_chemical_path_point")
		var relative: Vector3=point-effect.point_world
		var at: float=relative.dot(effect.direction)
		if at<distance-0.0001 or relative.distance_to(effect.direction*at)>0.0001: return _bad("chemical_path_not_forward")
		distance=at
	if effect.path[0].distance_to(effect.point_world)>0.0001 or distance>float(profile.range_m)+0.0001 or not _same(effect.get("distance_m"),distance): return _bad("invalid_chemical_range")
	if not _same(effect.get("initial_mm"),profile.penetration_mm) or not _number(effect.get("remaining_mm")) or effect.remaining_mm<0: return _bad("invalid_chemical_budget")
	if not _number(effect.get("queries")) or int(effect.queries)!=effect.queries or effect.queries<0 or effect.queries>=ChemicalProfile.MAX_CONTACTS: return _bad("invalid_chemical_query_count")
	var events := {}
	for field in ["contact_indices","damage_indices"]:
		if not effect.get(field) is Array: return _bad("missing_chemical_links")
		var records: Array=record.contacts if field=="contact_indices" else record.damage
		var seen := {}
		for index in effect[field]:
			if not _number(index) or int(index)!=index or index<0 or index>=records.size() or seen.has(int(index)): return _bad("invalid_chemical_link")
			seen[int(index)]=true
			var event: Variant=records[int(index)]
			if not event is Dictionary or event.get("effect_channel")!="chemical_jet" or not _number(event.get("jet_event_index")) or int(event.jet_event_index)!=event.jet_event_index or events.has(int(event.jet_event_index)): return _bad("invalid_chemical_event")
			events[int(event.jet_event_index)]=event
		if seen.size()!=records.size(): return _bad("unlinked_chemical_event")
	if events.size()>ChemicalProfile.MAX_CONTACTS: return _bad("chemical_event_limit")
	var budget := float(profile.penetration_mm); var previous := 0.0
	for i in events.size():
		if not events.has(i): return _bad("chemical_event_order")
		var event: Dictionary=events[i]
		if not _number(event.get("jet_distance_m")) or event.jet_distance_m<previous or event.jet_distance_m>distance+0.0001: return _bad("invalid_chemical_event_distance")
		if not event.get("impact_point") is Vector3 or event.impact_point.distance_to(effect.point_world+effect.direction*float(event.jet_distance_m))>0.0001 or not _same(event.get("flight_time_s"),effect.time_s): return _bad("invalid_chemical_event_pose")
		budget=maxf(0,budget-(float(event.jet_distance_m)-previous)*float(profile.path_loss_mm_per_m))
		if not _same(event.get("before_mm"),budget) or not _number(event.get("after_mm")) or event.after_mm<0 or event.after_mm>budget+0.0001: return _bad("chemical_budget_discontinuity")
		budget=float(event.after_mm); previous=float(event.jet_distance_m)
	if effect.complete and not _same(effect.remaining_mm,maxf(0,budget-(distance-previous)*float(profile.path_loss_mm_per_m))): return _bad("invalid_chemical_final_budget")
	return {"ok":true}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _same(a: Variant,b: Variant) -> bool:
	return _number(a) and _number(b) and absf(float(a)-float(b))<=0.0002
static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
