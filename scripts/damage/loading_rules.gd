class_name LoadingRules
extends RefCounted
## Pure capability derivation. A generic source module name never grants equipment.
static func compute(profile: LoadingProfile, state: VehicleRuntimeState) -> Dictionary:
	var p := profile if profile!=null else LoadingProfile.new()
	var reasons: Array[String]=[]
	var can_load := true; var rate := 1.0
	if not p.validate_bindings(state._damage_layout).is_empty(): reasons.append("loading_configuration"); can_load=false
	for id in p.required_module_ids:
		if not module_available(state,id): reasons.append("loading_module:"+id); can_load=false
	if p.mode=="crew" and not state.crew_states.is_empty() and not state.role_available(p.crew_role):
		rate=p.missing_crew_rate; reasons.append("loading_crew:"+p.crew_role)
	if state.destroyed: can_load=false; reasons.append("vehicle_destroyed")
	if not can_load: rate=0.0
	var replenish: bool=p.replenishment_enabled and can_load and state.fires.is_empty()
	if not p.replenishment_role.is_empty() and not state.role_available(p.replenishment_role): replenish=false
	for id in p.replenishment_module_ids:
		if not module_available(state,id): replenish=false
	return {"can_load":can_load and rate>0,"reload_rate":rate,"loading_mode":p.mode,"loading_reasons":reasons,"replenishment_allowed":replenish}

static func module_available(state: VehicleRuntimeState, id: String) -> bool:
	return state.module_states.has(id) and float(state.module_states[id].get("integrity",0))>0
