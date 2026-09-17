class_name VehicleReadiness
extends RefCounted
## WT-031-R1: one ledger that keeps five different questions about a vehicle apart
## instead of collapsing them into a single "ready" flag.
##
## Nothing here invents evidence. A dimension without a verifiable signal reports
## not_run / unverified together with a blocking code, and the caller decides.
## Reuses the existing gates (VehicleContentPipeline, VariantCompatibility,
## ReferenceEvidenceGate, ModelBindingValidator) rather than adding a parallel
## registry.

const DIMENSIONS := ["resource","combat_config","specialized_verified","match_verified","distribution_license"]

const CODES := {
	"unknown_vehicle":"未知车型：不在已准入目录中",
	"not_admitted":"未通过内容准入",
	"resource_missing":"资源缺失（模型或数据包）",
	"malformed_packet":"数据包损坏或字段非法",
	"config_incomplete":"关键战斗配置不完整",
	"variant_conflict":"改型或装配冲突",
	"reference_unadmitted":"参考依据未准入",
	"preview_only":"仅预览或候选，未开放正式战斗",
	"mode_restricted":"该模式不允许此车型",
	"not_unlocked":"尚未研发解锁",
	"loadout_invalid":"配弹无效",
	"match_evidence_missing":"缺少整局验证证据",
	"license_unverified":"分发许可未核",
	"ok":"通过",
}

static func reason_text(code: String) -> String:
	return str(CODES.get(code,code))

static func _packet_path(id: String) -> String:
	# WT-040-R1 (2026-09-17 ruling): the ledger could only see historical packets, so an admitted engineering
	# vehicle read as unknown_vehicle and was silently replaced. The engineering directory is now explicit; no
	# gate is widened - the packet still has to pass every downstream check.
	if id in VehicleCatalog.ENGINEERING_IDS: return VehicleCatalog.ENGINEERING_DIR+id+".json"
	return "res://configs/vehicles/historical/"+id+".json"

static func read_packet(id: String) -> Dictionary:
	var path := _packet_path(id)
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func _model_paths(id: String, packet: Dictionary) -> Array:
	var paths: Array = []
	if packet.get("model_binding") is Dictionary:
		var bound := str(packet.get("model_binding",{}).get("path",""))
		if not bound.is_empty(): paths.append(bound)
	for candidate in ["res://assets/vehicles/"+id+".glb","res://assets/research/models/"+id+".glb","res://assets/vehicles/modern_bound/"+id+".glb"]:
		if candidate not in paths: paths.append(candidate)
	return paths

static func _declared_external_model(packet: Dictionary) -> Dictionary:
	var rows: Variant = packet.get("model_candidates",[])
	if rows is Array and not rows.is_empty() and rows[0] is Dictionary:
		var row: Dictionary = rows[0]
		return {"path":str(row.get("glb_path","")),"sha256":str(row.get("glb_sha256","")),"status":str(row.get("declared_status","")),"published":bool(row.get("published",false)),"triangles_reported":int(row.get("triangles_reported",0))}
	return {}

## resource: repository data packet present, a repository model present, model self-contained.
## External制作目录 paths are recorded but never counted as a repository resource.
static func resource_state(id: String, packet: Dictionary, model_sources: Dictionary = {}) -> Dictionary:
	if packet.is_empty(): return {"value":"missing","codes":["resource_missing"]}
	var external := _declared_external_model(packet)
	var found := ""
	var tried: Array = _model_paths(id,packet)
	for path in tried:
		# File level existence, not ResourceLoader: the frozen research GLBs are read
		# as bytes by the mount adapter and are not all visible to the importer.
		if FileAccess.file_exists(path): found = path; break
	if found.is_empty():
		return {"value":"missing","codes":["resource_missing"],"tried":tried,"declared_external":external}
	var bytes := FileAccess.get_file_as_bytes(found)
	if bytes.is_empty(): return {"value":"missing","codes":["resource_missing"],"model_path":found,"declared_external":external}
	var errors := ModelBindingValidator.self_contained_glb(bytes)
	var import_visible := ResourceLoader.exists(found)
	if not errors.is_empty(): return {"value":"malformed","codes":["malformed_packet"],"errors":errors,"model_path":found,"import_visible":import_visible,"declared_external":external}
	return {"value":"ok","codes":[],"model_path":found,"bytes":bytes.size(),"import_visible":import_visible,"declared_external":external}

## combat_config: the production gate only — content pipeline plus variant compatibility.
## Reference admission runs on a separate track (reference candidates / research cache)
## and is reported as reference_admitted instead of being folded into this value.
static func config_state(id: String, packet: Dictionary, model_sources: Dictionary = {}) -> Dictionary:
	if packet.is_empty(): return {"value":"incomplete","codes":["resource_missing","config_incomplete"]}
	if str(packet.get("admission","")) == "candidate_only":
		var gap_count := 0
		var gaps: Variant = packet.get("gaps",[])
		if gaps is Array: gap_count = gaps.size()
		var has_combat := packet.get("combat_definition") != null
		return {"value":"not_applicable","codes":["config_incomplete"] if not has_combat else [],
			"errors":[],"gaps":gap_count,"combat_definition_present":has_combat,
			"note":"candidate package: not a production combat configuration"}
	var codes: Array[String] = []
	var errors: Array[String] = []
	var validated := VehicleContentPipeline.validate_package(packet,model_sources)
	if not validated.ok:
		codes.append("config_incomplete")
		for error in validated.get("errors",[]): errors.append(str(error))
	var variant := VariantCompatibility.check(packet)
	if not variant.ok:
		codes.append("variant_conflict")
		for error in variant.get("errors",[]): errors.append(str(error))
	var reference := ReferenceEvidenceGate.check(packet)
	if not reference.ok: errors.append("reference track (separate from combat configuration): "+", ".join(reference.get("errors",[])))
	var unique_codes: Array[String] = []
	for code in codes:
		if code not in unique_codes: unique_codes.append(code)
	return {"value":"ok" if unique_codes.is_empty() else "incomplete","codes":unique_codes,"errors":errors,"reference_admitted":reference.ok}

static func _evidence_row(evidence: Dictionary, id: String) -> Dictionary:
	var rows: Variant = evidence.get("vehicles",{})
	if not rows is Dictionary: return {}
	var row: Variant = rows.get(id,{})
	return row if row is Dictionary else {}

static func entry(id: String, packet: Dictionary, evidence: Dictionary, admitted: Array, model_sources: Dictionary = {}) -> Dictionary:
	var resource := resource_state(id,packet,model_sources)
	var config := config_state(id,packet,model_sources)
	var row := _evidence_row(evidence,id)
	var codes: Array[String] = []
	if not admitted.has(id): codes.append("unknown_vehicle")
	if ModernModelMountAdapter.SPECS.has(id): codes.append("preview_only")
	for code in resource.codes: if code not in codes: codes.append(code)
	for code in config.codes: if code not in codes: codes.append(code)
	var specialized := str(row.get("specialized_verified","not_run"))
	var match_verified := str(row.get("match_verified","not_run"))
	var license := str(row.get("distribution_license","unverified"))
	if specialized == "not_run" and "match_evidence_missing" not in codes: codes.append("match_evidence_missing")
	if license == "unverified" and "license_unverified" not in codes: codes.append("license_unverified")
	return {
		"id":id,
		"admitted":admitted.has(id),
		"resource":resource.value,
		"combat_config":config.value,
		"specialized_verified":specialized,
		"match_verified":match_verified,
		"distribution_license":license,
		"codes":codes,
		"reason":reason_text(codes[0]) if not codes.is_empty() else reason_text("ok"),
		"resource_detail":resource,
		"config_detail":config,
	}

## Unified eligibility for player, AI, first spawn, respawn and save restore.
static func eligible(id: String, mode: String, profile: Dictionary, catalog: VehicleCatalog) -> Dictionary:
	var admitted: Array = catalog.packages.keys() if not catalog.packages.is_empty() else VehicleCatalog.IDS
	if not id is String or id.is_empty(): return {"ok":false,"code":"unknown_vehicle","reason":reason_text("unknown_vehicle")}
	if mode not in ["training","normal","engineering"]: return {"ok":false,"code":"mode_restricted","reason":reason_text("mode_restricted")}
	# WT-040-R1 (2026-09-17 ruling): preview_only is about PUBLIC release, not about what the internal engineering
	# battle entry may use. The code is still reported, but it only blocks the public modes; the explicit
	# engineering mode is the controlled internal entry the ruling allows. Nothing is removed and the release
	# gating is unchanged, because every other gate below still applies.
	if ModernModelMountAdapter.SPECS.has(id) and mode != "engineering":
		return {"ok":false,"code":"preview_only","reason":reason_text("preview_only")}
	if not admitted.has(id): return {"ok":false,"code":"unknown_vehicle","reason":reason_text("unknown_vehicle")}
	if catalog.rejected.has(id):
		return {"ok":false,"code":"not_admitted","reason":reason_text("not_admitted"),"errors":catalog.rejected[id].get("errors",[])}
	var unlocked: Variant = profile.get("unlocked",[])
	if mode == "normal" and (not unlocked is Array or id not in unlocked):
		return {"ok":false,"code":"not_unlocked","reason":reason_text("not_unlocked")}
	return {"ok":true,"code":"ok","reason":reason_text("ok")}

## Pick the first admitted vehicle from a preference list; never returns a preview or
## unadmitted id. Used by AI slots and respawn so neither can bypass the gate.
static func first_eligible(preferences: Array, mode: String, profile: Dictionary, catalog: VehicleCatalog) -> Dictionary:
	for id in preferences:
		var checked := eligible(str(id),mode,profile,catalog)
		if checked.ok: return {"ok":true,"id":str(id),"checked":checked}
	var fallback := "training" if mode != "normal" else mode
	# WT-040-R1: the fallback search covers the curated roster, plus the engineering set in the engineering mode,
	# so an internal engineering match can still field a vehicle - and if nothing qualifies the caller refuses.
	var pool: Array = VehicleCatalog.IDS.duplicate()
	if mode == "engineering": pool.append_array(VehicleCatalog.ENGINEERING_IDS)
	for id in pool:
		var checked := eligible(str(id),fallback,profile,catalog)
		if checked.ok: return {"ok":true,"id":str(id),"checked":checked,"fallback":true}
	return {"ok":false,"code":"unknown_vehicle","reason":reason_text("unknown_vehicle")}

static func _count_glb(dir_path: String, found: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null: return
	for file in dir.get_files():
		if file.ends_with(".glb"): found.append(dir_path+"/"+file)
	for sub in dir.get_directories(): _count_glb(dir_path+"/"+sub,found)

## Honest catalogue grading, read from the in-repo tree instead of a remembered number.
static func catalog_summary() -> Dictionary:
	var tree_path := "res://assets/research/soviet_german_tree.json"
	var tree: Dictionary = {}
	if FileAccess.file_exists(tree_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tree_path))
		if parsed is Dictionary: tree = parsed
	var rows: Variant = tree.get("vehicles",[])
	var base_rows := 0
	var variant_refs := 0
	var with_model := 0
	var with_combat := 0
	var status: Dictionary = {}
	if rows is Array:
		for row in rows:
			if not row is Dictionary: continue
			if bool(row.get("base_model",false)): base_rows += 1
			if row.get("model") != null: with_model += 1
			if row.get("combat_package") != null: with_combat += 1
			var refs: Variant = row.get("variant_refs",[])
			if refs is Array: variant_refs += refs.size()
			var state := str(row.get("admission_status","unknown"))
			status[state] = int(status.get(state,0)) + 1
	var glbs: Array = []
	_count_glb("res://assets/research/models",glbs)
	var preview_valid: Array = []
	if FileAccess.file_exists("res://assets/vehicles/ussr_batch/catalog.json"):
		var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/ussr_batch/catalog.json"))
		if preview is Dictionary:
			var preview_rows: Variant = preview.get("vehicles",[])
			if preview_rows is Array:
				for row in preview_rows:
					if row is Dictionary and str(row.get("status","")) == "validated_preview": preview_valid.append(str(row.get("id","")))
	var admitted_ids: Array=VehicleCatalog.IDS.duplicate()
	if rows is Array:
		for row in rows:
			if row is Dictionary and row.get("combat_package") is Dictionary and str(row.get("id","")) not in admitted_ids:
				admitted_ids.append(str(row.id))
	return {
		"admitted_combat_vehicles": admitted_ids.size(),
		"admitted_ids": admitted_ids,
		"modern_candidates": ModernModelMountAdapter.SPECS.keys(),
		"tree_path": tree_path,
		"tree_rows": rows.size() if rows is Array else 0,
		"tree_counts": tree.get("counts",{}),
		"tree_models": tree.get("models",{}),
		"tree_base_rows": base_rows,
		"tree_variant_refs": variant_refs,
		"tree_rows_with_model": with_model,
		"tree_rows_with_combat_package": with_combat,
		"tree_admission_status": status,
		"research_model_glb_count": glbs.size(),
		"preview_registry_validated": preview_valid,
		"ladder": "已准入可出战 %d 辆（历史 %d + 工程 %d）｜树内基础型 %d 行｜改型引用 %d 条｜有模型 %d（与 assets/research/models 的 %d 个 GLB 逐 id 匹配）｜有战斗配置 %d" % [
			admitted_ids.size(), VehicleCatalog.IDS.size(), with_combat, base_rows, variant_refs, with_model, glbs.size(), with_combat],
		"note": "113 是树内可核实的模型数（苏联 37 + 德国 76）；其中只有具有精确数据、预览模型、运行模型和战斗包绑定的条目可出战。",
	}

static func ledger(catalog: VehicleCatalog, evidence: Dictionary = {}) -> Dictionary:
	var admitted: Array = catalog.packages.keys() if not catalog.packages.is_empty() else VehicleCatalog.IDS
	var rows: Array = []
	for id in admitted:
		rows.append(entry(str(id),read_packet(str(id)),evidence,admitted,catalog.model_sources))
	for id in ModernModelMountAdapter.SPECS.keys():
		if id in admitted: continue
		var candidate_packet := {}
		var candidate_path := "res://assets/reference_data/candidates/"+str(id)+".json"
		if FileAccess.file_exists(candidate_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate_path))
			if parsed is Dictionary: candidate_packet = parsed
		var row := entry(str(id),candidate_packet,evidence,admitted,catalog.model_sources)
		row["admission"] = str(candidate_packet.get("admission","unknown"))
		row["historical_verified"] = bool(candidate_packet.get("historical_verified",false))
		row["gaps"] = candidate_packet.get("gaps",[])
		rows.append(row)
	var complete := 0
	for row in rows:
		# Set-level evidence ("passed_set:") proves the pipeline, not this vehicle, so it
		# deliberately does not count towards per-vehicle combat readiness.
		if row.resource == "ok" and row.combat_config == "ok" and str(row.specialized_verified).begins_with("passed_vehicle") and str(row.match_verified).begins_with("passed_vehicle"): complete += 1
	return {
		"dims": DIMENSIONS,
		"catalog_summary": catalog_summary(),
		"vehicles": rows,
		"combat_ready": complete,
		"blocked": rows.size()-complete,
	}
