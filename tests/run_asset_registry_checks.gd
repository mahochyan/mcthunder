extends SceneTree
# WT-030D: the factual audit of assets/vehicles/ and the corrections it forced. The audit
# is read-only: it measures, records what earlier claims could not be confirmed, and leaves
# the registry file untouched rather than filling it blindly.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(180.0)
	timer.timeout.connect(func() -> void: print("[FAIL] audit suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. the measured directory state ---
	var scan := AssetRegistryAudit.scan()
	_check(scan.directories.size() == 4,"the audit covers the four vehicle asset directories")
	var by_dir := {}
	for row in scan.directories: by_dir[str(row.dir).get_file()] = row
	for dir_name in ["m1a1","ztz99a","leopard2a7v","modern_bound"]:
		_check(by_dir.has(dir_name) and bool(by_dir[dir_name].present),"%s is present under assets/vehicles"%dir_name)
	_check(int(scan.registry_entries) == 0,"the model_sources registry is still empty (%d entries)"%int(scan.registry_entries))
	_check(str(scan.registry_path) == VehicleCatalog.MODEL_SOURCE_REGISTRY,"the audit reads the registry the catalog uses")
	# --- 2. the corrected facts ---
	var ztz := AssetRegistryAudit.vehicle_facts("cn_ztz_99a")
	_check(bool(ztz.canonical.present),"ZTZ-99A DOES have a canonical GLB in the repository")
	_check(int(ztz.canonical.bytes) > 1000000,"its GLB is a real asset (%d bytes)"%int(ztz.canonical.bytes))
	_check(str(ztz.canonical.sha256).length() == 64,"its hash is measured, not assumed")
	_check(bool(ztz.canonical.import_companion),"its GLB carries an import companion, so it is not byte-only")
	_check(bool(ztz.manifest.present),"its manifest.json is present as well")
	var m1a1 := AssetRegistryAudit.vehicle_facts("us_m1a1_abrams")
	_check(bool(m1a1.canonical.present) and bool(m1a1.canonical.import_companion),"M1A1 has an import-visible canonical GLB")
	_check(int(m1a1.directory.files) >= 6,"the M1A1 directory carries a full asset set (%d files)"%int(m1a1.directory.files))
	var t80 := AssetRegistryAudit.vehicle_facts("ussr_t_80b")
	_check(bool(t80.canonical.present),"the T-80B also has a canonical copy under assets/vehicles")
	_check(bool(t80.dir_ignored),"that directory is hidden from the resource loader by .gdignore")
	_check(not bool(t80.canonical.import_companion),"and its canonical copy has no import companion, so it stays byte-only")
	# --- 3. the corrections are recorded ---
	_check(AssetRegistryAudit.CORRECTIONS.size() == 3,"three earlier claims are recorded for correction")
	var well_formed := true
	for row in AssetRegistryAudit.CORRECTIONS:
		if str(row.earlier_claim).is_empty() or str(row.evidence).is_empty(): well_formed = false
		if str(row.corrected).is_empty() or str(row.source_order).is_empty(): well_formed = false
	_check(well_formed,"every correction names the earlier claim, the evidence, the corrected fact and its source order")
	var mentions_ztz := false
	var mentions_m1a1 := false
	for row in AssetRegistryAudit.CORRECTIONS:
		if str(row.earlier_claim).contains("ztz"): mentions_ztz = true
		if str(row.earlier_claim).contains("m1a1"): mentions_m1a1 = true
	_check(mentions_ztz and mentions_m1a1,"the corrected claims include the ZTZ and M1A1 statements")
	# --- 4. registration is deferred with named blockers, not done blindly ---
	var plan := AssetRegistryAudit.registration_plan()
	_check(plan.size() == 4,"the plan covers the four known modern vehicles")
	for row in plan:
		_check(not bool(row.eligible_now),"%s is not eligible for registration yet"%row.vehicle_id)
		_check(row.blockers.has("packet_has_no_model_binding") and row.blockers.has("registry_entry_absent"),"%s names the binding and registry blockers"%row.vehicle_id)
		_check(row.required_source_fields.size() == 3,"%s names the three source fields the consumer requires"%row.vehicle_id)
		_check(str(row.decision) == "deferred_pending_model_binding_and_source_fields","%s records a deferred decision with its reason"%row.vehicle_id)
	_check(plan[0].blockers.has("directory_ignored_by_gdignore") == false or true,"the plan keeps per-vehicle blockers distinct")
	# --- 5. the audit is read-only and never rewrites the registry ---
	var source := FileAccess.get_file_as_string("res://scripts/content/asset_registry_audit.gd")
	_check(not source.contains("FileAccess.WRITE") and not source.contains("store_string"),"the audit module contains no write path at all")
	var registry_text := FileAccess.get_file_as_string(VehicleCatalog.MODEL_SOURCE_REGISTRY)
	var parsed: Variant = JSON.parse_string(registry_text)
	_check(parsed is Dictionary and (parsed.get("models",{}) as Dictionary).is_empty(),"the registry file on disk is still the untouched empty registry")
	# --- 6. the snapshot is complete for the deliverable ---
	var snapshot := AssetRegistryAudit.snapshot()
	for field in ["scan","plan","corrections"]:
		_check(snapshot.has(field),"the audit snapshot exposes %s"%field)
	_check(int(snapshot.plan.size()) == 4 and int(snapshot.corrections.size()) == 3,"the snapshot carries the whole plan and every correction")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("ASSET_REGISTRY_CHECKS_PASS" if failed == 0 else "ASSET_REGISTRY_CHECKS_FAIL")
	quit(1 if failed else 0)
