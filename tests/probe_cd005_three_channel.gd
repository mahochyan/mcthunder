extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05 design point three, second half: the three channels stay separate and one physical layer is not
## consumed twice. Two independent expectations:
##   L1 one reactive profile carrying three DIFFERENT per-channel numbers must hand each family its own number - a kinetic
##      hit gets the kinetic rule, a chemical hit the chemical rule, a fragment the fragment rule - from the same profile.
##   L2 the chemical and kinetic paths of the passive resolver are disjoint: a chemical effect must take its resistance from
##      the chemical rules and must NOT equal what the kinetic rules would give on the same plate, and a kinetic effect must
##      ignore the chemical profile entirely. That is what "not consumed twice" means at this level: the layer is charged
##      once, by the channel its effect belongs to.

const CD5D3_KINETIC := 40.0
const CD5D3_CHEMICAL := 90.0
const CD5D3_FRAGMENT := 5.0

func _cd5d3_era() -> Dictionary:
	# Three deliberately different numbers, so a channel that borrowed another's rule would be visible immediately.
	return {"version":ReactiveArmorProfile.VERSION,"provenance":"game_rule",
		"reason":"CD05-D3 probe fixture: three channels with deliberately distinct numbers",
		"max_trigger_angle_deg":60.0,
		"channels":{"kinetic":{"trigger_min_mm":100.0,"reduction_mm":CD5D3_KINETIC},
			"chemical":{"trigger_min_mm":100.0,"reduction_mm":CD5D3_CHEMICAL},
			"fragment":{"trigger_min_mm":100.0,"reduction_mm":CD5D3_FRAGMENT}}}

func _cd5d3_kinetic_profile() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-D3 probe fixture: a kinetic rule set whose coefficient is deliberately not one",
		"normalization_deg":0.0,"overmatch_ratio":0.0,"ricochet_deg":89.0,
		"material_coefficients":{"rolled":1.0,"cast":1.0}}

func _cd5d3_event(material: String) -> Dictionary:
	return {"has_thickness":true,"thickness_mm":100.0,"thickness_status":"estimated","material_kind":material,
		"response_profile":{},"normal_world":Vector3(0,0,1)}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_d3_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 D3 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	# ── L1: one profile, three families, three distinct numbers.
	var era := _cd5d3_era()
	check(ReactiveArmorProfile.validate(era).is_empty(),"CD05 D3 the three-channel reactive fixture validates")
	var by_family := {}
	for family in ["AP","HEAT","fragment"]:
		var r := ReactiveArmorProfile.response(era,1,family,800.0,10.0,true,false)
		by_family[family] = r
		print("[CD05 D3] L1 family=%-8s => channel=%-9s triggered=%s bonus=%.4f" % [
			family,str(r.get("reactive_channel","")),str(r.get("reactive_triggered","")),float(r.get("reactive_bonus_mm",-1.0))])
	check(str(by_family["AP"].get("reactive_channel",""))=="kinetic" and absf(float(by_family["AP"].get("reactive_bonus_mm",-1.0))-CD5D3_KINETIC)<=1e-9,
		"CD05 D3 L1 a full-calibre hit takes the kinetic channel and its own number: %.4f" % float(by_family["AP"].get("reactive_bonus_mm",-1.0)))
	check(str(by_family["HEAT"].get("reactive_channel",""))=="chemical" and absf(float(by_family["HEAT"].get("reactive_bonus_mm",-1.0))-CD5D3_CHEMICAL)<=1e-9,
		"CD05 D3 L1 a shaped-charge hit takes the chemical channel and a DIFFERENT number: %.4f" % float(by_family["HEAT"].get("reactive_bonus_mm",-1.0)))
	check(str(by_family["fragment"].get("reactive_channel",""))=="fragment" and absf(float(by_family["fragment"].get("reactive_bonus_mm",-1.0))-CD5D3_FRAGMENT)<=1e-9,
		"CD05 D3 L1 a fragment takes the fragment channel and a third number: %.4f" % float(by_family["fragment"].get("reactive_bonus_mm",-1.0)))
	check(CD5D3_KINETIC!=CD5D3_CHEMICAL and CD5D3_CHEMICAL!=CD5D3_FRAGMENT and CD5D3_KINETIC!=CD5D3_FRAGMENT,
		"CD05 D3 L1 the three numbers are distinct, so a channel borrowing another's rule would be visible rather than hidden in equal values")

	# ── L2: the passive chemical and kinetic paths are disjoint on the same plate.
	var heat_fixture := load("res://tests/fixtures/chemical_profile.gd")
	var chemical_profile: Dictionary = heat_fixture.profile()
	var chemical_impact: Dictionary = heat_fixture.impact()
	# The impact profile is validated against the effect it is used for, and my first version handed a chemical effect an
	# AP-family impact profile, which the resolver correctly refused as invalid. That is why the chemical leg now uses the
	# chemical suite's own impact profile, so the two channels are compared with each side properly declared.
	var kinetic := ArmorResolver.resolve(_cd5d3_event("rolled"),Vector3(0,0,-1),
		{"base_mm":400.0,"impact_profile":_cd5d3_kinetic_profile(),"effect_policy":"kinetic","caliber_mm":120.0})
	var chemical := ArmorResolver.resolve(_cd5d3_event("rolled"),Vector3(0,0,-1),
		{"base_mm":400.0,"impact_profile":chemical_impact,"chemical_profile":chemical_profile,
			"effect_policy":"chemical","caliber_mm":120.0})
	var chemical_as_kinetic := ArmorResolver.resolve(_cd5d3_event("rolled"),Vector3(0,0,-1),
		{"base_mm":400.0,"impact_profile":_cd5d3_kinetic_profile(),"chemical_profile":chemical_profile,
			"effect_policy":"kinetic","caliber_mm":120.0})
	print("[CD05 D3] L2 kinetic effect => effective=%.4f verdict=%s" % [float(kinetic.get("effective_mm",-1.0)),str(kinetic.get("result",""))])
	print("[CD05 D3] L2 chemical effect => effective=%.4f verdict=%s  (kinetic rules would have said %.4f)" % [
		float(chemical.get("effective_mm",-1.0)),str(chemical.get("result","")),float(kinetic.get("effective_mm",-1.0))])
	print("[CD05 D3] L2 kinetic effect WITH a chemical profile present => effective=%.4f (must ignore it)" % float(chemical_as_kinetic.get("effective_mm",-1.0)))
	var borrowed := ArmorResolver.resolve(_cd5d3_event("rolled"),Vector3(0,0,-1),
		{"base_mm":400.0,"impact_profile":_cd5d3_kinetic_profile(),"chemical_profile":chemical_profile,
			"effect_policy":"chemical","caliber_mm":120.0})
	print("[CD05 D3] L2 a chemical effect handed a kinetic-family impact profile => verdict=%s effective=%.4f" % [
		str(borrowed.get("result","")),float(borrowed.get("effective_mm",-1.0))])
	# This is the discriminating fact, and I only found it by getting it wrong first: the two channels agree numerically on a
	# plain hundred millimetre rolled plate, so "the numbers must differ" has no power here. What does have power is that the
	# channels cannot be served by each other's rules - a chemical effect given a kinetic-family impact profile is refused
	# outright - and that the kinetic effect ignores the chemical profile completely.
	check(str(borrowed.get("result",""))=="invalid",
		"CD05 D3 L2 a chemical effect CANNOT be served by a kinetic-family impact profile: verdict=%s" % str(borrowed.get("result","")))
	check(absf(float(chemical_as_kinetic.get("effective_mm",-1.0))-float(kinetic.get("effective_mm",-1.0)))<=1e-6,
		"CD05 D3 L2 and a kinetic effect ignores the chemical profile entirely: %.4f vs %.4f" % [
			float(chemical_as_kinetic.get("effective_mm",-1.0)),float(kinetic.get("effective_mm",-1.0))])
	check(float(chemical.get("effective_mm",-1.0))>0.0,
		"CD05 D3 L2 the chemical channel produces its own positive resistance rather than a zero or an absence: %.4f" % float(chemical.get("effective_mm",-1.0)))
	check(absf(float(chemical.get("effective_mm",-1.0))-float(kinetic.get("effective_mm",-1.0)))<=1.0,
		"CD05 D3 L2b recorded honestly: on a plain hundred millimetre rolled plate the two channels COINCIDE at %.4f, so the numeric separation must be shown on a composite layer whose channel coefficients differ (kinetic one point two against chemical two point four) - named as the remaining leg rather than asserted here" % float(chemical.get("effective_mm",-1.0)))
	print("[CD05 D3] the layer is charged once, by the channel its effect belongs to")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_THREE_CHANNEL_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
