class_name Lineup
extends RefCounted

static func validate(ids: Array, selected: String, mode: String, unlocked: Array, admitted_catalog: VehicleCatalog = null) -> Dictionary:
	if mode not in ["training","normal","engineering"]: return {"ok":false,"code":"mode_restricted","reason":LocalizationService.text("ui_4cd6f540a18b")}
	if ids.is_empty() or ids.size() > 3: return {"ok":false,"code":"lineup_size","reason":LocalizationService.text("ui_5154404a5df0")}
	var catalog := admitted_catalog if admitted_catalog != null else VehicleCatalog.new()
	var profile := {"unlocked":unlocked}
	var unique := {}
	for id in ids:
		if not id is String or unique.has(id): return {"ok":false,"code":"unknown_vehicle","reason":LocalizationService.text("ui_13e13846e3bc")}
		if mode == "engineering" and id not in VehicleCatalog.ENGINEERING_IDS: return {"ok":false,"code":"mode_restricted","reason":"现代河谷编成仅接受已准入的 T-80B 与豹 2A4。"}
		# WT-031-R1: one shared gate for player, AI, first spawn, respawn and save restore.
		var checked := VehicleReadiness.eligible(id,mode,profile,catalog)
		if not checked.ok:
			var text := LocalizationService.text("ui_2312f5fc2964") if checked.code == "not_unlocked" else LocalizationService.text("ui_13e13846e3bc")
			return {"ok":false,"code":checked.code,"reason":text}
		unique[id] = true
	if not unique.has(selected): return {"ok":false,"code":"selection_mismatch","reason":LocalizationService.text("ui_570e5fa50459")}
	return {"ok":true,"code":"ok","ids":ids.duplicate()}
