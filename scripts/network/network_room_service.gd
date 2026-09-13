class_name NetworkRoomService
extends RefCounted
## WT-037: rooms, teams, load gating and continuous running, with the external services
## kept as explicitly unauthorised stand-ins.
##
## Encoded rules:
##  * a round starts only after every seat confirmed loading, so nobody can drive before
##    the map is ready (controls_allowed is false until then).
##  * settling a round issues receipts once and then clears every round-local structure, so
##    old-round events cannot reach the next round (a late event names a stale round).
##  * a dedicated server keeps the room when a client leaves; only a departed host triggers
##    host migration, and only among remaining clients.
##  * capacity, protocol version and content hash are checked on join with distinct
##    feedback, and a reconnect resumes the same seat instead of adding another one.
##  * region/mode/tier matchmaking is a small design-value grouping; with few users it
##    falls back to a single room instead of pretending to be a global service.

const STATES := ["created","waiting","ready_check","loading","playing","settled","closed"]
const MODES := ["normal","dedicated"]
const JOIN_REFUSALS := ["room_full","version_mismatch","content_mismatch","authorization_expired",
	"already_seated","room_closed","unknown_room"]

## Small-scale design values, not copied from any commercial matchmaker.
const MATCHMAKING := {"max_tier_spread":1,"region_strict":true,"min_players_per_team":2,"max_players_per_team":4}

var room_id := ""
var round_id := 0
var state := "closed"
var mode := "normal"
var protocol_version := 0
var content_hash := ""
var region := ""
var rules_id := ""
var seats: Dictionary = {}        # peer_id -> {team, ready, loaded, tier, reconnected, joined_round}
var host_peer := -1
var events: Array[Dictionary] = []
var round_events: Array[Dictionary] = []
var receipts_issued := 0
var refusals: Array[Dictionary] = []
var test_scope := "unregistered"

func create_room(id: String, host: int, config: Dictionary) -> Dictionary:
	if id.is_empty(): return _refuse("unknown_room")
	room_id = id
	host_peer = host
	mode = str(config.get("mode","normal"))
	if not MODES.has(mode): return _refuse("unknown_mode")
	protocol_version = int(config.get("protocol_version",0))
	content_hash = str(config.get("content_hash",""))
	region = str(config.get("region","local"))
	rules_id = str(config.get("rules_id",MatchRulePreset.ID))
	round_id = 1
	state = "waiting"
	seats.clear()
	round_events.clear()
	_record("room_created",{"mode":mode,"rules":rules_id})
	return {"ok":true,"room_id":room_id,"state":state,"capacity":capacity()}

func capacity() -> int:
	return int(MATCHMAKING.max_players_per_team)*2

func seat_count() -> int:
	return seats.size()

func team_count(team: int) -> int:
	var total := 0
	for peer in seats:
		if int(seats[peer].team) == team: total += 1
	return total

func join(peer: int, hello: Dictionary) -> Dictionary:
	if state in ["closed","settled"]: return _refuse("room_closed")
	if seats.has(peer):
		# a reconnect resumes the same seat; it never adds a second one
		seats[peer].reconnected = true
		seats[peer].joined_round = round_id
		_record("seat_resumed",{"peer":peer,"team":int(seats[peer].team)})
		return {"ok":true,"resumed":true,"seat":seats[peer].duplicate(true)}
	if int(hello.get("version",-1)) != protocol_version: return _refuse("version_mismatch")
	if str(hello.get("content_hash","")) != content_hash: return _refuse("content_mismatch")
	if bool(hello.get("authorization_expired",false)): return _refuse("authorization_expired")
	if seat_count() >= capacity(): return _refuse("room_full")
	# deterministic balancing: alternate teams, respecting the per-team cap
	var team := 1 if team_count(1) <= team_count(2) else 2
	if team_count(team) >= int(MATCHMAKING.max_players_per_team): team = 3-team
	var tier := int(hello.get("tier",0))
	var seated := {"team":team,"ready":false,"loaded":false,"tier":tier,"reconnected":false,"joined_round":round_id}
	seats[peer] = seated
	_record("seat_joined",{"peer":peer,"team":team,"tier":tier})
	state = "ready_check"
	return {"ok":true,"seat":seated.duplicate(true),"teams":{"1":team_count(1),"2":team_count(2)}}

func leave(peer: int) -> Dictionary:
	if not seats.has(peer): return _refuse("unknown_peer")
	var was_host: bool = peer == host_peer
	seats.erase(peer)
	_record("seat_left",{"peer":peer})
	if was_host:
		if mode == "dedicated":
			# the dedicated server owns the room; nobody needs to inherit it
			_record("host_retained",{"reason":"dedicated_server"})
			return {"ok":true,"room_open":true,"host_changed":false}
		var remaining: Array = seats.keys()
		remaining.sort()
		if remaining.is_empty():
			state = "closed"
			return {"ok":true,"room_open":false,"host_changed":false}
		host_peer = int(remaining[0])
		_record("host_migrated",{"host":host_peer})
		return {"ok":true,"room_open":true,"host_changed":true,"host":host_peer}
	return {"ok":true,"room_open":true,"host_changed":false}

func mark_loaded(peer: int) -> Dictionary:
	if not seats.has(peer): return _refuse("unknown_peer")
	if not ["waiting","ready_check","loading"].has(state): return _refuse("round_not_loading")
	seats[peer].loaded = true
	seats[peer].ready = true
	state = "loading"
	if all_loaded():
		state = "playing"
		_record("round_started",{"round":round_id})
		return {"ok":true,"state":state,"started":true}
	return {"ok":true,"state":state,"started":false}

func all_loaded() -> bool:
	if seats.is_empty(): return false
	for peer in seats:
		if not bool(seats[peer].loaded): return false
	return true

## Nobody may control a vehicle before the round actually started for every seat.
func controls_allowed(peer: int) -> bool:
	if not seats.has(peer): return false
	return state == "playing" and bool(seats[peer].loaded)

func settle(result: Dictionary, receipt: NetworkResultReceipt, digest: String) -> Dictionary:
	if state != "playing": return _refuse("round_not_playing")
	state = "settled"
	var authority := {"phase":"finished","digest":digest}
	var issued := receipt.issue("%s:r%d" % [room_id,round_id],room_id,digest,result,authority,
		NetworkResultReceipt.TRUST_SERVER if mode == "dedicated" else NetworkResultReceipt.TRUST_HOST)
	if issued.ok: receipts_issued += 1
	_record("round_settled",{"round":round_id,"outcome":str(result.get("outcome",""))})
	return {"ok":issued.ok,"receipt":issued.get("receipt",{}),"state":state}

## Continuous running: a new round clears every round-local structure, so nothing from the
## old round can leak forward.
func begin_next_round() -> Dictionary:
	if state != "settled": return _refuse("round_not_settled")
	var previous := round_id
	round_id += 1
	round_events.clear()
	for peer in seats:
		seats[peer].loaded = false
		seats[peer].ready = false
		seats[peer].joined_round = round_id
	state = "ready_check"
	_record("round_opened",{"round":round_id,"previous":previous})
	return {"ok":true,"round":round_id,"previous":previous,"round_events":round_events.size()}

## An event that names a round other than the current one is refused, not applied.
func accept_round_event(event: Dictionary) -> Dictionary:
	var round := int(event.get("round",-1))
	if round != round_id:
		return {"ok":false,"reason":"stale_round"}
	round_events.append(event.duplicate(true))
	return {"ok":true,"events":round_events.size()}

## Minimal matchmaking: group by mode, content hash, region and tier spread. With few
## users the grouping simply yields one room rather than a global service.
func matchmake(candidates: Array) -> Dictionary:
	var groups: Dictionary = {}
	for row in candidates:
		if not row is Dictionary: continue
		var key := "%s|%s|%s" % [str(row.get("mode","normal")),str(row.get("content_hash","")),str(row.get("region","local"))]
		if not groups.has(key): groups[key] = []
		groups[key].append(row)
	var rooms: Array = []
	var unmatched: Array = []
	for key in groups:
		var pool: Array = groups[key]
		pool.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("tier",0)) < int(b.get("tier",0)))
		var room: Array = []
		for row in pool:
			if room.is_empty(): room.append(row); continue
			if absi(int(row.get("tier",0))-int(room[0].get("tier",0))) > int(MATCHMAKING.max_tier_spread):
				unmatched.append(row); continue
			if room.size() >= capacity(): unmatched.append(row); continue
			room.append(row)
		if room.size() >= int(MATCHMAKING.min_players_per_team)*2: rooms.append({"key":key,"players":room})
		else: unmatched.append_array(room)
	return {"rooms":rooms,"unmatched":unmatched,"groups":groups.size(),
		"fallback":"single_room" if rooms.size() <= 1 else "grouped"}

## External services are proposals with stand-ins until explicitly authorised.
static func external_service_proposal() -> Array[Dictionary]:
	return [
		{"service":"discovery","stand_in":"local room list file / in-process registry","requires_authorization":true,"cost":"hosting + egress"},
		{"service":"relay","stand_in":"loopback-only direct UDP (current transport)","requires_authorization":true,"cost":"bandwidth"},
		{"service":"dedicated_hosting","stand_in":"START_LOCAL_SERVER.bat on the operator's machine","requires_authorization":true,"cost":"compute"},
		{"service":"accounts","stand_in":"peer/session ids only (no account system)","requires_authorization":true,"cost":"identity provider"},
	]

## LAN loopback and public internet evidence are registered separately; an unrun scope is
## reported as such instead of being blurred together.
func register_test_scope(scope: String) -> Dictionary:
	if not ["loopback","lan","public"].has(scope): return _refuse("unknown_scope")
	test_scope = scope
	_record("test_scope",{"scope":scope})
	return {"ok":true,"scope":scope,"public_tested":scope == "public"}

## What the minimal room UI must show; the actual window is a separate suite.
func ui_contract() -> Dictionary:
	return {"must_show":["room id","seat list with team","ready/loaded state","protocol and content match",
			"host badge","room full / version mismatch / authorization feedback"],
		"must_block":["drive controls until every seat is loaded"],
		"window_suite":"NOT_RUN"}

func _record(kind: String, payload: Dictionary) -> void:
	events.append({"kind":kind,"round":round_id,"payload":payload})

func _refuse(reason: String) -> Dictionary:
	refusals.append({"reason":reason,"at_round":round_id})
	return {"ok":false,"reason":reason}

func snapshot() -> Dictionary:
	return {"room_id":room_id,"state":state,"mode":mode,"round":round_id,"host":host_peer,
		"capacity":capacity(),"seats":seats.duplicate(true),"teams":{"1":team_count(1),"2":team_count(2)},
		"round_events":round_events.size(),"events":events.size(),"refusals":refusals.size(),
		"receipts_issued":receipts_issued,"test_scope":test_scope,
		"rules_id":rules_id,"protocol_version":protocol_version,"content_hash":content_hash}
