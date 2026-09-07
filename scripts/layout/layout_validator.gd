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


static func validate(layout: VehicleLayoutDefinition, evidence_keys: PackedStringArray = []) -> Dictionary:
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
	validate_volumes(layout, part_ids, evidence_keys, errors, warnings, infos)
	validate_crew(layout, part_ids, evidence_keys, errors, warnings)

	# --- 空间布局：内部模块明显越界提示 + 可疑重叠 ---
	check_spatial(layout, part_ids, suspicious, warnings)

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


static func geo_err_paths(path: String, geo_errors: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for e in geo_errors:
		out.append(_err(path + "." + e, "patch geometry invalid"))
	return out


static func validate_volumes(
		layout: VehicleLayoutDefinition,
		part_ids: PackedStringArray,
		evidence_keys: PackedStringArray,
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
		if station.volume_status not in STATUS_VALUES:
			errors.append(_err(path + ".volume_status", "unknown status '%s'" % station.volume_status))
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

	# 内部模块包围盒与车辆根空间的大致范围检查：明显越界（离根原点 > 20 m）提示。
	# 用布局根（唯一根部件）的 bind 变换作为车辆局部参考。
	var root := _find_root(layout)
	if root == null:
		return
	var root_world := root.bind_local

	var boxes: Dictionary = {}
	var idx := 0
	for module in layout.modules:
		if module == null or module.external:
			idx += 1
			continue
		var corners := LayoutMath.box_world_corners(root_world, module.local_box_transform, module.size_m)
		if corners.is_empty():
			warnings.append(_warn("modules[%d]" % idx, "box corners unavailable (invalid transform or size)"))
			idx += 1
			continue
		boxes[module.id] = corners
		var far := false
		for corner in corners:
			if corner.length() > 20.0:
				far = true
				break
		if far:
			warnings.append(_warn("modules[%d].%s" % [idx, module.id], "interior module appears far outside vehicle bounds (> 20 m from origin)"))
		idx += 1

	# 可疑重叠（包围盒相交，仅提示不断言真实穿插）
	var ids := boxes.keys()
	ids.sort()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if _boxes_overlap(ids[i], boxes[ids[i]], ids[j], boxes[ids[j]]):
				suspicious.append("SUSPICIOUS_OVERLAP %s <-> %s (bounding boxes intersect; confirm intentional via allowed_overlaps or refine geometry)" % [ids[i], ids[j]])


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