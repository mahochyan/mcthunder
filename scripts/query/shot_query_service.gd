class_name ShotQueryService
extends RefCounted
## CD003 3A: the bounded ray budget for one query. Sampling a finite cross-section multiplies the narrow-phase ray work by
## the ray count, so the budget is declared here and its exhaustion reports incomplete with a diagnostic rather than being
## read as a clear path. The v1 line query uses exactly one ray and never approaches it.
const RAY_BUDGET := 512
## CD003 3C: the declared angular step for subdividing a rotating part across one step. Each sub-interval is expressed in a
## single frame, so a rotating boundary is met at the rotation's own time; the chord error of a sub-interval is bounded by
## this angle. A part that does not turn is never subdivided and its cull still runs exactly as before.
const ROTATION_STEP_RAD := 0.02
## 005：统一有限线段命中查询——汇总几何结果、身份过滤、去重、排序、诊断。
## 不修改弹药、模块、任务计数；不调用 register_hit / accept_hit / 冷却。
## 目标："这条线段在当前姿态下，几何上经过了什么"——不是穿透/损伤判定。

const MAX_ENTITIES := 24 # 016: eight active vehicles plus twelve retained wrecks, with a bounded margin.
const EPS_DIST_GROUP := 0.001   # 排序后的容差分组（米）
static var measure_enabled := false
static var measured_calls := 0
static var measured_usec := 0
static var measured_sources := {}
const BOUNDS_CACHE_LIMIT := 512
static var bounds_cache_enabled := true
static var _vertex_bounds := {}
static var part_culling_enabled := true
static var _part_bounds_cache := {}
const PART_CACHE_LIMIT := 64

static func _part_bounds(layout: VehicleLayoutDefinition) -> Dictionary:
	# Value comparison detects edited/replaced vertices without trusting revision tags.
	# Cache keys are explicitly duplicated: property element writes can alias packed arrays.
	var signature: Array=[]
	for patch in layout.armor_patches:
		if patch!=null:
			signature.append(patch.part_id); signature.append(patch.vertices_local_m); signature.append(patch.triangles)
	var key := layout.get_instance_id()
	var cached: Dictionary=_part_bounds_cache.get(key,{})
	if not cached.is_empty() and cached.signature==signature: return cached
	var bounds := {}
	var planes := {}; var unsafe := {}
	for patch in layout.armor_patches:
		if patch==null or patch.vertices_local_m.is_empty(): continue
		var row: PackedVector3Array=_bounds(patch.vertices_local_m)
		if bounds.has(patch.part_id):
			var old: PackedVector3Array=bounds[patch.part_id]
			row=PackedVector3Array([old[0].min(row[0]),old[1].max(row[1])])
		bounds[patch.part_id]=row
		if not planes.has(patch.part_id): planes[patch.part_id]={}
		var vertices := patch.vertices_local_m
		var triangles := patch.triangles
		if triangles.size()%3!=0: unsafe[patch.part_id]=true; continue
		for start in range(0,triangles.size(),3):
			var indices := [triangles[start],triangles[start+1],triangles[start+2]]
			if indices.min()<0 or indices.max()>=vertices.size(): unsafe[patch.part_id]=true; continue
			var a:=vertices[indices[0]]; var b:=vertices[indices[1]]; var c:=vertices[indices[2]]
			var normal := (b-a).cross(c-a)
			var area2 := normal.length()
			if not a.is_finite() or not b.is_finite() or not c.is_finite() or not is_finite(area2) or area2<=QueryGeometry.EPS_AREA or minf(a.distance_to(b),minf(b.distance_to(c),c.distance_to(a)))<=QueryGeometry.EPS_M:
				unsafe[patch.part_id]=true; continue
			normal/=area2
			planes[patch.part_id][PackedVector3Array([normal,a])]=true
	if _part_bounds_cache.size()>=PART_CACHE_LIMIT: _part_bounds_cache.clear()
	for index in signature.size():
		if index%3!=0: signature[index]=signature[index].duplicate()
	for part_id in planes: planes[part_id]=planes[part_id].keys()
	_part_bounds_cache[key]={"signature":signature,"bounds":bounds,"planes":planes,"unsafe":unsafe}
	return _part_bounds_cache[key]

static func _safe_slab_miss(data: Dictionary, part_id: String, a: Vector3, b: Vector3, bound: PackedVector3Array) -> bool:
	if data.unsafe.has(part_id) or AABB(bound[0],bound[1]-bound[0]).grow(QueryGeometry.EPS_M*4).intersects_segment(a,b): return false
	# Preserve the existing unresolved result even for a coplanar line outside a triangle.
	for plane: PackedVector3Array in data.planes.get(part_id,[]):
		if absf(plane[0].dot(a-plane[1]))<=QueryGeometry.EPS_M*4 and absf(plane[0].dot(b-plane[1]))<=QueryGeometry.EPS_M*4: return false
	return true

static func _bounds(vertices: PackedVector3Array) -> PackedVector3Array:
	# Packed arrays use value hashing/equality and copy-on-write. Changed geometry
	# gets a different key; no metadata is written onto shared layout resources.
	if bounds_cache_enabled:
		# Packed geometry keys hash by value: one lookup avoids hashing twice per patch.
		var cached: PackedVector3Array = _vertex_bounds.get(vertices,PackedVector3Array())
		if not cached.is_empty(): return cached
	var pmin:=vertices[0]; var pmax:=vertices[0]
	for vertex in vertices: pmin=pmin.min(vertex); pmax=pmax.max(vertex)
	var result:=PackedVector3Array([pmin,pmax])
	if bounds_cache_enabled:
		if _vertex_bounds.size()>=BOUNDS_CACHE_LIMIT: _vertex_bounds.clear()
		_vertex_bounds[vertices.duplicate()]=result
	return result


static func query(request: Dictionary, snapshots: Array) -> Dictionary:
	if not measure_enabled: return _query(request,snapshots)
	var started:=Time.get_ticks_usec()
	var result:=_query(request,snapshots)
	var elapsed := Time.get_ticks_usec()-started
	measured_calls+=1; measured_usec+=elapsed
	var id := str(request.get("query_id",""))
	var source := "other"
	for prefix in ["aim_","proj_","fragment_"]:
		if id.begins_with(prefix): source=prefix; break
	if not measured_sources.has(source): measured_sources[source]={"calls":0,"cpu_usec":0}
	measured_sources[source].calls+=1; measured_sources[source].cpu_usec+=elapsed
	return result

static func _query(request: Dictionary, snapshots: Array) -> Dictionary:
	# request: {query_id, physics_tick, from_world, to_world,
	#           excluded_instances: [{entity_id, life_id}], include_modules, include_crew,
	#           world_stop (可选，标准化世界接触 dict；由 WorldQueryAdapter 提供),
	#           world_stop_distance_m (旧字段兼容：纯距离)}
	# 返回 {ok, complete, query_id, events[], volume_intervals[], world_stop (接触 dict),
	#       world_stop_distance_m (float 或 -1), diagnostics[]}
	# complete=false 含义：几何未全解（共面未决/退化三角形）或快照不完整（缺布局/缺变换/非有限）——
	# 调用方不得据此判命中（保守未决）。
	var query_id: String = str(request.get("query_id", "q"))
	# CD01-T06 / WT-CD-001 design point 4: an optional expected occupancy revision. A request that names a revision
	# different from the one the snapshot was built from is refused as stale rather than being answered from older or
	# newer dynamic data. Callers that do not supply the field keep the previous behaviour.
	if request.has("expected_occupancy_revision"):
		for snapshot in snapshots:
			if int(snapshot.get("occupancy_revision",-1)) != int(request.get("expected_occupancy_revision")):
				return _fail(query_id,"stale_occupancy_revision")
	var from_world: Vector3 = request.get("from_world", Vector3.ZERO)
	var to_world: Vector3 = request.get("to_world", Vector3.ZERO)
	if not from_world.is_finite() or not to_world.is_finite():
		return _fail(query_id, "non_finite_segment")
	# CD003 3A: an optional STATIC FINITE CROSS-SECTION. When the request carries one, the narrow phase samples the section
	# with a bounded ring of rays, so a round no longer passes a slit narrower than itself. The centre ray still defines
	# the contact point, TOI and normal, so one plate is charged once per episode while the ring only decides whether the
	# plate is met at all - that is what keeps "same plate once, different layers separately" true. Without a section the
	# query keeps the v1 line behaviour byte for byte, which stays the explicit legacy entry. The ray budget is declared
	# and exhausting it reports incomplete rather than "no hit".
	var section_radius := 0.0
	var section_offsets: Array[Vector3] = []
	if request.has("shape_section") and request.shape_section is Dictionary:
		var sec: Dictionary = request.shape_section
		section_radius = float(sec.get("section_radius_m",0.0))
		var rays := int(sec.get("rays",0))
		if not is_finite(section_radius) or section_radius < 0.0:
			return _fail(query_id,"invalid_shape_section")
		if section_radius > 0.0 and rays >= 3:
			var axis := (to_world-from_world)
			if axis.length() <= QueryGeometry.EPS_M: return _fail(query_id,"zero_or_invalid_segment")
			var dir := axis.normalized()
			var helper := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			var e1 := dir.cross(helper).normalized()
			var e2 := dir.cross(e1).normalized()
			for i in rays:
				var ang := TAU*float(i)/float(rays)
				section_offsets.append((e1*cos(ang)+e2*sin(ang))*section_radius)
	# The sampling is declared in the result as well as in the profile, so a caller can see which section a query actually
	# used instead of inferring it from the contacts (the sub-order asks for exactly this in the contact record).
	var section_declared := not section_offsets.is_empty()
	var seg := to_world - from_world
	var seg_length := seg.length()
	if not is_finite(seg_length) or seg_length <= QueryGeometry.EPS_M:
		return _fail(query_id, "zero_or_invalid_segment")
	if not request.get("motion_fraction", Vector2.ONE) is Vector2:
		return _fail(query_id, "invalid_motion_fraction")
	var fractions: Vector2 = request.get("motion_fraction", Vector2.ONE)
	if not fractions.is_finite() or fractions.x < 0.0 or fractions.y > 1.0 or fractions.x > fractions.y:
		return _fail(query_id, "invalid_motion_fraction")
	if snapshots.size() > MAX_ENTITIES:
		return _fail(query_id, "too_many_entities (%d > %d)" % [snapshots.size(), MAX_ENTITIES])

	var include_modules: bool = request.get("include_modules", true)
	var include_crew: bool = request.get("include_crew", false)
	var excluded := _excluded_set(request.get("excluded_instances", []))

	# 世界遮挡：优先取标准化接触 dict；旧 world_stop_distance_m 字段兼容——
	# 按线段重建有限坐标（t/point_world），非法（非有限/超段）明确拒绝，不生成 INF 坐标。
	var world_contact: Dictionary = request.get("world_stop", {})
	if world_contact.is_empty() and request.get("world_stop_distance_m", -1.0) >= 0.0:
		var legacy_dist := float(request["world_stop_distance_m"])
		if not is_finite(legacy_dist) or legacy_dist < 0.0 or legacy_dist > seg_length:
			return _fail(query_id, "invalid_legacy_world_stop_distance (%.3f vs seg %.3f)" % [legacy_dist, seg_length])
		var dir_unit := seg / seg_length
		world_contact = {
			"kind": "world", "event_type": "surface",
			"distance_m": legacy_dist,
			"t": clampf(legacy_dist / seg_length, 0.0, 1.0),
			"point_world": from_world + dir_unit * legacy_dist,
			"normal_world": Vector3.ZERO,
			"normal_known": false,
			"at_start": legacy_dist <= QueryGeometry.EPS_M,
			"at_end": absf(legacy_dist - seg_length) <= QueryGeometry.EPS_M,
		}
	var world_ws: float = float(world_contact.get("distance_m", -1.0))

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
		if request.has("motion_fraction"):
			diagnostics.append_array(snapshot.get("motion_diagnostics", []))
		# 缺失/非有限变换：明确失败，不使用单位变换伪装；该实体整体跳过
		var bad := _first_invalid_part(layout, transforms, snapshot)
		if not bad.is_empty():
			diagnostics.append("entity %s: missing or invalid part transform %s (snapshot also reports %s)" % [
				entity_id, bad, str(snapshot.get("missing_parts", []))])
			complete = false
			continue
		if not _collect_patches(snapshot, layout, transforms, from_world, to_world, seg_length, events, diagnostics, fractions, section_radius, section_offsets):
			complete = false
		if include_modules:
			if not _collect_boxes(snapshot, layout, transforms, from_world, to_world, seg_length, "module", events, intervals, diagnostics, fractions, section_radius, section_offsets):
				complete = false
		if include_crew:
			if not _collect_boxes(snapshot, layout, transforms, from_world, to_world, seg_length, "crew", events, intervals, diagnostics, fractions, section_radius, section_offsets):
				complete = false

	# 去重：只合并同一个面片的重复三角形交点（同 entity/life/part/surface + 接近位置）
	events = _dedupe_patch_events(events)

	# 排序：统一严格排序（收尾 C）——真实 distance_m 严格比较 + 确定性 tie-break
	# event_key（JSON 数组 [kind, entity_id, life_id, part_id, item_id, event_type]）；
	# 容差分组只允许发生在排序之后（显示层），比较器本身不得使用容差。
	events.sort_custom(event_less)

	# 墙后候选标注（遮挡是规则/显示层关心的事，服务不删除候选）
	if world_ws >= 0.0:
		for ev in events:
			ev["occluded_by_world"] = float(ev.get("distance_m", 0.0)) > world_ws + EPS_DIST_GROUP
	else:
		for ev in events:
			ev["occluded_by_world"] = false

	# 统一有序接触列表（收尾 C）：事件 + 最近世界接触合并为单一严格排序序列。
	# 面板/展示直接读取本顺序，不得自带排序规则；选择器墙优先仍是接触选择政策。
	var ordered_contacts: Array = []
	for ev in events:
		ordered_contacts.append(ev)
	if world_ws >= 0.0:
		var wrow := world_contact.duplicate(true)
		if not wrow.has("entity_id"):
			wrow["entity_id"] = "world"
		if not wrow.has("part_id"):
			wrow["part_id"] = "world"
		if not wrow.has("surface_id"):
			wrow["surface_id"] = "world_contact"
		if not wrow.has("event_type"):
			wrow["event_type"] = "surface"
		wrow["occluded_by_world"] = false
		ordered_contacts.append(wrow)
	ordered_contacts.sort_custom(event_less)

	# State the sampling this query actually used, once, in the result. The sub-order asks for the sampling and its error
	# bound to be visible in the record rather than inferred from the contacts.
	if section_declared:
		diagnostics.append("section_sampled rays=%d radius_m=%.6f" % [section_offsets.size(),section_radius])

	return {
		"ok": true,
		"complete": complete,
		"query_id": query_id,
		"events": events,
		"ordered_contacts": ordered_contacts,
		"volume_intervals": intervals,
		"world_stop": world_contact,
		"world_stop_distance_m": world_ws,
		"diagnostics": diagnostics,
	}


static func _fail(query_id: String, reason: String) -> Dictionary:
	return {
		"ok": false, "complete": false, "query_id": query_id,
		"events": [], "volume_intervals": [], "world_stop": {},
		"world_stop_distance_m": -1.0,
		"diagnostics": [reason],
	}


static func _first_invalid_part(
		layout: VehicleLayoutDefinition, transforms: Dictionary, snapshot: Dictionary
	) -> String:
	# 布局每个部件必须有有效刚体变换（005-R1 收尾：复用 LayoutMath.is_rigid——
	# 仅 is_finite 不足以排除全零/不可逆基底）；快照自身登记的 missing_parts 一并视为缺失。
	var missing: Array = snapshot.get("missing_parts", [])
	for p in missing:
		return str(p)
	for part in layout.parts:
		if part == null:
			continue
		if not transforms.has(part.id):
			return part.id
		var t: Transform3D = transforms[part.id]
		if not (t is Transform3D) or not LayoutMath.is_rigid(t):
			return part.id
	return ""


static func _excluded_set(excluded_instances: Array) -> Dictionary:
	var out := {}
	for inst in excluded_instances:
		if inst is Dictionary:
			out["%s:%d" % [str(inst.get("entity_id", "")), int(inst.get("life_id", 0))]] = true
	return out


static func _collect_patches(
		snapshot: Dictionary, layout: VehicleLayoutDefinition, transforms: Dictionary,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		events: Array, diagnostics: Array, fractions: Vector2 = Vector2.ONE,
		section_radius: float = 0.0, section_offsets: Array[Vector3] = []
	) -> bool:
	# 返回 complete（false = 存在未解几何关系/退化三角形——保守未决）
	var complete := true
	# CD003 3A: the ray budget is per query and its exhaustion reports incomplete, never "no hit".
	var ray_casts := 0
	var entity_id: String = str(snapshot.get("entity_id", ""))
	var life_id: int = int(snapshot.get("life_id", 0))
	var local_segments := {}
	var missed_parts := {}
	if part_culling_enabled:
		var part_data := _part_bounds(layout)
		var part_bounds: Dictionary=part_data.bounds
		for part_id in part_bounds:
			if not transforms.has(part_id): continue
			var segment := TranslationSweep.local_segment(snapshot, str(part_id), from_world, to_world, fractions)
			var a := segment[0]; var b := segment[1]
			local_segments[part_id]=segment
			var bound: PackedVector3Array=part_bounds[part_id]
			# CD003 3A: this PART-level cull must allow for the section too. It did not, so a declared section whose centre
			# line ran just outside the part's bounding box marked the whole part as missed and the ring rays were never
			# tried - which is exactly why a grazing shot passed with no contact while a control centre line at the position
			# a ring ray should occupy did hit. The expansion is a conservative pre-filter for the real multi-ray narrow
			# phase, not a scaled-up collision box standing in for a volumetric round.
			if section_radius > 0.0:
				bound = PackedVector3Array([bound[0]-Vector3(section_radius,section_radius,section_radius),
					bound[1]+Vector3(section_radius,section_radius,section_radius)])
			# Match the existing patch AABB gate. A tighter slab test could suppress
			# its coplanar/degenerate diagnostics and incorrectly turn unknown into clear.
			# CD003 3C: a part that TURNS across the step is NOT culled here. The whole-step local segment mixes two frames
			# once the basis rotates, so this conservative gate marked the whole part as missed and the patch loop never ran -
			# which is exactly why the first subdivided attempt produced no contact at all. A rotating part is culled per
			# sub-interval inside the patch loop instead, where each span has a single frame.
			if TranslationSweep.rotation_angle(snapshot,str(part_id)) <= ROTATION_STEP_RAD:
				if segment[3].x<bound[0].x or segment[2].x>bound[1].x or segment[3].y<bound[0].y or segment[2].y>bound[1].y or segment[3].z<bound[0].z or segment[2].z>bound[1].z:
					missed_parts[part_id]=true
				elif _safe_slab_miss(part_data,str(part_id),a,b,bound): missed_parts[part_id]=true
		if missed_parts.size()==part_bounds.size() and part_bounds.size()>0: return true
	for patch in layout.armor_patches:
		if patch == null:
			continue
		if missed_parts.has(patch.part_id): continue
		if not transforms.has(patch.part_id):
			diagnostics.append("patch %s: missing part transform %s" % [patch.id, patch.part_id])
			complete = false
			continue
		var segment: PackedVector3Array = local_segments.get(patch.part_id,PackedVector3Array())
		if segment.is_empty():
			segment = TranslationSweep.local_segment(snapshot, patch.part_id, from_world, to_world, fractions)
			local_segments[patch.part_id]=segment
		var local_from: Vector3=segment[0]
		var local_to: Vector3=segment[1]
		# 保守 AABB 粗筛（局部系）。有截面时按半径外扩：这是给真实多射线的保守粗筛，不是把碰撞盒放大冒充体积弹。
		var bounds:=_bounds(patch.vertices_local_m)
		# CD003 3C: a part that TURNS across the step cannot be served by one local segment; the step is subdivided by the
		# declared angular step and each sub-interval gets its own frame, local segment and ray offsets. A part that does not
		# turn keeps exactly one span, so nothing changes for it.
		var turn := TranslationSweep.rotation_angle(snapshot,patch.part_id)
		var spans: Array = []
		if turn > ROTATION_STEP_RAD:
			var count := int(ceil(turn/ROTATION_STEP_RAD))
			for i in count:
				var fa := float(i)/float(count)
				var fb := float(i+1)/float(count)
				spans.append({"fa":fa,"fb":fb,
					"seg":TranslationSweep.local_sub_segment(snapshot,patch.part_id,from_world,to_world,fa,fb),
					"xform":TranslationSweep.part_transform(snapshot,patch.part_id,fa)})
		else:
			spans.append({"fa":0.0,"fb":1.0,"seg":segment,
				"xform":TranslationSweep.part_transform(snapshot,patch.part_id,1.0)})
		var tris := patch.triangles
		var best_hit: Dictionary = {}
		for span in spans:
			var span_seg: PackedVector3Array = span.seg
			var span_from: Vector3 = span_seg[0]
			var span_to: Vector3 = span_seg[1]
			var pmin:=bounds[0]-Vector3(section_radius,section_radius,section_radius)
			var pmax:=bounds[1]+Vector3(section_radius,section_radius,section_radius)
			var seg_min := span_seg[2]
			var seg_max := span_seg[3]
			if seg_max.x < pmin.x or seg_min.x > pmax.x \
					or seg_max.y < pmin.y or seg_min.y > pmax.y \
					or seg_max.z < pmin.z or seg_min.z > pmax.z:
				continue
			var span_xform: Transform3D = span.xform
			var local_offsets: Array[Vector3] = [Vector3.ZERO]
			for world_offset in section_offsets:
				local_offsets.append(span_xform.basis.inverse()*world_offset)
			for ray_index in local_offsets.size():
				if ray_casts >= RAY_BUDGET:
					diagnostics.append("ray_budget_exhausted at patch %s (budget %d)" % [patch.id,RAY_BUDGET])
					complete = false
					break
				ray_casts += 1
				var lf: Vector3 = span_from+local_offsets[ray_index]
				var lt: Vector3 = span_to+local_offsets[ray_index]
				for start in range(0, tris.size(), 3):
					var a := patch.vertices_local_m[tris[start]]
					var b := patch.vertices_local_m[tris[start + 1]]
					var c := patch.vertices_local_m[tris[start + 2]]
					var r := QueryGeometry.segment_triangle(lf, lt, a, b, c)
					if not r.get("ok", false):
						diagnostics.append("patch %s: %s" % [patch.id, str(r.get("error", "unknown"))])
						complete = false
						continue
					if not r.get("hit", false):
						if r.get("relation", "") == "coplanar_unresolved":
							diagnostics.append("patch %s: coplanar_unresolved (no unique crossing; not proof of clear path)" % patch.id)
							complete = false
						continue
					var t_global: float = lerpf(span.fa,span.fb,float(r["t"]))
					if best_hit.is_empty() or t_global < float(best_hit.get("t",INF)):
						best_hit = {"r":r,"ray":ray_index,"t":t_global,"offset":local_offsets[ray_index]}
					break
				if not best_hit.is_empty() and int(best_hit["ray"]) == 0:
					break
			if not best_hit.is_empty():
				break
		if best_hit.is_empty():
			continue
		var r: Dictionary = best_hit["r"]
		if best_hit.has("r"):
			var t: float = float(best_hit.get("t",r["t"]))
			var ray_offset: Vector3 = best_hit.get("offset",Vector3.ZERO)
			var point_world := from_world.lerp(to_world, t)
			var contact_fraction := lerpf(fractions.x, fractions.y, t)
			var part_world := TranslationSweep.part_transform(snapshot, patch.part_id, contact_fraction)
			var normal_world := part_world.basis * (r["normal_local"] as Vector3)
			var event := {
				"distance_m": seg_length * t,
				"t": t,
				"kind": "armor",
				"target_generation":snapshot.get("target_generation",-1),
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
				"section_ray_index": int(best_hit["ray"]),
				"section_offset_local_m": ray_offset,
				"section_radius_m": section_radius,
				"thickness_mm": patch.thickness_mm,
				"thickness_status": patch.thickness_status,
				"material_kind": patch.material_kind,
				"response_profile": patch.response_profile.duplicate(true),
				"reactive_profile": patch.reactive_profile.duplicate(true),
				"part_world_transform": part_world,
				"layout_id": layout.id,
				"layout_revision": layout.schema_version,
				"content_tier": layout.content_tier,
			}
			if snapshot.get(TranslationSweep.PREVIOUS_KEY, {}).has(patch.part_id):
				event["motion_fraction"] = contact_fraction
			events.append(event)
	return complete


static func _collect_boxes(
		snapshot: Dictionary, layout: VehicleLayoutDefinition, transforms: Dictionary,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		kind: String, events: Array, intervals: Array, diagnostics: Array, fractions: Vector2 = Vector2.ONE,
		section_radius: float = 0.0, section_offsets: Array[Vector3] = []
	) -> bool:
	# 返回 complete（false = 缺部件变换/非有限——保守未决）
	var complete := true
	# CD003: volumes get their own ray budget, declared, so sampling a section here cannot run unbounded either.
	var ray_casts := 0
	var entity_id: String = str(snapshot.get("entity_id", ""))
	var life_id: int = int(snapshot.get("life_id", 0))
	var items: Array = layout.modules if kind == "module" else layout.crew_stations
	for item in items:
		if item == null:
			continue
		if not transforms.has(item.part_id):
			diagnostics.append("%s %s: missing part transform %s" % [kind, item.id, item.part_id])
			complete = false
			continue
		var part_world := TranslationSweep.part_transform(snapshot, item.part_id, fractions.x)
		var box_world: Transform3D = part_world * item.local_box_transform
		var inv: Transform3D = box_world.affine_inverse()
		var local_from: Vector3 = inv * from_world
		var end_box: Transform3D = TranslationSweep.part_transform(snapshot, item.part_id, fractions.y) * item.local_box_transform
		var local_to: Vector3 = end_box.affine_inverse() * to_world
		var moving: bool = snapshot.get(TranslationSweep.PREVIOUS_KEY, {}).has(item.part_id)
		# CD003 必须设计 #4: the declared section applies to volumes too, in the SAME box-local frame the centre ray uses, so a
		# module the round is wide enough for is met even when the centre line passes beside it. The centre ray always wins,
		# so one item is still one interval per episode, and exhausting the declared budget reports incomplete.
		var local_offsets: Array[Vector3] = [Vector3.ZERO]
		for world_offset in section_offsets:
			local_offsets.append(box_world.basis.inverse()*world_offset)
		var r: Dictionary = {}
		for ray_index in local_offsets.size():
			if ray_casts >= RAY_BUDGET:
				diagnostics.append("ray_budget_exhausted at %s %s (budget %d)" % [kind,item.id,RAY_BUDGET])
				complete = false
				break
			ray_casts += 1
			var off: Vector3 = local_offsets[ray_index]
			var q := TranslationSweep.box_query(local_from+off, local_to+off, item.size_m) if moving else QueryGeometry.segment_box_local(local_from+off, local_to+off, item.size_m)
			if not q.get("ok", false):
				diagnostics.append("%s %s: box query error: %s" % [kind, item.id, str(q.get("error", "unknown"))])
				complete = false
				break
			if not q.get("hit", false):
				continue
			if r.is_empty() or float(q["t_enter"]) < float(r.get("t_enter", INF)):
				r = q
			if ray_index == 0:
				break
		if not r.get("ok", false):
			continue
		if not r.get("hit", false):
			continue
		var t_enter: float = r["t_enter"]
		var t_exit: float = r["t_exit"]
		box_world = TranslationSweep.part_transform(snapshot, item.part_id, lerpf(fractions.x, fractions.y, t_enter)) * item.local_box_transform
		var id_key := "module_id" if kind == "module" else "crew_id"
		var item_id: String = item.id
		var interval := {
			"kind": kind,
			"entity_id": entity_id,
			"life_id": life_id,
			"part_id": item.part_id,
			id_key: item_id,
			"t_enter": t_enter,
			"target_generation":snapshot.get("target_generation",-1),
			"t_exit": t_exit,
			"distance_enter_m": seg_length * t_enter,
			"distance_exit_m": seg_length * t_exit,
			"starts_inside": r.get("starts_inside", false),
			"grazing": r.get("grazing", false),
			"external": item.external if kind == "module" else false,
			"distance_m": seg_length * t_enter,
			"t": t_enter,
			"point_world": from_world.lerp(to_world,t_enter),
			"event_type": "enter",
			"box_world_transform": box_world,
			"box_size_m": item.size_m,
		}
		if moving:
			interval["motion_fraction"] = lerpf(fractions.x, fractions.y, t_enter)
		intervals.append(interval)
		if r.get("grazing", false):
			# 擦边/沿表面退化接触——UI 区分，不当作穿过有效体积
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"touch", t_enter, from_world, to_world, seg_length, Vector3.ZERO, false, lerpf(fractions.x, fractions.y, t_enter) if moving else -1.0))
			continue
		if r.get("has_entry_boundary", false):
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"enter", t_enter, from_world, to_world, seg_length,
				(box_world.basis * (r["normal_enter_local"] as Vector3)).normalized(), true, lerpf(fractions.x, fractions.y, t_enter) if moving else -1.0))
		if r.get("has_exit_boundary", false):
			events.append(_box_event(kind, id_key, item_id, snapshot, item.part_id,
				"exit", t_exit, from_world, to_world, seg_length,
				(box_world.basis * (r["normal_exit_local"] as Vector3)).normalized(), true, lerpf(fractions.x, fractions.y, t_exit) if moving else -1.0))
	return complete


static func _box_event(
		kind: String, id_key: String, item_id: String, snapshot: Dictionary,
		part_id: String, event_type: String, t: float,
		from_world: Vector3, to_world: Vector3, seg_length: float,
		normal_world: Vector3, normal_known: bool, motion_fraction: float = -1.0
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
	if motion_fraction >= 0.0:
		ev["motion_fraction"] = motion_fraction
		ev["target_generation"] = snapshot.get("target_generation", -1)
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


static func event_less(ev_a: Dictionary, ev_b: Dictionary) -> bool:
	# 005-R1 收尾 C：唯一权威排序比较器——真实 distance_m 严格比较（无容差），
	# 完全相同距离用确定性 event_key 打破平局。供服务排序与 ordered_contacts 使用。
	var da: float = float(ev_a.get("distance_m", 0.0))
	var db: float = float(ev_b.get("distance_m", 0.0))
	if da != db:
		return da < db
	return event_key(ev_a) < event_key(ev_b)


static func event_key(ev: Dictionary) -> String:
	# 确定性身份键：[kind, entity_id, life_id, part_id, item_id, event_type]
	return JSON.stringify([
		str(ev.get("kind", "")),
		str(ev.get("entity_id", "")),
		int(ev.get("life_id", 0)),
		str(ev.get("part_id", "")),
		str(ev.get("surface_id", ev.get("module_id", ev.get("crew_id", "")))),
		str(ev.get("event_type", "")),
	])
