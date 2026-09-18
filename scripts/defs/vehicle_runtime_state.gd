class_name VehicleRuntimeState
extends RefCounted
## 003：车辆运行时状态（每实例独立，禁止放进共享车型 Resource）。
## 速度/炮塔/装填/计数/模块占位状态全部在此；重置只改本实例。

var entity_id: String = ""
var life_id := 0
var generation := 0
var team_id: int = 0
var definition_id: String = ""

# --- movement ---
var forward_speed: float = 0.0

# --- turret ---
var turret_yaw: float = 0.0
var gun_pitch: float = 0.0

# --- weapon ---
var cooldown_left: float = 0.0
var resume_grace: float = 0.0
var shots_fired: int = 0
var last_shot_result: String = ""   # "" / "hit" / "miss" / "blocked:cooldown" / "blocked:grace" / "blocked:barrel_occluded"

# --- 命中/损伤占位（004 装甲/内构用） ---
var hits_taken: int = 0
var module_states: Dictionary = {}   # module_id -> 占位状态
var destroyed: bool = false
var crew_states: Dictionary = {}
var crew_assignments: Dictionary = {}
var station_roles: Dictionary = {}
# CD08-T02: station id -> person id, so an occupied or vacated station is readable without confusing the two identities.
var station_occupancy: Dictionary = {}
var _damage_layout: VehicleLayoutDefinition
var _damage_seen: Dictionary = {}
var reactive_armor: Dictionary = {} # surface id -> remaining single-use charge; instance state only.
var _armor_seen: Dictionary = {}
var recovery_enabled := false
var fires: Dictionary = {}
var repair_progress: Dictionary = {}
var recovery_action := ""
var action_target := ""
var action_person := ""
var action_progress := 0.0
var recovery_reason := ""
var extinguisher_charges := RecoveryRules.EXTINGUISH_CHARGES
var death_record: Dictionary = {}
# CD08-T06: the last legacy migration performed on this instance, with its rollback, so the change is auditable.
var legacy_migration: Dictionary = {}
var death_notified := false

func reset() -> void:
	forward_speed = 0.0
	turret_yaw = 0.0
	gun_pitch = 0.0
	cooldown_left = 0.0
	resume_grace = 0.0
	shots_fired = 0
	last_shot_result = ""
	hits_taken = 0
	module_states.clear()
	destroyed = false
	initialize_damage(_damage_layout)

func initialize_damage(layout: VehicleLayoutDefinition) -> void:
	generation += 1
	_damage_layout = layout
	module_states.clear()
	crew_states.clear()
	crew_assignments.clear()
	station_roles.clear()
	station_occupancy.clear()
	_damage_seen.clear()
	_armor_seen.clear()
	reactive_armor.clear()
	destroyed = false
	recovery_enabled = layout != null and layout.recovery_enabled
	fires.clear()
	repair_progress.clear()
	cancel_recovery()
	recovery_reason = ""
	extinguisher_charges = RecoveryRules.EXTINGUISH_CHARGES
	death_record.clear()
	death_notified = false
	if layout == null:
		return
	for patch in layout.armor_patches:
		if not patch.reactive_profile.is_empty(): reactive_armor[patch.id]=1
	for module in layout.modules:
		module_states[module.id] = {"kind":module.kind,"integrity":module.max_integrity,
			"max_integrity":module.max_integrity,"resistance_mm":module.resistance_mm,"external":module.external,
			"fire_module_targets":module.fire_module_targets.duplicate(),"fire_crew_targets":module.fire_crew_targets.duplicate()}
		if not module.ammo_protection.is_empty(): module_states[module.id]["ammo_protection"]=module.ammo_protection.duplicate(true)
	for station in layout.crew_stations:
		# CD08: the versioned condition is the readable state; alive is retained and derived so a legacy reader sees
		# exactly what it saw before. No penalty is applied by the condition in this version.
		# CD08-T02: a person is identified apart from the station they occupy. The role stays the bridge between them, and
		# every reader already resolves the person through crew_assignments, so nothing needs to know the new key.
		# CD08-T02 REVERTED: binding a person identity to the role made a move change who the person is, and the existing
		# suite already asserts that a living person can occupy another role. The proper fix needs an identity independent of
		# both the role and the station, which is the next step; until then this stays exactly as it was.
		crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)
		crew_assignments[station.role] = station.id
		station_occupancy[station.id] = station.id
		station_roles[station.id] = station.role

func damage_snapshot() -> Dictionary:
	return {"modules":module_states.duplicate(true),"people":crew_states.duplicate(true),
		"assignments":crew_assignments.duplicate(true),"station_roles":station_roles.duplicate(true),
			"station_occupancy":station_occupancy.duplicate(true)}

func role_available(role: String) -> bool:
	var person := str(crew_assignments.get(role,""))
	if person.is_empty() or not crew_states.has(person): return false
	# CD08: condition and availability are separate. Legacy records without a condition fall back to the boolean, and in
	# this version only incapacitation removes a person from duty, so no unconfirmed middle penalty is switched on.
	var person_state: Dictionary = crew_states[person]
	var condition := str(person_state.get("condition",""))
	if condition.is_empty(): return bool(person_state.get("alive",false))
	return bool(person_state.get("alive",false)) and CrewDamageProfile.is_available(condition)

func alive_crew_count() -> int:
	var count := 0
	for person in crew_states.values():
		if person.get("alive",false):
			count += 1
	return count

func assign_crew(role: String, person_id: String) -> bool:
	var result := CrewRoster.assign(crew_assignments,crew_states,role,person_id)
	if not result.get("ok",false):
		return false
	crew_assignments = result.assignments
	return true

func apply_damage_delta(event_id: String, delta: Dictionary) -> Dictionary:
	if not delta.get("ok",false) or event_id.is_empty() or _damage_seen.has(event_id):
		return {"ok":false,"reason":"invalid_or_duplicate"}
	# CD08-T06: a record written before this order migrates under a named version, and the rollback is kept beside it.
	if str(delta.get("kind","")) == "legacy_alive":
		var legacy: Dictionary = delta.get("snapshot",{})
		var people_in: Dictionary = legacy.get("people",{})
		var migrated := CrewDamageProfile.migrate_legacy(people_in)
		crew_states = (migrated.get("people",{}) as Dictionary).duplicate(true)
		if not crew_assignments.is_empty(): pass
		legacy_migration = {"version":migrated.get("version",""),"from_version":migrated.get("from_version",""),
			"migrated":migrated.get("migrated",[]),"rollback":CrewDamageProfile.rollback_to_legacy(crew_states)}
		return {"ok":true,"migration_version":str(legacy_migration.get("version","")),
			"migrated_entries":(legacy_migration.get("migrated",[]) as Array).size(),"rollback_available":true}
	var item := str(delta.get("item_id",""))
	var before: Dictionary = delta.get("before",{})
	var after: Dictionary = delta.get("after",{})
	if not after.is_empty():
		if delta.kind == "module":
			if not module_states.has(item) or module_states[item] != before:
				return {"ok":false,"reason":"stale_state"}
			module_states[item] = after.duplicate(true)
		elif delta.kind == "crew":
			var person := str(delta.person_id)
			if not crew_states.has(person) or crew_states[person] != before:
				return {"ok":false,"reason":"stale_state"}
			# CD08-T04: an incapacitated person does not come back in this life. Recovery for lesser conditions is a declared
			# rule that this version does not have, so raising anyone out of incapacitation is refused by name.
			var was_incapacitated := CrewDamageProfile.is_incapacitated(str((crew_states[person] as Dictionary).get("condition","")))
			var now_available := bool(after.get("alive",false)) and CrewDamageProfile.is_available(str(after.get("condition",CrewDamageProfile.CONDITION_HEALTHY)))
			if was_incapacitated and now_available:
				return {"ok":false,"reason":"incapacitated_in_this_life"}
			crew_states[person] = after.duplicate(true)
	_damage_seen[event_id] = true
	# Local simulation retains bounded recent identities; manager also deduplicates each shot.
	if _damage_seen.size() > 256:
		_damage_seen.erase(_damage_seen.keys()[0])
	var newly_destroyed := false
	if not destroyed and not crew_states.is_empty() and alive_crew_count() < GameConfig.DAMAGE_MIN_CREW:
		newly_destroyed = destroy_once("crew_out",delta.get("source",{}))
	return {"ok":true,"newly_destroyed":newly_destroyed}

func cancel_recovery() -> void:
	recovery_action = ""
	action_target = ""
	action_person = ""
	action_progress = 0.0

func destroy_once(cause: String, source: Dictionary) -> bool:
	if destroyed: return false
	destroyed = true
	death_record = {"entity_id":entity_id,"life_id":life_id,"generation":generation,
		"cause":cause,"source":source.duplicate(true),"rules_version":RecoveryRules.VERSION}
	cancel_recovery()
	repair_progress.clear()
	fires.clear()
	return true
