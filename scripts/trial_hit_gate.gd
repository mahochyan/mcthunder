class_name TrialHitGate
extends RefCounted
## 003-R2：任务收分唯一来源（对齐 GPT 参考实现 trial_hit_gate）。
## 轮次 round_id、命中数 hits、去重集合全部在这里维护——Main 与 HUD 只读，
## 不再另外保留一份可修改的轮次与分数。
## 只负责任务归属/轮次/生命周期/去重校验；不负责射线检测，
## 也不能证明任意构造的字典确实来自真实射击——集成测试必须走生产射击路径。
## 事件字典在开火时冻结（round_id/shooter/shooter_life_id/shot_id），
## 不在任务收到命中时补填。

var round_id := 0
var hits := 0
var required_hits := 3
var _shooter_id := ""
var _shooter_life_id := 0
var _target_id := ""
var _target_life_id := 0
var _seen: Dictionary = {}

func begin_round(shooter_id: String, shooter_life_id: int, target_id: String, target_life_id: int, goal: int = 3) -> bool:
	# 开始/整场重开任务：轮次推进、锁定双方身份、清空进度与去重集合。
	# 不用于每次命中，也不要在普通单车重置中无条件调用。
	if shooter_id.is_empty() or target_id.is_empty():
		return false
	if shooter_id == target_id or shooter_life_id <= 0 or target_life_id <= 0 or goal <= 0:
		return false
	round_id += 1
	_shooter_id = shooter_id
	_shooter_life_id = shooter_life_id
	_target_id = target_id
	_target_life_id = target_life_id
	required_hits = goal
	hits = 0
	_seen.clear()   # 旧事件由开火时冻结的轮次/生命周期 ID 拒绝
	return true

func accept_hit(event: Dictionary) -> Dictionary:
	# 校验任务归属/轮次/生命周期/去重；返回 {accepted, reason, hits, complete}
	for key in ["round_id", "shooter_life_id", "target_life_id", "shot_id"]:
		if not event.has(key) or typeof(event[key]) != TYPE_INT or int(event[key]) <= 0:
			return _reject("invalid_event")
	for key in ["shooter_id", "target_id"]:
		if not event.has(key) or typeof(event[key]) != TYPE_STRING or String(event[key]).is_empty():
			return _reject("invalid_event")
	if int(event["round_id"]) != round_id:
		return _reject("stale_round")
	if String(event["shooter_id"]) != _shooter_id or int(event["shooter_life_id"]) != _shooter_life_id:
		return _reject("wrong_shooter_or_lifetime")
	if String(event["target_id"]) != _target_id or int(event["target_life_id"]) != _target_life_id:
		return _reject("wrong_target_or_lifetime")
	var key := "%d|%s|%d|%d" % [round_id, _shooter_id, _shooter_life_id, int(event["shot_id"])]
	if _seen.has(key):
		return _reject("duplicate")
	if hits >= required_hits:
		return _reject("already_complete")
	_seen[key] = true
	hits += 1
	return {"accepted": true, "reason": "accepted", "hits": hits, "complete": hits == required_hits}

func _reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "hits": hits, "complete": hits >= required_hits}