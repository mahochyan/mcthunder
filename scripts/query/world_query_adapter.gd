class_name WorldQueryAdapter
extends RefCounted
## 005：在物理阶段取得最近世界遮挡（LAYER_WORLD：地面/围墙/箱子/靶板/面板测试墙）。
## 不把车辆驾驶粗碰撞当作装甲面——车辆命中由 ShotQueryService 几何查询决定。
## Godot 官方要求直接物理空间查询放在安全的物理更新阶段，不能随意放到鼠标事件或画面更新里。
##
## 返回结构（统一语义，供 Gunner 与调试面板共用）：
##   {ok, hit, reason, contact}
##   ok=false, reason="invalid_input"/"no_space" → 输入或物理空间无效（保守未决，不得当无墙）
##   ok=true,  hit=false, reason="none"           → 路径畅通（无 LAYER_WORLD 遮挡）
##   ok=true,  hit=true                            → contact = 标准化世界接触
##       contact: {kind:"world", event_type:"surface", distance_m, t, point_world,
##                 normal_world, normal_known, collider (Object，仅立即使用), face_index}

static func query_world_stop(
		space_state: PhysicsDirectSpaceState3D,
		from: Vector3, dir: Vector3, dist: float,
		exclude_rids: Array[RID] = []
	) -> Dictionary:
	if space_state == null:
		return {"ok": false, "hit": false, "reason": "no_space", "contact": {}}
	if not from.is_finite() or not dir.is_finite() or not is_finite(dist) or dist <= 0.0:
		return {"ok": false, "hit": false, "reason": "invalid_input", "contact": {}}
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, GameConfig.LAYER_WORLD, exclude_rids)
	var hit := space_state.intersect_ray(q)
	if hit.is_empty():
		return {"ok": true, "hit": false, "reason": "none", "contact": {}}
	var contact: Dictionary = {
		"kind": "world",
		"event_type": "surface",
		"distance_m": from.distance_to(hit["position"]),
		"t": 0.0,   # 服务段参数未定义于适配器；保留字段由调用方填入（可选）
		"point_world": hit["position"],
		"normal_world": hit.get("normal", Vector3.UP) as Vector3,
		"normal_known": true,
	}
	if hit.has("collider"):
		contact["collider"] = hit["collider"]
	if hit.has("face_index"):
		contact["face_index"] = hit["face_index"]
	return {"ok": true, "hit": true, "reason": "wall", "contact": contact}
