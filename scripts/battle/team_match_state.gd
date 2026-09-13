class_name TeamMatchState
extends CapturePointState
const START_TICKETS := 300
const DEATH_COST := 30
const TIME_LIMIT := 600.0
const RESPAWN_DELAY := 8.0
const PROTECTION_SECONDS := 3.0
const CAPTURE_RADIUS := 12.0
const CAPTURE_SECONDS := 12.0
const EVENT_SCHEMA_VERSION := 1
const EVENT_HISTORY_LIMIT := 128
static var next_match_id := 100
## WT-022-R1: the rules this match runs under, frozen as one versioned preset. The
## constants above remain the implementation values; the preset is the auditable copy and
## the rule suite guards the two against drift.
var rules := MatchRulePreset.standard()
func rule_fingerprint() -> String: return rules.fingerprint()
var match_id := 0
var phase := "loading"
var elapsed := 0.0
var countdown := 3.0
var tickets := {1:START_TICKETS,2:START_TICKETS}
var drain_bank := {1:0.0,2:0.0}
var objectives: BattleObjectives
var team_size := 4
var roster: Dictionary = {}
var pending_deaths: Dictionary = {}
var seen_deaths: Dictionary = {}
var events: Array[Dictionary] = []
var event_sequence := 0
var result: Dictionary = {}
var finish_count := 0

func initialize(capacity: int = 4) -> bool:
	if capacity < 1 or capacity > 16: return false
	team_size = capacity
	elapsed=0; countdown=3; tickets={1:START_TICKETS,2:START_TICKETS}; drain_bank={1:0.0,2:0.0}
	capture_progress=0; capture_owner=0; contested=false; objectives=null
	roster.clear(); pending_deaths.clear(); seen_deaths.clear(); events.clear(); event_sequence=0
	result.clear(); finish_count=0
	next_match_id += 1
	match_id = next_match_id
	phase = "countdown"
	for team in [1,2]:
		for index in team_size:
			var id := ("A" if team == 1 else "B")+(str(index+1) if index>0 else "")
			roster[id] = {"team":team,"actor":null,"life_id":-1,"generation":-1,"respawn_at":-1.0,"protection_left":0.0,"player":id == "A","deaths":0,"spawns":0,"waiting_reason":"","request_sent":false,"respawn_requested":false}
	return true

func record(kind: String, data: Dictionary) -> void:
	var event := data.duplicate(true)
	event_sequence += 1
	# Metadata belongs to the committing match, never to caller-supplied payload.
	event["schema_version"] = EVENT_SCHEMA_VERSION
	event["match_id"] = match_id
	event["sequence"] = event_sequence
	event["physics_tick"] = Engine.get_physics_frames()
	event["kind"] = kind
	event["time"] = elapsed
	events.append(event)
	if events.size() > EVENT_HISTORY_LIMIT: events.pop_front()

func actor_for(id: String) -> VehicleActor:
	if not roster.has(id) or roster[id].actor == null: return null
	return roster[id].actor.get_ref() as VehicleActor

func is_protected(id: String, life_id: int) -> bool:
	return roster.has(id) and roster[id].life_id == life_id and roster[id].protection_left > 0

func register_spawn(id: String, vehicle: VehicleActor) -> bool:
	if not roster.has(id) or not is_instance_valid(vehicle) or phase not in ["countdown","playing"]: return false
	var row: Dictionary = roster[id]
	row.actor = weakref(vehicle)
	row.life_id = vehicle.life_id
	row.generation = vehicle.state.generation
	row.respawn_at = -1.0
	row.protection_left = PROTECTION_SECONDS
	row.waiting_reason = ""
	row.request_sent = false
	row.respawn_requested = false
	row.spawns += 1
	record("spawn",{"entity_id":id,"life_id":vehicle.life_id})
	return true

func queue_death(record: Dictionary) -> bool:
	if phase != "playing": return false
	var id := str(record.get("entity_id",""))
	if not roster.has(id): return false
	var row: Dictionary = roster[id]
	if record.get("life_id",-1) != row.life_id or record.get("generation",-1) != row.generation: return false
	var key := "%s:%s:%s"%[id,row.life_id,row.generation]
	if seen_deaths.has(key) or pending_deaths.has(key): return false
	pending_deaths[key] = record.duplicate(true)
	return true
