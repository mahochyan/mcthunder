extends SceneTree
# WT-028: the modern capability and module dependency matrix. Equipment is opt-in per
# vehicle, the first-release must-have list is frozen, thermal/night vision obey the
# observation rules instead of revealing through walls, power loss disables exactly the
# equipment that needs it, gameplay sensor limits never read display settings, and the
# unimplemented systems are declared as such rather than implied by a vehicle class.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] equipment suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	var t80 := "ussr_t_80b"
	var leo := "germ_leopard_2a4"
	# --- 1. the frozen first-release must-have list ---
	var must := ModernEquipment.must_have_list()
	_check(must.size() == 4,"the first-release must-have list is frozen at four items (%s)"%str(must))
	for item in ["rangefinding","sight","power","fire_control_dependency"]:
		_check(must.has(item),"the must-have list contains %s"%item)
	_check(str(ModernEquipment.PROVENANCE) == "game_rule","the equipment table is labelled as a calibratable game rule")
	# --- 2. tiers are honest: nothing claims to be finished ---
	for equipment_id in ["rangefinding","optical_sight","thermal_sight","night_vision","fire_control_computer","gun_stabilizer"]:
		_check(ModernEquipment.tier_of(equipment_id) == "experimental","%s is registered as experimental, not supported"%equipment_id)
	_check(ModernEquipment.tier_of("radar") == "unimplemented","radar is registered as unimplemented")
	_check(ModernEquipment.tier_of("not_a_thing") == "unknown","an unknown equipment id is reported as unknown")
	# --- 3. equipment is opt-in per vehicle, never switched on by class ---
	_check(ModernEquipment.is_equipped(t80,"night_vision"),"the T-80B explicitly lists night vision")
	_check(not ModernEquipment.is_equipped(leo,"night_vision"),"the Leopard 2A4 does not list night vision")
	_check(str(ModernEquipment.availability(leo,"night_vision").reason) == "not_equipped","a capability the vehicle does not carry is not available to it")
	_check(str(ModernEquipment.availability("ussr_t_90","optical_sight").reason) == "not_equipped","an unknown vehicle carries nothing automatically")
	_check(str(ModernEquipment.availability(t80,"teleporter").reason) == "unknown_equipment","an unknown equipment id is refused")
	var thermal_on := ModernEquipment.availability(t80,"thermal_sight",true)
	_check(thermal_on.ok and str(thermal_on.sensor_channel) == "thermal" and str(thermal_on.module) == "optics","an available sensor names its channel and its module")
	# --- 4. unimplemented systems need their own orders ---
	var radar := ModernEquipment.availability(t80,"radar")
	_check(not radar.ok and str(radar.reason) == "unimplemented" and bool(radar.requires_separate_order),"radar is declared unimplemented and needs a separate order")
	var unimplemented := ModernEquipment.unimplemented_list()
	_check(unimplemented.size() == 5,"warning, radar, active protection and both guided/programmable ammunition are listed as unimplemented")
	var all_flagged := true
	var all_ruled := true
	for row in unimplemented:
		if not bool(row.requires_separate_order): all_flagged = false
		if str(row.abstract_rule).length() < 20: all_ruled = false
	_check(all_flagged,"each unimplemented system is flagged as requiring its own order")
	_check(all_ruled,"each unimplemented system carries an abstract calibratable rule")
	# --- 5. thermal and night vision obey the observation rules ---
	var smoke_optical := ModernEquipment.sensor_visibility("smoke","optical")
	var smoke_thermal := ModernEquipment.sensor_visibility("smoke","thermal")
	var wall_thermal := ModernEquipment.sensor_visibility("building","thermal")
	var open_optical := ModernEquipment.sensor_visibility("none","optical")
	_check(bool(smoke_optical.blocked) and not bool(smoke_thermal.blocked),"smoke blocks the optical channel while the thermal channel keeps its own rule")
	_check(float(smoke_thermal.attenuation) > 0.0 and float(smoke_thermal.attenuation) < 1.0,"the thermal channel is attenuated by smoke, not untouched")
	_check(bool(wall_thermal.blocked),"a wall blocks the thermal channel as well: no seeing through cover")
	_check(float(open_optical.attenuation) == 0.0,"open air does not attenuate the optical channel")
	_check(float(smoke_optical.attenuation) == float(ObservationPolicy.attenuation("smoke","optical")),"the sensor rule comes from the one observation policy")
	# --- 6. power loss disables exactly what depends on power ---
	var report_ok := ModernEquipment.power_report(t80,true)
	var report_lost := ModernEquipment.power_report(t80,false)
	_check(report_ok.lost.is_empty() and report_lost.lost.size() > 0,"losing power disables the powered equipment")
	_check(report_lost.kept.has("optical_sight") and report_lost.kept.has("rangefinding"),"unpowered optics and the rangefinder keep working")
	_check(report_lost.lost.has("thermal_sight") and report_lost.lost.has("fire_control_computer"),"the thermal sight and the fire-control computer stop with power")
	_check(str(ModernEquipment.availability(t80,"thermal_sight",false).reason) == "power_lost","a powered sensor reports power_lost, matching the prompt")
	_check(ModernEquipment.availability(t80,"optical_sight",false).ok,"an unpowered sight still reports available")
	var gunner_ok := ModernEquipment.role_readiness(t80,"gunner",true)
	var gunner_dark := ModernEquipment.role_readiness(t80,"gunner",false)
	_check(bool(gunner_ok.ready),"with power the gunner's required capabilities are present")
	_check(not bool(gunner_dark.ready),"without power the gunner's required capabilities are no longer all present")
	_check(gunner_dark.missing.has("fire_control_dependency"),"the missing capability is named, so the prompt can agree with reality")
	# --- 7. no role may be reported fully ready while nothing is supported ---
	var fully := ModernEquipment.fully_ready(t80,"gunner")
	_check(not bool(fully.fully_ready) and str(fully.reason) == "no_supported_tier_yet","no modern role is reported fully ready while every capability is still experimental")
	_check(fully.capabilities_without_supported_equipment.size() > 0,"the capabilities lacking supported equipment are listed")
	_check(not bool(ModernEquipment.fully_ready(leo,"commander").fully_ready),"the same holds for a second vehicle and role")
	# --- 8. gameplay sensor limits never read display settings ---
	_check(ModernEquipment.effects_independent(),"the equipment module declares the sensor limits display independent")
	var source := FileAccess.get_file_as_string("res://scripts/content/modern_equipment.gd")
	_check(not source.contains("AccessibilitySettings") and not source.contains("fx_level"),"no display-quality reference exists in the equipment policy")
	var original_fx := AccessibilitySettings.fx_level
	var attenuation_at := {}
	for level in [0,1,2]:
		AccessibilitySettings.fx_level = level
		attenuation_at[level] = ModernEquipment.sensor_visibility("smoke","thermal").attenuation
	AccessibilitySettings.fx_level = original_fx
	_check(attenuation_at[0] == attenuation_at[1] and attenuation_at[1] == attenuation_at[2],"turning effects off never changes the gameplay sensor limit")
	# --- 9. the matrix is complete and traceable to modules ---
	var matrix := ModernEquipment.capability_matrix(t80)
	_check(matrix.size() == ModernEquipment.equipment_ids().size()+5,"the matrix lists every equipment id plus the unimplemented systems")
	var complete := true
	for row in matrix:
		if str(row.equipment).is_empty(): complete = false
		if not row.has("tier") or not row.has("sensor_channel") or not row.has("equipped"): complete = false
	_check(complete,"every matrix row carries its id, tier, channel and opt-in state")
	var modules := ModernEquipment.required_modules(t80)
	_check(modules.has("optics") and modules.has("fire_control") and modules.has("turret_drive"),"the vehicle's equipment maps onto real modules for damage tracing (%s)"%str(modules))
	_check(ModernEquipment.required_modules(leo).has("optics"),"the second vehicle maps onto modules as well")
	var snap := ModernEquipment.snapshot(t80)
	for field in ["must_have","equipment","modules","gunner","power","unimplemented","historical_values_claimed"]:
		_check(snap.has(field),"the equipment snapshot exposes %s"%field)
	_check(snap.historical_values_claimed == false,"the snapshot states that no historical values are claimed")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MODERN_EQUIPMENT_CHECKS_PASS" if failed == 0 else "MODERN_EQUIPMENT_CHECKS_FAIL")
	quit(1 if failed else 0)
