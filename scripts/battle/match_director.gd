class_name MatchDirector
extends Node
## Lifecycle authority. Damage is applied by actors; decisions commit after their physics step.
signal round_started
signal match_finished(result: Dictionary)
const COUNTDOWN_SECONDS := 3.0
const TIME_LIMIT_SECONDS := 600.0
const EVENT_LIMIT := 128
var phase := "loading"
var round_id := 0
var elapsed := 0.0
var countdown_left := COUNTDOWN_SECONDS
var participants: Dictionary = {}
var deaths: Dictionary = {}
var events: Array[Dictionary] = []
var totals: Dictionary = {}
var result: Dictionary = {}
var finish_count := 0
var _seen: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 300
	process_mode = Node.PROCESS_MODE_PAUSABLE

func begin(vehicles: Array, id: int) -> bool:
	if phase in ["countdown","playing"] or vehicles.size() != 2: return false
	var ids := {}
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.state.destroyed or vehicle.entity_id not in ["A","B"] or ids.has(vehicle.entity_id): return false
		ids[vehicle.entity_id] = true
	phase = "spawn"
	participants.clear()
	deaths.clear()
	events.clear()
	totals.clear()
	_seen.clear()
	result.clear()
	elapsed = 0
	countdown_left = COUNTDOWN_SECONDS
	round_id = id
	finish_count = 0
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.state.destroyed: phase = "loading"; return false
		participants[vehicle.entity_id] = {"ref":weakref(vehicle),"life_id":vehicle.life_id,"generation":vehicle.state.generation,"team":vehicle.state.team_id,"last_shot":vehicle.gunner.shot_id}
		totals[vehicle.entity_id] = {"shots":0,"contacts":0,"stopped":0,"module_damage":0,"crew_damage":0,"deaths":0}
	phase = "countdown"
	return true

func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or get_tree().paused: return
	if phase == "countdown":
		countdown_left = maxf(0,countdown_left-delta)
		if countdown_left <= 0:
			phase = "playing"
			round_started.emit()
		return
	if phase != "playing": return
	elapsed += delta
	# Poll actual death states as a fallback; duplicate notifications remain idempotent.
	for id in participants:
		var vehicle: VehicleActor = participants[id].ref.get_ref()
		if vehicle != null:
			for shot in range(participants[id].last_shot+1,vehicle.gunner.shot_id+1):
				on_launch({"round_id":round_id,"shooter_id":id,"shooter_life_id":vehicle.life_id,"shot_id":shot})
			participants[id].last_shot = vehicle.gunner.shot_id
		if vehicle != null and vehicle.state.destroyed: on_vehicle_destroyed(vehicle.state.death_record)
	var player_dead := deaths.has("A")
	var enemy_dead := deaths.has("B")
	if player_dead and enemy_dead: finish_once("draw","simultaneous_destruction")
	elif player_dead: finish_once("defeat","player_destroyed")
	elif enemy_dead: finish_once("victory","enemy_destroyed")
	elif elapsed >= TIME_LIMIT_SECONDS: finish_once("draw","time_limit")

func _append(kind: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["kind"] = kind
	row["time"] = elapsed
	events.append(row)
	if events.size() > EVENT_LIMIT: events.pop_front()

func on_vehicle_destroyed(record: Dictionary) -> bool:
	if phase != "playing": return false
	var id := str(record.get("entity_id",""))
	if not participants.has(id) or deaths.has(id): return false
	var identity: Dictionary = participants[id]
	if record.get("life_id",-1) != identity.life_id or record.get("generation",-1) != identity.generation: return false
	var vehicle: VehicleActor = identity.ref.get_ref()
	if vehicle == null or not vehicle.state.destroyed: return false
	deaths[id] = vehicle.state.death_record.duplicate(true)
	totals[id].deaths += 1
	_append("death",{"entity_id":id,"cause":deaths[id].get("cause","unknown")})
	return true

func on_launch(record: Dictionary) -> void:
	if phase != "playing" or int(record.get("round_id",-1)) != round_id: return
	var id := str(record.get("shooter_id",""))
	if not participants.has(id) or record.get("shooter_life_id",-1) != participants[id].life_id: return
	var key := "launch:%s:%s"%[id,record.get("shot_id",-1)]
	if _seen.has(key): return
	_seen[key] = true
	totals[id].shots += 1
	_append("shot",{"entity_id":id,"shot_id":record.get("shot_id",-1)})

func on_finished_projectile(record: Dictionary) -> void:
	if phase != "playing" or int(record.get("round_id",-1)) != round_id: return
	var id := str(record.get("shooter_id",""))
	if not totals.has(id): return
	if record.get("shooter_life_id",-1) != participants[id].life_id: return
	var key := "finish:%s"%record.get("projectile_id",-1)
	if _seen.has(key): return
	_seen[key] = true
	var contacts: Array = record.get("contacts",[])
	if not contacts.is_empty():
		totals[id].contacts += 1
		if record.get("reason","") == "armor_stopped": totals[id].stopped += 1
		_append("contact",{"entity_id":id,"reason":record.get("reason",""),"surface":record.get("surface_id","")})

func on_damage(record: Dictionary) -> void:
	if phase != "playing" or int(record.get("round_id",-1)) != round_id: return
	var shooter := str(record.get("shooter_id",""))
	if not totals.has(shooter): return
	if record.get("shooter_life_id",-1) != participants[shooter].life_id: return
	var key := "damage:"+str(record.get("event_id",""))
	if _seen.has(key): return
	_seen[key] = true
	var is_crew: bool = record.get("kind","") == "crew"
	var before: Dictionary = record.get("before",{})
	var after: Dictionary = record.get("after",{})
	var effective := bool(before.get("alive",false)) and not bool(after.get("alive",false)) if is_crew else float(before.get("integrity",0))>float(after.get("integrity",0))
	if not effective: return
	totals[shooter]["crew_damage" if is_crew else "module_damage"] += 1
	_append("damage",{"entity_id":shooter,"target_id":record.get("target_id",""),"item":record.get("item_id",""),"reason":record.get("reason","")})

func finish_once(outcome: String, reason: String) -> bool:
	if phase not in ["countdown","playing"] or outcome not in ["victory","defeat","draw","abandoned"]: return false
	phase = "finished"
	finish_count += 1
	result = {"title":"1对1歼灭","round_id":round_id,"outcome":outcome,"reason":reason,"seconds":elapsed,"status":"passed" if outcome == "victory" else "failed","shots":int(totals.get("A",{}).get("shots",0)),"totals":totals.duplicate(true),"deaths":deaths.duplicate(true),"events":events.duplicate(true)}
	match_finished.emit(result.duplicate(true))
	return true

func abandon() -> void: finish_once("abandoned","player_returned")
