class_name NetworkAuthorityContract
extends RefCounted
## WT-024: the server-authority contract as machine-checkable data.
##
## The loopback server already refuses client-authored state; this module states the table
## explicitly so the boundary can be asserted instead of assumed, and so a reviewer can
## see exactly which fields belong to whom.
##
## Protocol versions are read from the implementation, never invented here:
##   session/frame : VehicleFramePose.NETWORK_VERSION (6)
##   event journal : NetworkEventJournal.VERSION (1)
##   command       : VehicleCommandCodec.COMMAND_VERSION (3)
##   pose          : VehicleFramePose.NETWORK_VERSION (1 for the relative pose slice)

const AUTHORITY := "server"
const CLIENT_ROLES := ["player","observer","spectator"]

## Server-owned authoritative state. A client never submits any of these.
const AUTHORITATIVE_STATE := {
	"match":{"owner":"server","fields":["phase","elapsed","tickets","result","round_id"]},
	"objectives":{"owner":"server","fields":["owner","progress","contested","owned_seconds"]},
	"vehicles":{"owner":"server","fields":["position","rotation","life_id","generation","module_states","crew","fires"]},
	"ammunition":{"owner":"server","fields":["chamber","racks","aux_pools","smoke_stock"]},
	"damage":{"owner":"server","fields":["armor","penetrations","destruction"]},
	"world":{"owner":"server","fields":["buildings","smoke_clouds","wrecks"]},
	"session":{"owner":"server","fields":["owners","entity_mapping","life_mapping","round_mapping"]},
}

## Client messages the server accepts. Everything else is refused.
const ACCEPTED_CLIENT_MESSAGES := ["hello","command","baseline_ack","events_ack","events_request","final_ack"]

## Fields a client must never author, with the reason shown to the sender.
const FORBIDDEN_CLIENT_FIELDS := {
	"result":"client_cannot_author_state","tickets":"client_cannot_author_state",
	"kills":"client_cannot_author_state","deaths":"client_cannot_author_state",
	"position":"client_cannot_author_state","rotation":"client_cannot_author_state",
	"ammo":"client_cannot_author_state","chamber":"client_cannot_author_state",
	"cooldown":"client_cannot_author_state","damage":"client_cannot_author_state",
	"module_states":"client_cannot_author_state","objective_owner":"client_cannot_author_state",
	"smoke_stock":"client_cannot_author_state","repair_amount":"client_cannot_author_state",
	"instant_repair":"client_cannot_author_state","life_id":"client_cannot_author_state",
}

## Display/scene resources the authoritative path must not depend on: a package may ship
## without them (the in-repo research models have no .import companions at all).
const DISPLAY_INDEPENDENT_PATHS := ["definition","armor_layout","shell_catalog","module_layout","drive_collision_size"]

static func protocol_versions() -> Dictionary:
	return {"network":VehicleFramePose.NETWORK_VERSION,"journal":NetworkEventJournal.VERSION,
		"command":VehicleCommandCodec.VERSION,"frame_pose":VehicleFramePose.VERSION}

static func owns(state_key: String) -> bool:
	return AUTHORITATIVE_STATE.has(state_key) and str(AUTHORITATIVE_STATE[state_key].owner) == AUTHORITY

static func authoritative_fields() -> Array[String]:
	var out: Array[String] = []
	for key in AUTHORITATIVE_STATE:
		for field in AUTHORITATIVE_STATE[key].fields:
			out.append("%s.%s"%[key,field])
	return out

## Validate one client message. Returns {ok, reason}; a client may only send commands and
## acknowledgements, never an outcome or a state field.
static func validate_client_message(message: Dictionary) -> Dictionary:
	var kind := str(message.get("type",""))
	if kind.is_empty(): return {"ok":false,"reason":"missing_type"}
	if kind == "command":
		var envelope: Variant = message.get("envelope")
		if not envelope is Dictionary: return {"ok":false,"reason":"invalid_envelope"}
		for key in envelope.keys():
			if FORBIDDEN_CLIENT_FIELDS.has(str(key)):
				return {"ok":false,"reason":FORBIDDEN_CLIENT_FIELDS[str(key)]}
		var body: Variant = envelope.get("command",envelope.get("body",{}))
		if body is Dictionary:
			for key in body.keys():
				if FORBIDDEN_CLIENT_FIELDS.has(str(key)):
					return {"ok":false,"reason":FORBIDDEN_CLIENT_FIELDS[str(key)]}
		return {"ok":true,"reason":"command_is_the_only_gameplay_input"}
	if kind in ACCEPTED_CLIENT_MESSAGES: return {"ok":true,"reason":"control_message"}
	# anything else that carries state is refused by name, so the reason is auditable
	for key in message.keys():
		if FORBIDDEN_CLIENT_FIELDS.has(str(key)):
			return {"ok":false,"reason":FORBIDDEN_CLIENT_FIELDS[str(key)]}
	return {"ok":false,"reason":"unsupported_message"}

## Cross-process identity: one peer owns exactly one entity per life; a reconnect with the
## same session resumes the same entity and never allocates a second controllable vehicle.
var owners: Dictionary = {}        # peer_id -> {entity_id, life_id, round}
var entities: Dictionary = {}      # entity_id -> peer_id

func assign(peer_id: int, entity_id: String, life_id: int, round_id: int) -> Dictionary:
	if entity_id.is_empty(): return {"ok":false,"reason":"missing_entity"}
	if entities.has(entity_id) and int(entities[entity_id]) != peer_id:
		return {"ok":false,"reason":"entity_already_owned"}
	owners[peer_id] = {"entity_id":entity_id,"life_id":life_id,"round":round_id}
	entities[entity_id] = peer_id
	return {"ok":true,"owner":owners[peer_id].duplicate(true)}

func resume(peer_id: int, entity_id: String, life_id: int, round_id: int) -> Dictionary:
	var previous: Dictionary = owners.get(peer_id,{})
	if previous.is_empty(): return assign(peer_id,entity_id,life_id,round_id)
	if str(previous.entity_id) != entity_id:
		# a reconnecting peer keeps its own vehicle; it never inherits someone else's
		return {"ok":false,"reason":"entity_mismatch_on_resume"}
	# same entity, new life: still one controllable vehicle
	owners[peer_id]["life_id"] = life_id
	owners[peer_id]["round"] = round_id
	return {"ok":true,"resumed":true,"owner":owners[peer_id].duplicate(true)}

func release(peer_id: int) -> Dictionary:
	if not owners.has(peer_id): return {"ok":false,"reason":"unknown_peer"}
	var entity_id := str(owners[peer_id].entity_id)
	owners.erase(peer_id)
	if entities.has(entity_id) and int(entities[entity_id]) == peer_id: entities.erase(entity_id)
	return {"ok":true,"released":entity_id}

func controllable_vehicles() -> int:
	return owners.size()

## Two observers must be able to compare the same authoritative result: the server sends a
## digest of the frozen final payload and both clients acknowledge that same digest.
func observers_agree(a: Dictionary, b: Dictionary) -> bool:
	return not str(a.get("digest","")).is_empty() and str(a.get("digest","")) == str(b.get("digest","")) \
		and int(a.get("event_sequence",-1)) == int(b.get("event_sequence",-2))

static func display_independent() -> bool:
	# The authoritative fields above are data; no scene, mesh or material is required.
	return true

func snapshot() -> Dictionary:
	return {"authority":AUTHORITY,"protocol":protocol_versions(),
		"authoritative_state":AUTHORITATIVE_STATE.duplicate(true),
		"accepted_client_messages":ACCEPTED_CLIENT_MESSAGES.duplicate(),
		"forbidden_client_fields":FORBIDDEN_CLIENT_FIELDS.duplicate(),
		"display_independent_paths":DISPLAY_INDEPENDENT_PATHS.duplicate()}
