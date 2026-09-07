class_name ShotQueryService
extends RefCounted
## 005：统一有限线段命中查询——汇总几何结果、身份过滤、去重、排序、诊断。
## 不修改弹药、模块、任务计数；不调用 register_hit / accept_hit / 冷却。
## 目标："这条线段在当前姿态下，几何上经过了什么"——不是穿透/损伤判定。

const MAX_ENTITIES := 8
const EPS_DIST_GROUP := 0.001   # 排序后的容差分组（米）


static func query(request: Dictionary, snapshots: Array) -> Dictionary:
	# request: {query_id, physics_tick, from_world, to_world,
	#           excluded_instances: [{entity_id, life_id}], include_modules, include_crew,
	#           world_stop_distance_m (可选，由世界适配器提供)}
	# 返回 {ok, complete, query_id, events[], volume_intervals[], world_stop_distance_m, diagnostics[]}
	var query_id: String = str(request.get("query_id", "q"))
	var from_world: Vector3 = request.get("from_world", Vector3.ZERO)
	var to_world: Vector3 = request.get("to_world", Vector3.ZERO)
	if not from_world.is_finite() or not to_world.is_finite():
		return _fail(query_id, "non_finite_segment")
	var seg := to_world - from_world
	var seg_length := seg.length()
	if not is_finite(seg_length) or seg_length <= QueryGeometry.EPS_M:
		return _fail(query_id, "zero_or_invalid_segment")
	if snapshots.size() > MAX_ENTITIES:
		return _fail(query_id, "too_many_entities (%d > %d)" % [snapshots.size(), MAX_ENTITIES])

	var include_modules: bool = request.get("include_modules", true)
	var include_crew: bool = request.get("include_crew", false)
	var excluded := _excluded_set(request.get("excluded_instances", []))

	var events: Array = []
	var intervals: Array = []
	var diagnostics: Array = []
	var complete := true

	for snapshot in snapshots:
		if snapshot is not Dictionary or snapshot.is_empty():
			continue
		var entity_id: String = str(snapshot.get("entity_id", ""))
		var life_id: int = int(snapshot.get("life_id", 0))
		if excluded.has("%s:%d" % [entity_id, life_id]):
			continue
		var layout: VehicleLayoutDefinition = snapshot.get("layout", null)
		if layout == null:
			diagnostics.append("entity %s: no layout in snapshot" % entity_id)
			complete = false
			continue
		var transforms: Dictionary = snapshot.get("part_world_transforms", {})
		_collect_patches(snapshot, layout, transforms, from_world, to_world, seg_length, events, diagnostics)
		if include_modules:
			_collect_boxes(snapshot, layout, transforms, from_world, to_world, seg_length, "module", events, intervals)
		if include_crew:
			_collect_boxes(snapshot, layout, transforms, from_world, to_world, seg_length, "crew", events, intervals)

	# 去重：只合并同一个面片的重复三角形交点（同 entity/life/part/surface + 接近位置）
	events = _dedupe_patch_events(events)

	# 排序：先按真实 distance_m，再按稳定身份处理完全相同距离；容差分组在排序之后
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a.get("distance_m", 0.0)
		var db: float = b.get("distance_m", 0.0)
		if absf(da - db) > 0.0:
			return da < db
		return _event_sort_key(a) < _event_sort_key(b)
	)

	var world_stop: float = request.get("world_stop_distance_m", -1.0)
	return {
		"ok": true,
		"complete": complete,
		"query_id": query_id,
		"events": events,
		"volume_intervals": intervals,
		"world_stop_distance_m": world_stop,
		"diagnostics": diagnostics,
	}


static func _fail(query_id: String, reason: String) -> Dictionary:
	return {
		"ok": false, "complete": false, "query_id": query_id,
		"events": [], "volume_intervals": [], "world_stop_distance_m": -1.0,
		"diagnostics": [reason],
	}


static func _excluded_set(excluded_instances: Array) -> Dictionary:
	var out := {}
	for inst in excluded_instances:
		if inst is Dictionary:
			out["%s:%d" % [str(inst.get("entity_id", "")), int(inst.get("life_id", 0))]] = true
	return out


static func _collect_patches(
		snapshot: Dictionary, layout: VehicleLayoutDefinition, transforms: Dictionary,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		events: Array, diagnostics: Array
	) -> void:
	var entity_id: String = str(snapshot.get("entity_id", ""))
	var life_id: int = int(snapshot.get("life_id", 0))
	for patch in layout.armor_patches:
		if patch == null:
			continue
		var part_world: Transform3D = transforms.get(patch.part_id, Transform3D.IDENTITY)
		var inv := part_world.affine_inverse()
		var local_from := inv * from_world
		var local_to := inv * to_world
		# 保守 AABB 粗筛（局部系）
		var pmin := patch.vertices_local_m[0]
		var pmax := patch.vertices_local_m[0]
		for v in patch.vertices_local_m:
			pmin = pmin.min(v)
			pmax = pmax.max(v)
		var seg_min := local_from.min(local_to)
		var seg_max := local_from.max(local_to)
		if seg_max.x < pmin.x or seg_min.x > pmax.x \
				or seg_max.y < pmin.y or seg_min.y > pmax.y \
				or seg_max.z < pmin.z or seg_min.z > pmax.z:
			continue
		var tris := patch.triangles
		for start in range(0, tris.size(), 3):
			var a := patch.vertices_local_m[tris[start]]
			var b := patch.vertices_local_m[tris[start + 1]]
			var c := patch.vertices_local_m[tris[start + 2]]
			var r := QueryGeometry.segment_triangle(local_from, local_to, a, b, c)
			if not r.get("ok", false):
				diagnostics.append("patch %s: %s" % [patch.id, str(r.get("error", "unknown"))])
				continue
			if not r.get("hit", false):
				if r.get("relation", "") == "coplanar_unresolved":
					diagnostics.append("patch %s: coplanar_unresolved (no unique crossing; not proof of clear path)" % patch.id)
				continue
			var t: float = r["t"]
			var point_world := from_world.lerp(to_world, t)
			var normal_world := part_world.basis * (r["normal_local"] as Vector3)
			events.append({
				"distance_m": seg_length * t,
				"t": t,
				"kind": "armor",
				"event_type": "surface",
				"entity_id": entity_id,
				"life_id": life_id,
				"part_id": patch.part_id,
				"surface_id": patch.id,
				"point_world": point_world,
				"normal_world": normal_world,
				"normal_known": true,
				"at_start": r.get("at_start", false),
				"at_end": r.get("at_end", false),
				"on_edge": r.get("on_edge", false),
				"has_thickness": patch.has_thickness,
				"thickness_mm": patch.thickness_mm,
				"thickness_status": patch.thickness_status,
				"material_kind": patch.material_kind,
			})


static func _collect_boxes(
		snapshot: Dictionary, layout: VehicleLayoutDefinition, transforms: Dictionary,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		kind: String, events: Array, intervals: Array
	) -> void:
	var entity_id: String = str(snapshot.get("entity_id", ""))
	var life_id: int = int(snapshot.get("life_id", 0))
	var items: Array = layout.modules if kind == "module" else layout.crew_stations
	for item in items:
		if item == null:
			continue
		var part_world: Transform3D = transforms.get(item.part_id, Transform3D.IDENTITY)
		var box_world: Transform3D = part_world * item.local_box_transform
		var inv: Transform3D = box_world.affine_inverse()
		var local_from: Vector3 = inv * from_world
		var local_to: Vector3 = inv * to_world
		var r := QueryGeometry.segment_box_local(local_from, local_to, item.size_m)
		if not r.get("ok", false):
			continue
		if not r.get("hit", false):
			continue
		var t_enter: float = r["t_enter"]
		var t_exit: float = r["t_exit"]
		var id_key := "module_id" if kind == "module" else "crew_id"
		var item_id: String = item.id
		intervals.append({
			"kind": kind,
			"entity_id": entity_id,
			"life_id": life_id,
			"part_id": item.part_id,
			id_key: item_id,
			"t_enter": t_enter,
			"t_exit": t_exit,
			"distance_enter_m": seg_length * t_enter,
			"distance_exit_m": seg_length * t_exit,
			"starts_inside": r.get("starts_inside", false),
			"grazing": r.get("grazing", false),
		})
		if r.get("grazing", false):
			# 擦边/沿表面退化接触——UI 区分，不当作穿过有效体积
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"touch", t_enter, from_world, to_world, seg_length, Vector3.ZERO, false))
			continue
		if r.get("has_entry_boundary", false):
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"enter", t_enter, from_world, to_world, seg_length,
				part_world.basis * (r["normal_enter_local"] as Vector3), true))
		if r.get("has_exit_boundary", false):
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"exit", t_exit, from_world, to_world, seg_length,
				part_world.basis * (r["normal_exit_local"] as Vector3), true))


static func _box_event(
		kind: String, id_key: String, item_id: String, snapshot: Dictionary,
		part_id: String, event_type: String, t: float,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		normal_world: Vector3, normal_known: bool
	) -> Dictionary:
	var ev := {
		"distance_m": seg_length * t,
		"t": t,
		"kind": kind,
		"event_type": event_type,
		"entity_id": str(snapshot.get("entity_id", "")),
		"life_id": int(snapshot.get("life_id", 0)),
		"part_id": part_id,
		id_key: item_id,
		"point_world": from_world.lerp(to_world, t),
		"normal_world": normal_world,
		"normal_known": normal_known,
		"at_start": t <= QueryGeometry.EPS_M / maxf(seg_length, 0.0001),
		"at_end": t >= 1.0 - QueryGeometry.EPS_M / maxf(seg_length, 0.0001),
		"on_edge": false,
	}
	return ev


static func _dedupe_patch_events(events: Array) -> Array:
	# 只合并同一个面片的重复三角形交点（同一四边形拆成两个三角形、射线过共享对角线时
	# 只产生一个该面片事件）。不同车辆/不同装甲层/不同 surface_id/模块进出点不合并。
	var out: Array = []
	var seen: Dictionary = {}
	for ev in events:
		if ev.get("kind", "") != "armor":
			out.append(ev)
			continue
		var key := "%s:%d:%s:%s" % [str(ev.get("entity_id", "")), int(ev.get("life_id", 0)),
			str(ev.get("part_id", "")), str(ev.get("surface_id", ""))]
		var merged := false
		if seen.has(key):
			for existing in seen[key]:
				if absf(float(existing["distance_m"]) - float(ev["distance_m"])) <= EPS_DIST_GROUP:
					merged = true
					break
		if not merged:
			seen.get_or_add(key, []).append(ev)
			out.append(ev)
	return out


static func _event_sort_key(ev: Dictionary) -> String:
	# 稳定身份排序键（同距时确定性顺序）
	return "%s:%d:%s:%s:%s" % [
		str(ev.get("kind", "")), int(ev.get("life_id", 0)),
		str(ev.get("entity_id", "")), str(ev.get("part_id", "")),
		str(ev.get("surface_id", ev.get("module_id", ev.get("crew_id", "")))),
	]