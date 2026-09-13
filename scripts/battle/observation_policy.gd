class_name ObservationPolicy
extends RefCounted
## WT-017: one contract for "who may know what".
##
## Four information classes are kept apart:
##   world_truth      - authority only; never handed to a client UI as-is
##   observer_visible - what one observer can actually see right now
##   shared_intel     - team-reported contacts (coarse, timestamped)
##   last_seen_memory - remembered contacts that are no longer visible
##
## Visual attenuation and physical blocking are SEPARATE fields: a medium that hides a
## vehicle does not thereby stop a shell. A medium must opt in per channel, so "all smoke
## behaves the same for every sensor" is not a default anywhere in this data.
##
## Nothing here reads display quality settings: gameplay occlusion is a rule, not a
## graphics option, which is what "lowering quality must not remove gameplay smoke" means
## in code.

const INFO_CLASSES := ["world_truth","observer_visible","shared_intel","last_seen_memory"]
const MEDIA := ["none","smoke","foliage","building"]
const CHANNELS := ["optical","thermal"]
const VIEWS := ["player","ai","spectator","replay","killcam","minimap"]

## attenuation 0..1 per channel; blocks_projectile is a physical fact, not a visual one.
const MEDIA_RULES := {
	"none":{"optical":0.0,"thermal":0.0,"blocks_projectile":false},
	"smoke":{"optical":1.0,"thermal":0.6,"blocks_projectile":false},
	"foliage":{"optical":0.7,"thermal":0.2,"blocks_projectile":false},
	"building":{"optical":1.0,"thermal":1.0,"blocks_projectile":true},
}

const MEMORY_DEFAULT_S := 6.0
const SHARED_INTEL_S := 12.0
## Coarse is honest: a remembered or reported contact is a position with an error bound,
## never a live module/crew reading.
const PRECISION_M := {"world_truth":0.0,"observer_visible":2.0,"shared_intel":15.0,"last_seen_memory":25.0}
const INTERNAL_FIELDS := ["modules","crew","module_states","crew_states","ammo","inventory","shell","loadout"]

static func attenuation(media: String, channel: String = "optical") -> float:
	if not MEDIA_RULES.has(media) or not CHANNELS.has(channel): return 1.0
	return float(MEDIA_RULES[media].get(channel,1.0))

static func visual_blocked(media: String, channel: String = "optical") -> bool:
	return attenuation(media,channel) >= 0.999

static func blocks_projectile(media: String) -> bool:
	if not MEDIA_RULES.has(media): return true
	return bool(MEDIA_RULES[media].blocks_projectile)

static func precision_for(source: String) -> float:
	return float(PRECISION_M.get(source,999.0))

static func expiry_for(source: String) -> float:
	match source:
		"observer_visible": return MEMORY_DEFAULT_S
		"shared_intel": return SHARED_INTEL_S
		"last_seen_memory": return MEMORY_DEFAULT_S
	return 0.0

static func is_internal_field(key: String) -> bool:
	return key in INTERNAL_FIELDS

## One memory store per view. Entries are plain data; no node references are kept.
var entries: Dictionary = {}          # entity_id -> entry
var live_lives: Dictionary = {}       # entity_id -> current life_id (authority truth, ids only)
var rejected: Array[String] = []

func register_life(entity_id: String, life_id: int) -> int:
	# A new life invalidates every marker of the old one: an enemy that respawns must not
	# inherit the old marker.
	var dropped := 0
	if live_lives.has(entity_id) and int(live_lives[entity_id]) != life_id and entries.has(entity_id):
		entries.erase(entity_id)
		dropped = 1
	live_lives[entity_id] = life_id
	return dropped

func record(observer_id: String, contact: Dictionary, now: float, source: String, media: String = "none", channel: String = "optical") -> Dictionary:
	if not INFO_CLASSES.has(source): return {"ok":false,"reason":"unknown_source"}
	var entity_id := str(contact.get("entity_id",""))
	var life_id := int(contact.get("life_id",-1))
	if entity_id.is_empty() or life_id < 0: return {"ok":false,"reason":"malformed_contact"}
	if source == "world_truth" and observer_id != "authority":
		# world truth is authority-only; a view records what it observed or was told
		rejected.append("%s:world_truth_for_%s"%[entity_id,observer_id])
		return {"ok":false,"reason":"world_truth_is_authority_only"}
	if live_lives.has(entity_id) and int(live_lives[entity_id]) != life_id:
		return {"ok":false,"reason":"stale_life"}
	if source == "observer_visible" and visual_blocked(media,channel):
		return {"ok":false,"reason":"occluded"}
	var previous: Dictionary = entries.get(entity_id,{})
	var entry := {
		"entity_id":entity_id,"life_id":life_id,
		"position":contact.get("position",Vector3.ZERO),
		"source":source,"precision_m":precision_for(source),
		"observed_at":now,"expires_at":now+expiry_for(source),
		"media":media,"channel":channel,
		"last_visible_at":now if source == "observer_visible" else float(previous.get("last_visible_at",-INF)),
	}
	entries[entity_id] = entry
	return {"ok":true,"entry":entry.duplicate(true)}

func query(now: float) -> Array[Dictionary]:
	# Only authorised, unexpired, life-matching entries leave this call.
	var out: Array[Dictionary] = []
	for entity_id in entries.keys():
		var entry: Dictionary = entries[entity_id]
		if live_lives.has(entity_id) and int(live_lives[entity_id]) != int(entry.life_id):
			entries.erase(entity_id)
			continue
		if now > float(entry.expires_at):
			entries.erase(entity_id)
			continue
		out.append(entry.duplicate(true))
	return out

func mark_visible(entity_id: String, now: float) -> bool:
	if not entries.has(entity_id): return false
	entries[entity_id].source = "observer_visible"
	entries[entity_id].precision_m = precision_for("observer_visible")
	entries[entity_id].last_visible_at = now
	entries[entity_id].expires_at = now+expiry_for("observer_visible")
	return true

## Audio gives a direction and a coarse distance band; it never carries internals.
static func audio_cue(event: Dictionary, listener: Vector3) -> Dictionary:
	var point: Vector3 = event.get("position",listener)
	var offset := point-listener
	var distance := offset.length()
	var bearing := rad_to_deg(atan2(offset.x,-offset.z))
	var band := "near" if distance <= 60.0 else ("mid" if distance <= 250.0 else "far")
	var cue := {"kind":str(event.get("kind","unknown")),"bearing_deg":bearing,"distance_band":band,
		"direction_hint":("front" if absf(bearing) <= 45.0 else ("right" if bearing > 45.0 and bearing <= 135.0 else ("left" if bearing < -45.0 and bearing >= -135.0 else "rear")))}
	for key in event.keys():
		if is_internal_field(str(key)): cue.erase(key)
	return cue

## Per-view projection. Replay, spectator and killcam may show the SUBJECT's own internals
## but never another entity's live internals; the minimap gets position plus age only.
static func project(view: String, viewer_id: String, entry: Dictionary, subject_id: String = "") -> Dictionary:
	if not VIEWS.has(view): return {}
	var out := {"entity_id":str(entry.get("entity_id","")),"life_id":int(entry.get("life_id",-1)),
		"position":entry.get("position",Vector3.ZERO),"source":str(entry.get("source","")),
		"precision_m":float(entry.get("precision_m",999.0))}
	match view:
		"minimap":
			out["age_s"] = float(entry.get("age_s",0.0))
		"killcam","replay","spectator":
			var is_subject := viewer_id == subject_id and subject_id != ""
			out["internals_visible"] = is_subject
			if is_subject:
				for key in entry.keys():
					if is_internal_field(str(key)): out[key] = entry[key]
		_:
			pass   # player and ai views carry no internals of other entities at all
	for key in out.keys():
		if is_internal_field(str(key)) and not bool(out.get("internals_visible",false)):
			out.erase(key)
	return out

func summary() -> Dictionary:
	return {"entries":entries.size(),"rejected":rejected.size(),"classes":INFO_CLASSES.duplicate(),
		"media":MEDIA.duplicate(),"channels":CHANNELS.duplicate(),"views":VIEWS.duplicate()}
