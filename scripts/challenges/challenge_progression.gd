class_name ChallengeProgression
extends RefCounted
## Binds the actual arena director; accepts no user-authored result argument.
var store: ProfileStore
var _live: Dictionary = {}
var _pending: Dictionary = {}
var _settled: Dictionary = {}
func _init(profile: ProfileStore) -> void: store = profile
func bind(director: ChallengeDirector) -> bool:
	if director == null or director.phase != "countdown" or _live.has(director.attempt_id): return false
	for old in _live.keys():
		if _live[old].get_ref() == null and not _pending.has(old): _live.erase(old)
	if _live.size() >= 16: return false
	_live[director.attempt_id] = weakref(director)
	return true
func settle(attempt_id: int) -> Dictionary:
	if _settled.has(attempt_id):
		var prior: Dictionary = _settled[attempt_id].duplicate(true)
		prior.duplicate = true
		return prior
	if not _live.has(attempt_id): return {"ok":false,"reason":"挑战身份未登记"}
	if not _pending.has(attempt_id):
		var director: ChallengeDirector = _live[attempt_id].get_ref()
		if director == null or director.phase != "finished": return {"ok":false,"reason":"挑战尚未产生有效结果"}
		_pending[attempt_id] = director.result.duplicate(true)
	var result: Dictionary = _pending[attempt_id]
	var next := store.snapshot()
	var key: String = result.best_key
	var prior: Dictionary = next.challenge_bests.get(key,{})
	var improved: bool = result.status == "passed" and (prior.is_empty() or int(result.score) > int(prior.score))
	if improved:
		next.challenge_bests[key] = ChallengeScore.best_row(result)
		var saved := store.commit(next)
		if not saved.ok: return saved
	_live.erase(attempt_id); _pending.erase(attempt_id)
	var receipt := {"ok":true,"improved":improved,"reason":("新个人最佳已保存\n" if improved else "本次未刷新最佳\n")+ChallengeScore.describe_best(store.snapshot().challenge_bests.get(key,{}))}
	_settled[attempt_id] = receipt.duplicate(true)
	while _settled.size() > 64: _settled.erase(_settled.keys()[0])
	return receipt
