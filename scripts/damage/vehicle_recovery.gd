class_name VehicleRecovery
extends RefCounted
## Pure state transactions. Actor alone advances time and publishes committed events.
static func source_from(record: Dictionary) -> Dictionary:
	var source := {}
	for key in ["round_id","shooter_id","shooter_life_id","shot_id","projectile_id","event_id"]:
		if record.has(key): source[key] = record[key]
	return source

static func on_direct_damage(state: VehicleRuntimeState, ammo: AmmoInventory, record: Dictionary) -> bool:
	if not state.recovery_enabled or state.destroyed or record.get("kind","") != "module": return false
	var id := str(record.get("item_id",""))
	if not state.module_states.has(id): return false
	var module: Dictionary = state.module_states[id]
	var source := source_from(record)
	if module.kind == "ammo" and float(module.integrity) <= 0 and int(ammo.racks.get(id,0)) > 0:
		return state.destroy_once("ammo_detonation",source)
	if module.kind == "engine" and float(module.integrity) <= float(module.max_integrity)*RecoveryRules.FIRE_IGNITION_INTEGRITY:
		ignite(state,id,source)
	return false

static func ignite(state: VehicleRuntimeState, module_id: String, source: Dictionary = {}) -> bool:
	if not state.recovery_enabled or state.destroyed or state.fires.has(module_id) or not state.module_states.has(module_id): return false
	state.fires[module_id] = {"source":source.duplicate(true),"tick_left":0.0,"crew_exposure":{}}
	if state.recovery_action == "repair":
		state.cancel_recovery()
		state.recovery_reason = "repair_interrupted_fire"
	return true

static func handle_command(state: VehicleRuntimeState, cmd: VehicleCommand, speed: float) -> void:
	if not state.recovery_enabled: return
	if state.destroyed:
		state.cancel_recovery()
		state.recovery_reason = "vehicle_destroyed"
		return
	if cmd.cancel_recovery_requested:
		state.cancel_recovery()
		state.recovery_reason = "cancelled"
		return
	if cmd.extinguish_requested:
		if state.recovery_action == "extinguish": return # Held/repeated request never charges twice.
		if state.fires.is_empty():
			state.recovery_reason = "not_on_fire"
			return
		if state.extinguisher_charges <= 0:
			state.recovery_reason = "no_extinguishers"
			return
		state.cancel_recovery()
		state.extinguisher_charges -= 1
		state.recovery_action = "extinguish"
		state.recovery_reason = ""
	elif cmd.repair_requested:
		if not state.fires.is_empty():
			state.recovery_reason = "cannot_repair_on_fire"
			return
		if absf(speed) >= RecoveryRules.REPAIR_MAX_SPEED or absf(cmd.steer) > 0.01 or absf(cmd.throttle) > 0.01:
			state.recovery_reason = "stop_to_repair"
			return
		if state.recovery_action == "repair": return
		var target := _repair_target(state)
		if target.is_empty():
			state.recovery_reason = "nothing_to_repair"
			return
		state.cancel_recovery()
		state.recovery_action = "repair"
		state.action_target = target
		state.action_progress = float(state.repair_progress.get(target,0.0))
		state.recovery_reason = ""
	elif cmd.replace_crew_requested:
		if state.recovery_action == "replace": return
		var role := ""
		for candidate in RecoveryRules.REPLACEMENT_PRIORITY:
			if state.crew_assignments.has(candidate) and not state.role_available(candidate):
				role = candidate
				break
		var person := ""
		for donor in RecoveryRules.DONOR_PRIORITY:
			if state.role_available(donor):
				person = state.crew_assignments[donor]
				break
		if role.is_empty() or person.is_empty():
			state.recovery_reason = "no_valid_replacement"
			return
		state.cancel_recovery()
		state.recovery_action = "replace"
		state.action_target = role
		state.action_person = person
		state.recovery_reason = ""

static func _repair_target(state: VehicleRuntimeState) -> String:
	for kind in RecoveryRules.REPAIR_PRIORITY:
		for id in state.module_states:
			var m: Dictionary = state.module_states[id]
			if m.kind == kind and float(m.integrity) < float(m.max_integrity)*RecoveryRules.REPAIR_TARGET:
				return id
	return ""

static func step(state: VehicleRuntimeState, delta: float, speed: float, cmd: VehicleCommand) -> bool:
	if not state.recovery_enabled or state.destroyed or not is_finite(delta) or delta <= 0: return false
	# Commands start at this physical tick. Fire and recovery both consume the same simulated time.
	handle_command(state,cmd,speed)
	# Fire advances before actions; finishing an extinguisher never rewinds exposure already accrued.
	for id in state.fires.keys():
		var fire: Dictionary = state.fires[id]
		fire.tick_left += delta
		while float(fire.tick_left) >= RecoveryRules.FIRE_TICK_SECONDS-1e-6:
			fire.tick_left -= RecoveryRules.FIRE_TICK_SECONDS
			var source_module: Dictionary = state.module_states[id]
			for target in source_module.fire_module_targets:
				if state.module_states.has(target):
					var module: Dictionary = state.module_states[target]
					module.integrity = maxf(0,float(module.integrity)-float(module.max_integrity)*RecoveryRules.FIRE_MODULE_DAMAGE)
			for station in source_module.fire_crew_targets:
				var role := str(state.station_roles.get(station,""))
				var person := str(state.crew_assignments.get(role,""))
				if person.is_empty() or not state.crew_states.has(person): continue
				fire.crew_exposure[person] = float(fire.crew_exposure.get(person,0.0))+RecoveryRules.FIRE_TICK_SECONDS
				if float(fire.crew_exposure[person]) >= RecoveryRules.FIRE_CREW_EXPOSURE_SECONDS:
					state.crew_states[person].alive = false
			if not state.crew_states.is_empty() and state.alive_crew_count() < GameConfig.DAMAGE_MIN_CREW:
				return state.destroy_once("fire_crew_out",fire.source)
	if state.recovery_action == "repair":
		if absf(speed) >= RecoveryRules.REPAIR_MAX_SPEED or absf(cmd.throttle)>0.01 or absf(cmd.steer)>0.01 or not state.fires.is_empty():
			state.cancel_recovery()
			state.recovery_reason = "repair_interrupted_motion_or_fire"
			return false
		state.action_progress += delta
		state.repair_progress[state.action_target] = state.action_progress
		if state.action_progress >= RecoveryRules.REPAIR_SECONDS-1e-6:
			var module: Dictionary = state.module_states[state.action_target]
			module.integrity = maxf(float(module.integrity),float(module.max_integrity)*RecoveryRules.REPAIR_TARGET)
			state.repair_progress.erase(state.action_target)
			state.cancel_recovery()
			state.recovery_reason = "module_repaired"
	elif state.recovery_action == "extinguish":
		state.action_progress += delta
		if state.action_progress >= RecoveryRules.EXTINGUISH_SECONDS-1e-6:
			state.fires.clear()
			state.cancel_recovery()
			state.recovery_reason = "fire_extinguished"
	elif state.recovery_action == "replace":
		var person: Dictionary = state.crew_states.get(state.action_person,{})
		if not person.get("alive",false) or state.role_available(state.action_target):
			state.cancel_recovery()
			state.recovery_reason = "replacement_cancelled"
			return false
		state.action_progress += delta
		if state.action_progress >= RecoveryRules.REPLACEMENT_SECONDS-1e-6:
			var assigned := state.assign_crew(state.action_target,state.action_person)
			state.cancel_recovery()
			state.recovery_reason = "crew_replaced" if assigned else "replacement_cancelled"
	return false
