class_name Lineup
extends RefCounted

static func validate(ids: Array, selected: String, mode: String, unlocked: Array) -> Dictionary:
	if mode not in ["training","normal"]: return {"ok":false,"reason":"模式不可用"}
	if ids.is_empty() or ids.size() > 3: return {"ok":false,"reason":"编成需要1至3辆车"}
	var unique := {}
	for id in ids:
		if not id is String or id not in VehicleCatalog.IDS or unique.has(id): return {"ok":false,"reason":"编成包含无效或重复车型"}
		if mode == "normal" and id not in unlocked: return {"ok":false,"reason":"正式模式编成含未研发车辆"}
		unique[id] = true
	if not unique.has(selected): return {"ok":false,"reason":"首发车辆必须在编成内"}
	return {"ok":true,"ids":ids.duplicate()}
