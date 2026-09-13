extends SceneTree
# WT-031C-D: the authored role mapping must agree with the LIVE asset, not with a
# transcribed list. Every `node` entry is re-checked against a fresh probe, derived roles
# are marked as authored frames, missing roles name their reason, and nothing is installed.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(300.0)
	timer.timeout.connect(func() -> void: print("[FAIL] mapping suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. every authored node entry exists in the live asset ---
	for asset_id in RoleMapping.asset_ids():
		var validation := RoleMapping.validate(asset_id)
		_check(validation.ok,"%s mapping validates against its node inventory"%asset_id)
		_check(int(validation.slots) == ModelBindingValidator.ROLES.size(),"%s covers every binding role"%asset_id)
		var kinds := {}
		for row in validation.roles: kinds[str(row.kind)] = int(kinds.get(str(row.kind),0))+1
		_check(int(kinds.get("node",0))+int(kinds.get("derived",0))+int(kinds.get("missing",0)) == int(validation.slots),"%s states a kind for every role"%asset_id)
		print("[info] %s: node=%d derived=%d missing=%d resolved=%d/%d"%[asset_id,int(kinds.get("node",0)),
			int(kinds.get("derived",0)),int(kinds.get("missing",0)),int(validation.resolved),int(validation.slots)])
	# --- 2. the mapping is re-checked against a FRESH probe of the real GLB ---
	for asset_id in RoleMapping.asset_ids():
		var path := str(RoleMapping.ASSET_PATHS[asset_id])
		var report := ModelBindingProbe.probe(path)
		_check(report.ok,"%s re-probes successfully"%asset_id)
		if not report.ok: continue
		var live_names: Array = []
		for row in report.nodes: live_names.append(str(row.name))
		var mapping := RoleMapping.mapping_for(asset_id)
		for role in mapping:
			var entry: Dictionary = mapping[role]
			if str(entry.get("kind","")) != "node": continue
			_check(live_names.has(str(entry.path)),"%s role %s points at a node the live asset really contains (%s)"%[asset_id,role,str(entry.path)])
		for role in mapping:
			var entry: Dictionary = mapping[role]
			if str(entry.get("kind","")) != "derived": continue
			_check(live_names.has(str(entry.parent)),"%s derived role %s hangs off a real parent (%s)"%[asset_id,role,str(entry.parent)])
	# --- 3. the outcome per asset ---
	var coverage := {}
	for row in RoleMapping.coverage(): coverage[str(row.asset_id)] = row
	_check(coverage.has("cn_ztz_99a") and bool(coverage["cn_ztz_99a"].complete),"ZTZ-99A maps completely from its own node names")
	_check(int(coverage["cn_ztz_99a"].by_kind.node) == 6,"all six ZTZ roles are real nodes")
	_check(bool(coverage["ussr_t_80b"].complete),"the T-80B maps completely once its muzzle frame is derived")
	_check(int(coverage["ussr_t_80b"].by_kind.derived) == 1,"the T-80B needs exactly one authored frame")
	_check(bool(coverage["germ_leopard_2a4"].complete),"the Leopard 2A4 maps completely once its muzzle frame is derived")
	_check(not bool(coverage["us_m1a1_abrams"].complete),"the M1A1 does not map completely: its merged LOD has no track nodes")
	_check(int(coverage["us_m1a1_abrams"].by_kind.missing) == 2,"the M1A1 reports both missing track roles")
	_check(str(coverage["us_m1a1_abrams"].blocker) == "asset_needs_re_export_for_missing_roles","the M1A1 blocker names a re-export rather than hiding the gap")
	_check(bool(coverage["cn_ztz_99a"].registration_ready) and not bool(coverage["us_m1a1_abrams"].registration_ready),"registration readiness is per asset")
	# --- 4. draft bindings: authored, never installed ---
	for asset_id in RoleMapping.asset_ids():
		var draft := RoleMapping.draft_binding(asset_id)
		_check(draft.get("applied",true) == false,"%s draft is explicitly not applied"%asset_id)
		_check(str(draft.model.sha256).length() == 64,"%s draft carries the measured hash"%asset_id)
		_check(int(draft.nodes.size())+int(draft.derived_frames.size())+draft.missing_roles.size() == ModelBindingValidator.ROLES.size(),"%s draft accounts for every role"%asset_id)
	var m1a1_draft := RoleMapping.draft_binding("us_m1a1_abrams")
	_check(m1a1_draft.missing_roles.has("running_left") and m1a1_draft.missing_roles.has("running_right"),"the M1A1 draft names the two roles it cannot place")
	_check(not bool(m1a1_draft.complete),"an incomplete draft never claims completeness")
	for asset_id in ["ussr_t_80b","germ_leopard_2a4","us_m1a1_abrams"]:
		var draft := RoleMapping.draft_binding(asset_id)
		_check(draft.derived_frames.has("muzzle"),"%s marks its muzzle as an authored frame rather than a measured node"%asset_id)
		_check(str(draft.derived_frames.muzzle.provenance) == "author","the derived frame records author provenance, not a measurement")
	# --- 5. read-only guarantees ---
	var source := FileAccess.get_file_as_string("res://scripts/content/role_mapping.gd")
	_check(not source.contains("FileAccess.WRITE") and not source.contains("store_string"),"the mapping module contains no write path")
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(VehicleCatalog.MODEL_SOURCE_REGISTRY))
	_check(registry is Dictionary and (registry.get("models",{}) as Dictionary).is_empty(),"the registry is still the untouched empty registry")
	var snapshot := RoleMapping.snapshot()
	_check(snapshot.installed == false and snapshot.registry_untouched == true,"the snapshot states nothing is installed and the registry is untouched")
	_check(int(snapshot.drafts.size()) == 4 and int(snapshot.coverage.size()) == 4,"the snapshot covers all four assets")
	_check(str(RoleMapping.validate("not_an_asset").reason) == "unknown_asset","an unknown asset is refused")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("ROLE_MAPPING_CHECKS_PASS" if failed == 0 else "ROLE_MAPPING_CHECKS_FAIL")
	quit(1 if failed else 0)
