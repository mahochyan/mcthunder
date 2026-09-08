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
	# 004-R2-C：来源按身份、字段和状态绑定；缺失登记不静默绕过。
	# research/production 布局必须有字段依据登记文件（缺失=明确数据错误）；
	# test 布局允许无来源文件。程序只检查记录一致性，不宣布史料事实正确。
	if layout.content_tier == "test":
		return
	if field_evidence_doc.is_empty():
		errors.append(_err("evidence", "field evidence registry missing for %s layout (configs/evidence/<identity>.json)" % layout.content_tier))
		return
	var keys_in_doc: Dictionary = {}
	for ek in field_evidence_doc.get("evidence_keys", []):
		if ek is Dictionary and ek.has("key"):
			keys_in_doc[str(ek["key"])] = ek
	var fields_in_doc: Array = field_evidence_doc.get("fields", [])

	# 每个对象：evidence key 必须登记 + 身份适用（包含/排除列表）
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

	# 字段级绑定：声明的字段状态必须有字段记录背书（状态一致 + 来源可解析 + 身份适用）。
	# 005-a：字段请求用具体 ID（armor_patches.hull_front_upper.thickness_mm）；
	# 通配符只属于来源记录的匹配模式，不属于待验证对象的身份。
	idx = 0
	for patch in layout.armor_patches:
		if patch != null and patch.thickness_status != "unknown":
			validate_field_claim(layout.historical_identity_id, "armor_patches.%s.thickness_mm" % patch.id,
				patch.thickness_status, fields_in_doc, keys_in_doc, patch.evidence_keys,
				"armor_patches[%d].thickness_status" % idx, errors)
		idx += 1
	idx = 0
	for station in layout.crew_stations:
		if station == null:
			idx += 1
			continue
		if station.role_placement_status != "unknown":
			validate_field_claim(layout.historical_identity_id, "crew_stations.%s.role_placement" % station.id,
				station.role_placement_status, fields_in_doc, keys_in_doc, station.evidence_keys,
				"crew_stations[%d].role_placement_status" % idx, errors)
		if station.position_status != "unknown":
			validate_field_claim(layout.historical_identity_id, "crew_stations.%s.local_box_transform" % station.id,
				station.position_status, fields_in_doc, keys_in_doc, station.evidence_keys,
				"crew_stations[%d].position_status" % idx, errors)
		if station.volume_status != "unknown":
			validate_field_claim(layout.historical_identity_id, "crew_stations.%s.size_m" % station.id,
				station.volume_status, fields_in_doc, keys_in_doc, station.evidence_keys,
				"crew_stations[%d].volume_status" % idx, errors)
		idx += 1


static func validate_field_claim(
		identity_id: String,
		field_path: String,
		declared_status: String,
		fields_in_doc: Array,
		keys_in_doc: Dictionary,
		referenced_sources: PackedStringArray,
		claim_path: String,
		errors: PackedStringArray
	) -> void:
	# 004-R2-C：固定顺序——字段记录存在并覆盖 → 状态一致 → source_refs 可解析 →
	# 身份适用（包含+排除）→ 历史 verified 不能由 game_rule/test_fixture/warthunder_reference 背书。
	# 005-a：字段请求是具体路径（armor_patches.<id>.thickness_mm）；来源记录可用通配
	# （armor_patches.*.thickness_mm）。精确记录优先于通配记录；同等具体程度的冲突记录报错。
	var matches: Array = []
	for f in fields_in_doc:
		if f is Dictionary and _field_path_matches(str(f.get("field_path", "")), field_path):
			matches.append(f)
	if matches.is_empty():
		errors.append(_err(claim_path, "no field evidence record covers '%s'" % field_path))
		return
	# 具体程度 = 记录路径中通配段数（0 = 最具体）
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _wildcard_count(str(a.get("field_path", ""))) < _wildcard_count(str(b.get("field_path", "")))
	)
	var best: Dictionary = matches[0]
	var best_wild := _wildcard_count(str(best.get("field_path", "")))
	var conflicts: Array = []
	for f in matches:
		if _wildcard_count(str(f.get("field_path", ""))) == best_wild and f != best:
			conflicts.append(str(f.get("field_path", "")))
	if not conflicts.is_empty():
		errors.append(_err(claim_path, "conflicting field records at same specificity for '%s': %s" % [field_path, ", ".join(conflicts)]))
		return
	var field_record: Dictionary = best
	if str(field_record.get("status", "")) != declared_status:
		errors.append(_err(claim_path, "declared status '%s' conflicts with field record status '%s' for '%s'" % [declared_status, str(field_record.get("status", "")), field_path]))
		return
	var refs: Array = field_record.get("source_refs", [])
	if refs.is_empty():
		errors.append(_err(claim_path, "field record '%s' has no source_refs" % field_path))
		return
	for ref in refs:
		var ref_key := str(ref)
		if not keys_in_doc.has(ref_key):
			errors.append(_err(claim_path, "field record '%s' references unregistered source '%s'" % [field_path, ref_key]))
			continue
		var ek: Dictionary = keys_in_doc[ref_key]
		if not _identity_applies(identity_id, ek):
			errors.append(_err(claim_path, "source '%s' does not apply to identity '%s'" % [ref_key, identity_id]))
		if declared_status == "verified" and str(ek.get("origin", "")) in ["game_rule", "test_fixture", "warthunder_reference"]:
			errors.append(_err(claim_path, "verified claim '%s' backed by non-historical source '%s' (origin %s)" % [field_path, ref_key, str(ek.get("origin", ""))]))
	# 对象自身引用的来源也必须身份适用（防错误车型来源挂到本车）
	for key in referenced_sources:
		if not keys_in_doc.has(key):
			continue
		if not _identity_applies(identity_id, keys_in_doc[key]):
			errors.append(_err(claim_path, "evidence key '%s' does not apply to identity '%s'" % [key, identity_id]))


static func _wildcard_count(path: String) -> int:
	var count := 0
	for seg in path.split("."):
		if seg == "*":
			count += 1
	return count


static func _identity_applies(identity_id: String, ek: Dictionary) -> bool:
	# 机器可检查的身份适用：applies_to_identity_ids 包含 + excluded_identity_ids 不包含。
	# 005-a：research/production 缺机器身份列表 → 不适用（不回退自由文本匹配）；
	# 调用方（_check_keys / validate_field_claim）据此报错。
	var includes: Array = ek.get("applies_to_identity_ids", [])
	var excludes: Array = ek.get("excluded_identity_ids", [])
	if includes.is_empty() and excludes.is_empty():
		return false
	return includes.has(identity_id) and not excludes.has(identity_id)


static func _field_path_matches(pattern: String, path: String) -> bool:
	# * 只匹配一个路径段（不跨段）。
	var p_parts := pattern.split(".")
	var f_parts := path.split(".")
	if p_parts.size() != f_parts.size():
		return false
	for i in range(p_parts.size()):
		if p_parts[i] == "*":
			continue
		if p_parts[i] != f_parts[i]:
			return false
	return true


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
		if not _identity_applies(layout.historical_identity_id, ek):
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
		if not is_finite(module.max_integrity) or module.max_integrity <= 0:
			errors.append(_err(path + ".max_integrity", "must be finite and positive"))
		if not is_finite(module.resistance_mm) or module.resistance_mm <= 0:
			errors.append(_err(path + ".resistance_mm", "must be finite and positive"))
		for field in ["fire_module_targets","fire_crew_targets"]:
			var seen_links: Dictionary = {}
			for target_id in module.get(field):
				var exists := false
				var candidates: Array = layout.modules if field == "fire_module_targets" else layout.crew_stations
				for candidate in candidates:
					if candidate != null and candidate.id == target_id: exists = true
				if not exists or seen_links.has(target_id):
					errors.append(_err(path + "." + field,"unknown or duplicate target '%s'" % target_id))
				seen_links[target_id] = true
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
	# 004-R2-B：声明重叠需要有效对象（模块/乘员 id 存在）与非空理由
	var known_ids := PackedStringArray()
	for module in layout.modules:
		if module != null:
			known_ids.append(module.id)
	for station in layout.crew_stations:
		if station != null:
			known_ids.append(station.id)
	for ov in layout.allowed_overlaps:
		if ov == null or not ov.has("a") or not ov.has("b"):
			warnings.append(_warn("allowed_overlaps", "entry missing 'a'/'b' object ids"))
			continue
		var reason: String = str(ov.get("reason", ""))
		if reason.is_empty():
			warnings.append(_warn("allowed_overlaps", "entry %s<->%s has empty reason" % [str(ov["a"]), str(ov["b"])]))
			continue
		if not known_ids.has(str(ov["a"])) or not known_ids.has(str(ov["b"])):
			warnings.append(_warn("allowed_overlaps", "entry references unknown object id (%s<->%s)" % [str(ov["a"]), str(ov["b"])]))
			continue
		var pair := [str(ov["a"]), str(ov["b"])]
		pair.sort()
		declared[pair[0] + "|" + pair[1]] = reason

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
	# 004-R2-B：包含语义（encloses）——方盒必须整体在车辆范围 AABB 内才算"在界内"；
	# 相交只用于可疑重叠提示。外扩余量由 _vehicle_bounds 统一加 0.1m，这里不再重复扩。
	var mn := corners[0]
	var mx := corners[0]
	for c in corners:
		mn = mn.min(c)
		mx = mx.max(c)
	var bmin: Vector3 = bounds["min"]
	var bmax: Vector3 = bounds["max"]
	return mn.x >= bmin.x and mx.x <= bmax.x \
		and mn.y >= bmin.y and mx.y <= bmax.y \
		and mn.z >= bmin.z and mx.z <= bmax.z


static func check_declared_openings(
		layout: VehicleLayoutDefinition,
		errors: PackedStringArray,
		warnings: PackedStringArray
	) -> void:
	# 004-R2-B：开口必须匹配"相邻边"，非流形不可豁免。
	# 1) 入口短路：面片索引/几何检查失败时不进入依赖有效索引的边界遍历。
	# 2) 边分类（坐标焊合）：f==1 and r==1 → 内部边；f+r != 1 → 重复/绕向/非流形
	#    ERROR（不可由开口声明豁免）；f+r == 1 → 真边界边，必须匹配 declared_edges。
	# 3) declared_edges 只由 boundary_loop 相邻顶点对生成（loop[i]-loop[i+1]、
	#    loop[last]-loop[0]），不生成环内两两组合；声明检查所属部件/至少 3 有效
	#    顶点/连续边非零/声明边确实对应模型边界。
	var part_ids := PackedStringArray()
	for part in layout.parts:
		if part != null:
			part_ids.append(part.id)

	# --- 入口短路：索引与几何有效性 ---
	for patch in layout.armor_patches:
		if patch == null:
			continue
		var path := "armor_patches.%s" % patch.id
		if patch.triangles.size() % 3 != 0:
			errors.append(_err(path + ".triangles", "index count not a multiple of 3"))
			return
		for t in patch.triangles:
			if t < 0 or t >= patch.vertices_local_m.size():
				errors.append(_err(path + ".triangles", "index %d out of bounds (vertex count %d)" % [t, patch.vertices_local_m.size()]))
				return
		var geo := ArmorPatchMesh.validate_geometry(patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		if not geo.is_empty():
			errors.append(_err(path, "geometry invalid (%s); boundary traversal skipped" % geo[0]))
			return

	# --- 边分类（按 part，坐标焊合） ---
	var boundary_by_part: Dictionary = {}   # part_id -> Array of {"a": Vector3, "b": Vector3}
	var manifold_errors: PackedStringArray = []
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
			if f == 1 and r == 1:
				continue   # 正常内部边
			if f + r != 1:
				# 重复面/绕向/非流形——不能由开口声明豁免
				manifold_errors.append("armor_patches(part %s): duplicate, miswound or non-manifold edge (%s -> %s) f=%d r=%d" % [part.id, str(coord_of[ak]), str(coord_of[bk]), f, r])
				continue
			edges.append({"a": coord_of[ak], "b": coord_of[bk]})
		if not edges.is_empty():
			boundary_by_part[part.id] = edges

	for me in manifold_errors:
		errors.append(_err("", me))

	if boundary_by_part.is_empty():
		return

	# --- declared_edges：只由 boundary_loop 相邻顶点对生成（按 part 隔离） ---
	# 005-a：declared_edges_by_part[part_id][edge_key]——不同部件的局部坐标可能相同，
	# 车体上的开口声明不得豁免炮塔上的同坐标边。
	var declared_edges_by_part: Dictionary = {}   # part_id -> {edge_key -> opening id}
	for opening in layout.declared_openings:
		if opening == null:
			continue
		var oid: String = str(opening.get("id", "?"))
		var pid: String = str(opening.get("part", ""))
		var loop: Array = opening.get("boundary_loop", [])
		if loop.is_empty():
			errors.append(_err("declared_openings.%s" % oid, "missing boundary_loop (must reference concrete opening loop vertices)"))
			continue
		if not part_ids.has(pid):
			errors.append(_err("declared_openings.%s" % oid, "part '%s' does not exist" % pid))
			continue
		if loop.size() < 3:
			errors.append(_err("declared_openings.%s" % oid, "boundary_loop needs at least 3 vertices, got %d" % loop.size()))
			continue
		var pts := PackedVector3Array()
		for p in loop:
			pts.append(p)
		var bad := false
		for i in range(pts.size()):
			if not pts[i].is_finite():
				errors.append(_err("declared_openings.%s" % oid, "boundary_loop vertex %d not finite" % i))
				bad = true
				break
			if pts[i].is_equal_approx(pts[(i + 1) % pts.size()]):
				errors.append(_err("declared_openings.%s" % oid, "boundary_loop consecutive vertices %d and %d coincide (zero-length edge)" % [i, (i + 1) % pts.size()]))
				bad = true
				break
		if bad:
			continue
		var part_edges: Dictionary = declared_edges_by_part.get_or_add(pid, {})
		for i in range(pts.size()):
			var a := _coord_key(pts[i])
			var b := _coord_key(pts[(i + 1) % pts.size()])
			part_edges[a + ">" + b] = oid
			part_edges[b + ">" + a] = oid
		# 声明边必须确实对应模型边界（该 part 存在边界边集合）
		if not boundary_by_part.has(pid):
			warnings.append(_warn("declared_openings.%s" % oid, "declared on part '%s' which has no boundary edges (shell closed there)" % pid))
			continue
		var part_boundary: Array = boundary_by_part[pid]
		var any_matched := false
		for e in part_boundary:
			if part_edges.has(_coord_key(e["a"]) + ">" + _coord_key(e["b"])):
				any_matched = true
				break
		if not any_matched:
			warnings.append(_warn("declared_openings.%s" % oid, "declared boundary_loop does not match any actual boundary edge on part '%s'" % pid))

	# --- 边界边必须被声明覆盖（按 part 隔离查表） ---
	for pid in boundary_by_part.keys():
		var edges: Array = boundary_by_part[pid]
		var part_edges: Dictionary = declared_edges_by_part.get(pid, {})
		for e in edges:
			var ek := _coord_key(e["a"]) + ">" + _coord_key(e["b"])
			if not part_edges.has(ek):
				errors.append(_err("armor_patches(part %s)" % pid, "undeclared boundary edge (%s -> %s)" % [str(e["a"]), str(e["b"])]))


static func _coord_key(v: Vector3) -> String:
	return "%0.4f|%0.4f|%0.4f" % [v.x, v.y, v.z]


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
