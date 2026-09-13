extends SceneTree
# WT-031-R1: the readiness ledger must separate five questions, must grade the
# in-repo tree honestly, and the shared gate must refuse unknown / preview-only /
# locked / bad-mode vehicles for player, AI, first spawn, respawn and save restore.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	var catalog := VehicleCatalog.new()
	_check(catalog.model_source_errors.is_empty(),"model source registry parses without errors")
	var evidence: Dictionary = {}
	if FileAccess.file_exists("res://docs/wt/continuation/VEHICLE_EVIDENCE.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/wt/continuation/VEHICLE_EVIDENCE.json"))
		if parsed is Dictionary: evidence = parsed
	var ledger := VehicleReadiness.ledger(catalog,evidence)
	var by_id := {}
	for row in ledger.get("vehicles",[]): by_id[str(row.id)] = row
	# --- positive: the four admitted historical vehicles ---
	for id in VehicleCatalog.IDS:
		var row: Dictionary = by_id.get(id,{})
		_check(not row.is_empty(),"ledger contains admitted vehicle %s" % id)
		_check(str(row.get("resource","")) == "ok","resource complete for %s" % id)
		_check(str(row.get("combat_config","")) == "ok","combat configuration complete for %s" % id)
		_check(str(row.get("specialized_verified","")).begins_with("passed"),"registered specialised evidence is applied for %s" % id)
		_check(str(row.get("match_verified","")) == "not_run","match evidence stays not_run until a match suite is run for %s" % id)
		_check(str(row.get("distribution_license","")) == "unverified","distribution licence stays unverified for %s" % id)
		var reference_ok: Variant = row.get("config_detail",{}).get("reference_admitted",true)
		_check(reference_ok == false,"reference admission is reported as its own track for %s" % id)
	# --- positive: the two modern candidates are visible but preview-only ---
	for id in ModernModelMountAdapter.SPECS.keys():
		var row: Dictionary = by_id.get(id,{})
		_check(not row.is_empty(),"ledger contains modern candidate %s" % id)
		_check("preview_only" in row.get("codes",[]),"modern candidate %s carries preview_only" % id)
		_check(str(row.get("admission","")) == "candidate_only","candidate file records candidate_only for %s" % id)
		var claimed: Variant = row.get("historical_verified",true)
		_check(claimed != true,"candidate is not claimed as historically verified (%s)" % id)
		_check(str(row.get("combat_config","")) == "not_applicable","candidate combat configuration is not_applicable (%s)" % id)
		_check(str(row.get("resource","")) == "ok","repository frozen model is found for candidate %s" % id)
		var external: Dictionary = row.get("resource_detail",{}).get("declared_external",{})
		_check(not str(external.get("path","")).is_empty(),"external declared model path is recorded for %s" % id)
		_check(str(external.get("status","")) != "","external declared build status is recorded for %s" % id)
		_check(int(external.get("triangles_reported",0)) > 0,"external triangle count is recorded for %s" % id)
		var import_visible: Variant = row.get("resource_detail",{}).get("import_visible",true)
		_check(import_visible == false,"research model is read as bytes and is not import-visible (%s)" % id)
	# --- catalogue ladder read from the in-repo tree ---
	var summary: Dictionary = ledger.get("catalog_summary",{})
	_check(int(summary.get("tree_rows",0)) == 212,"research tree carries 212 vehicle rows")
	_check(int(summary.get("tree_base_rows",0)) == 212,"all tree rows are base models")
	_check(int(summary.get("tree_rows_with_model",0)) == 113,"113 tree rows have a model")
	_check(int(summary.get("research_model_glb_count",0)) == 113,"113 model GLB files exist in the repository")
	_check(int(summary.get("tree_variant_refs",0)) == 160,"160 variant references are recorded")
	_check(int(summary.get("tree_rows_with_combat_package",0)) == 0,"no tree vehicle has a combat package")
	_check(int(summary.get("tree_admission_status",{}).get("static_preview_only",0)) == 113,"113 rows are static_preview_only")
	_check(int(summary.get("tree_admission_status",{}).get("awaiting_model",0)) == 99,"99 rows await a model")
	_check(int(summary.get("admitted_combat_vehicles",0)) == 4,"four vehicles are admitted for combat")
	_check(int(ledger.get("combat_ready",-1)) == 0,"no vehicle reaches all five dimensions yet")
	# --- negative gates ---
	var unknown := VehicleReadiness.eligible("nonexistent_vehicle","training",{},catalog)
	_check(not unknown.ok and unknown.code == "unknown_vehicle","unknown vehicle is refused with a code")
	var preview := VehicleReadiness.eligible("ussr_t_80b","normal",{"unlocked":["ussr_t_80b"]},catalog)
	_check(not preview.ok and preview.code == "preview_only","preview-only candidate cannot enter a formal match")
	var locked := VehicleReadiness.eligible("us_m26_m3_1945","normal",{"unlocked":[ResearchGraph.STARTER]},catalog)
	_check(not locked.ok and locked.code == "not_unlocked","save without research is refused as not_unlocked")
	var bad_mode := VehicleReadiness.eligible(ResearchGraph.STARTER,"ranked",{},catalog)
	_check(not bad_mode.ok and bad_mode.code == "mode_restricted","unsupported mode is refused")
	var empty_id := VehicleReadiness.eligible("","training",{},catalog)
	_check(not empty_id.ok and empty_id.code == "unknown_vehicle","empty vehicle id is refused")
	# --- negative: resource and configuration defects ---
	var ghost := VehicleReadiness.entry("us_ghost_vehicle",{},evidence,VehicleCatalog.IDS)
	_check(str(ghost.resource) == "missing","missing packet reports resource missing")
	_check("resource_missing" in ghost.codes,"missing packet carries resource_missing")
	var packet := VehicleReadiness.read_packet("us_m4a3_75w_vvss_1944")
	_check(not packet.is_empty(),"historical packet loads for tamper test")
	var tampered := packet.duplicate(true)
	if tampered.get("assembly") is Dictionary: tampered.assembly.variant = "not_the_recorded_variant"
	var state := VehicleReadiness.config_state("us_m4a3_75w_vvss_1944",tampered,{})
	_check("variant_conflict" in state.codes,"tampered variant is reported as variant_conflict")
	var missing_field := packet.duplicate(true)
	missing_field.erase("assembly")
	var malformed := VehicleReadiness.config_state("us_m4a3_75w_vvss_1944",missing_field,{})
	_check(not malformed.codes.is_empty(),"packet without assembly is reported incomplete")
	# --- shared gate wiring: lineup keeps working and now returns codes ---
	var ok_lineup := Lineup.validate([ResearchGraph.STARTER],ResearchGraph.STARTER,"training",[])
	_check(ok_lineup.ok and str(ok_lineup.get("code","")) == "ok","training lineup still accepted through the shared gate")
	var preview_lineup := Lineup.validate(["ussr_t_80b"],"ussr_t_80b","training",[])
	_check(not preview_lineup.ok and str(preview_lineup.get("code","")) == "preview_only","preview-only id refused by lineup with its code")
	var locked_lineup := Lineup.validate([ResearchGraph.STARTER],ResearchGraph.STARTER,"normal",[])
	_check(not locked_lineup.ok and str(locked_lineup.get("code","")) == "not_unlocked","normal lineup without research refused with not_unlocked")
	var over := Lineup.validate([ResearchGraph.STARTER,"us_m24_m6_t85e1_1951","us_m26_m3_1945","us_m36_m4a1_1945"],ResearchGraph.STARTER,"training",[])
	_check(not over.ok,"lineup larger than three vehicles is refused")
	# --- AI slot and respawn cannot bypass the gate (same helper they now use) ---
	var ai_pick := VehicleReadiness.first_eligible(["ussr_t_80b","nonexistent_vehicle"],"training",{},catalog)
	_check(ai_pick.ok and str(ai_pick.id) in VehicleCatalog.IDS,"AI slot falls back to an admitted vehicle instead of a preview id")
	_check(bool(ai_pick.get("fallback",false)),"AI fallback is reported, not silent")
	var respawn_pick := VehicleReadiness.first_eligible(["ussr_t_80b"],"training",{},catalog)
	_check(respawn_pick.ok and str(respawn_pick.id) in VehicleCatalog.IDS,"respawn request for a preview id resolves to an admitted vehicle")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("VEHICLE_READINESS_CHECKS_PASS" if failed == 0 else "VEHICLE_READINESS_CHECKS_FAIL")
	quit(1 if failed else 0)
