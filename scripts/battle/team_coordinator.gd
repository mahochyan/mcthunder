class_name TeamCoordinator
extends RefCounted
## WT-021: one coordinator per team.
##
## It owns the public task assignment (through the WT-020 allocator, so task changes keep
## their hysteresis), publishes the friendly rows the AI controllers need for a bounded
## give-way, treats wrecks as dynamic obstacles, and attributes every idle second so a
## justified hold is never reported as a traffic jam.

const MOVING_SPEED_MPS := 0.6
const ATTRIBUTIONS := ["moving","engaging","repairing","immobile","legitimate_hold","yielding","traffic_blocked"]

var team := 1
var allocator := AIRoleAllocator.new()
var context: Dictionary = {}
var chokepoint_test := Callable()
var attribution: Dictionary = {}          # entity_id -> {per-class seconds, total}
var dynamic_obstacles: Array[Dictionary] = []
var events: Array[Dictionary] = []
var clock := 0.0
var _last_status: Dictionary = {}

func configure(team_id: int, objectives: Array, supply: Dictionary, chokepoint: Callable = Callable()) -> void:
	team = team_id
	chokepoint_test = chokepoint
	# the map owns its choke points; the coordinator only hands them to the allocator
	if chokepoint_test.is_valid(): allocator.chokepoint_test = chokepoint_test
	context = {"team":team,"objectives":objectives,"supply":supply}

func set_roster(rows: Array) -> void:
	context["roster"] = rows

func step(now: float, delta: float) -> Dictionary:
	clock = now
	allocator.tick(delta)
	var rows: Array = context.get("roster",[])
	dynamic_obstacles.clear()
	var active: Array = []
	for row in rows:
		if not row is Dictionary: continue
		if bool(row.get("destroyed",false)):
			# a wreck changes local navigation: publish it as a dynamic obstacle instead
			dynamic_obstacles.append({"entity_id":str(row.get("entity_id","")),
				"position":row.get("position",Vector3.ZERO),"kind":"wreck"})
			continue
		active.append(row.duplicate(true))
	var assignments := allocator.assign(active,context)
	context["friendly_rows"] = active.duplicate(true)
	for row in active:
		var status := classify(row,active)
		var entity_id := str(row.get("entity_id",""))
		_last_status[entity_id] = status
		_bump(entity_id,status,delta)
	return {"assignments":assignments,"friendly_rows":active.duplicate(true),
		"dynamic_obstacles":dynamic_obstacles.duplicate(true)}

## "Holding, engaging, repairing, immobile" are separate from "traffic jam": only a slow
## vehicle that is actually blocked on the move is counted as congestion.
func classify(row: Dictionary, friendly_rows: Array) -> String:
	if bool(row.get("destroyed",false)): return "immobile"
	if not bool(row.get("mobile",true)) or bool(row.get("immobile_damaged",false)): return "immobile"
	if bool(row.get("repairing",false)): return "repairing"
	if bool(row.get("engaging",false)): return "engaging"
	var speed := float(row.get("speed_mps",0.0))
	if speed < MOVING_SPEED_MPS and bool(row.get("at_objective",false)): return "legitimate_hold"
	for other in friendly_rows:
		if str(other.get("entity_id","")) == str(row.get("entity_id","")): continue
		if allocator.should_give_way(row,other): return "yielding"
	if speed < MOVING_SPEED_MPS and bool(row.get("blocked",false)): return "traffic_blocked"
	return "moving"

func _bump(entity_id: String, status: String, delta: float) -> void:
	var row: Dictionary = attribution.get(entity_id,{"total":0.0})
	row[status] = float(row.get(status,0.0))+delta
	row["total"] = float(row.total)+delta
	attribution[entity_id] = row

func status_for(entity_id: String) -> String:
	return str(_last_status.get(entity_id,"unknown"))

func task_for(entity_id: String) -> Dictionary:
	return allocator.task_for(entity_id)

func decision_reason(entity_id: String, observation: Dictionary = {}) -> Dictionary:
	return allocator.decision_reason(entity_id,observation)

## The whole-match attribution summary the work order asks for.
func summary() -> Dictionary:
	var totals := {}
	for status in ATTRIBUTIONS: totals[status] = 0.0
	var justified := 0.0
	var congestion := 0.0
	for entity_id in attribution:
		var row: Dictionary = attribution[entity_id]
		for status in ATTRIBUTIONS:
			var seconds := float(row.get(status,0.0))
			totals[status] = float(totals[status])+seconds
			if status in ["legitimate_hold","engaging","repairing","immobile","yielding"]: justified += seconds
			elif status == "traffic_blocked": congestion += seconds
	var total := 0.0
	for status in ATTRIBUTIONS: total += float(totals[status])
	return {"team":team,"vehicles":attribution.size(),"totals":totals,"total_seconds":total,
		"justified_seconds":justified,"congestion_seconds":congestion,
		"justified_fraction":(justified/total if total > 0.0 else 0.0),
		"dynamic_obstacles":dynamic_obstacles.duplicate(true),
		"status_by_vehicle":_last_status.duplicate(true),
		"assignments":allocator.assignments.duplicate(true),
		"chokepoints_bound":chokepoint_test.is_valid()}
