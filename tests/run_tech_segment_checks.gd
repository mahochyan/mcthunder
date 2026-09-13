extends SceneTree
# WT-029: the first-release technology segment (pools, blockers, facts versus tuning) and
# the modern sample harness that exercises mechanisms and equipment without pretending to
# be a gunnery duel.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] segment suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. the frozen segment and its pools ---
	_check(TechSegment.SEGMENT_ID == "first_release_main" and TechSegment.SEGMENT_VERSION == 1,"the technology segment carries a frozen id and version")
	_check(TechSegment.POOLS.first_release.size() == VehicleCatalog.IDS.size(),"the first-release pool matches the four admitted historical vehicles")
	var pool_matches := true
	for vehicle_id in VehicleCatalog.IDS:
		if not TechSegment.POOLS.first_release.has(vehicle_id): pool_matches = false
	_check(pool_matches,"every admitted vehicle is listed in the first-release pool")
	_check(TechSegment.POOLS.experimental.size() == 2 and TechSegment.POOLS.experimental.has("ussr_t_80b") and TechSegment.POOLS.experimental.has("germ_leopard_2a4"),"the two pilots sit in the experimental pool")
	_check(TechSegment.POOLS.deferred.has("us_m1a1_abrams") and TechSegment.POOLS.deferred.has("cn_ztz_99a"),"M1A1 and ZTZ-99A are deferred rather than forced into the segment")
	_check(TechSegment.pool_of("ussr_t_80b") == "experimental" and not TechSegment.in_first_release("ussr_t_80b"),"an experimental pilot is not silently first-release")
	_check(TechSegment.pool_of("us_m4a3_75w_vvss_1944") == "first_release","an admitted historical vehicle is first release")
	_check(TechSegment.pool_of("not_a_vehicle") == "unlisted","an unknown vehicle belongs to no pool")
	_check(TechSegment.experience_gate() == "PENDING","without human feedback the experience gate stays pending")
	# --- 2. facts are separated from tuning values ---
	var facts := TechSegment.factual_fields("ussr_t_80b")
	var tuning := TechSegment.tuning_fields("ussr_t_80b")
	_check(facts.has("ready_rounds") and facts.has("crew") and facts.has("has_loader"),"rack counts, crew and loader presence are recorded as facts")
	_check(tuning.has("reload_s") and tuning.has("ready_resupply_s"),"reload and resupply durations are recorded as tuning values")
	_check(TechSegment.is_tuning("reload_s") and not TechSegment.is_tuning("ready_rounds"),"a tuning field is recognised as tuning and a fact is not")
	var overlap := false
	for field in facts:
		if tuning.has(field): overlap = true
	_check(not overlap,"no field is both a fact and a tuning value")
	_check(TechSegment.facts_of("ussr_t_80b").ready_rounds == LoadingMechanism.VEHICLES.ussr_t_80b.ready,"the recorded rack facts match the loading mechanism definition")
	_check(TechSegment.facts_of("germ_leopard_2a4").reserve_rounds == LoadingMechanism.VEHICLES.germ_leopard_2a4.reserve,"the second pilot's facts match its mechanism as well")
	_check(not bool(TechSegment.facts_of("ussr_t_80b").combat_admitted) and not bool(TechSegment.facts_of("germ_leopard_2a4").combat_admitted),"both pilots are recorded as not combat admitted")
	# --- 3. promotion is refused while blockers stand ---
	var blocked := TechSegment.promote("us_m1a1_abrams","first_release")
	_check(not blocked.ok and str(blocked.reason) == "blockers_remain","a deferred vehicle cannot be promoted while blockers stand")
	_check(blocked.blockers.has("no_reference_entry_in_content_tree") and blocked.blockers.has("model_is_an_unintegrated_lod_study"),"its blockers are named, including the unintegrated model")
	_check(TechSegment.blockers_of("cn_ztz_99a").has("no_model_in_repository"),"the other deferred vehicle names its own blockers")
	var not_admitted := TechSegment.promote("ussr_t_80b","first_release")
	_check(not not_admitted.ok and str(not_admitted.reason) == "not_combat_admitted","a pilot is not promoted into the combat pool without admission")
	_check(TechSegment.promote("ussr_t_80b","experimental").ok,"a pilot may stay in the experimental pool")
	_check(str(TechSegment.promote("ussr_t_80b","ranked").reason) == "unknown_pool","an unknown pool is refused")
	# --- 4. capability differences and their counters ---
	_check(TechSegment.CAPABILITY_DIFFERENCES.size() >= 3,"the difference table covers loading, sensors and crew")
	var all_countered := true
	for row in TechSegment.CAPABILITY_DIFFERENCES:
		if str(row.counter).length() < 20: all_countered = false
		if str(row.ussr_t_80b).is_empty() or str(row.germ_leopard_2a4).is_empty(): all_countered = false
	_check(all_countered,"every recorded difference carries a counter for both vehicles")
	var loading_row: Dictionary = TechSegment.CAPABILITY_DIFFERENCES[0]
	_check(str(loading_row.counter).contains("power") or str(loading_row.counter).contains("loader"),"the loading difference is countered by a recorded mechanism fact, not by a name")
	# --- 5. the must-have versus deferred gap table ---
	var gaps := TechSegment.gap_table()
	_check(gaps.size() == 2,"the gap table covers both experimental pilots")
	for row in gaps:
		_check(row.must_have_present.size() > 0,"%s has must-have equipment present"%row.vehicle_id)
		_check(row.deferred_systems.size() == 5,"%s lists the five deferred systems"%row.vehicle_id)
		_check(str(row.experience_gate) == "PENDING","%s keeps the experience gate pending"%row.vehicle_id)
	# --- 6. levers, not a copied rating table ---
	var levers := TechSegment.levers()
	_check(levers.size() == 4,"balance runs through matchmaking, mission, spawn resources and map")
	var spawn_value := ""
	for row in levers:
		if str(row.lever) == "spawn_resources": spawn_value = str(row.value)
	_check(spawn_value.contains("300") or spawn_value.contains(str(MatchRulePreset.standard().start_tickets)),"the spawn-resource lever quotes the frozen ticket rule")
	_check(not str(TechSegment.snapshot()).to_lower().contains("battle_rating"),"no battle-rating table is copied into the segment")
	# --- 7. the sample harness ---
	var report := ModernSample.run_all("ussr_t_80b")
	_check(report.total == 6 and report.passed == 6,"all six sample records pass (%d of %d)"%[report.passed,report.total])
	_check(bool(report.not_a_gunnery_duel),"the sample states it is not a gunnery duel")
	_check(report.modern_in_normal_match == false,"the sample states modern equipment is not yet used in a normal match")
	_check(str(report.experience_gate) == "PENDING","the sample reports the pending experience gate")
	# long range through smoke: optical blocked, thermal attenuated
	var smoked: Dictionary = report.records[1]
	var optical_after := {}
	var thermal_after := {}
	for step in smoked.steps:
		if str(step.step) == "optical_visibility": optical_after = step
		if str(step.step) == "thermal_visibility": thermal_after = step
	_check(bool(optical_after.blocked),"at long range through smoke the optical channel is blocked")
	_check(not bool(thermal_after.blocked) and float(thermal_after.attenuation) > 0.0,"the thermal channel keeps its own smoke rule at range")
	# both sides keep attack and defence options in both layouts
	_check(bool(ModernSample.flank(16).ok),"the 16v16 layout offers both an attack lane and a bypass")
	_check(bool(ModernSample.flank(10).ok),"the 10v10 layout offers both an attack lane and a bypass")
	_check(bool(ModernSample.hilltop().ok),"an observation position above the lane exists")
	var smoke_step := ModernSample.smoke_retreat("germ_leopard_2a4")
	_check(bool(smoke_step.ok),"the smoke retreat scenario passes for the second pilot")
	# --- 8. the same vehicle with a different loadout changes the inventory ---
	var ap := LoadingMechanism.new()
	ap.begin("germ_leopard_2a4","ap")
	ap.start_load(); ap.advance(10.0); ap.advance(10.0); ap.advance(10.0)
	var heat := LoadingMechanism.new()
	heat.begin("germ_leopard_2a4","heat")
	heat.start_load(); heat.advance(10.0); heat.advance(10.0); heat.advance(10.0)
	_check(ap.chamber_shell == "ap" and heat.chamber_shell == "heat","a different loadout chambers a different round, so the choice reaches the inventory")
	_check(ap.ready_rack[0] == "ap" and heat.ready_rack[0] == "heat","the rack composition itself differs with the loadout")
	_check(ap.fire_chambered().shell == "ap" and heat.fired_count == 0,"firing returns the round that was actually loaded")
	# --- 9. recovery scenario for both mechanisms ---
	for vehicle_id in ["ussr_t_80b","germ_leopard_2a4"]:
		var recovery := ModernSample.damaged_loading_recovery(vehicle_id)
		_check(bool(recovery.ok),"%s recovers from loading damage with the account conserved"%vehicle_id)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TECH_SEGMENT_CHECKS_PASS" if failed == 0 else "TECH_SEGMENT_CHECKS_FAIL")
	quit(1 if failed else 0)
