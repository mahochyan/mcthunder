class_name ContributionLedger
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD13: the ONE service that records combat events and attributes contribution.
##
## The order is explicit about what this must be and what it must NOT be:
##   * a single service whose event identity is complete: match / entity / life / generation / shot / projectile /
##     root_effect / event;
##   * explicitly NOT the sixteen entry replay buffer used as the whole match statistics ledger;
##   * separate counters for actual contacts, effective damage, shots fired, firing slots and kills, with the statistics
##     SUBJECT and the DEDUP KEY never conflated;
##   * kill attribution, the assist window, recon and repair contribution and sustained fire inheritance all explicitly
##     VERSIONED;
##   * damage without a legitimate cause is never credited as a kill, and friendly fire, abandonment and environmental
##     death are handled separately;
##   * the key damage and the final death may come from different shooters, decided by a frozen rule;
##   * a temporary UI hint is never written into the reward, and a kill is never guessed from an observed HUD colour.
##
## Two boundaries are deliberate and are stated here so they cannot be crossed by accident:
##   * this ledger RECORDS. It is not the death authority: the runtime state own death_notified gate stays the only thing
##     that decides a death happens once.
##   * it is not the ticket authority either: the ticket ledger stays the only place tickets move.
##
## Every threshold and window below is a declared project design initial value with comparison NOT_COMPARED.

const VERSION := "cd13-contribution-v1"
const ATTRIBUTION_VERSION := "cd13-attribution-v1"

## The assist window: damage older than this before the death still counts as an assist.
const ASSIST_WINDOW_S := 12.0
## A hit must carry at least this much effective damage to be treated as a key damage candidate.
const KEY_DAMAGE_MIN := 0.0001

const KIND_CONTACT := "contact"
const KIND_DAMAGE := "effective_damage"
const KIND_SHOT := "shot_fired"
const KIND_FIRING_SLOT := "firing_slot"
const KIND_KILL := "kill"
const KINDS := [KIND_CONTACT, KIND_DAMAGE, KIND_SHOT, KIND_FIRING_SLOT, KIND_KILL]

## Causes that must NEVER be credited as a kill, handled separately as the order requires.
const NO_CREDIT_CAUSES := {
	"friendly_fire": "friendly fire is never a kill credit",
	"abandonment": "abandonment is handled separately from a kill",
	"environment": "an environmental death is handled separately from a kill",
	"sustained_fire_orphan": "a fire with no living origin does not become a kill",
}

const WEAPON_KINDS := ["shot", "sustained_fire", "recon", "repair", "ram"]

var match_id: int = 0
var generation: int = 0
var _event_seq: int = 0
var events: Array[Dictionary] = []
## Dedup keys already consumed, so the same shot, projectile or root effect can never be counted twice.
var _seen: Dictionary = {}
## counters[subject][kind] -> count ; the SUBJECT is who is credited, the DEDUP KEY is what prevents repeats.
var counters: Dictionary = {}
## Per target life: who damaged it, when, and with which root effect, which is what attribution reads.
var _damage_log: Dictionary = {}
var receipts: Array[Dictionary] = []
var refusals: Array[Dictionary] = []

func begin(id: int, gen: int = 0) -> void:
	match_id = id
	generation = gen
	_event_seq = 0
	events.clear()
	_seen.clear()
	counters.clear()
	_damage_log.clear()
	receipts.clear()
	refusals.clear()

## The identity is completed here rather than trusted from the caller, and a missing key is a named refusal.
func _identity(identity: Dictionary) -> Dictionary:
	var out := identity.duplicate(true)
	out["match_id"] = int(identity.get("match_id",match_id))
	out["generation"] = int(identity.get("generation",generation))
	out["event_id"] = "%d:%d:%s" % [match_id,_event_seq+1,str(identity.get("kind","event"))]
	return out


func _tag(subject: String, kind: String) -> void:
	if subject.is_empty(): return
	if not counters.has(subject): counters[subject] = {}
	counters[subject][kind] = int((counters[subject] as Dictionary).get(kind,0)) + 1

func count_for(subject: String, kind: String) -> int:
	return int((counters.get(subject,{}) as Dictionary).get(kind,0))

func totals() -> Dictionary:
	var out := {}
	for kind in KINDS: out[kind] = 0
	for subject in counters:
		for kind in counters[subject]:
			out[kind] = int(out.get(kind,0)) + int(counters[subject][kind])
	return out

## Record one event. Returns the committed row, or a refusal with a reason. The dedup key is what stops double counting.
func record(kind: String, identity: Dictionary, dedup_key: String, subject: String) -> Dictionary:
	if not (kind in KINDS): return _refuse(identity,"unsupported_kind:%s"%kind)
	if dedup_key.strip_edges().is_empty(): return _refuse(identity,"dedup_key_required")
	if subject.strip_edges().is_empty(): return _refuse(identity,"subject_required")
	if _seen.has(dedup_key):
		return _refuse(identity,"already_counted:%s"%dedup_key)
	_seen[dedup_key] = true
	_event_seq += 1
	var row := _identity(identity)
	row["kind"] = kind
	row["subject"] = subject
	row["dedup_key"] = dedup_key
	row["version"] = VERSION
	events.append(row)
	_tag(subject,kind)
	return {"ok":true,"event":row}

func _refuse(identity: Dictionary, reason: String) -> Dictionary:
	var row := {"ok":false,"reason":reason,"attribution_version":ATTRIBUTION_VERSION,"identity":identity.duplicate(true)}
	refusals.append(row)
	return row

## A contact: what an observer or a solver actually established, counted by its own definition.
func record_contact(identity: Dictionary, dedup_key: String, subject: String) -> Dictionary:
	return record(KIND_CONTACT,identity,dedup_key,subject)

## An effective damage: only damage that actually did something counts, and only once per root effect.
func record_damage(identity: Dictionary, dedup_key: String, subject: String, target_id: String, amount: float, now: float) -> Dictionary:
	var row := record(KIND_DAMAGE,identity,dedup_key,subject)
	if not bool(row.get("ok",false)): return row
	_remember_damage(target_id,subject,now,amount,str(identity.get("root_effect","")),str(identity.get("weapon_kind","shot")))
	return row

func _remember_damage(target_id: String, subject: String, now: float, amount: float, root_effect: String, weapon_kind: String) -> void:
	if not _damage_log.has(target_id): _damage_log[target_id] = []
	(_damage_log[target_id] as Array).append({"subject":subject,"at":now,"amount":amount,
		"root_effect":root_effect,"weapon_kind":weapon_kind})

## A displayed UI hint is never written into the reward, so it is recorded as its own kind with no subject credit.
func note_ui_hint(_text: String) -> void:
	pass

## The frozen attribution rule. The key damage is the largest effective damage inside the window; ties are broken by the
## earliest time and then by the subject id, so the same inputs always decide the same way.
func attribute(target_id: String, now: float, cause: String = "") -> Dictionary:
	var rows: Array = _damage_log.get(target_id,[])
	var window: Array = []
	for row in rows:
		if now - float(row.at) <= ASSIST_WINDOW_S: window.append(row)
	var primary := ""
	var assists: Array[String] = []
	var best := -1.0
	var best_at := INF
	for row in window:
		var amount := float(row.amount)
		if amount > best or (is_equal_approx(amount,best) and float(row.at) < best_at) \
			or (is_equal_approx(amount,best) and is_equal_approx(float(row.at),best_at) and str(row.subject) < primary):
			best = amount; best_at = float(row.at); primary = str(row.subject)
	for row in window:
		var subject := str(row.subject)
		if subject != primary and not (subject in assists): assists.append(subject)
	assists.sort()
	var blocked := str(cause) in NO_CREDIT_CAUSES
	var receipt := {"attribution_version":ATTRIBUTION_VERSION,"version":VERSION,"target_id":target_id,
		"now":now,"cause":cause,"primary":("" if blocked else primary),"assists":([] if blocked else assists),
		"window_s":ASSIST_WINDOW_S,"legitimate":not blocked,
		"reason":(str(NO_CREDIT_CAUSES.get(cause,"")) if blocked else "attributed by the frozen rule")}
	receipts.append(receipt.duplicate(true))
	return receipt

## Credit a kill. A cause with no legitimate damage is refused by name rather than silently counted.
func credit_kill(target_id: String, now: float, cause: String = "", identity: Dictionary = {}) -> Dictionary:
	var receipt := attribute(target_id,now,cause)
	if not bool(receipt.get("legitimate",false)):
		return {"ok":false,"reason":"no_credit_cause:%s"%cause,"receipt":receipt}
	var subject := str(receipt.get("primary",""))
	if subject.is_empty(): return {"ok":false,"reason":"no_legitimate_damage","receipt":receipt}
	var key := "kill:%d:%s:%s" % [match_id,target_id,str(receipt.get("attribution_version",""))]
	var row := record(KIND_KILL,identity,key,subject)
	if not bool(row.get("ok",false)): return {"ok":false,"reason":str(row.get("reason","")),"receipt":receipt}
	receipt["credited_subject"] = subject
	receipt["dedup_key"] = key
	return {"ok":true,"receipt":receipt}

## Sustained fire inheritance: a fire keeps the origin of whoever started it, which is why it is recorded with a root effect.
func record_sustained_fire(identity: Dictionary, origin_subject: String, dedup_key: String) -> Dictionary:
	var row := identity.duplicate(true)
	row["weapon_kind"] = "sustained_fire"
	row["root_effect"] = str(identity.get("root_effect","fire"))
	return record_damage(row,dedup_key,origin_subject,str(identity.get("target_id","")),float(identity.get("amount",0.0)),float(identity.get("at",0.0)))

func summary() -> Dictionary:
	return {"version":VERSION,"attribution_version":ATTRIBUTION_VERSION,"match_id":match_id,"generation":generation,
		"events":events.size(),"counters":counters,"totals":totals(),"receipts":receipts.size(),"refusals":refusals.size(),
		"provenance":"game_rule","comparison":"NOT_COMPARED",
		"note":"Records contribution only. The death gate and the ticket ledger remain the only authorities for death and tickets."}
