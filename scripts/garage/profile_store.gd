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
	return {"schema_version":3,"tutorial":{"chapter":0,"completed":[]},"challenge_bests":{},"revision":0,"profile_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"research_points":100,"unlocked":[ResearchGraph.STARTER],"next_match":1,"pending":{},"receipts":{},
		"garage":{"mode":"training","selected_vehicle_id":ResearchGraph.STARTER,"map":"hill_village","difficulty":"normal","lineup":[ResearchGraph.STARTER],"loadouts":loadouts}}

func snapshot() -> Dictionary: return _data.duplicate(true)

func reset_progress() -> Dictionary:
	# Keep identity/revision and monotonically increasing match ids; old results cannot be re-awarded.
	var fresh := _fresh()
	fresh.profile_id = _data.profile_id; fresh.revision = _data.revision; fresh.next_match = _data.next_match
	return commit(fresh)

func validate(value: Dictionary) -> Dictionary:
	var keys := ["schema_version","tutorial","challenge_bests","revision","profile_id","research_points","unlocked","next_match","pending","receipts","garage"]
	if value.size() != keys.size(): return _bad(LocalizationService.text("ui_68c613b313e6"))
	for key in keys:
		if not value.has(key): return _bad(LocalizationService.text("ui_a97a82669cec"))
	if value.schema_version != 3: return _bad(LocalizationService.text("ui_202f00976ad5"))
	if not TutorialCatalog.validate(value.tutorial): return _bad(LocalizationService.text("tutorial_invalid_progress"))
	if not ChallengeScore.validate_bests(value.challenge_bests): return _bad(LocalizationService.text("ui_2d53e86beed1"))
	for key in ["schema_version","revision","research_points","next_match"]:
		if not value[key] is int or value[key] < 0 or value[key] > 1000000000: return _bad(LocalizationService.text("ui_a8a87b711ea9"))
	if value.next_match < 1: return _bad(LocalizationService.text("ui_7922b71f7c99"))
	if not value.profile_id is String or value.profile_id.length() != 32 or not value.profile_id.is_valid_hex_number(): return _bad(LocalizationService.text("ui_342c276bb290"))
	if not value.unlocked is Array or ResearchGraph.STARTER not in value.unlocked: return _bad(LocalizationService.text("ui_bb4b43e7f16b"))
	var unique := {}
	for id in value.unlocked:
		if not id is String or not ResearchGraph.NODES.has(id) or unique.has(id): return _bad(LocalizationService.text("ui_485c48a888d8"))
		unique[id] = true
		for parent in ResearchGraph.NODES[id].requires:
			if parent not in value.unlocked: return _bad(LocalizationService.text("ui_edc4f9cc34c7"))
	for field in ["pending","receipts"]:
		if not value[field] is Dictionary or value[field].size() > (16 if field == "pending" else 128): return _bad(LocalizationService.text("ui_b9b067aa625c"))
		for token in value[field]:
			if not token is String or not token.begins_with(value.profile_id+":"): return _bad(LocalizationService.text("ui_b5d96f5126e4"))
			var sequence: String = token.trim_prefix(value.profile_id+":")
			if not sequence.is_valid_int() or int(sequence) < 1 or int(sequence) >= value.next_match: return _bad(LocalizationService.text("ui_ce92baba78fe"))
			var row: Variant = value[field][token]
			if not row is Dictionary: return _bad(LocalizationService.text("ui_9f6872613013"))
			if field == "pending":
				if row.size()!=2 or row.get("mode")!="normal" or not row.get("vehicle_id") is String or row.vehicle_id not in value.unlocked: return _bad(LocalizationService.text("ui_1223488250c7"))
			elif row.size()!=2 or row.get("outcome") not in ["victory","defeat","draw","abandoned"] or not row.get("points") is int or row.points != ProgressionService.REWARDS[row.outcome]: return _bad(LocalizationService.text("ui_83b306b1c3fa"))
	for token in value.pending:
		if value.receipts.has(token): return _bad(LocalizationService.text("ui_044d5c97f3be"))
	if not value.garage is Dictionary or not value.garage.get("loadouts") is Dictionary: return _bad(LocalizationService.text("ui_704e5ef6fa4b"))
	for id in value.garage.loadouts:
		if id not in VehicleCatalog.IDS and id not in VehicleCatalog.ENGINEERING_IDS: return _bad(LocalizationService.text("ui_fc74cdab294b"))
	for id in VehicleCatalog.IDS:
		if not value.garage.loadouts.get(id) is Dictionary: return _bad(LocalizationService.text("ui_8c333e24339e"))
	for id in value.garage.loadouts:
		if not value.garage.loadouts[id] is Dictionary: return _bad(LocalizationService.text("ui_8c333e24339e"))
		var prepared := service.build_loadout(value.garage.loadouts[id])
		if not prepared.ok or prepared.loadout.vehicle_id != id: return _bad(LocalizationService.text("ui_027590f44079"))
	var battle := MatchConfig.build(value.garage,service,value.unlocked)
	if not battle.ok: return _bad(battle.reason)
	return {"ok":true}

func commit(candidate: Dictionary) -> Dictionary:
	if not writable: return _bad(problem)
	var checked := validate(candidate)
	if not checked.ok: return checked
	if candidate.revision != _data.revision or candidate.profile_id != _data.profile_id: return _bad(LocalizationService.text("ui_d16a26231239"))
	var next := candidate.duplicate(true)
	next.revision += 1
	if not _path.is_empty():
		var folder := ProjectSettings.globalize_path(_path).get_base_dir()
		if DirAccess.make_dir_recursive_absolute(folder) != OK: return _bad(LocalizationService.text("ui_00f54fa7e8ed"))
		var lock_path := ProjectSettings.globalize_path(_path+".lock")
		var lock := _acquire_lock(lock_path)
		if not lock.ok: return lock
		var disk := _latest()
		var result: Dictionary
		if disk.get("future",false): result = _bad(LocalizationService.text("profile_future"))
		elif disk.get("found",false) and (disk.data.revision != _data.revision or disk.data.profile_id != _data.profile_id): result = _bad(LocalizationService.text("ui_3242b1716223"))
		elif disk.get("corrupt",false) and not disk.get("found",false): result = _bad(LocalizationService.text("ui_8166cefd8a51"))
		else: result = _write_slot(next)
		_release_lock(lock_path)
		if not result.ok: return result
	_data = next
	return {"ok":true}

# Save-lock recovery (029 small item). GPT review ruling round two: elapsed age
# CANNOT prove the holder died — a suspended or slow process is alive, so age
# only supports a "suspected stale" message and never authorizes takeover.
# No existing lock is reclaimed, including another store in this process.
# owner.txt ("pid time nonce") is written at acquisition and
# the lock is only ever removed when this process demonstrably owns it.
const LOCK_SUSPECT_STALE_S := 10.0
var _held_lock := ""   # lock path this instance acquired, until it is released
var _held_owner := ""

func _acquire_lock(lock_path: String) -> Dictionary:
	if not _held_lock.is_empty(): return _bad("当前存档实例已有保存请求，未重复申请锁")
	if DirAccess.make_dir_absolute(lock_path) == OK:
		var stamp := FileAccess.open(lock_path.path_join("owner.txt"), FileAccess.WRITE)
		if stamp == null:
			DirAccess.remove_absolute(lock_path)   # an unstamped lock cannot state ownership: fail closed
			return _bad("无法写入存档锁信息，未开始保存")
		var owner := "%d %d %s" % [OS.get_process_id(), int(Time.get_unix_time_from_system()),Crypto.new().generate_random_bytes(32).hex_encode()]
		stamp.store_string(owner)
		stamp.flush()
		var write_error := stamp.get_error()
		stamp.close()
		if write_error != OK or FileAccess.get_file_as_string(lock_path.path_join("owner.txt")) != owner:
			return _bad("存档锁写入未确认，已保留锁且未开始保存")
		_held_lock = lock_path
		_held_owner = owner
		return {"ok":true}
	var info := _read_lock_owner(lock_path)
	if float(info.get("time",0)) > 0 and Time.get_unix_time_from_system()-float(info.time) > LOCK_SUSPECT_STALE_S:
		return _bad("存档正被占用：锁已超过 %d 秒，疑似遗留，但无法确认持有者已退出，未自动清理；请关闭其它游戏实例后重试" % int(LOCK_SUSPECT_STALE_S))
	return _bad("存档正被占用（另一实例正在写入），请稍候重试")

static func _read_lock_owner(lock_path: String) -> Dictionary:
	var file := FileAccess.open(lock_path.path_join("owner.txt"), FileAccess.READ)
	if file == null: return {"pid":-1,"time":maxf(FileAccess.get_modified_time(lock_path),0.0)}
	var parts := file.get_as_text().split(" ")
	file.close()
	if parts.size() < 2: return {"pid":-1,"time":-1.0}   # half-written stamp: state unknowable, never delete
	return {"pid":int(parts[0]),"time":float(parts[1])}

func _release_lock(lock_path: String) -> void:
	if _held_lock != lock_path or _held_owner.is_empty(): return
	var stamp_path := lock_path.path_join("owner.txt")
	var owned := FileAccess.file_exists(stamp_path) and FileAccess.get_file_as_string(stamp_path) == _held_owner
	_held_lock = ""
	_held_owner = ""
	if not owned: return
	if DirAccess.remove_absolute(stamp_path) != OK: return
	DirAccess.remove_absolute(lock_path)

func _write_slot(value: Dictionary) -> Dictionary:
	var target := ProjectSettings.globalize_path(_path+"."+str(value.revision%2)+".json")
	var temporary := target+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return _bad(LocalizationService.text("ui_00de070dcf14"))
	file.store_string(JSON.stringify(value,"\t")); file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return _bad(LocalizationService.text("ui_cf9223913a6d"))
	var verified := _read(temporary)
	if not verified.ok or verified.data != value: return _bad(LocalizationService.text("ui_01fcf5537639"))
	# Only the older slot is replaced, while the last committed slot stays readable.
	if FileAccess.file_exists(target) and not _read(target).ok:
		var preserved := target+".corrupt-"+str(Time.get_ticks_usec())
		if DirAccess.copy_absolute(target,preserved)!=OK: return _bad(LocalizationService.text("settings_backup_failed"))
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK: return _bad(LocalizationService.text("ui_e12e2b675c61"))
	if DirAccess.rename_absolute(temporary,target) != OK: return _bad(LocalizationService.text("ui_a4869a80c43b"))
	return {"ok":true}

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1048576: return {"ok":false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return _bad(LocalizationService.text("ui_d289dfebe9e2"))
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {"ok":false}
	var normalized: Dictionary = _integers(parsed)
	var version: Variant = normalized.get("schema_version")
	if (version is int or version is float) and version>3: return {"ok":false,"future":true}
	# Schema 1 had exactly nine fields. Adding an empty best table preserves all
	# old data, and the complete schema-2 validation still rejects malformed slots.
	if normalized.get("schema_version") == 1 and normalized.size() == 9 and not normalized.has("challenge_bests"):
		normalized.schema_version = 2
		normalized.challenge_bests = {}
	if normalized.get("schema_version") == 2 and normalized.size() == 10 and not normalized.has("tutorial"):
		normalized.schema_version = 3
		normalized.tutorial = {"chapter":0,"completed":[]}
	var result := validate(normalized)
	return {"ok":true,"data":normalized} if result.ok else result

func _latest() -> Dictionary:
	var out := {"found":false,"corrupt":false}
	for slot in 2:
		var path := _path+"."+str(slot)+".json"
		if not FileAccess.file_exists(path): continue
		var read := _read(path)
		if read.get("future",false): out.future = true
		if not read.ok: out.corrupt = true; continue
		if not out.found or read.data.revision > out.data.revision: out.found = true; out.data = read.data
	return out

func _load() -> void:
	var latest := _latest()
	if latest.found: _data = latest.data
	if latest.corrupt:
		problem = LocalizationService.text("ui_2270e519845f") if latest.found else LocalizationService.text("ui_952c27139197")
		writable = latest.found
	if latest.get("future",false):
		problem = LocalizationService.text("profile_future"); writable = false

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
