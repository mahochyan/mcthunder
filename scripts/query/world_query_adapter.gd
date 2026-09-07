class_name WorldQueryAdapter
extends RefCounted
## 005：在物理阶段取得最近世界遮挡（LAYER_WORLD：地面/围墙/箱子/靶板）。
## 不把车辆驾驶粗碰撞当作装甲面——车辆命中由 ShotQueryService 几何查询决定。
## Godot 官方要求直接物理空间查询放在安全的物理更新阶段，不能随意放到鼠标事件或画面更新里。

static func query_world_stop(
		space_state: PhysicsDirectSpaceState3D,
		from: Vector3, dir: Vector3, dist: float,
		exclude_rids: Array[RID] = []
	) -> Dictionary:
	# 返回 PhysicsRayQueryParameters3D 的 intersect_ray 结果（空字典 = 无世界遮挡）。
	if space_state == null:
		return {}
	if not from.is_finite() or not dir.is_finite() or not is_finite(dist) or dist <= 0.0:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, GameConfig.LAYER_WORLD, exclude_rids)
	return space_state.intersect_ray(q)