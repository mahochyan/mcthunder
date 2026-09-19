class_name SortieService
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD14: the PERSONAL sortie point book and the sortie transaction, as one service.
##
## Two of the order requirements live here, and both are deliberately separate from everything else:
##
##   * the personal book is the SECOND of the four independent books. The rejection conditions forbid the team ticket pool
##     being read as personal sortie points, so this book is fed by COMMITTED EVENTS with their own dedup keys and never by
##     the team pool, and its balance can never go negative.
##   * the sortie transaction is exactly the four steps the order names - validate, reserve, confirm, commit - with the
##     reservation RELEASED when the spawn is blocked, fails or is cancelled, a repeat request for the same token
##     IDEMPOTENT, and the balance never negative.
##
## It is NOT the ticket authority and NOT the death authority; those stay exactly where they were.

const VERSION := "cd14-sortie-v1"

const STEP_VALIDATE := "validate"
const STEP_RESERVE := "reserve"
const STEP_CONFIRM := "confirm"
const STEP_COMMIT := "commit"

const SPEND_SORTIE := "sortie_cost"
const EARN_CAPTURE := "capture"
const EARN_KILL := "kill"
const EARN_ASSIST := "assist"
const EARN_SPOT := "spot"

const INCOME := {"capture":80,"kill":120,"assist":40,"spot":20}

var initial_sp := 450
var balance := 0
var lifetime_earned := 0
var lifetime_spent := 0
var entries: Array[Dictionary] = []
var _seen_income: Dictionary = {}
var _seen_spend: Dictionary = {}
## token -> {subject, vehicle_id, cost, state}
var reservations: Dictionary = {}
var receipts: Array[Dictionary] = []
var refusals: Array[Dictionary] = []

func begin(sp: int = 450) -> void:
	initial_sp = sp
	balance = sp
	lifetime_earned = 0
	lifetime_spent = 0
	entries.clear()
	_seen_income.clear()
	_seen_spend.clear()
	reservations.clear()
	receipts.clear()
	refusals.clear()

func _refuse(reason: String, extra: Dictionary = {}) -> Dictionary:
	var row := {"ok":false,"reason":reason,"version":VERSION}
	for k in extra: row[k] = extra[k]
	refusals.append(row.duplicate(true))
	return row

## Income follows a COMMITTED EVENT, so the dedup key is the event, not the subject, and a replayed event adds nothing.
func earn(subject: String, kind: String, event_key: String) -> Dictionary:
	if subject.strip_edges().is_empty(): return _refuse("subject_required")
	if not INCOME.has(kind): return _refuse("unsupported_income_kind:%s"%kind)
	if event_key.strip_edges().is_empty(): return _refuse("event_key_required")
	if _seen_income.has(event_key): return _refuse("already_earned:%s"%event_key)
	var amount := int(INCOME[kind])
	_seen_income[event_key] = true
	balance += amount
	lifetime_earned += amount
	entries.append({"kind":"earn","subject":subject,"income":kind,"event_key":event_key,"amount":amount,
		"balance":balance,"version":VERSION})
	return {"ok":true,"amount":amount,"balance":balance}

## Step one of the four: a request is validated before anything is reserved or charged.
func request(subject: String, vehicle_id: String, cost: int, token: String, spawn_blocked: bool = false) -> Dictionary:
	if subject.strip_edges().is_empty(): return _refuse("subject_required")
	if vehicle_id.strip_edges().is_empty(): return _refuse("vehicle_required")
	if token.strip_edges().is_empty(): return _refuse("token_required")
	if cost < 0: return _refuse("cost_must_not_be_negative")
	if reservations.has(token):
		var held: Dictionary = reservations[token]
		if str(held.get("state","")) == STEP_COMMIT:
			return {"ok":true,"token":token,"state":STEP_COMMIT,"idempotent":true,"charged":0,
				"balance":balance,"note":"the same token already committed; nothing is charged twice"}
		return {"ok":true,"token":token,"state":str(held.get("state","")),"idempotent":true,"charged":0,"balance":balance}
	if _seen_spend.has(token):
		return {"ok":true,"token":token,"state":STEP_COMMIT,"idempotent":true,"charged":0,"balance":balance}
	# VALIDATE: the balance itself must cover the cost.
	if balance < cost: return _refuse("insufficient_sp",{"needed":cost,"balance":balance,"token":token})
	# RESERVE: hold the cost without moving the balance yet, so a failure releases it.
	reservations[token] = {"subject":subject,"vehicle_id":vehicle_id,"cost":cost,"state":STEP_RESERVE}
	if spawn_blocked:
		return release(token,"spawn_blocked")
	return {"ok":true,"token":token,"state":STEP_RESERVE,"reserved":cost,"balance":balance}

## Step three: the spawn actually happened, so the reservation becomes a charge that can no longer go negative.
func confirm(token: String) -> Dictionary:
	if not reservations.has(token): return _refuse("no_such_reservation:%s"%token)
	var held: Dictionary = reservations[token]
	var cost := int(held.get("cost",0))
	if balance < cost:
		release(token,"insufficient_sp_at_confirm")
		return _refuse("insufficient_sp_at_confirm",{"token":token})
	balance -= cost
	lifetime_spent += cost
	_seen_spend[token] = true
	held["state"] = STEP_CONFIRM
	reservations[token] = held
	return {"ok":true,"token":token,"state":STEP_CONFIRM,"charged":cost,"balance":balance}

## Step four: the charge is committed and a receipt is issued exactly once.
func commit(token: String) -> Dictionary:
	if not reservations.has(token): return _refuse("no_such_reservation:%s"%token)
	var held: Dictionary = reservations[token]
	if str(held.get("state","")) != STEP_CONFIRM:
		return _refuse("not_confirmed:%s"%str(held.get("state","")),{"token":token})
	held["state"] = STEP_COMMIT
	reservations[token] = held
	var receipt := {"token":token,"subject":str(held.get("subject","")),"vehicle_id":str(held.get("vehicle_id","")),
		"cost":int(held.get("cost",0)),"balance":balance,"version":VERSION}
	receipts.append(receipt.duplicate(true))
	entries.append({"kind":"spend","subject":receipt.subject,"token":token,"amount":receipt.cost,"balance":balance,
		"version":VERSION})
	return {"ok":true,"token":token,"state":STEP_COMMIT,"receipt":receipt,"balance":balance}

## Release a reservation on failure, cancellation or a blocked spawn. The balance was never moved, so nothing is refunded.
func release(token: String, why: String = "cancelled") -> Dictionary:
	if not reservations.has(token): return _refuse("no_such_reservation:%s"%token)
	var held: Dictionary = reservations[token]
	reservations.erase(token)
	return {"ok":true,"token":token,"released":true,"reason":why,"charged":0,"balance":balance,
		"note":"the reservation is released and nothing was ever charged, so the balance cannot be refunded twice"}

func state_of(token: String) -> String:
	return str((reservations.get(token,{}) as Dictionary).get("state",""))

func balance_is_never_negative() -> bool:
	if balance < 0: return false
	for entry in entries:
		if int(entry.get("balance",0)) < 0: return false
	return true

func summary() -> Dictionary:
	return {"version":VERSION,"initial_sp":initial_sp,"balance":balance,"lifetime_earned":lifetime_earned,
		"lifetime_spent":lifetime_spent,"entries":entries.size(),"reservations":reservations.size(),
		"receipts":receipts.size(),"refusals":refusals.size(),"never_negative":balance_is_never_negative(),
		"books_note":"this is the PERSONAL sortie book; the team pool lives in the ticket ledger and the two never share a balance",
		"provenance":"game_rule","comparison":"NOT_COMPARED"}
