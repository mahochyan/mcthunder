class_name LayoutValidator
extends RefCounted

# 004-a：布局三级校验——ERROR（不能加载）/ WARNING（可查看但必须显示记录）/
# INFO（说明或已声明的近似）。所有条目带字段路径定位。
# 返回 {"errors": [...], "warnings": [...], "infos": [...], "suspicious_overlaps": [...]}。

const CONTENT_TIERS := ["test", "research", "production"]
const JOINT_KINDS := ["fixed", "yaw", "pitch"]
const STATUS_VALUES := ["verified", "estimated", "unknown"]
const MATERIAL_KINDS := ["rolled", "cast", "unknown"]

const REQUIRED_HISTORICAL_ROLES := [
	"commander", "gunner", "loader", "driver", "assistant_driver_bow_gunner"
]


static func _err(path: String, msg: String) -> String:
	return "ERROR %s: %s" % [path, msg]


static func _warn(path: String, msg: String) -> String:
	return "WARNING %s: %s" % [path, msg]


static func _info(path: String, msg: String) -> String:
	return "INFO %s: %s" % [path, msg]


static func validate(layout: VehicleLayoutDefinition, evidence_keys: PackedStringArray = [], field_evidence_doc: Dictionary = {}) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var infos := PackedStringArray()
	var suspicious := PackedStringArray()

	if layout == null:
		return {"errors": PackedStringArray(["ERROR layout: null layout"]),
			"warnings": warnings, "infos": infos, "suspicious_overlaps": suspicious}

	# --- 头部 ---
	if layout.schema_version != 1:
		errors.append(_err("schema_version", "must be 1, got %d" % layout.schema_version))
	if layout.id.is_empty():
		errors.append(_err("id", "empty"))
	if layout.content_tier not in CONTENT_TIERS:
		errors.append(_err("content_tier", "must be one of %s, got '%s'" % [str(CONTENT_TIERS), layout.content_tier]))
	if layout.display_name.is_empty():
		errors.append(_err("display_name", "empty"))
	if layout.historical_identity_id.is_empty() and layout.content_tier != "test":
		errors.append(_err("historical_identity_id", "required for non-test content_tier"))

	# --- 004-R1 组B：全局 ID 唯一登记表（四类对象共用；空值/重复/跨类别冲突） ---
	var global_ids: Dictionary = {}   # id -> first field path
	_register_id(global_ids, "layout.id", layout.id, errors)

	# --- 部件：身份与引用 ---
	var part_ids: PackedStringArray = []
	var roots: PackedStringArray = []
	var idx := 0
	for part in layout.parts:
		var path := "parts[%d]" % idx
		if part == null:
			errors.append(_err(path, "null part"))
			idx += 1
			continue
		if part.id.is_empty():
			errors.append(_err(path + ".id", "empty"))
		elif part_ids.has(part.id):
			errors.append(_err(path + ".id", "duplicate id '%s'" % part.id))
		else:
			part_ids.append(part.id)
		_register_id(global_ids, path + ".id", part.id, errors)

		if part.parent_id.is_empty():
			roots.append(part.id)
		if part.joint_kind not in JOINT_KINDS:
			errors.append(_err(path + ".joint_kind", "unknown '%s'" % part.joint_kind))
		if part.joint_kind != "fixed":
			if not is_finite(part.min_angle_deg) or not is_finite(part.max_angle_deg):
				errors.append(_err(path + ".min_angle_deg", "non-finite joint limits"))
			elif part.min_angle_deg > part.max_angle_deg:
				errors.append(_err(path + ".min_angle_deg", "joint limits reversed"))
		if not LayoutMath.is_rigid(part.bind_local):
			errors.append(_err(path + ".bind_local", "not a finite rigid transform"))
		for key in part.evidence_keys:
			if not evidence_keys.has(key):
				errors.append(_err(path + ".evidence_keys", "unknown evidence key '%s'" % key))
		idx += 1

	if roots.size() == 0:
		errors.append(_err("parts", "no root part (parent_id empty)"))
	elif roots.size() > 1:
		errors.append(_err("parts", "multiple root parts: %s" % ", ".join(roots)))

	# 父部件存在 + 无循环引用（沿父链向上）
	idx = 0
	for part in layout.parts:
		if part == null:
			idx += 1
			continue
		var path := "parts[%d]" % idx
		if part.parent_id != "" and not part_ids.has(part.parent_id):
			errors.append(_err(path + ".parent_id", "parent '%s' does not exist" % part.parent_id))
		# 循环引用检测
		var seen := {part.id: true}
		var cur := part.parent_id
		var hops := 0
		while cur != "" and hops <= part_ids.size():
			if seen.has(cur):
				errors.append(_err(path + ".parent_id", "circular reference via '%s'" % cur))
				break
			seen[cur] = true
			var parent := _find_part(layout, cur)
			if parent == null:
				break
			cur = parent.parent_id
			hops += 1
		idx += 1

	# --- 装甲面片 ---
	var patch_ids: PackedStringArray = []
	idx = 0
	for patch in layout.armor_patches:
		var path := "armor_patches[%d]" % idx
		if patch == null:
			errors.append(_err(path, "null patch"))
			idx += 1
			continue
		if patch.id.is_empty():
			errors.append(_err(path + ".id", "empty"))
		elif patch_ids.has(patch.id):
			errors.append(_err(path + ".id", "duplicate id '%s'" % patch.id))
		else:
			patch_ids.append(patch.id)
		_register_id(global_ids, path + ".id", patch.id, errors)
		if patch.part_id == "" or not part_ids.has(patch.part_id):
			errors.append(_err(path + ".part_id", "unknown part '%s'" % patch.part_id))
		if patch.plate_group_id.is_empty():
			warnings.append(_warn(path + ".plate_group_id", "empty plate_group_id"))
		for status_val in [patch.geometry_status, patch.thickness_status]:
			if status_val not in STATUS_VALUES:
				errors.append(_err(path + ".geometry_status", "unknown status '%s'" % status_val))
		if patch.material_kind not in MATERIAL_KINDS:
			errors.append(_err(path + ".material_kind", "unknown '%s'" % patch.material_kind))
		for key in patch.evidence_keys:
			if not evidence_keys.has(key):
				errors.append(_err(path + ".evidence_keys", "unknown evidence key '%s'" % key))
		# 厚度：已知必须有限且 >0；未知不能冒充已核验
		if patch.has_thickness:
			if not is_finite(patch.thickness_mm) or patch.thickness_mm <= 0.0:
				errors.append(_err(path + ".thickness_mm", "declared thickness must be finite and > 0, got %s" % str(patch.thickness_mm)))
			if patch.thickness_status == "unknown":
				errors.append(_err(path + ".thickness_status", "has_thickness=true conflicts with unknown status"))
		else:
			if patch.thickness_status == "verified":
				errors.append(_err(path + ".thickness_status", "no thickness declared but status=verified"))
		var geo_errors := ArmorPatchMesh.validate_geometry(
			patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		for geo_err in geo_errors:
			errors.append(_err(path + ".geometry", "patch geometry invalid: %s" % geo_err))
		if patch.geometry_status == "verified" and geo_errors.size() > 0:
			errors.append(_err(path + ".geometry_status", "verified but geometry has errors"))
		# 已核验字段不能只有 TEST ONLY 或空来源
		if (patch.thickness_status == "verified" or patch.geometry_status == "verified") \
				and patch.evidence_keys.is_empty():
			errors.append(_err(path + ".evidence_keys", "verified fields require non-empty evidence"))
		idx += 1

	# --- 模块与乘员 ---
	validate_volumes(layout, part_ids, evidence_keys, global_ids, errors, warnings, infos)
	validate_crew(layout, part_ids, evidence_keys, global_ids, errors, warnings)

	# --- 004-R1 组C：来源一致性（research 布局引用的字段依据必须登记、适用、非夹具冒充） ---
	check_evidence_consistency(layout, field_evidence_doc, errors)

	# --- 空间布局：完整父链变换 + 实际部件范围 AABB 粗筛 + 可疑/已声明重叠区分 ---
	check_spatial(layout, part_ids, suspicious, warnings)

	# --- 004-R1 组B：declared_openings 必须指向具体边界环（research/production 布局；
	# test 夹具是独立浮动测试板，豁免——其边界全部是工程边界而非历史缺口） ---
	if layout.content_tier != "test":
		check_declared_openings(layout, errors, warnings)

	var result := {
		"errors": errors,
		"warnings": warnings,
		"infos": infos,
		"suspicious_overlaps": suspicious
	}
	return result


static func _find_part(layout: VehicleLayoutDefinition, part_id: String) -> LayoutPartDefinition:
	for part in layout.parts:
		if part != null and part.id == part_id:
			return part
	return null


static func check_evidence_consistency(
		layout: VehicleLayoutDefinition,
		field_evidence_doc: Dictionary,
		errors: PackedStringArray
	) -> void:
	# 004-R1 组C：research 布局的每个 evidence key 必须在字段依据字典中登记，
	# 且 origin 不是 test_fixture（夹具依据不得冒充历史 verified 来源），
	# applies_to 不得与历史身份冲突（"test fixtures only" 即不适用）。
	# 程序只检查记录一致性，不宣布史料事实正确（原文核验靠原页目视）。
	if layout.content_tier != "research" or field_evidence_doc.is_empty():
		return
	var keys_in_doc: Dictionary = {}
	for ek in field_evidence_doc.get("evidence_keys", []):
		if ek is Dictionary and ek.has("key"):
			keys_in_doc[str(ek["key"])] = ek
	var idx := 0
	for patch in layout.armor_patches:
		_check_keys(patch, "armor_patches[%d]" % idx, keys_in_doc, layout, errors)
		idx += 1
	idx = 0
	for module in layout.modules:
		_check_keys(module, "modules[%d]" % idx, keys_in_doc, layout, errors)
		idx += 1
	idx = 0
	for station in layout.crew_stations:
		_check_keys(station, "crew_stations[%d]" % idx, keys_in_doc, layout, errors)
		idx += 1
	idx = 0
	for part in layout.parts:
		_check_keys(part, "parts[%d]" % idx, keys_in_doc, layout, errors)
		idx += 1


static func _check_keys(item: Resource, path: String, keys_in_doc: Dictionary, layout: VehicleLayoutDefinition, errors: PackedStringArray) -> void:
	if item == null:
		return
	for key in item.evidence_keys:
		if not keys_in_doc.has(key):
			errors.append(_err(path + ".evidence_keys", "evidence key '%s' not present in field evidence registry" % key))
			continue
		var ek: Dictionary = keys_in_doc[key]
		if str(ek.get("origin", "")) == "test_fixture":
			errors.append(_err(path + ".evidence_keys", "test-fixture evidence '%s' must not back historical layout content" % key))
		var applies: String = str(ek.get("applies_to", ""))
		if applies == "" or applies.to_lower().contains("test fixtures only"):
			errors.append(_err(path + ".evidence_keys", "evidence '%s' does not apply to identity '%s'" % [key, layout.historical_identity_id]))


static func _register_id(global_ids: Dictionary, path: String, id: String, errors: PackedStringArray) -> void:
	# 004-R1 组B：全局唯一登记。空值/重复均报错；重复时报告第一次与第二次出现的字段路径。
	if id.is_empty():
		return
	if global_ids.has(id):
		errors.append(_err(path, "duplicate id '%s' (first occurrence at %s)" % [id, global_ids[id]]))
	else:
		global_ids[id] = path


static func geo_err_paths(path: String, geo_errors: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for e in geo_errors:
		out.append(_err(path + "." + e, "patch geometry invalid"))
	return out


static func validate_volumes(
		layout: VehicleLayoutDefinition,
		part_ids: PackedStringArray,
		evidence_keys: PackedStringArray,
		global_ids: Dictionary,
		errors: PackedStringArray,
		warnings: PackedStringArray,
		infos: PackedStringArray
	) -> void:

	var idx := 0
	for module in layout.modules:
		var path := "modules[%d]" % idx
		if module == null:
			errors.append(_err(path, "null module"))
			idx += 1
			continue
		if module.id.is_empty():
			errors.append(_err(path + ".id", "empty"))
		_register_id(global_ids, path + ".id", module.id, errors)
		if module.kind.is_empty():
			errors.append(_err(path + ".kind", "empty"))
		if module.part_id == "" or not part_ids.has(module.part_id):
			errors.append(_err(path + ".part_id", "unknown part '%s'" % module.part_id))
		if not module.size_m.is_finite() or module.size_m.x <= 0.0 or module.size_m.y <= 0.0 or module.size_m.z <= 0.0:
			errors.append(_err(path + ".size_m", "all three axes must be finite and > 0"))
		if not LayoutMath.is_rigid(module.local_box_transform):
			errors.append(_err(path + ".local_box_transform", "not a finite rigid transform"))
		if module.geometry_status not in STATUS_VALUES:
			errors.append(_err(path + ".geometry_status", "unknown status '%s'" % module.geometry_status))
		for key in module.evidence_keys:
			if not evidence_keys.has(key):
				errors.append(_err(path + ".evidence_keys", "unknown evidence key '%s'" % key))
		if module.external:
			infos.append(_info(path, "external module '%s' excluded from interior checks" % module.id))
		idx += 1


static func validate_crew(
		layout: VehicleLayoutDefinition,
		part_ids: PackedStringArray,
		evidence_keys: PackedStringArray,
		global_ids: Dictionary,
		errors: PackedStringArray,
		warnings: PackedStringArray
	) -> void:

	var roles: PackedStringArray = []
	var idx := 0
	for station in layout.crew_stations:
		var path := "crew_stations[%d]" % idx
		if station == null:
			errors.append(_err(path, "null crew station"))
			idx += 1
			continue
		if station.id.is_empty():
			errors.append(_err(path + ".id", "empty"))
		_register_id(global_ids, path + ".id", station.id, errors)
		if station.role.is_empty():
			errors.append(_err(path + ".role", "empty"))
		elif roles.has(station.role):
			errors.append(_err(path + ".role", "duplicate role '%s'" % station.role))
		else:
			roles.append(station.role)
		if station.part_id == "" or not part_ids.has(station.part_id):
			errors.append(_err(path + ".part_id", "unknown part '%s'" % station.part_id))
		if not station.size_m.is_finite() or station.size_m.x <= 0.0 or station.size_m.y <= 0.0 or station.size_m.z <= 0.0:
			errors.append(_err(path + ".size_m", "all three axes must be finite and > 0"))
		if not LayoutMath.is_rigid(station.local_box_transform):
			errors.append(_err(path + ".local_box_transform", "not a finite rigid transform"))
		if station.position_status not in STATUS_VALUES:
			errors.append(_err(path + ".position_status", "unknown status '%s'" % station.position_status))
		if station.role_placement_status not in STATUS_VALUES:
			errors.append(_err(path + ".role_placement_status", "unknown status '%s'" % station.role_placement_status))
		if station.volume_status not in STATUS_VALUES:
			errors.append(_err(path + ".volume_status", "unknown status '%s'" % station.volume_status))
		# 004-R1 组C：research 布局要求岗位/相对方位有资料核验；
		# 坐标（position_status）不因岗位核验而自动升级——FM 只支持岗位方位。
		if layout.content_tier == "research" and station.role_placement_status != "verified":
			errors.append(_err(path + ".role_placement_status", "research layout requires verified role placement, got '%s'" % station.role_placement_status))
		if layout.content_tier == "research" and station.position_status == "verified" and station.role_placement_status != "verified":
			errors.append(_err(path + ".position_status", "verified coordinates require verified role placement"))
		for key in station.evidence_keys:
			if not evidence_keys.has(key):
				errors.append(_err(path + ".evidence_keys", "unknown evidence key '%s'" % key))
		idx += 1

	# 五名乘员齐全（historical/research 布局）
	if layout.content_tier == "research":
		for required in ["commander", "gunner", "loader", "driver", "assistant_driver_bow_gunner"]:
			if not roles.has(required):
				errors.append(_err("crew_stations", "historical layout missing crew role '%s'" % required))


static func check_spatial(
		layout: VehicleLayoutDefinition,
		part_ids: PackedStringArray,
		suspicious: PackedStringArray,
		warnings: PackedStringArray
	) -> void:

	# 004-R1 组B：模块/乘员方盒 = 所属部件沿父链组合的 bind 变换 × 局部方盒（零姿态）。
	# 越界粗筛用实际部件范围（本布局全部面片顶点的 AABB 外扩余量），不是统一 20 米球。
	# AABB 相交仅作可疑提示；allowed_overlaps 声明的配对归入"已声明"，与未声明区分。
	var vehicle_bounds := _vehicle_bounds(layout)
	var boxes: Dictionary = {}    # label(类别:id) -> corners
	var declared: Dictionary = {} # 配对 key "a|b"(sorted) -> reason
	for ov in layout.allowed_overlaps:
		if ov == null or not ov.has("a") or not ov.has("b"):
			continue
		var pair := [str(ov["a"]), str(ov["b"])]
		pair.sort()
		declared[pair[0] + "|" + pair[1]] = str(ov.get("reason", ""))

	var idx := 0
	for module in layout.modules:
		if module == null or module.external:
			idx += 1
			continue
		var corners := _module_world_corners(layout, module)
		if corners.is_empty():
			warnings.append(_warn("modules[%d]" % idx, "box corners unavailable (invalid transform or size)"))
			idx += 1
			continue
		boxes["module:" + module.id] = corners
		if vehicle_bounds.size() > 0 and not _inside_bounds(corners, vehicle_bounds):
			warnings.append(_warn("modules[%d].%s" % [idx, module.id], "module box outside actual vehicle armor bounds (coarse AABB check; not a verdict of physical intersection)"))
		idx += 1

	var cidx := 0
	for station in layout.crew_stations:
		if station == null:
			cidx += 1
			continue
		var corners2 := _crew_world_corners(layout, station)
		if corners2.is_empty():
			warnings.append(_warn("crew_stations[%d]" % cidx, "box corners unavailable (invalid transform or size)"))
			cidx += 1
			continue
		boxes["crew:" + station.id] = corners2
		if vehicle_bounds.size() > 0 and not _inside_bounds(corners2, vehicle_bounds):
			warnings.append(_warn("crew_stations[%d].%s" % [cidx, station.id], "crew box outside actual vehicle armor bounds (coarse AABB check; not a verdict of physical intersection)"))
		cidx += 1

	# 可疑重叠（包围盒相交，仅提示不断言真实穿插）；已声明配对单独归类
	var ids := boxes.keys()
	ids.sort()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if not _boxes_overlap(ids[i], boxes[ids[i]], ids[j], boxes[ids[j]]):
				continue
			var a: String = (ids[i] as String).split(":")[1]
			var b: String = (ids[j] as String).split(":")[1]
			var pair: Array = [a, b]
			pair.sort()
			var dkey: String = "%s|%s" % [pair[0], pair[1]]
			if declared.has(dkey):
				suspicious.append("DECLARED_OVERLAP %s <-> %s (allowed_overlaps: %s)" % [ids[i], ids[j], declared[dkey]])
			else:
				suspicious.append("SUSPICIOUS_OVERLAP %s <-> %s (bounding boxes intersect; confirm intentional via allowed_overlaps or refine geometry)" % [ids[i], ids[j]])


static func _part_world_bind(layout: VehicleLayoutDefinition, part_id: String) -> Transform3D:
	# 沿父链组合 bind_local（零姿态）；根的 bind 即其自身。
	var chain: Array[Transform3D] = []
	var cur := _find_part(layout, part_id)
	var hops := 0
	while cur != null and hops <= 32:
		chain.append(cur.bind_local)
		if cur.parent_id == "":
			break
		cur = _find_part(layout, cur.parent_id)
		hops += 1
	var out := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		out = out * chain[i]
	return out


static func _module_world_corners(layout: VehicleLayoutDefinition, module: ModuleVolumeDefinition) -> PackedVector3Array:
	return LayoutMath.box_world_corners(_part_world_bind(layout, module.part_id), module.local_box_transform, module.size_m)


static func _crew_world_corners(layout: VehicleLayoutDefinition, station: CrewStationDefinition) -> PackedVector3Array:
	return LayoutMath.box_world_corners(_part_world_bind(layout, station.part_id), station.local_box_transform, station.size_m)


static func _vehicle_bounds(layout: VehicleLayoutDefinition) -> Dictionary:
	# 实际车体范围 = 全部装甲面片顶点（各自 part 局部 → 根空间）的 AABB 外扩 0.1 m。
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for patch in layout.armor_patches:
		if patch == null:
			continue
		var pw := _part_world_bind(layout, patch.part_id)
		for v in patch.vertices_local_m:
			var w: Vector3 = pw * v
			mn = mn.min(w)
			mx = mx.max(w)
	if mn == Vector3.INF:
		return {}
	return {"min": mn - Vector3(0.1, 0.1, 0.1), "max": mx + Vector3(0.1, 0.1, 0.1)}


static func _inside_bounds(corners: PackedVector3Array, bounds: Dictionary) -> bool:
	# 粗筛：方盒 AABB 与车辆范围 AABB 相交即视为"在界内"（不是精确包含判定）
	var mn := corners[0]
	var mx := corners[0]
	for c in corners:
		mn = mn.min(c)
		mx = mx.max(c)
	var bmin: Vector3 = bounds["min"]
	var bmax: Vector3 = bounds["max"]
	return mn.x <= bmax.x and mx.x >= bmin.x \
		and mn.y <= bmax.y and mx.y >= bmin.y \
		and mn.z <= bmax.z and mx.z >= bmin.z


static func check_declared_openings(
		layout: VehicleLayoutDefinition,
		errors: PackedStringArray,
		warnings: PackedStringArray
	) -> void:
	# 004-R1 组B：收集全部面片边界边（按坐标焊合——面片间不共享索引），
	# 每 part 一组；每个 declared opening 必须给出 boundary_loop（开口内环顶点坐标），
	# 且其顶点能覆盖该 part 上的边界边；存在不被任何 opening 覆盖的边界边 → ERROR。
	var boundary_by_part: Dictionary = {}   # part_id -> Array of {"a": Vector3, "b": Vector3}
	for part in layout.parts:
		if part == null:
			continue
		var forward: Dictionary = {}   # 坐标 key "a_key>b_key" -> count（有向）
		var coord_of: Dictionary = {}  # key -> Vector3
		for patch in layout.armor_patches:
			if patch == null or patch.part_id != part.id:
				continue
			var vkeys: Array[String] = []
			for v in patch.vertices_local_m:
				var k := "%0.4f|%0.4f|%0.4f" % [v.x, v.y, v.z]
				vkeys.append(k)
				coord_of[k] = v
			var tris := patch.triangles
			for start in range(0, tris.size(), 3):
				for offset in range(3):
					var a: String = vkeys[tris[start + offset]]
					var b: String = vkeys[tris[start + ((offset + 1) % 3)]]
					forward[a + ">" + b] = int(forward.get(a + ">" + b, 0)) + 1
		var seen := {}
		var edges: Array = []
		for fwd_key in forward.keys():
			if seen.has(fwd_key):
				continue
			var pp := (fwd_key as String).split(">")
			var ak: String = pp[0]
			var bk: String = pp[1]
			var bwd_key: String = bk + ">" + ak
			seen[fwd_key] = true
			seen[bwd_key] = true
			var f := int(forward.get(fwd_key, 0))
			var r := int(forward.get(bwd_key, 0))
			if f != 1 or r != 1:
				edges.append({"a": coord_of[ak], "b": coord_of[bk]})
		if not edges.is_empty():
			boundary_by_part[part.id] = edges

	if boundary_by_part.is_empty():
		return

	# opening 的内环顶点集合（按 part）
	var opening_cover: Dictionary = {}   # part_id -> Array of PackedVector3Array
	for opening in layout.declared_openings:
		if opening == null:
			continue
		var pid: String = str(opening.get("part", ""))
		var loop: Array = opening.get("boundary_loop", [])
		if loop.is_empty():
			errors.append(_err("declared_openings.%s" % str(opening.get("id", "?")), "missing boundary_loop (must reference concrete opening loop vertices)"))
			continue
		var pts := PackedVector3Array()
		for p in loop:
			pts.append(p)
		if not boundary_by_part.has(pid):
			warnings.append(_warn("declared_openings.%s" % str(opening.get("id", "?")), "declared on part '%s' which has no boundary edges (shell closed there)" % pid))
			continue
		opening_cover.get_or_add(pid, []).append(pts)

	for pid in boundary_by_part.keys():
		var edges: Array = boundary_by_part[pid]
		var loops: Array = opening_cover.get(pid, [])
		for e in edges:
			var covered := false
			for pts in loops:
				var has_a := false
				var has_b := false
				for p in pts:
					if (p as Vector3).is_equal_approx(e["a"]):
						has_a = true
					if (p as Vector3).is_equal_approx(e["b"]):
						has_b = true
				if has_a and has_b:
					covered = true
					break
			if not covered:
				errors.append(_err("armor_patches(part %s)" % pid, "boundary edge (%s -> %s) is not covered by any declared opening boundary_loop" % [str(e["a"]), str(e["b"])]))


static func _find_root(layout: VehicleLayoutDefinition) -> LayoutPartDefinition:
	for part in layout.parts:
		if part != null and part.parent_id == "":
			return part
	return null


static func _boxes_overlap(id_a: String, corners_a: PackedVector3Array, id_b: String, corners_b: PackedVector3Array) -> bool:
	# AABB 相交（世界轴对齐包围盒），仅作可疑提示
	var min_a := corners_a[0]
	var max_a := corners_a[0]
	for c in corners_a:
		min_a = min_a.min(c)
		max_a = max_a.max(c)
	var min_b := corners_b[0]
	var max_b := corners_b[0]
	for corner in corners_b:
		min_b = min_b.min(corner)
		max_b = max_b.max(corner)
	return min_a.x <= max_b.x and max_a.x >= min_b.x \
		and min_a.y <= max_b.y and max_a.y >= min_b.y \
		and min_a.z <= max_b.z and max_a.z >= min_b.z


# --- T004-04：封闭几何边邻接检查 ---
# 每条内部边必须由两个三角形以相反方向共享（2-流形）；
# 只被一个三角形使用的有向边 = 边界边，必须出现在 declared_openings 中，
# 不能用"全局忽略"掩盖缺失。返回未声明的边界/非流形边 key 列表。

static func check_edge_adjacency(
		vertices: PackedVector3Array,
		triangles: PackedInt32Array
	) -> PackedStringArray:

	# 返回未匹配的有向边 key（"a>b"）与重边信息；空 = 完全封闭
	var problems := PackedStringArray()
	if triangles.size() % 3 != 0:
		problems.append("triangles: index count not a multiple of 3")
		return problems

	var forward: Dictionary = {}   # "a:b" -> count
	var backward: Dictionary = {}  # "b:a" -> count（forward 的反向）
	for start in range(0, triangles.size(), 3):
		for offset in range(3):
			var a := triangles[start + offset]
			var b := triangles[start + ((offset + 1) % 3)]
			if a < 0 or a >= vertices.size() or b < 0 or b >= vertices.size():
				problems.append("edge %d:%d index out of bounds" % [a, b])
				continue
			if a == b:
				problems.append("edge %d:%d degenerate (same vertex)" % [a, b])
				continue
			var fwd_key := "%d:%d" % [a, b]
			var bwd_key := "%d:%d" % [b, a]
			forward[fwd_key] = int(forward.get(fwd_key, 0)) + 1
			backward[bwd_key] = int(backward.get(bwd_key, 0)) + 1

	# 无向边统计：每条边必须恰好两个三角形、方向相反（各 1 次）。
	# 方向计数直接来自有向边字典（forward["a:b"] = a→b 方向三角形数）。
	var undirected: Dictionary = {}   # "lo:hi" -> [lo_to_hi_count, hi_to_lo_count]
	for fwd_key in forward.keys():
		var parts := (fwd_key as String).split(":")
		var a := int(parts[0])
		var b := int(parts[1])
		var lo := mini(a, b)
		var hi := maxi(a, b)
		var ukey := "%d:%d" % [lo, hi]
		var pair: Array = undirected.get(ukey, [0, 0])
		if a == lo:
			pair[0] += int(forward[fwd_key])   # lo→hi 方向
		else:
			pair[1] += int(forward[fwd_key])   # hi→lo 方向
		undirected[ukey] = pair
	for ukey in undirected.keys():
		var counts: Array = undirected[ukey]
		if counts[0] > 1 or counts[1] > 1:
			problems.append("edge %s shared by same-direction triangles (non-manifold)" % ukey)
		elif counts[0] != 1 or counts[1] != 1:
			problems.append("edge %s unmatched (boundary or miswound)" % ukey)
	return problems