class_name TrainingDirector
extends RefCounted
const TITLES := ["正面防护","侧后弱点","发动机失能","炮闩失能","空弹药架","断履带与维修","斜甲跳弹"]
const GOALS := ["射击标记处，观察正面厚甲为何不穿。","射击侧面发动机；随后可接管目标检查能力。","射击后部发动机，观察不能驾驶但仍能射击。","射击炮塔标记处，使炮闩失能。","射击空弹架，验证没有弹药殉爆。","击断左履带后，Tab接管目标，驻车按T维修。","射击斜板，观察实际反弹路径。"]
var case_index := 0
var round_id := -1
var shooter_life := -1
var target_life := -1
var status := "idle"
var last_record: Dictionary = {}
var explanation := ""
var accepted_shots := 0
var _seen: Dictionary = {}
var _track_hit := false

func start(index: int, round_number: int, shooter: VehicleActor, target: VehicleActor) -> bool:
	if index < 0 or index >= TITLES.size(): return false
	case_index = index
	round_id = round_number
	shooter_life = shooter.life_id
	target_life = target.life_id
	status = "running"
	last_record.clear()
	explanation = GOALS[index]
	accepted_shots = 0
	_seen.clear()
	_track_hit = false
	return true

func accept_record(record: Dictionary, target: VehicleActor) -> bool:
	if status != "running" or not record.get("identity") is Dictionary: return false
	var identity: Dictionary = record.identity
	if identity.get("round_id",-1) != round_id or identity.get("shooter_id","") != "A" or identity.get("shooter_life_id",-1) != shooter_life: return false
	if _seen.has(record.get("record_id","")): return false
	_seen[record.record_id] = true
	accepted_shots += 1
	last_record = record.duplicate(true)
	explanation = ShotExplanation.describe(record,target)
	var hit_items: Array = []
	for damage in record.damage:
		if damage.target_id == "B" and damage.target_life_id == target_life: hit_items.append(damage.item_id)
	var passed := false
	match case_index:
		0:
			for contact in record.contacts:
				if contact.get("entity_id","") == "B" and contact.get("life_id",-1) == target_life and contact.result == "stopped": passed = true
		1,2: passed = hit_items.has("engine") and not target.capabilities().drive and target.capabilities().fire
		3: passed = hit_items.has("breech") and not target.capabilities().fire
		4: passed = hit_items.has("ammo_rack") and not target.state.destroyed and target.gunner.inventory.racks.get("ammo_rack",-1) == 0
		5: _track_hit = hit_items.has("track_left") and target.state.module_states.track_left.integrity <= 0
		6:
			for contact in record.contacts:
				if contact.result == "ricochet": passed = true
	if passed: status = "passed"
	return true

func step(target: VehicleActor, shooter: VehicleActor, active_projectiles: int, infinite: bool) -> void:
	if status != "running": return
	if case_index == 5 and _track_hit and target.state.module_states.track_left.integrity > 0 and target.capabilities().drive:
		status = "passed"
		explanation += "\n驻车维修已恢复履带，目标重新具备驾驶能力。"
	if target.state.destroyed or shooter.state.destroyed:
		status = "failed"
		explanation += "\n车辆阵亡，当前课目未完成；可重试。"
	elif not infinite and shooter.gunner.rounds_remaining == 0 and active_projectiles == 0 and case_index != 5:
		status = "failed"
		explanation += "\n弹药耗尽，目标条件尚未满足；可重试或返回调整配弹。"

func finish() -> Dictionary:
	return {"case_index":case_index,"title":TITLES[case_index],"status":status,"shots":accepted_shots,"explanation":explanation,"record_id":last_record.get("record_id","")}
