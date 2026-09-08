class_name VehicleRuntimeState
extends RefCounted
## 003：车辆运行时状态（每实例独立，禁止放进共享车型 Resource）。
## 速度/炮塔/装填/计数/模块占位状态全部在此；重置只改本实例。

var entity_id: String = ""
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
var _damage_layout: VehicleLayoutDefinition
var _damage_seen: Dictionary = {}

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
	_damage_layout = layout
	module_states.clear()
	crew_states.clear()
	crew_assignments.clear()
	station_roles.clear()
	_damage_seen.clear()
	destroyed = false
	if layout == null:
		return
	for module in layout.modules:
		module_states[module.id] = {"kind":module.kind,"integrity":module.max_integrity,
			"max_integrity":module.max_integrity,"resistance_mm":module.resistance_mm,"external":module.external}
	for station in layout.crew_stations:
		crew_states[station.id] = {"alive":true,"original_role":station.role}
		crew_assignments[station.role] = station.id
		station_roles[station.id] = station.role

func damage_snapshot() -> Dictionary:
	return {"modules":module_states.duplicate(true),"people":crew_states.duplicate(true),
		"assignments":crew_assignments.duplicate(true),"station_roles":station_roles.duplicate(true)}

func role_available(role: String) -> bool:
	var person := str(crew_assignments.get(role,""))
	return not person.is_empty() and crew_states.has(person) and crew_states[person].get("alive",false)

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
			crew_states[person] = after.duplicate(true)
	_damage_seen[event_id] = true
	# Local simulation retains bounded recent identities; manager also deduplicates each shot.
	if _damage_seen.size() > 256:
		_damage_seen.erase(_damage_seen.keys()[0])
	var newly_destroyed := false
	if not destroyed and not crew_states.is_empty() and alive_crew_count() < GameConfig.DAMAGE_MIN_CREW:
		destroyed = true
		newly_destroyed = true
	return {"ok":true,"newly_destroyed":newly_destroyed}
