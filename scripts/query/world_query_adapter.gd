class_name WorldQueryAdapter
extends RefCounted
## 005（收尾 A）：在物理阶段取得最近世界遮挡（LAYER_WORLD：地面/围墙/箱子/靶板/面板测试墙）。
## 不把车辆驾驶粗碰撞当作装甲面——车辆命中由 ShotQueryService 几何查询决定。
## Godot 官方要求直接物理空间查询放在安全的物理更新阶段，不能随意放到鼠标事件或画面更新里。
##
## 边界语义（005-R1 收尾）：
##   - hit_from_inside=true：从实体墙内部开始的查询也识别世界接触（命中点在起点、法线为零
##     ——"未取得法线"不等于"没有墙"）；整段都位于墙盒内部时同样报告起点接触。
##   - t = distance_m/dist（clamp 0..1）；at_start/at_end 由端点容差标记。
##   - 错误传播：输入无效/零方向/终点非有限/命中结果异常 → ok=false + 明确 reason，
##     调用方必须保守未决，不得当作"无墙"。
##
## 返回结构（统一语义，供 Gunner 与调试面板共用）：
##   {ok, hit, reason, contact}
##   ok=false, reason="no_space"/"invalid_input"/"invalid_endpoint"/"invalid_world_result"/
##             "world_result_out_of_segment" → 未决（不得当无墙）
##   ok=true,  hit=false, reason="none"       → 路径畅通（无 LAYER_WORLD 遮挡）
##   ok=true,  hit=true,  reason="world_hit"  → contact = 标准化世界接触
##       contact: {kind:"world", event_type:"surface", distance_m, t, point_world,
##                 normal_world, normal_known, at_start, at_end,
##                 collider (Object，仅立即使用), face_index}

const EPS_M := 0.00001


static func query_world_stop(
		space_state: PhysicsDirectSpaceState3D,
		from: Vector3, dir: Vector3, dist: float,
		exclude_rids: Array[RID] = []
	) -> Dictionary:
	if space_state == null:
		return {"ok": false, "hit": false, "reason": "no_space", "contact": {}}

	if not from.is_finite() or not dir.is_finite() or not is_finite(dist):
		return {"ok": false, "hit": false, "reason": "invalid_input", "contact": {}}

	var direction_length := dir.length()
	if dist <= EPS_M or not is_finite(direction_length) or direction_length <= EPS_M:
		return {"ok": false, "hit": false, "reason": "invalid_input", "contact": {}}

	# dist 明确表示米数，不随 dir 的长度改变。
	var direction := dir / direction_length
	var to := from + direction * dist
	if not to.is_finite():
		return {"ok": false, "hit": false, "reason": "invalid_endpoint", "contact": {}}

	var q := PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_WORLD, exclude_rids)
	q.hit_from_inside = true

	var hit := space_state.intersect_ray(q)
	if hit.is_empty():
		return {"ok": true, "hit": false, "reason": "none", "contact": {}}

	var p: Variant = hit.get("position", null)
	var n: Variant = hit.get("normal", Vector3.ZERO)
	if not (p is Vector3) or not (n is Vector3):
		return {"ok": false, "hit": false, "reason": "invalid_world_result", "contact": {}}

	var point: Vector3 = p
	var normal: Vector3 = n
	if not point.is_finite() or not normal.is_finite():
		return {"ok": false, "hit": false, "reason": "invalid_world_result", "contact": {}}

	var distance_m := from.distance_to(point)
	if not is_finite(distance_m) or distance_m > dist + EPS_M:
		return {"ok": false, "hit": false, "reason": "world_result_out_of_segment", "contact": {}}

	var normal_known: bool = normal.length() > EPS_M
	var contact: Dictionary = {
		"kind": "world",
		"event_type": "surface",
		"distance_m": distance_m,
		"t": clampf(distance_m / dist, 0.0, 1.0),
		"point_world": point,
		"normal_world": normal.normalized() if normal_known else Vector3.ZERO,
		"normal_known": normal_known,
		"at_start": distance_m <= EPS_M,
		"at_end": absf(distance_m - dist) <= EPS_M,
	}
	if hit.has("collider"):
		contact["collider"] = hit["collider"]
	if hit.has("face_index"):
		contact["face_index"] = hit["face_index"]
	return {"ok": true, "hit": true, "reason": "world_hit", "contact": contact}
