class_name Lineup
extends RefCounted

static func validate(ids: Array, selected: String, mode: String, unlocked: Array) -> Dictionary:
	if mode not in ["training","normal"]: return {"ok":false,"reason":LocalizationService.text("ui_4cd6f540a18b")}
	if ids.is_empty() or ids.size() > 3: return {"ok":false,"reason":LocalizationService.text("ui_5154404a5df0")}
	var unique := {}
	for id in ids:
		if not id is String or id not in VehicleCatalog.IDS or unique.has(id): return {"ok":false,"reason":LocalizationService.text("ui_13e13846e3bc")}
		if mode == "normal" and id not in unlocked: return {"ok":false,"reason":LocalizationService.text("ui_2312f5fc2964")}
		unique[id] = true
	if not unique.has(selected): return {"ok":false,"reason":LocalizationService.text("ui_570e5fa50459")}
	return {"ok":true,"ids":ids.duplicate()}
