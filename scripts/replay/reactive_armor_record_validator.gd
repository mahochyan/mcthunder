class_name ReactiveArmorRecordValidator
extends RefCounted
## Charge history is ordered across the carrier and all synchronous fragment batches.
static func validate(record: Dictionary) -> Dictionary:
	var count: Variant=record.get("reactive_event_count",0)
	if not ReactiveArmorProfile._number(count) or int(count)!=count or count<0 or count>1024: return {"ok":false,"reason":"invalid_reactive_count"}
	if (count>0 and record.rules_versions.get("reactive")!=ReactiveArmorProfile.VERSION) or (count==0 and record.rules_versions.has("reactive")): return {"ok":false,"reason":"invalid_reactive_version"}
	var contacts: Array=record.contacts.duplicate()
	for fragment in record.get("fragments",[]): contacts.append_array(fragment.contacts)
	var ordered := {}
	for contact in contacts:
		if contact.get("reactive_profile",{}).is_empty():
			if contact.has("reactive_event_index"): return {"ok":false,"reason":"unexpected_reactive_event"}
			continue
		var index: Variant=contact.get("reactive_event_index")
		if not ReactiveArmorProfile._number(index) or int(index)!=index or index<0 or index>=count or ordered.has(int(index)): return {"ok":false,"reason":"invalid_reactive_index"}
		ordered[int(index)]=contact
	if ordered.size()!=count: return {"ok":false,"reason":"missing_reactive_events"}
	var states := {}
	for index in int(count):
		var contact: Dictionary=ordered[index]
		for field in ["reactive_before","reactive_after"]:
			if not ReactiveArmorProfile._number(contact.get(field)) or (contact[field]!=0 and contact[field]!=1): return {"ok":false,"reason":"invalid_reactive_charge"}
		var key := JSON.stringify([contact.get("entity_id"),contact.get("life_id"),contact.get("target_generation"),contact.get("part_id"),contact.get("surface_id")])
		if states.has(key) and states[key]!=contact.reactive_before: return {"ok":false,"reason":"reactive_charge_discontinuity"}
		if contact.reactive_after>contact.reactive_before: return {"ok":false,"reason":"reactive_charge_restored_in_shot"}
		states[key]=contact.reactive_after
	return {"ok":true}
