class_name NetworkResultReceipt
extends RefCounted
## WT-026: idempotent receipts for online results, with the trusted online domain kept
## apart from the offline research save.
##
## A receipt exists only if the authority issued it for a FINISHED match and the digest
## matches the frozen result. Claiming is idempotent. Editing the offline save can never
## mint a receipt, so local edits cannot change trusted results, and a network failure
## never deletes the offline save.

const TRUST_SERVER := "authority_server"
const TRUST_HOST := "host_self_hosted"
const REWARDS := {"victory":60,"defeat":30,"draw":40,"abandoned":0}

var receipts: Dictionary = {}      # token -> {session_id, digest, outcome, points, trust}
var claims: Dictionary = {}        # token -> true
var online_points := 0
var offline_points := 0
var events: Array[Dictionary] = []

func issue(token: String, session_id: String, digest: String, result: Dictionary, authority: Dictionary, trust: String = TRUST_SERVER) -> Dictionary:
	if token.is_empty() or session_id.is_empty() or digest.is_empty():
		return _refuse("invalid_receipt_identity","issue",token)
	if str(authority.get("phase","")) != "finished":
		# only a finished match can produce a receivable result
		return _refuse("match_not_finished","issue",token)
	if str(authority.get("digest","")) != digest:
		return _refuse("digest_mismatch","issue",token)
	var outcome := str(result.get("outcome",""))
	if not REWARDS.has(outcome): return _refuse("unknown_outcome","issue",token)
	if trust != TRUST_SERVER and trust != TRUST_HOST: return _refuse("unknown_trust_level","issue",token)
	if receipts.has(token):
		# re-issuing the identical receipt is harmless; a different one is refused
		if str(receipts[token].digest) == digest and str(receipts[token].outcome) == outcome:
			return {"ok":true,"duplicate":true,"receipt":receipts[token].duplicate(true)}
		return _refuse("receipt_conflict","issue",token)
	receipts[token] = {"token":token,"session_id":session_id,"digest":digest,"outcome":outcome,
		"points":int(REWARDS[outcome]),"trust":trust}
	events.append({"kind":"issued","token":token,"trust":trust,"points":int(REWARDS[outcome])})
	return {"ok":true,"receipt":receipts[token].duplicate(true)}

## Idempotent: a second claim of the same receipt earns nothing.
func claim(token: String, digest: String) -> Dictionary:
	if not receipts.has(token): return _refuse("no_receipt","claim",token)
	if claims.has(token):
		events.append({"kind":"claim_duplicate","token":token,"points":0})
		return {"ok":true,"duplicate":true,"points":0,"online_points":online_points}
	if digest != str(receipts[token].digest): return _refuse("digest_mismatch","claim",token)
	claims[token] = true
	var points := int(receipts[token].points)
	online_points += points
	events.append({"kind":"claimed","token":token,"points":points})
	return {"ok":true,"points":points,"online_points":online_points,"trust":str(receipts[token].trust)}

## The offline research save is a separate domain: it can be edited freely and still
## cannot produce a trusted receipt.
func edit_offline_save(points: int) -> Dictionary:
	offline_points = maxi(0,points)
	events.append({"kind":"offline_edit","points":offline_points})
	return {"ok":true,"offline_points":offline_points}

func trusted_result_tokens() -> Array[String]:
	var out: Array[String] = []
	for token in receipts.keys():
		if str(receipts[token].trust) == TRUST_SERVER: out.append(token)
	return out

func domains() -> Dictionary:
	return {"trusted_online":{"receipts":receipts.size(),"claimed":claims.size(),"points":online_points,
			"source":"authority-issued receipts of finished matches"},
		"offline_research":{"points":offline_points,"source":"local save, never trusted as an online result",
			"can_mint_receipt":false}}

func _refuse(reason: String, kind: String, token: String) -> Dictionary:
	events.append({"kind":"refused","reason":reason,"operation":kind,"token":token,"points":0})
	return {"ok":false,"reason":reason}

func snapshot() -> Dictionary:
	return {"receipts":receipts.duplicate(true),"domains":domains(),"events":events.duplicate(true)}
