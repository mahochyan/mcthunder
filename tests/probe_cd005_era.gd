extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05-T04: ERA is single use. The order asks that the first hit consumes it only if the trigger
## conditions are met, and that a second hit must not receive un-consumed protection. Both are measurable directly from the
## rule and then end to end through the resolver.
##
## The declared judgment, from the rule's own schema BEFORE measuring:
##   L1 a live charge, inward, residual at or above the trigger minimum and angle inside the maximum => TRIGGERED, the
##      charge goes to zero and the reduction is applied;
##   L2 the same impact with the charge already spent => NOT triggered and no reduction at all;
##   L3 a live charge whose residual is BELOW the trigger minimum => NOT triggered and, crucially, the charge is NOT spent;
##   L4 through the resolver at a geometry that does trigger, a live charge must make the effective thickness LARGER than a
##      spent one by exactly the declared reduction.

const CD5T4_REDUCTION := 120.0
const CD5T4_TRIGGER_MIN := 100.0
const CD5T4_MAX_ANGLE := 60.0

func _cd5t4_era() -> Dictionary:
	return {"version":ReactiveArmorProfile.VERSION,"provenance":"game_rule",
		"reason":"CD05-T04 probe fixture: a versioned ERA rule with an explicit three-channel table",
		"max_trigger_angle_deg":CD5T4_MAX_ANGLE,
		"channels":{"kinetic":{"trigger_min_mm":CD5T4_TRIGGER_MIN,"reduction_mm":CD5T4_REDUCTION},
			"chemical":{"trigger_min_mm":CD5T4_TRIGGER_MIN,"reduction_mm":CD5T4_REDUCTION},
			"fragment":{"trigger_min_mm":CD5T4_TRIGGER_MIN,"reduction_mm":CD5T4_REDUCTION}}}

func _cd5t4_passive() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-T04 probe fixture: the passive layer the ERA sits on",
		"normalization_deg":0.0,"overmatch_ratio":0.0,"ricochet_deg":89.0,
		"material_coefficients":{"rolled":1.0,"cast":1.0}}

## The resolver-level impact: a hundred millimetre plate, shot straight at it, so the geometry is inward and the angle is
## zero - inside the trigger maximum - and the remaining budget after the plate is well above the trigger minimum.
func _cd5t4_resolve(before: int) -> Dictionary:
	var contact := {"has_thickness":true,"thickness_mm":100.0,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":Vector3(0,0,1),"reactive_profile":_cd5t4_era(),"reactive_before":before}
	return ArmorResolver.resolve(contact,Vector3(0,0,-1),
		{"base_mm":900.0,"impact_profile":_cd5t4_passive(),"effect_policy":"kinetic","caliber_mm":120.0})

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t04_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T04 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	var era := _cd5t4_era()
	check(ReactiveArmorProfile.validate(era).is_empty(),"CD05 T04 the ERA fixture validates as a versioned game rule")

	# ── L1 to L3: the rule's own table.
	var l1 := ReactiveArmorProfile.response(era,1,"AP",800.0,10.0,true,false)
	var l2 := ReactiveArmorProfile.response(era,0,"AP",800.0,10.0,true,false)
	var l3 := ReactiveArmorProfile.response(era,1,"AP",CD5T4_TRIGGER_MIN-1.0,10.0,true,false)
	var l3b := ReactiveArmorProfile.response(era,1,"AP",800.0,10.0,false,false)
	print("[CD05 T04] L1 live charge, residual 800 >= %.0f : %s" % [CD5T4_TRIGGER_MIN,JSON.stringify(l1)])
	print("[CD05 T04] L2 charge already spent            : %s" % JSON.stringify(l2))
	print("[CD05 T04] L3 residual just below the minimum : %s" % JSON.stringify(l3))
	print("[CD05 T04] L3b live charge but not inward     : %s" % JSON.stringify(l3b))
	check(bool(l1.reactive_triggered) and int(l1.reactive_after)==0 and absf(float(l1.reactive_bonus_mm)-CD5T4_REDUCTION)<=1e-9,
		"CD05 T04 L1 a qualifying hit triggers the charge, spends it and applies the declared reduction")
	check(not bool(l2.reactive_triggered) and float(l2.reactive_bonus_mm)==0.0 and int(l2.reactive_after)==0,
		"CD05 T04 L2 a spent charge gives NO protection on the second hit, and stays spent")
	check(not bool(l3.reactive_triggered) and float(l3.reactive_bonus_mm)==0.0 and int(l3.reactive_after)==1,
		"CD05 T04 L3 a hit below the trigger minimum does NOT spend the charge: after=%d" % int(l3.reactive_after))
	check(not bool(l3b.reactive_triggered) and int(l3b.reactive_after)==1,
		"CD05 T04 L3b a non-inward hit does not spend the charge either: after=%d" % int(l3b.reactive_after))

	# ── L4: end to end through the resolver at the same geometry, live versus spent.
	var live := _cd5t4_resolve(1)
	var spent := _cd5t4_resolve(0)
	var live_effective := float(live.get("effective_mm",-1.0))
	var spent_effective := float(spent.get("effective_mm",-1.0))
	print("[CD05 T04] L4 resolver: live charge effective=%.4f mm triggered=%s bonus=%.4f ; spent effective=%.4f mm triggered=%s" % [
		live_effective,str(live.get("reactive_triggered","")),float(live.get("reactive_bonus_mm",-1.0)),
		spent_effective,str(spent.get("reactive_triggered",""))])
	check(bool(live.get("reactive_triggered",false)),
		"CD05 T04 L4 the resolver's own reactive path triggers at a qualifying geometry: triggered=%s" % str(live.get("reactive_triggered","")))
	check(absf((live_effective-spent_effective)-CD5T4_REDUCTION)<=1e-6,
		"CD05 T04 L4 through the resolver the live charge costs exactly the declared reduction more than the spent one: %.4f vs %.4f mm" % [live_effective,spent_effective])
	check(not bool(spent.get("reactive_triggered",false)) and absf(spent_effective-100.0)<=1e-6,
		"CD05 T04 L4 the spent charge leaves the bare passive plate: %.4f mm" % spent_effective)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_ERA_SINGLE_USE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
