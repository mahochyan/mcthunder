class_name LayoutCatalog
extends RefCounted

# 004-a：布局目录——通过稳定 layout_id 从 configs/layouts/ 加载结构定义。
# 历史/测试布局统一入口；加载即缓存，调用方不得写回共享定义。

const LAYOUT_DIR := "res://configs/layouts"

# 证据 key 注册表（加载时校验引用存在）。默认含测试夹具依据；
# 历史布局加载前应 register_evidence() 登记真实史料 key。
static var registered_evidence: PackedStringArray = PackedStringArray(["EV-TEST-FIXTURE"])


static func register_evidence(keys: PackedStringArray) -> void:
	for key in keys:
		if not registered_evidence.has(key):
			registered_evidence.append(key)


static func load_layout(layout_id: String) -> VehicleLayoutDefinition:
	# 返回 null = 加载失败（不存在/解析失败/校验拒绝）
	if layout_id.is_empty():
		push_error("LayoutCatalog: empty layout_id")
		return null
	if _cache.has(layout_id):
		return _cache[layout_id]

	var path := "%s/%s.tres" % [LAYOUT_DIR, layout_id]
	if not ResourceLoader.exists(path):
		push_error("LayoutCatalog: layout not found: %s (%s)" % [layout_id, path])
		return null

	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		push_error("LayoutCatalog: failed to load: %s" % path)
		return null
	if res is not VehicleLayoutDefinition:
		push_error("LayoutCatalog: not a VehicleLayoutDefinition: %s" % path)
		return null

	var layout := res as VehicleLayoutDefinition
	if layout.id != layout_id:
		push_error("LayoutCatalog: id mismatch file=%s vs resource=%s" % [layout_id, layout.id])
		return null

	var validation := LayoutValidator.validate(layout, registered_evidence)
	if validation["errors"].size() > 0:
		for e in validation["errors"]:
			push_error("LayoutCatalog: %s: %s" % [layout_id, e])
		return null
	for w in validation["warnings"]:
		push_warning("LayoutCatalog: %s: %s" % [layout_id, w])

	_cache[layout_id] = layout
	return layout


static func list_available() -> PackedStringArray:
	# 列出 configs/layouts/ 下可用布局 id（按文件名；不校验内容）
	var result := PackedStringArray()
	var dir := DirAccess.open(LAYOUT_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			result.append(fname.trim_suffix(".tres"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


static func clear_cache() -> void:
	_cache.clear()


static var _cache: Dictionary = {}