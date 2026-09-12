class_name AmmoCompartmentProfile
extends RefCounted
## Authored rear-bustle isolation rule, not a pressure/temperature simulation.
const VERSION := "wt015-rear-bustle-v1"

static func validate(value: Variant) -> Array[String]:
	if not value is Dictionary: return ["ammo_protection: expected dictionary"]
	if value.is_empty(): return []
	if value.get("version")!=VERSION or value.get("mode")!="rear_bustle" or value.get("provenance")!="game_rule": return ["ammo_protection: explicit versioned game rule required"]
	if not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): return ["ammo_protection: explanation required"]
	for key in ["barrier_module_id","vent_module_id"]:
		if not value.get(key) is String or str(value[key]).length()>96 or not str(value[key]).is_valid_identifier(): return ["ammo_protection: explicit module identifiers required"]
	if value.barrier_module_id==value.vent_module_id: return ["ammo_protection: barrier and vent must be distinct"]
	for key in value:
		if key not in ["version","mode","provenance","reason","barrier_module_id","vent_module_id"]: return ["ammo_protection: unknown field "+str(key)]
	return []

static func check(packet: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	var modules := {}
	for row in packet.modules: modules[row.id]=row
	for row in packet.modules:
		if not row.has("ammo_protection"): continue
		var policy: Variant=row.ammo_protection
		var invalid := validate(policy); errors.append_array(invalid)
		if not invalid.is_empty() or policy.is_empty(): continue
		if row.kind!="ammo" or row.get("external",false): errors.append("ammo_protection: internal ammo module required"); continue
		var key := "protection.ammo."+str(row.id)
		var fact: Variant=packet.facts.get(key)
		errors.append_array(ReferenceEvidenceGate.check_claim(key,fact,packet,"structured"))
		if not fact is Dictionary or fact.get("value")!=policy or fact.get("origin")!="game_rule" or fact.get("status")!="estimated": errors.append(key+": exact independent design evidence required")
		if not modules.has(policy.barrier_module_id) or not modules.has(policy.vent_module_id): errors.append(key+": missing bound protection geometry"); continue
		var barrier: Dictionary=modules[policy.barrier_module_id]; var vent: Dictionary=modules[policy.vent_module_id]
		if barrier.kind!="ammo_partition" or vent.kind!="blowout_panel" or barrier.part!=row.part or vent.part!=row.part or barrier.get("external",false) or vent.get("external",false): errors.append(key+": same-part internal partition and vent required"); continue
		var rack := _box(row); var wall := _box(barrier); var roof := _box(vent)
		if wall.end.z>=rack.position.z-0.01 or wall.position.x>rack.position.x or wall.end.x<rack.end.x or wall.position.y>rack.position.y or wall.end.y<rack.end.y: errors.append(key+": partition must precede and cover the rear rack cross-section")
		if roof.position.y<rack.end.y or roof.position.x>rack.position.x or roof.end.x<rack.end.x or roof.position.z>rack.position.z or roof.end.z<rack.end.z: errors.append(key+": roof vent must cover the rack from above")
		for crew in packet.crew:
			if crew.part==row.part and _box(crew).end.z>=wall.position.z: errors.append(key+": occupied turret station lies behind or inside isolation partition")
	return errors

static func _box(row: Dictionary) -> AABB:
	var size := HistoricalVehicleGeometry.vec(row.size)
	return AABB(HistoricalVehicleGeometry.vec(row.position)-size*0.5,size)

static func can_vent(policy: Dictionary, state: VehicleRuntimeState, ammo: AmmoInventory, rack: String) -> bool:
	if policy.is_empty() or not validate(policy).is_empty(): return false
	var wall: Dictionary=state.module_states.get(policy.barrier_module_id,{})
	var vent: Dictionary=state.module_states.get(policy.vent_module_id,{})
	if wall.get("kind")!="ammo_partition" or float(wall.get("integrity",0))<=0 or vent.get("kind")!="blowout_panel": return false
	# Chamber contents are already outside the closed compartment. Active loading
	# and replenishment expose its access path; a spent/open roof vent still vents.
	if ammo.in_transfer>0 and ammo.transfer_from==rack: return false
	var move := ammo.rack_move_snapshot()
	return move.is_empty() or (move.from!=rack and move.to!=rack)

static func valid_record(event: Dictionary) -> bool:
	if not event.has("ammo_event"): return true
	var row: Variant=event.ammo_event
	if not row is Dictionary or row.size()!=9 or row.get("version")!=VERSION or row.get("outcome")!="vented": return false
	for key in ["version","outcome","rack_id","lost_shells","barrier_module_id","vent_module_id","before","after","isolation"]:
		if not row.has(key): return false
	if not row.rack_id is String: return false
	if not row.isolation is Dictionary: return false
	var wall: Variant=row.isolation.get("barrier")
	var vent: Variant=row.isolation.get("vent")
	if not wall is Dictionary or wall.get("kind")!="ammo_partition" or not _number(wall.get("integrity")) or wall.integrity<=0: return false
	if not vent is Dictionary or vent.get("kind")!="blowout_panel": return false
	if event.get("kind")!="module" or event.get("item_id")!=row.get("rack_id") or event.get("newly_destroyed",false): return false
	var module: Variant=event.get("after")
	if not module is Dictionary or module.get("kind")!="ammo" or module.get("integrity")!=0: return false
	var policy: Variant=module.get("ammo_protection")
	if not validate(policy).is_empty() or policy.is_empty(): return false
	if row.get("barrier_module_id")!=policy.barrier_module_id or row.get("vent_module_id")!=policy.vent_module_id: return false
	if not row.get("before") is Dictionary or not row.get("after") is Dictionary or not row.get("lost_shells") is Dictionary: return false
	var before: Dictionary=row.before; var after: Dictionary=row.after; var lost_count := 0
	if not before.get("rack_shells") is Dictionary or not before.rack_shells.get(row.rack_id) is Dictionary: return false
	if not _inventory(before) or not _inventory(after): return false
	if not _equivalent(before.rack_shells[row.rack_id],row.lost_shells): return false
	for value in row.lost_shells.values():
		if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value!=int(value): return false
		lost_count+=int(value)
	if lost_count<=0: return false
	for key in ["racks","shell_counts","rack_move"]:
		if not before.get(key) is Dictionary: return false
	for key in ["lost","available"]:
		if not _whole(before.get(key)): return false
	if before.get("in_transfer",0)>0 and before.get("transfer_from")==row.rack_id: return false
	if not before.rack_move.is_empty() and (before.rack_move.get("from")==row.rack_id or before.rack_move.get("to")==row.rack_id): return false
	var expected := before.duplicate(true)
	for shell in row.lost_shells:
		if not _whole(expected.shell_counts.get(shell)): return false
		expected.shell_counts[shell]-=int(row.lost_shells[shell])
		expected.rack_shells[row.rack_id][shell]=0
	expected.racks[row.rack_id]=0; expected.lost+=lost_count; expected.available-=lost_count
	return _equivalent(expected,after)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value: Variant) -> bool:
	return _number(value) and value>=0 and value<=1000000 and value==int(value)

static func _inventory(value: Dictionary) -> bool:
	for key in ["racks","rack_shells","shell_counts","rack_move"]:
		if not value.get(key) is Dictionary: return false
	for key in ["chamber","in_transfer","available","capacity","supplied","fired","lost"]:
		if not _whole(value.get(key)): return false
	if value.chamber+value.in_transfer>1 or value.available>value.capacity: return false
	if value.available+value.fired+value.lost!=value.supplied: return false
	var counts := {}; var total := 0
	for shell in value.shell_counts:
		if not shell is String or not _whole(value.shell_counts[shell]): return false
		counts[shell]=0
	if value.racks.size()!=value.rack_shells.size(): return false
	for rack in value.rack_shells:
		var stored: Variant=value.rack_shells[rack]
		if not rack is String or not stored is Dictionary or not _whole(value.racks.get(rack)): return false
		var rack_total := 0
		for shell in stored:
			if not counts.has(shell) or not _whole(stored[shell]): return false
			counts[shell]+=stored[shell]; rack_total+=int(stored[shell])
		if rack_total!=value.racks[rack]: return false
		total+=rack_total
	for key in ["chamber","transfer"]:
		var shell: Variant=value.get(key+"_shell")
		var amount: int=int(value.chamber if key=="chamber" else value.in_transfer)
		if not shell is String or (amount==0 and shell!="") or (amount==1 and not counts.has(shell)): return false
		if amount==1: counts[shell]+=1; total+=1
	return total==value.available and _equivalent(counts,value.shell_counts)

static func _equivalent(a: Variant, b: Variant) -> bool:
	# JSON decodes whole numbers as floats; container equality distinguishes them.
	if _number(a) and _number(b): return a==b
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not _equivalent(a[i],b[i]): return false
		return true
	return a==b
