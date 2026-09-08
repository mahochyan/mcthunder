class_name ProfileStore
extends RefCounted
## Alternating validated save slots: the previous committed slot survives interrupted writes.
## Empty path is an explicitly isolated in-memory profile for automated fixtures.
const DEFAULT_PATH := "user://profiles/commander"
var _data: Dictionary = {}
var _path := ""
var service: GarageService
var problem := ""
var writable := true

func _init(path: String = "", garage_service: GarageService = null) -> void:
	service = garage_service if garage_service != null else GarageService.new()
	_path = path
	_data = _fresh()
	if not path.is_empty(): _load()

func _fresh() -> Dictionary:
	var loadouts := {}
	for id in VehicleCatalog.IDS: loadouts[id] = service.default_loadout(id)
	return {"schema_version":1,"revision":0,"profile_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"research_points":100,"unlocked":[ResearchGraph.STARTER],"next_match":1,"pending":{},"receipts":{},
		"garage":{"mode":"training","selected_vehicle_id":ResearchGraph.STARTER,"map":"hill_village","difficulty":"normal","lineup":[ResearchGraph.STARTER],"loadouts":loadouts}}

func snapshot() -> Dictionary: return _data.duplicate(true)

func validate(value: Dictionary) -> Dictionary:
	var keys := ["schema_version","revision","profile_id","research_points","unlocked","next_match","pending","receipts","garage"]
	if value.size() != keys.size(): return _bad("存档字段不匹配")
	for key in keys:
		if not value.has(key): return _bad("存档字段缺失")
	if value.schema_version != 1: return _bad("不支持的存档版本")
	for key in ["schema_version","revision","research_points","next_match"]:
		if not value[key] is int or value[key] < 0 or value[key] > 1000000000: return _bad("存档数值无效")
	if value.next_match < 1: return _bad("比赛序号无效")
	if not value.profile_id is String or value.profile_id.length() != 32 or not value.profile_id.is_valid_hex_number(): return _bad("存档身份无效")
	if not value.unlocked is Array or ResearchGraph.STARTER not in value.unlocked: return _bad("初始车辆缺失")
	var unique := {}
	for id in value.unlocked:
		if not id is String or not ResearchGraph.NODES.has(id) or unique.has(id): return _bad("研发记录无效")
		unique[id] = true
		for parent in ResearchGraph.NODES[id].requires:
			if parent not in value.unlocked: return _bad("研发依赖缺失")
	for field in ["pending","receipts"]:
		if not value[field] is Dictionary or value[field].size() > (16 if field == "pending" else 128): return _bad("结算记录超限")
		for token in value[field]:
			if not token is String or not token.begins_with(value.profile_id+":"): return _bad("比赛身份不匹配")
			var sequence: String = token.trim_prefix(value.profile_id+":")
			if not sequence.is_valid_int() or int(sequence) < 1 or int(sequence) >= value.next_match: return _bad("比赛序号越界")
			var row: Variant = value[field][token]
			if not row is Dictionary: return _bad("结算字段无效")
			if field == "pending":
				if row.size()!=2 or row.get("mode")!="normal" or not row.get("vehicle_id") is String or row.vehicle_id not in value.unlocked: return _bad("待结算配置无效")
			elif row.size()!=2 or row.get("outcome") not in ["victory","defeat","draw","abandoned"] or not row.get("points") is int or row.points != ProgressionService.REWARDS[row.outcome]: return _bad("收益记录无效")
	for token in value.pending:
		if value.receipts.has(token): return _bad("比赛重复登记")
	if not value.garage is Dictionary or not value.garage.get("loadouts") is Dictionary: return _bad("车库设置缺失")
	if value.garage.loadouts.size() != VehicleCatalog.IDS.size(): return _bad("配装记录缺失")
	for id in VehicleCatalog.IDS:
		if not value.garage.loadouts.get(id) is Dictionary: return _bad("配装格式无效")
		var prepared := service.build_loadout(value.garage.loadouts[id])
		if not prepared.ok or prepared.loadout.vehicle_id != id: return _bad("保存配弹无效")
	var battle := MatchConfig.build(value.garage,service,value.unlocked)
	if not battle.ok: return _bad(battle.reason)
	return {"ok":true}

func commit(candidate: Dictionary) -> Dictionary:
	if not writable: return _bad(problem)
	var checked := validate(candidate)
	if not checked.ok: return checked
	if candidate.revision != _data.revision or candidate.profile_id != _data.profile_id: return _bad("存档已更新，请重新载入")
	var next := candidate.duplicate(true)
	next.revision += 1
	if not _path.is_empty():
		var folder := ProjectSettings.globalize_path(_path).get_base_dir()
		if DirAccess.make_dir_recursive_absolute(folder) != OK: return _bad("无法创建存档目录")
		var lock_path := ProjectSettings.globalize_path(_path+".lock")
		if DirAccess.make_dir_absolute(lock_path) != OK: return _bad("存档正被占用；若上次异常退出，请关闭游戏后移除 commander.lock 空目录")
		var disk := _latest()
		var result: Dictionary
		if disk.get("found",false) and (disk.data.revision != _data.revision or disk.data.profile_id != _data.profile_id): result = _bad("另一实例已保存，请重新载入")
		elif disk.get("corrupt",false) and not disk.get("found",false): result = _bad("现有存档损坏，已保留原文件")
		else: result = _write_slot(next)
		DirAccess.remove_absolute(lock_path)
		if not result.ok: return result
	_data = next
	return {"ok":true}

func _write_slot(value: Dictionary) -> Dictionary:
	var target := ProjectSettings.globalize_path(_path+"."+str(value.revision%2)+".json")
	var temporary := target+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return _bad("无法写入存档；进度未变更")
	file.store_string(JSON.stringify(value,"\t")); file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return _bad("存档写入失败；进度未变更")
	var verified := _read(temporary)
	if not verified.ok or verified.data != value: return _bad("存档写后校验失败")
	# Only the older slot is replaced, while the last committed slot stays readable.
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK: return _bad("无法替换旧存档槽")
	if DirAccess.rename_absolute(temporary,target) != OK: return _bad("无法提交新存档槽")
	return {"ok":true}

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1048576: return {"ok":false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return _bad("存档JSON损坏")
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {"ok":false}
	var normalized: Dictionary = _integers(parsed)
	var result := validate(normalized)
	return {"ok":true,"data":normalized} if result.ok else result

func _latest() -> Dictionary:
	var out := {"found":false,"corrupt":false}
	for slot in 2:
		var path := _path+"."+str(slot)+".json"
		if not FileAccess.file_exists(path): continue
		var read := _read(path)
		if not read.ok: out.corrupt = true; continue
		if not out.found or read.data.revision > out.data.revision: out.found = true; out.data = read.data
	return out

func _load() -> void:
	var latest := _latest()
	if latest.found: _data = latest.data
	if latest.corrupt:
		problem = "一个存档槽损坏，已恢复上一份有效进度。" if latest.found else "存档损坏，已保留原文件；正式进度暂不可写。"
		writable = latest.found

static func _integers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value) and absf(value) <= 1000000000: return int(value)
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _integers(value[key])
		return out
	if value is Array:
		var out: Array = []
		for child in value: out.append(_integers(child))
		return out
	return value

static func _bad(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
