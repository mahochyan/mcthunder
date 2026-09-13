class_name NetworkIdentityPolicy
extends RefCounted
## WT-026: threat and permission model as data, plus bounded command validation.
##
## Rules encoded here:
##  * a peer may only act for the entity its session owns; another player's entity_id is
##    refused before any simulation code sees the command.
##  * command fields are type- and range-checked; NaN/Inf/out-of-range never reaches the
##    simulation.
##  * sequences must advance and stale input ticks are refused (no replay of old input).
##  * message frequency is bounded per tick and per second.
##  * only logical resource identifiers are accepted; arbitrary paths, script paths and
##    object construction requests are refused.
##  * sensitive session fields are stripped before anything is logged.
##  * reconnect tokens, authorisation expiry and error feedback are separate outcomes.

const ALLOWED_MESSAGES := ["hello","command","baseline_ack","events_ack","events_request","final_ack"]
const PERMISSIONS := {
	"player":["command","baseline_ack","events_ack","events_request","final_ack"],
	"observer":["baseline_ack","events_ack","events_request","final_ack"],
	"spectator":["baseline_ack","events_ack","events_request"],
}
const MAX_MESSAGES_PER_TICK := 4
const MAX_COMMANDS_PER_SECOND := 20
const MAX_INPUT_AGE_TICKS := 12
const MAX_SEQUENCE_GAP := 64
const RESOURCE_PREFIXES := ["shell:","vehicle:","map:","objective:","smoke:"]
const SENSITIVE_FIELDS := ["token","reconnect_token","secret","key","password","session_secret","authorization"]

## Value ranges for the bounded command fields; flags are validated as booleans.
const FIELD_RANGES := {
	"throttle":[-1.0,1.0],"steer":[-1.0,1.0],
	"turret_yaw":[-6.2832,6.2832],"gun_pitch":[-0.35,0.35],
}
const VECTOR_LIMIT := 5000.0
const FLAG_FIELDS := ["has_aim_point","clear_aim","aim_held","hold_aim","fire_requested","repair_requested",
	"extinguish_requested","replace_crew_requested","cancel_recovery_requested","range_requested",
	"apply_range_requested","cycle_shell_requested"]

var sessions: Dictionary = {}      # peer_id -> {session_id, entity_id, life_id, role, token}
var refusals: Array[Dictionary] = []
var command_times: Array[float] = []

func bind(peer_id: int, session_id: String, entity_id: String, life_id: int, role: String = "player", token: String = "") -> Dictionary:
	if session_id.is_empty() or entity_id.is_empty(): return {"ok":false,"reason":"invalid_identity"}
	if not PERMISSIONS.has(role): return {"ok":false,"reason":"unknown_role"}
	sessions[peer_id] = {"session_id":session_id,"entity_id":entity_id,"life_id":life_id,"role":role,"token":token}
	return {"ok":true,"identity":sessions[peer_id].duplicate(true)}

func rebind_token(peer_id: int, token: String) -> Dictionary:
	if not sessions.has(peer_id): return {"ok":false,"reason":"unknown_peer"}
	if token.is_empty(): return {"ok":false,"reason":"invalid_reconnect_token"}
	sessions[peer_id].token = token
	return {"ok":true,"reason":"reconnect_token_accepted"}

func expire_authorization(peer_id: int, reason: String = "authorization_expired") -> Dictionary:
	if not sessions.has(peer_id): return {"ok":false,"reason":"unknown_peer"}
	sessions.erase(peer_id)
	return {"ok":true,"reason":reason,"feedback":"authorization"}

func authorizes(peer_id: int, action: String, entity_id: String = "") -> Dictionary:
	if not sessions.has(peer_id): return _refuse("handshake_required")
	var identity: Dictionary = sessions[peer_id]
	var allowed: Array = PERMISSIONS.get(str(identity.role),[])
	if not allowed.has(action): return _refuse("action_not_permitted_for_role")
	if action == "command" and not entity_id.is_empty() and entity_id != str(identity.entity_id):
		# another player's vehicle: refused before the simulation sees anything
		return _refuse("not_owner")
	return {"ok":true,"identity":identity.duplicate(true)}

func allow_message(peer_id: int, kind: String, per_tick_count: int, now_seconds: float = -1.0) -> Dictionary:
	if not ALLOWED_MESSAGES.has(kind): return _refuse("unsupported_message")
	if per_tick_count > MAX_MESSAGES_PER_TICK: return _refuse("rate_limited_per_tick")
	var verdict := authorizes(peer_id,kind)
	if not verdict.ok: return verdict
	if kind == "command" and now_seconds >= 0.0:
		command_times = command_times.filter(func(t: float) -> bool: return now_seconds-t <= 1.0)
		if command_times.size() >= MAX_COMMANDS_PER_SECOND: return _refuse("rate_limited_per_second")
		command_times.append(now_seconds)
	return {"ok":true}

func validate_command(peer_id: int, envelope: Dictionary, now_tick: int) -> Dictionary:
	if not envelope.has("entity_id") or not envelope.has("sequence"): return _refuse("malformed_envelope")
	var verdict := authorizes(peer_id,"command",str(envelope.entity_id))
	if not verdict.ok: return verdict
	var sequence: Variant = envelope.get("sequence")
	if not (sequence is int) or int(sequence) < 0: return _refuse("invalid_sequence")
	var previous: int = int(sessions[peer_id].get("last_sequence",-1))
	if int(sequence) <= previous: return _refuse("stale_sequence")
	if previous >= 0 and int(sequence)-previous > MAX_SEQUENCE_GAP: return _refuse("sequence_gap_too_large")
	var input_tick: Variant = envelope.get("input_tick")
	if not (input_tick is int): return _refuse("invalid_input_tick")
	var age := now_tick-int(input_tick)
	if age < 0 or age > MAX_INPUT_AGE_TICKS: return _refuse("stale_input_tick")
	var body: Variant = envelope.get("command",{})
	if not body is Dictionary: return _refuse("invalid_command_body")
	for key in body.keys():
		var name := str(key)
		var value: Variant = body[key]
		if name in FLAG_FIELDS:
			if not (value is bool): return _refuse("invalid_flag_type")
			continue
		if FIELD_RANGES.has(name):
			if not (value is int or value is float): return _refuse("invalid_field_type")
			var number := float(value)
			if not is_finite(number): return _refuse("non_finite_field")
			var range: Array = FIELD_RANGES[name]
			if number < float(range[0]) or number > float(range[1]): return _refuse("field_out_of_range")
			continue
		if name == "aim_world_point":
			if not value is Vector3: return _refuse("invalid_field_type")
			if not is_finite(value.x) or not is_finite(value.y) or not is_finite(value.z): return _refuse("non_finite_field")
			if absf(value.x) > VECTOR_LIMIT or absf(value.y) > VECTOR_LIMIT or absf(value.z) > VECTOR_LIMIT: return _refuse("field_out_of_range")
	sessions[peer_id].last_sequence = int(sequence)
	return {"ok":true}

func resource_id_allowed(id: String) -> bool:
	for prefix in RESOURCE_PREFIXES:
		if id.begins_with(prefix): return true
	return false

## Anything a client might try to name directly is refused by construction.
func validate_resource_request(id: String) -> Dictionary:
	if resource_id_allowed(id): return {"ok":true}
	return _refuse("resource_id_not_allowed")

func log_safe(payload: Dictionary) -> Dictionary:
	var out := {}
	for key in payload.keys():
		if str(key).to_lower() in SENSITIVE_FIELDS: continue
		out[key] = payload[key]
	return out

static func trust_label(host_self_hosted: bool) -> String:
	return "host_self_hosted" if host_self_hosted else "authority_server"

func _refuse(reason: String) -> Dictionary:
	refusals.append({"reason":reason,"count":refusals.size()})
	return {"ok":false,"reason":reason}

func snapshot() -> Dictionary:
	return {"allowed_messages":ALLOWED_MESSAGES.duplicate(),"permissions":PERMISSIONS.duplicate(true),
		"max_messages_per_tick":MAX_MESSAGES_PER_TICK,"max_commands_per_second":MAX_COMMANDS_PER_SECOND,
		"max_input_age_ticks":MAX_INPUT_AGE_TICKS,"resource_prefixes":RESOURCE_PREFIXES.duplicate(),
		"sensitive_fields":SENSITIVE_FIELDS.duplicate(),"sessions":sessions.size(),"refusals":refusals.size()}
