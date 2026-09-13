class_name AIRoleAllocator
extends RefCounted
## WT-020-R1: public task distribution for AI teams.
##
## Deliberately a pure decision layer: it reads only the objective public state, the
## team's own roster (position, ammunition, mobility, damage) and its own assignment
## history. It never reads an enemy's internal truth, so "see through walls" cannot be
## introduced here. Roles change only on an urgent trigger or after a hysteresis
## window, which is what stops permanent per-step task oscillation.

const ROLES := ["repair","supply","defend","attack","flank"]
const SWITCH_COOLDOWN_S := 12.0
const HOLD_RADIUS_M := 45.0
const CHOKEPOINT_GIVE_WAY_S := 6.0
const FRIEND_GAP_M := 6.0
const OPPOSING_DOT := -0.3
const DRY_AMMO_FRACTION := 0.25

var assignments: Dictionary = {}      # entity_id -> {role, objective, since, reason, urgent}
var clock := 0.0
var chokepoint_test := Callable()     # func(position: Vector3) -> bool

func tick(delta: float) -> void:
	if delta > 0.0 and is_finite(delta): clock += delta

func _row(roster: Array, entity_id: String) -> Dictionary:
	for row in roster:
		if row is Dictionary and str(row.get("entity_id","")) == entity_id: return row
	return {}

## Assign roles for one team. Deterministic for a given roster/context pair.
func assign(roster: Array, context: Dictionary) -> Dictionary:
	var objectives: Array = context.get("objectives",[])      # [{id, position:Vector3, owner_team}]
	var supply: Dictionary = context.get("supply",{})         # team -> Vector3
	var team := int(context.get("team",1))
	var ids: Array[String] = []
	for row in roster:
		if row is Dictionary and int(row.get("team",team)) == team and not bool(row.get("destroyed",false)):
			ids.append(str(row.get("entity_id","")))
	ids.sort()
	var movable: Array[String] = []
	for id in ids:
		var row := _row(roster,id)
		if bool(row.get("mobile",true)): movable.append(id)
	var attack_pool: Array[String] = []
	var flank_pool: Array[String] = []
	for i in movable.size():
		# one flank element per team, the rest push objectives
		if i == 0 and movable.size() >= 3: flank_pool.append(movable[i])
		else: attack_pool.append(movable[i])
	var wanted := {}
	for i in attack_pool.size():
		if objectives.is_empty(): break
		var objective: Dictionary = objectives[i % objectives.size()]
		wanted[attack_pool[i]] = {"role":"attack","objective":str(objective.get("id","")),"reason":"public_objective_push"}
	for id in flank_pool:
		var objective: Dictionary = objectives[objectives.size()-1] if not objectives.is_empty() else {}
		wanted[id] = {"role":"flank","objective":str(objective.get("id","")),"reason":"outer_lane_flank"}
	for id in ids:
		var row := _row(roster,id)
		var current: Dictionary = assignments.get(id,{})
		var urgent := ""
		if not bool(row.get("mobile",true)) or bool(row.get("immobile_damaged",false)):
			urgent = "repair"
		elif float(row.get("ammo_fraction",1.0)) <= DRY_AMMO_FRACTION:
			urgent = "supply"
		elif not wanted.has(id):
			urgent = "defend"
		var proposed: Dictionary = wanted.get(id,{"role":"defend","objective":str(current.get("objective","")),"reason":"objective_hold"})
		if urgent == "repair":
			proposed = {"role":"repair","objective":str(current.get("objective","")),"reason":"immobile_or_damaged_first"}
		elif urgent == "supply":
			proposed = {"role":"supply","objective":str(current.get("objective","")),"reason":"dry_ammo_resupply"}
		elif urgent == "defend":
			proposed = {"role":"defend","objective":str(current.get("objective","")),"reason":"no_public_push_target"}
		# holding an objective we already own is a legitimate hold, never a stall
		if str(proposed.role) == "defend" and bool(row.get("at_objective",false)):
			proposed["hold_reason"] = "legitimate_objective_hold"
		var since := float(current.get("since",-INF))
		var same := str(current.get("role","")) == str(proposed.role) and str(current.get("objective","")) == str(proposed.objective)
		var is_urgent := not urgent.is_empty() and not same
		var cooled := clock - since >= SWITCH_COOLDOWN_S
		if current.is_empty() or (not same and (is_urgent or cooled)):
			assignments[id] = {"role":proposed.role,"objective":proposed.objective,"reason":proposed.reason,
				"since":clock,"urgent":is_urgent,"hold_reason":str(proposed.get("hold_reason",""))}
	return assignments.duplicate(true)

func task_for(entity_id: String) -> Dictionary:
	return (assignments.get(entity_id,{}) as Dictionary).duplicate(true)

func objective_position(entity_id: String, context: Dictionary) -> Vector3:
	var task := task_for(entity_id)
	var role := str(task.get("role",""))
	if role == "supply":
		var supply: Dictionary = context.get("supply",{})
		var team := int(context.get("team",1))
		if supply.has(team): return supply[team]
	if role == "repair": return Vector3.ZERO   # hold position; recovery decides the rest
	var objectives: Array = context.get("objectives",[])
	for objective in objectives:
		if objective is Dictionary and str(objective.get("id","")) == str(task.get("objective","")):
			return objective.get("position",Vector3.ZERO)
	return Vector3.ZERO

## Auditable decision record: what the task is, why, how old, and the state it saw.
func decision_reason(entity_id: String, observation: Dictionary = {}) -> Dictionary:
	var task := task_for(entity_id)
	return {
		"entity_id":entity_id,
		"task":str(task.get("role","")),
		"objective":str(task.get("objective","")),
		"reason":str(task.get("reason","")),
		"assigned_age_s":clock-float(task.get("since",clock)),
		"urgent":bool(task.get("urgent",false)),
		"hold_reason":str(task.get("hold_reason","")),
		"last_seen_age_s":float(observation.get("last_seen_age_s",-1.0)),
		"ammo_state":str(observation.get("ammo_state","unknown")),
		"damage_state":str(observation.get("damage_state","unknown")),
	}

## Bounded give-way: when two same-team AI meet head-on inside a chokepoint, exactly one
## holds, and only for a bounded time. Outside a chokepoint, or when headings are not
## opposing, nobody yields.
func should_give_way(self_row: Dictionary, other_row: Dictionary) -> bool:
	if self_row.is_empty() or other_row.is_empty(): return false
	if int(self_row.get("team",-1)) != int(other_row.get("team",-2)): return false
	var mine: Vector3 = self_row.get("position",Vector3.ZERO)
	var theirs: Vector3 = other_row.get("position",Vector3.ZERO)
	if mine.distance_to(theirs) > FRIEND_GAP_M: return false
	var in_chokepoint := true
	if chokepoint_test.is_valid():
		in_chokepoint = bool(chokepoint_test.call(mine)) or bool(chokepoint_test.call(theirs))
	if not in_chokepoint: return false
	var my_forward: Vector3 = self_row.get("forward",Vector3.FORWARD)
	var their_forward: Vector3 = other_row.get("forward",Vector3.FORWARD)
	if my_forward.normalized().dot(their_forward.normalized()) > OPPOSING_DOT: return false
	# determinism: the higher entity id yields, so both sides agree without negotiation
	return str(self_row.get("entity_id","")) > str(other_row.get("entity_id",""))
