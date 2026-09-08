class_name DamageResolver
extends RefCounted
## Pure selection + deterministic direct-hit game rule. No total vehicle health.
static func target_key(event: Dictionary) -> String:
	return JSON.stringify([event.get("entity_id",""),event.get("life_id",0)])

static func item_key(event: Dictionary) -> String:
	return JSON.stringify([event.get("entity_id",""),event.get("life_id",0),event.get("kind",""),
		event.get("part_id",""),event.get("module_id",event.get("crew_id",""))])

static func next_contact(query: Dictionary, interior: Dictionary, seen: Dictionary, before_distance: float) -> Dictionary:
	if not query.get("ok",false) or not query.get("complete",false):
		return {}
	var best: Dictionary = {}
	for interval in query.get("volume_intervals",[]):
		if interval.get("grazing",false) or seen.has(item_key(interval)):
			continue
		if not interval.get("external",false) and not interior.get(target_key(interval),false):
			continue
		var distance := float(interval.get("distance_enter_m",INF))
		# Armor/world wins an exact tie; a successful armor contact re-queries at t=0.
		if distance >= before_distance - 1e-6:
			continue
		if best.is_empty() or ShotQueryService.event_less(interval,best):
			best = interval.duplicate(true)
	return best

static func resolve(event: Dictionary, available_mm: float, snapshot: Dictionary) -> Dictionary:
	if not is_finite(available_mm) or available_mm <= 0:
		return {"ok":false,"reason":"no_budget"}
	var kind := str(event.get("kind",""))
	var item_id := str(event.get("module_id",event.get("crew_id","")))
	var out := {"ok":true,"kind":kind,"item_id":item_id,"consumed_mm":0.0,"before":{},
		"after":{},"person_id":"","reason":"empty_station"}
	if kind == "module":
		var modules: Dictionary = snapshot.get("modules",{})
		if not modules.has(item_id):
			return {"ok":false,"reason":"missing_module"}
		var m: Dictionary = modules[item_id]
		var resistance := float(m.get("resistance_mm",-1))
		var maximum := float(m.get("max_integrity",-1))
		if not is_finite(resistance) or resistance <= 0 or not is_finite(maximum) or maximum <= 0:
			return {"ok":false,"reason":"invalid_module_rule"}
		out.before = m.duplicate(true)
		out.after = m.duplicate(true)
		var ratio := minf(1.0, available_mm/resistance)
		out.after.integrity = maxf(0, float(m.integrity) - maximum*ratio)
		out.consumed_mm = minf(resistance,available_mm)
		out.reason = "module_destroyed" if float(out.after.integrity) <= 0 else "module_damaged"
	elif kind == "crew":
		var station_roles: Dictionary = snapshot.get("station_roles",{})
		var assignments: Dictionary = snapshot.get("assignments",{})
		var people: Dictionary = snapshot.get("people",{})
		var role := str(station_roles.get(item_id,""))
		var person := str(assignments.get(role,""))
		if person.is_empty():
			return out
		if not people.has(person):
			return {"ok":false,"reason":"missing_person"}
		out.person_id = person
		out.before = people[person].duplicate(true)
		out.after = people[person].duplicate(true)
		out.after.alive = false
		out.consumed_mm = minf(available_mm,GameConfig.DAMAGE_CREW_RESISTANCE_MM)
		out.reason = "crew_incapacitated"
	else:
		return {"ok":false,"reason":"invalid_damage_kind"}
	return out
