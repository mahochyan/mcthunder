class_name ExternalContactSelector
extends RefCounted
## 005-R1：统一"有效外部接触"选择规则——开火、实际指向标记、调试面板共用同一判定。
## 车辆命中只认"首个有效装甲外表面接触"；模块/乘员是内部候选，不参与本轮计分
## （不替代外部接触判定；显式车外部件留待后续工作单单独引入接触类型）。
## 查询不完整/失败 → conservative unresolved（不产生车辆命中，也不假装畅通）。
## 世界遮挡取最近 LAYER_WORLD 接触（world_stop）；与装甲同距时墙优先（TIE_EPS 容差）。

const TIE_EPS := 1e-5
const STATUS_VEHICLE := "vehicle"
const STATUS_WORLD := "world"
const STATUS_MISS := "miss"
const STATUS_UNRESOLVED := "unresolved"


static func select_contact(result: Dictionary) -> Dictionary:
	# result: ShotQueryService.query 的返回
	# 返回 {status, event ({}), contact ({}), reason}
	#   status=vehicle → event = 首个有效装甲 surface 事件
	#   status=world   → contact = world_stop（墙/靶板等世界遮挡）
	#   status=miss    → 合法且完整、无任何装甲外表面接触、也无世界遮挡
	#   status=unresolved → ok=false 或 complete=false（保守未决，不计命中）
	var out := {"status": STATUS_UNRESOLVED, "event": {}, "contact": {}, "reason": "query_failed"}
	if not result.get("ok", false):
		out["reason"] = "query_failed"
		return out
	if not result.get("complete", false):
		out["reason"] = "incomplete"
		return out
	var world_contact: Dictionary = result.get("world_stop", {})
	var world_ws: float = float(world_contact.get("distance_m", -1.0))
	var first_armor: Dictionary = {}
	for ev in result.get("events", []):
		if ev.get("kind", "") == "armor" and ev.get("event_type", "") == "surface":
			first_armor = ev
			break
	if first_armor.is_empty():
		if world_ws >= 0.0:
			out = {"status": STATUS_WORLD, "event": {}, "contact": world_contact, "reason": "world_first"}
		else:
			out = {"status": STATUS_MISS, "event": {}, "contact": {}, "reason": "no_contact"}
		return out
	var armor_d: float = float(first_armor.get("distance_m", 0.0))
	if world_ws >= 0.0 and world_ws <= armor_d + TIE_EPS:
		out = {"status": STATUS_WORLD, "event": {}, "contact": world_contact, "reason": "wall_before_or_tie"}
	else:
		out = {"status": STATUS_VEHICLE, "event": first_armor, "contact": {}, "reason": "armor_first"}
	return out
