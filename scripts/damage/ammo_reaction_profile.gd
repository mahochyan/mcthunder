class_name AmmoReactionProfile
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD10: what a hit on stored ammunition actually does, chosen by material and by compartment state.
##
## The order is explicit about the shape of the wrong answer: every rack at zero must NOT be turned into a guaranteed vehicle
## detonation, and an inert penetrator hit must NOT be read as "therefore this round has no propellant risk". So this profile
## separates the two things a round is made of - the body and the propellant - and answers with one of four outcomes rather
## than a single explode flag.
##
## The deterministic compartment rule that already exists (`AmmoCompartmentProfile`, version wt015-rear-bustle-v1) is KEPT and
## is reachable from here as the legacy strategy; nothing about it is replaced or deleted.
##
## Every number is a PROJECT DESIGN INITIAL VALUE with comparison NOT_COMPARED. Nothing here is a claim about real
## ammunition behaviour, and the order forbids presenting an unverified figure as external truth.

const VERSION := "cd10-ammo-reaction-v1"
const LEGACY_VERSION := "wt015-rear-bustle-v1"

const NOT_EXPLODED := "not_exploded"
const BURNING := "burning"
const PARTIAL_LOSS := "partial_loss"
const LETHAL := "lethal"
const OUTCOMES := [NOT_EXPLODED, BURNING, PARTIAL_LOSS, LETHAL]

## Storage classes, by what the store actually holds. A sabot round is stored as a body and as a propellant charge, and the
## two are NOT the same material: an inert penetrator still sits on top of a propellant charge.
const STORE_BODY := "body"
const STORE_PROPELLANT := "propellant"
const STORE_MIXED := "mixed"

## Which storage class each module carries, by the module id prefix and the protection policy. A rack without a declared
## protection policy is treated as mixed, which is the conservative reading rather than an optimistic one.
static func store_kind_for(module_id: String, protection: Dictionary) -> String:
	if not protection.is_empty(): return STORE_MIXED
	if module_id.contains("propellant") or module_id.contains("charge"): return STORE_PROPELLANT
	if module_id.contains("body") or module_id.contains("projectile") or module_id.contains("shot"): return STORE_BODY
	return STORE_MIXED

## The damage channel reaching the store changes the answer, because fire and fragments are not the same event as a jet.
static func channel_weight(channel: String) -> float:
	match channel:
		"chemical": return 1.0
		"he_blast": return 0.9
		"kinetic": return 0.7
		"fragment": return 0.45
		_: return 0.5

## The compartment state: an intact barrier with its vent present isolates the store, a perforated barrier does not.
static func compartment_state(module_state: Dictionary) -> String:
	var protection: Dictionary = module_state.get("ammo_protection",{})
	if protection.is_empty(): return "unprotected"
	var barrier := str(protection.get("barrier_module_id",""))
	var vent := str(protection.get("vent_module_id",""))
	var barrier_ok := barrier != "" and float((module_state.get("barrier_integrity",1.0) as float)) > 0.0
	var vent_ok := vent != "" and float((module_state.get("vent_integrity",1.0) as float)) > 0.0
	if barrier_ok and vent_ok: return "isolated"
	if barrier_ok and not vent_ok: return "barrier_only"
	if not barrier_ok and vent_ok: return "vent_only"
	return "unprotected"

## A declared chance that one stored round reacts, per storage class and channel, before the compartment is considered.
const REACTION_CHANCE := {
	"body": {"kinetic":0.05, "chemical":0.10, "he_blast":0.18, "fragment":0.06, "default":0.08},
	"propellant": {"kinetic":0.30, "chemical":0.45, "he_blast":0.50, "fragment":0.22, "default":0.30},
	"mixed": {"kinetic":0.18, "chemical":0.30, "he_blast":0.34, "fragment":0.14, "default":0.20},
}

## How much of the store is lost when it reacts, as a fraction of what is actually there.
const LOSS_FRACTION := {"body":0.10, "propellant":0.60, "mixed":0.35}

## The isolation credit an intact, vented compartment earns: it does not stop the fire, it redirects it, so the loss falls
## but a crew risk remains possible rather than certain.
const ISOLATION_CREDIT := {"isolated":0.25, "barrier_only":0.55, "vent_only":0.70, "unprotected":1.0}

static func reaction_chance(store: String, channel: String) -> float:
	var table: Dictionary = REACTION_CHANCE.get(store,REACTION_CHANCE["mixed"])
	return float(table.get(channel,table.get("default",0.2)))

## The judgement. Deterministic in the seed, so the same event always yields the same outcome and nothing re-rolls.
static func plan(module_id: String, module_state: Dictionary, channel: String, stock: int, seed: int) -> Dictionary:
	var store := store_kind_for(module_id,module_state.get("ammo_protection",{}))
	var state := compartment_state(module_state)
	var chance := clampf(reaction_chance(store,channel) * float(ISOLATION_CREDIT.get(state,1.0)),0.0,1.0)
	var roll := float(abs(seed) % 1000) / 1000.0
	var outcome := NOT_EXPLODED
	var loss := 0
	if stock > 0 and roll < chance:
		# It reacted. What that means depends on the material: a propellant store can be lethal in an unisolated compartment,
		# while a body store loses rounds and burns rather than killing the crew outright.
		var severity := chance * (1.0 if store == STORE_PROPELLANT else 0.5)
		if store == STORE_PROPELLANT and state == "unprotected" and severity >= 0.30:
			outcome = LETHAL
			loss = stock
		elif store == STORE_PROPELLANT and severity >= 0.18:
			outcome = PARTIAL_LOSS
			loss = int(ceil(float(stock) * float(LOSS_FRACTION[store])))
		elif severity >= 0.10:
			outcome = BURNING
			loss = int(ceil(float(stock) * float(LOSS_FRACTION[store]) * 0.5))
		else:
			outcome = PARTIAL_LOSS
			loss = int(ceil(float(stock) * float(LOSS_FRACTION[store]) * 0.25))
	return {"version":VERSION, "store":store, "channel":channel, "compartment":state, "stock":stock,
		"chance":chance, "roll":roll, "outcome":outcome, "loss":clampi(loss,0,stock),
		"legacy_version":LEGACY_VERSION, "legacy_kept":true, "provenance":"game_rule", "comparison":"NOT_COMPARED",
		"reason":"declared project design reaction for this storage class, channel and compartment state"}

## The legacy deterministic path stays reachable and unchanged: it answers with the compartment rule alone.
static func legacy_isolation_holds(module_state: Dictionary) -> bool:
	return compartment_state(module_state) == "isolated"

static func validate(outcome: String) -> Array:
	if outcome.is_empty(): return ["ammo reaction: missing outcome"]
	if outcome not in OUTCOMES: return ["ammo reaction: unsupported outcome"]
	return []
