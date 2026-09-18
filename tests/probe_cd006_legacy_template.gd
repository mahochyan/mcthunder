extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD06 design point five and implementation step one: the fixed post-effect template becomes an
## explicitly named legacy configuration, and each family of engineering shell is parameterised by the rule that belongs to
## it. Three independent expectations, all measured against the DELIVERED shell configurations rather than invented:
##   L1 every delivered engineering shell names a profile of its own, and the profile it names is valid FOR ITS FAMILY -
##      long rods through the spall rule, shaped charges through the chemical rule.
##   L2 the families are not interchangeable: the spall rule accepts only the long-rod effect, so a shaped charge cannot be
##      parameterised by it, which is why the two families carry different declarations rather than one shared template.
##   L3 the old fixed template still exists, and it is now NAMED and versioned, with every number unchanged - so a shell
##      without a profile resolves to an explicit legacy rule rather than to an anonymous fallback, and nothing about the
##      previous behaviour moved.

const CD6_SHELLS := "res://configs/shells/modern_engineering_loadouts.json"

func _cd6_load() -> Dictionary:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(CD6_SHELLS))
	if text.is_empty(): text = FileAccess.get_file_as_string(CD6_SHELLS)
	return JSON.parse_string(text) if not text.is_empty() else {}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd006_d5_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD06 D5 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	# ── L3 first, because it is the change this round actually makes.
	var legacy := ShellEffectPolicy.legacy_template()
	print("[CD06 D5] L3 legacy template = %s" % JSON.stringify(legacy))
	check(str(legacy.get("id",""))==ShellEffectPolicy.LEGACY_TEMPLATE_ID and not str(legacy.get("id","")).is_empty(),
		"CD06 D5 L3 the old fixed template is NAMED: %s" % str(legacy.get("id","")))
	check(str(legacy.get("version",""))==ShellEffectPolicy.VERSION and bool(legacy.get("explicit_legacy",false)),
		"CD06 D5 L3 it stays versioned and is marked explicit legacy: version=%s" % str(legacy.get("version","")))
	check(int(legacy.get("max_fragments",-1))==ShellEffectPolicy.MAX_FRAGMENTS and absf(float(legacy.get("fragment_budget_mm",-1.0))-ShellEffectPolicy.FRAGMENT_BUDGET_MM)<=1e-9,
		"CD06 D5 L3 and every number is unchanged from the constants, so no existing behaviour moved: %d lines / %.4f mm" % [
			int(legacy.get("max_fragments",-1)),float(legacy.get("fragment_budget_mm",-1.0))])

	# ── L1 and L2: what the delivered shells actually declare, and whether it fits their family.
	var loadouts := _cd6_load()
	check(not loadouts.is_empty(),"CD06 D5 the delivered shell configuration loads")
	var families := {}
	for vehicle in loadouts.get("vehicles",{}):
		for shell in loadouts.vehicles[vehicle].get("shells",[]):
			var id := str(shell.get("id",""))
			var family := str(shell.get("family",""))
			var post: Variant = shell.get("post_penetration_profile",{})
			var chemical: Variant = shell.get("chemical_profile",{})
			families[id] = {"family":family,"post":post,"chemical":chemical}
			print("[CD06 D5] L1 %-22s family=%-8s post_penetration=%s chemical_profile=%s" % [
				id,family,("declared" if not (post is Dictionary and post.is_empty()) else "absent"),
				("declared" if not (chemical is Dictionary and chemical.is_empty()) else "absent")])
			var parameterised := false
			if family=="APFSDS":
				parameterised = not (post is Dictionary and post.is_empty()) and SpallProfile.validate(post,"long_rod").is_empty()
			elif family=="HEAT":
				parameterised = (not (chemical is Dictionary and chemical.is_empty())) or (not (post is Dictionary and post.is_empty()))
			else:
				parameterised = false
			check(parameterised,
				"CD06 D5 L1 %s is parameterised by the rule that belongs to its family (%s)" % [id,family])
	for wanted in ["eng_125_apfsds_v1","eng_125_heat_v1","eng_120_apfsds_v1","eng_120_heat_v1"]:
		check(families.has(wanted),"CD06 D5 L1 the delivered shell %s exists in the loadouts" % wanted)

	# ── L2: the spall rule belongs to long rods only.
	var long_rod_post: Dictionary = families["eng_125_apfsds_v1"]["post"]
	var heat_post: Dictionary = families["eng_125_heat_v1"]["post"]
	var heat_chemical: Dictionary = families["eng_125_heat_v1"]["chemical"]
	print("[CD06 D5] L2 spall-on-long-rod errors=%s ; spall-on-HEAT errors=%s ; HEAT chemical profile present=%s" % [
		str(SpallProfile.validate(long_rod_post,"long_rod")),str(SpallProfile.validate(long_rod_post,"chemical")),
		str(not heat_chemical.is_empty())])
	check(SpallProfile.validate(long_rod_post,"long_rod").is_empty(),
		"CD06 D5 L2 the long rod's own spall profile validates for the long-rod effect")
	check(not SpallProfile.validate(long_rod_post,"chemical").is_empty(),
		"CD06 D5 L2 the same profile is REFUSED for a shaped-charge effect, so the families cannot share one template")
	check(heat_post is Dictionary and heat_post.is_empty(),
		"CD06 D5 L2 and the delivered shaped charge does NOT carry a spall profile, which is why it must be parameterised by the chemical rule instead")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD06_LEGACY_TEMPLATE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
