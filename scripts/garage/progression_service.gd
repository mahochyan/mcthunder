class_name ProgressionService
extends RefCounted
const REWARDS := {"victory":60,"defeat":30,"draw":40,"abandoned":0}
var store: ProfileStore
var _live: Dictionary = {}
var _completed: Dictionary = {}

func _init(profile: ProfileStore) -> void: store = profile

func register_match(config: MatchConfig) -> Dictionary:
	if config.mode() != "normal": return {"ok":true,"token":""}
	var next := store.snapshot()
	var checked := MatchConfig.build(config.snapshot(),store.service,next.unlocked)
	if not checked.ok: return checked
	var token: String = next.profile_id+":"+str(next.next_match)
	next.next_match += 1
	# Interrupted previous sessions never receive an invented result or a reward.
	for old in next.pending.keys():
		if not _live.has(old): next.pending.erase(old)
	if next.pending.size() >= 16: return {"ok":false,"reason":"待结算比赛过多"}
	next.pending[token] = {"mode":"normal","vehicle_id":config.selected()}
	var saved := store.commit(next)
	if not saved.ok: return saved
	_live[token] = null
	return {"ok":true,"token":token}

func bind_director(token: String, director: TeamMatchDirector) -> bool:
	if token.is_empty(): return true
	if not _live.has(token) or _live[token] != null or director == null: return false
	_live[token] = weakref(director)
	return true

func apply_result_once(token: String, result: Dictionary) -> Dictionary:
	if token.is_empty(): return {"ok":true,"points":0,"reason":"训练 / 自由对战：不计研发收益"}
	var next := store.snapshot()
	if next.receipts.has(token): return {"ok":true,"points":0,"duplicate":true,"reason":"本局收益已结算"}
	if not next.pending.has(token) or not _live.has(token) or _live[token] == null: return {"ok":false,"reason":"未登记的比赛结果"}
	if _completed.has(token):
		if _completed[token] != result: return {"ok":false,"reason":"结算内容不匹配"}
	else:
		var director: TeamMatchDirector = _live[token].get_ref()
		if director == null or director.state.phase != "finished" or director.state.result != result: return {"ok":false,"reason":"比赛尚未产生有效结算"}
		_completed[token] = result.duplicate(true)
	if result.get("outcome") not in REWARDS: return {"ok":false,"reason":"未知结果"}
	var points: int = REWARDS[result.outcome]
	next.pending.erase(token)
	next.receipts[token] = {"outcome":result.outcome,"points":points}
	while next.receipts.size() > 128: next.receipts.erase(next.receipts.keys()[0])
	next.research_points += points
	var saved := store.commit(next)
	if not saved.ok: return saved
	_live.erase(token)
	_completed.erase(token)
	return {"ok":true,"points":points,"reason":"研发点 +%d · 现有%d"%[points,next.research_points]}
