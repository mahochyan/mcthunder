class_name SpallRecordValidator
extends RefCounted
## Checks the recorded budget split and actual traces; does not synthesize damage.
static func validate(record: Dictionary) -> Dictionary:
	var profile: Dictionary=record.launch.post_penetration_profile
	var batches: Variant=record.get("spall_events",[])
	var fragments: Variant=record.get("fragments",[])
	if not record.get("burst",{}) is Dictionary or not record.get("burst",{}).is_empty(): return _bad("spall_is_not_aphe_burst")
	if not batches is Array or batches.size()>SpallProfile.MAX_EVENTS or not fragments is Array or fragments.size()>SpallProfile.MAX_EVENTS*SpallProfile.MAX_COUNT: return _bad("spall_limits")
	var next_fragment := 0
	var previous_contact := -1
	var surfaces := {}
	var linked_damage := {}
	for index in batches.size():
		var batch: Variant=batches[index]
		if not batch is Dictionary or batch.get("id")!=index or batch.get("rules_version")!=SpallProfile.VERSION: return _bad("invalid_spall_batch")
		for key in ["contact_index","fragment_start","fragment_count","geometry_frame"]:
			if not _number(batch.get(key)) or int(batch[key])!=batch[key]: return _bad("invalid_spall_index")
		if batch.contact_index<=previous_contact or batch.contact_index>=record.contacts.size(): return _bad("invalid_spall_contact")
		previous_contact=int(batch.contact_index)
		var contact: Variant=record.contacts[previous_contact]
		if not contact is Dictionary or contact.get("result")!="penetrated" or contact.get("backface")!=false: return _bad("spall_requires_inward_penetration")
		var key := ProjectileManager._surface_key(contact)
		if surfaces.has(key): return _bad("duplicate_spall_surface")
		surfaces[key]=true
		if not batch.get("point_world") is Vector3 or not batch.point_world.is_finite() or not contact.get("impact_point") is Vector3 or batch.point_world.distance_to(contact.impact_point)>0.0001: return _bad("invalid_spall_origin")
		if not _same(batch.get("time_s"),contact.get("flight_time_s")) or batch.geometry_frame!=contact.get("geometry_frame"): return _bad("invalid_spall_time_or_frame")
		if not batch.get("direction") is Vector3 or not batch.direction.is_finite() or not contact.get("incoming_velocity") is Vector3 or contact.incoming_velocity.length_squared()<1e-12 or batch.direction.distance_to(contact.incoming_velocity.normalized())>0.0001: return _bad("invalid_spall_direction")
		if not _same(batch.get("parent_before_mm"),contact.get("after_mm")): return _bad("invalid_spall_parent_budget")
		var allocation := SpallProfile.allocation(profile,float(contact.after_mm))
		if allocation<=0 or not _same(batch.get("allocated_mm"),allocation) or not _same(batch.get("parent_after_mm"),float(contact.after_mm)-allocation): return _bad("invalid_spall_allocation")
		if batch.fragment_start!=next_fragment or batch.fragment_count<0 or batch.fragment_count>profile.count or next_fragment+batch.fragment_count>fragments.size(): return _bad("invalid_spall_fragment_range")
		if record.complete and batch.fragment_count!=profile.count: return _bad("missing_complete_spall_fragments")
		var directions := SpallProfile.directions(profile,batch.direction,int(record.identity.seed),index)
		for local_index in int(batch.fragment_count):
			var fragment: Variant=fragments[next_fragment]
			var checked := ShotRecordBuilder.validate_fragment_trace(record,fragment,next_fragment,batch.point_world,float(profile.range_m),linked_damage)
			if not checked.ok: return checked
			if fragment.get("spall_event_id")!=index or fragment.direction.distance_to(directions[local_index])>0.0001: return _bad("invalid_spall_seeded_direction")
			for damage_index in fragment.damage_indices:
				var damage: Dictionary=record.damage[int(damage_index)]
				if not _same(damage.get("flight_time_s"),batch.time_s) or not _number(damage.get("before_mm")) or damage.before_mm>allocation/float(profile.count)+0.0001: return _bad("invalid_spall_damage_budget")
			for contact_event in fragment.contacts:
				if not _number(contact_event.get("before_mm")) or contact_event.before_mm>allocation/float(profile.count)+0.0001: return _bad("invalid_spall_fragment_budget")
			next_fragment+=1
	if next_fragment!=fragments.size(): return _bad("unlinked_spall_fragments")
	for index in record.damage.size():
		var damage: Variant=record.damage[index]
		if not damage is Dictionary or (damage.get("fragment_id",-1)!=-1 and not linked_damage.has(index)): return _bad("unlinked_spall_damage")
	return {"ok":true}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _same(a: Variant,b: Variant) -> bool:
	return _number(a) and _number(b) and absf(float(a)-float(b))<=0.0001

static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
