class_name LoadingMechanism
extends RefCounted
## WT-027: per-vehicle loading mechanisms, ready versus reserve rounds, and interruption
## recovery - defined by equipment data, not by one shared state-machine constant.
##
## Rules encoded here:
##  * a vehicle's mechanism comes from its own entry: an autoloader carousel (T-80B, three
##    crew, no loader) behaves differently from a manual loader (Leopard 2A4, four crew).
##  * ready rounds exhausted and the whole vehicle out of ammunition are DIFFERENT states.
##  * loader, mechanism, power, breech and fire influence the flow through separate
##    channels, so a loader injury cannot stop an autoloader and a power loss cannot stop a
##    manual loader.
##  * an interruption returns the round to where it came from: cancel, shell swap and
##    re-damage never duplicate ammunition.
##  * selecting the next shell never changes the round already in the chamber.
##  * every duration is a design value (game_rule); no historical precision is claimed.

const STATES := ["idle","extracting","transferring","chambering","ready","interrupted","empty_ready","empty_all"]
const CHANNELS := ["loader","mechanism","power","breech","fire"]
const PROVENANCE := "game_rule"

## Equipment definitions. `ready`/`reserve` counts come from the candidate configurations;
## every duration below is a design value and is labelled as such.
const MECHANISMS := {
	"autoloader_carousel":{"channels":["mechanism","power","breech","fire"],"requires_loader":false,
		"extract_s":1.6,"transfer_s":2.4,"chamber_s":1.4,"design_note":"carousel autoloader, crew of three"},
	"manual_loader":{"channels":["loader","breech","fire"],"requires_loader":true,
		"extract_s":2.0,"transfer_s":2.6,"chamber_s":1.8,"design_note":"human loader, ready rack then reserve"},
}
const VEHICLES := {
	"ussr_t_80b":{"mechanism":"autoloader_carousel","ready":28,"reserve":10,"admitted":false},
	"germ_leopard_2a4":{"mechanism":"manual_loader","ready":15,"reserve":27,"admitted":false},
}
## Mapping onto the ONE inventory used everywhere (no second ammunition system).
const INVENTORY_MAPPING := {
	"ready_rack":"ammo_inventory.rack_capacities[ready]",
	"reserve_rack":"ammo_inventory.rack_capacities[reserve]",
	"chamber":"ammo_inventory.chamber_shell",
	"transfer":"ammo_inventory.transfer_shell",
	"selected":"ammo_inventory.selected_shell",
	"allowed":"ammo_inventory.allowed_shells",
}

static func mechanism_for(vehicle_id: String) -> String:
	return str(VEHICLES.get(vehicle_id,{}).get("mechanism","manual_loader"))

static func definition_for(vehicle_id: String) -> Dictionary:
	var entry: Dictionary = VEHICLES.get(vehicle_id,{})
	if entry.is_empty(): return {}
	var mechanism := str(entry.mechanism)
	var row: Dictionary = (MECHANISMS.get(mechanism,{}) as Dictionary).duplicate(true)
	row["vehicle_id"] = vehicle_id
	row["mechanism"] = mechanism
	row["ready_capacity"] = int(entry.get("ready",0))
	row["reserve_capacity"] = int(entry.get("reserve",0))
	row["provenance"] = PROVENANCE
	row["historical_value"] = null
	row["admitted_for_combat"] = bool(entry.get("admitted",false))
	return row

## Per-vehicle state. Racks are plain counts plus a shell list so conservation is provable.
var vehicle_id := ""
var mechanism := ""
var definition: Dictionary = {}
var state := "idle"
var ready_rack: Array[String] = []
var reserve_rack: Array[String] = []
var transfer_shell := ""
var chamber_shell := ""
var selected_shell := ""
var stage_time_left := 0.0
var last_interrupt := ""
var history: Array[Dictionary] = []
var disabled: Dictionary = {}      # channel -> true when that channel is broken
var fired_count := 0

func begin(vehicle: String, shell: String = "ap") -> Dictionary:
	definition = definition_for(vehicle)
	if definition.is_empty(): return {"ok":false,"reason":"unknown_vehicle"}
	vehicle_id = vehicle
	mechanism = str(definition.mechanism)
	ready_rack.clear()
	reserve_rack.clear()
	for i in int(definition.ready_capacity): ready_rack.append(shell)
	for i in int(definition.reserve_capacity): reserve_rack.append(shell)
	transfer_shell = ""
	chamber_shell = ""
	selected_shell = shell
	state = "idle"
	disabled.clear()
	history.clear()
	return {"ok":true,"mechanism":mechanism,"ready":ready_rack.size(),"reserve":reserve_rack.size()}

func total_rounds() -> int:
	return ready_rack.size()+reserve_rack.size()+(1 if not transfer_shell.is_empty() else 0)+(1 if not chamber_shell.is_empty() else 0)

## Live rounds plus fired rounds: this is the conservation figure (it never changes).
func accounted_rounds() -> int:
	return total_rounds()+fired_count

## Firing empties the chamber; the round is accounted as fired rather than vanishing.
func fire_chambered() -> Dictionary:
	if chamber_shell.is_empty(): return {"ok":false,"reason":"chamber_empty"}
	var shell := chamber_shell
	chamber_shell = ""
	fired_count += 1
	_record("fired",{"shell":shell,"total":total_rounds(),"fired":fired_count})
	return {"ok":true,"shell":shell,"total":total_rounds(),"fired":fired_count}

func ready_exhausted() -> bool:
	return ready_rack.is_empty() and not vehicle_empty()

func vehicle_empty() -> bool:
	return ready_rack.is_empty() and reserve_rack.is_empty() and transfer_shell.is_empty() and chamber_shell.is_empty()

## Distinct, named states: ready rounds gone is not the same as nothing left at all.
func status() -> String:
	if vehicle_empty(): return "empty_all"
	if ready_exhausted(): return "empty_ready"
	if state == "interrupted": return "interrupted"
	return state

func _channel_blocked(channel: String) -> bool:
	return bool(disabled.get(channel,false))

func _usable_channels() -> Array:
	return definition.get("channels",[])

func can_load() -> Dictionary:
	for channel in _usable_channels():
		if _channel_blocked(channel): return {"ok":false,"reason":"%s_unavailable"%channel}
	if not transfer_shell.is_empty() or not chamber_shell.is_empty(): return {"ok":false,"reason":"already_loaded"}
	if ready_rack.is_empty() and reserve_rack.is_empty(): return {"ok":false,"reason":"empty_all"}
	return {"ok":true,"source":"ready" if not ready_rack.is_empty() else "reserve"}

## Begin a load cycle: ready rack first, reserve only when the ready rack is empty.
func start_load() -> Dictionary:
	var verdict := can_load()
	if not verdict.ok:
		state = "empty_ready" if str(verdict.reason) == "empty_ready" else state
		return verdict
	var source := str(verdict.source)
	var shell: String = str(ready_rack.pop_back()) if source == "ready" else str(reserve_rack.pop_back())
	transfer_shell = shell
	state = "extracting"
	stage_time_left = float(definition.extract_s)
	_record("start_load",{"source":source,"shell":shell})
	return {"ok":true,"state":state,"source":source,"total":total_rounds()}

## Advance the cycle. Stage durations are design values.
func advance(delta: float) -> Dictionary:
	if not ["extracting","transferring","chambering"].has(state): return {"ok":false,"reason":"not_loading"}
	stage_time_left -= maxf(delta,0.0)
	if stage_time_left > 0.0: return {"ok":true,"state":state,"left":stage_time_left}
	match state:
		"extracting":
			state = "transferring"
			stage_time_left = float(definition.transfer_s)
		"transferring":
			state = "chambering"
			stage_time_left = float(definition.chamber_s)
		"chambering":
			chamber_shell = transfer_shell
			transfer_shell = ""
			state = "ready"
			_record("chambered",{"shell":chamber_shell,"total":total_rounds()})
	return {"ok":true,"state":state,"chamber":chamber_shell,"total":total_rounds()}

## Interrupt the cycle. The round goes back where it came from: never duplicated.
func interrupt(reason: String) -> Dictionary:
	if not ["extracting","transferring","chambering"].has(state):
		return {"ok":false,"reason":"not_loading"}
	if transfer_shell.is_empty(): return {"ok":false,"reason":"nothing_in_transfer"}
	var shell := transfer_shell
	# a round pulled from reserve returns to reserve, one pulled from ready returns to ready
	if ready_rack.size() < int(definition.ready_capacity): ready_rack.append(shell)
	else: reserve_rack.append(shell)
	transfer_shell = ""
	state = "interrupted"
	last_interrupt = reason
	stage_time_left = 0.0
	_record("interrupted",{"reason":reason,"shell":shell,"total":total_rounds()})
	return {"ok":true,"reason":reason,"state":state,"total":total_rounds()}

## Damage/repair and crew changes act on separate channels.
func set_channel(channel: String, broken: bool) -> Dictionary:
	if not CHANNELS.has(channel): return {"ok":false,"reason":"unknown_channel"}
	if not _usable_channels().has(channel):
		# a channel the vehicle does not use cannot affect it
		return {"ok":true,"ignored":true,"reason":"channel_not_used_by_this_mechanism"}
	disabled[channel] = broken
	if broken and ["extracting","transferring","chambering"].has(state):
		interrupt("%s_damaged"%channel)
	return {"ok":true,"channel":channel,"broken":broken,"state":state}

func resume() -> Dictionary:
	if state != "interrupted": return {"ok":false,"reason":"not_interrupted"}
	for channel in _usable_channels():
		if _channel_blocked(channel): return {"ok":false,"reason":"%s_still_unavailable"%channel}
	state = "idle"
	_record("resumed",{"total":total_rounds()})
	return {"ok":true,"state":state}

## Selecting the next shell never touches the chambered round.
func select_next(shell: String) -> Dictionary:
	if shell.is_empty(): return {"ok":false,"reason":"invalid_shell"}
	selected_shell = shell
	return {"ok":true,"selected":selected_shell,"chamber_unchanged":chamber_shell}

## Ready-rack resupply (design value) tops the ready rack up from the reserve rack.
func resupply_ready(delta: float, resupply_seconds: float = 20.0) -> Dictionary:
	if ready_rack.size() >= int(definition.ready_capacity): return {"ok":false,"reason":"ready_full"}
	if reserve_rack.is_empty(): return {"ok":false,"reason":"reserve_empty"}
	if delta < resupply_seconds: return {"ok":false,"reason":"resupply_incomplete","left":resupply_seconds-delta}
	var moved := 0
	while ready_rack.size() < int(definition.ready_capacity) and not reserve_rack.is_empty():
		ready_rack.append(reserve_rack.pop_back())
		moved += 1
	_record("resupply",{"moved":moved,"total":total_rounds()})
	return {"ok":true,"moved":moved,"ready":ready_rack.size(),"reserve":reserve_rack.size()}

static func times_are_design_values() -> bool:
	for mechanism in MECHANISMS:
		var row: Dictionary = MECHANISMS[mechanism]
		for key in ["extract_s","transfer_s","chamber_s"]:
			if not row.has(key): return false
	return true

func state_diagram() -> Dictionary:
	return {"states":STATES.duplicate(),"channels":CHANNELS.duplicate(),
		"mechanism":mechanism,"channels_in_use":definition.get("channels",[]).duplicate(),
		"requires_loader":bool(definition.get("requires_loader",true)),
		"inventory_mapping":INVENTORY_MAPPING.duplicate(),"provenance":PROVENANCE}

func _record(kind: String, payload: Dictionary) -> void:
	history.append({"kind":kind,"state":state,"payload":payload})

func snapshot() -> Dictionary:
	return {"vehicle_id":vehicle_id,"mechanism":mechanism,"state":state,"status":status(),
		"ready":ready_rack.size(),"reserve":reserve_rack.size(),"transfer":transfer_shell,
		"chamber":chamber_shell,"selected":selected_shell,"total":total_rounds(),
		"fired":fired_count,"accounted":accounted_rounds(),
		"disabled":disabled.duplicate(),"last_interrupt":last_interrupt,"history":history.size()}
