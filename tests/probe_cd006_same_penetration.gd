extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD06-T01, written BEFORE the implementation because that is the order the work has to be done in.
##
## The case: two engineering rounds with the SAME penetration fired at the SAME compartment must take their fuze and
## distribution from their OWN profiles rather than falling back to one fixed template. The live shell set contains a
## natural pair for this - m61_m3 and m61_m6 share the penetration curve [2500, 39] to the value - so the pair is the
## fixture and nothing has to be invented for it.
##
## The judgments:
##   L1 the live set really does contain two internal-burst rounds with an identical penetration curve;
##   L2 BOTH of them declare a post-penetration profile of their own (this is what the order requires and what is missing);
##   L3 the two profiles DIFFER, so switching rounds changes the distribution and not only the penetration;
##   L4 the third internal-burst round may stay undeclared, and then it resolves to the NAMED legacy template rather than
##      to an anonymous fallback, because that is the convention this order already established.
##
## It is expected to FAIL on L2 and L3 until the profile is extended for internal bursts; that failure is the specification.

const CD6T1_LIVE := "res://configs/shells/historical_loadouts.json"

func _cd6t1_load() -> Dictionary:
	var text := FileAccess.get_file_as_string(CD6T1_LIVE)
	return JSON.parse_string(text) if not text.is_empty() else {}

func _cd6t1_curve_key(shell: Dictionary) -> String:
	return JSON.stringify(shell.get("penetration_curve",[]))

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd006_t01_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD06 T01 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	# ── L1: the live set, and the natural same-penetration pair inside it.
	var live := _cd6t1_load()
	check(not live.is_empty(),"CD06 T01 the live shell set loads from the path the catalog reads")
	var shells: Dictionary = live.get("shells",{})
	var internal: Dictionary = {}
	for id in shells:
		if str(shells[id].get("effect_policy",""))=="internal_burst": internal[id] = shells[id]
	print("[CD06 T01] internal-burst rounds in the live set: %s" % str(internal.keys()))
	check(internal.size()>=2,"CD06 T01 the live set carries at least two internal-burst rounds for the pair")
	var pair: Array = []
	for id in internal:
		if absf(float(shells[id].penetration_curve[-1][1])-39.0)<=0.001: pair.append(id)
	print("[CD06 T01] rounds whose penetration curve ends at 39 mm: %s (keys %s)" % [
		str(pair),str(pair.map(func(i): return _cd6t1_curve_key(shells[i])))])
	check(pair.size()>=2,
		"CD06 T01 L1 two internal-burst rounds share one penetration curve, so the pair is real rather than constructed: %s" % str(pair))
	var same_key := true
	for i in pair:
		if _cd6t1_curve_key(shells[i])!=_cd6t1_curve_key(shells[pair[0]]): same_key = false
	check(same_key,"CD06 T01 L1 their curves are identical to the value, not merely similar")

	# ── L2: both rounds of the pair declare a profile of their own.
	var declared: Array = []
	for id in pair:
		var profile: Variant = shells[id].get("post_penetration_profile",{})
		var present: bool = profile is Dictionary and not profile.is_empty()
		print("[CD06 T01] L2 %s post_penetration_profile %s" % [str(id),("declared: "+JSON.stringify(profile)) if present else "ABSENT"])
		if present: declared.append(id)
	check(declared.size()==pair.size(),
		"CD06 T01 L2 BOTH rounds of the same-penetration pair declare a post-penetration profile of their own: %d of %d" % [declared.size(),pair.size()])

	# ── L3: and the two profiles differ, so the round choice changes the distribution.
	if declared.size()==2:
		var a := JSON.stringify(shells[declared[0]].post_penetration_profile)
		var b := JSON.stringify(shells[declared[1]].post_penetration_profile)
		print("[CD06 T01] L3 profile A=%s" % a)
		print("[CD06 T01] L3 profile B=%s" % b)
		check(a!=b,
			"CD06 T01 L3 the same-penetration pair carries DIFFERENT post-penetration profiles, so the distribution is not one shared template")
	else:
		check(false,"CD06 T01 L3 cannot compare the pair's profiles because at least one is absent (this is the specification, not a surprise)")

	# ── L4: an undeclared round resolves to the NAMED legacy template, never to an anonymous fallback.
	var legacy := ShellEffectPolicy.legacy_template()
	var undeclared: Array = []
	for id in internal:
		var profile: Variant = shells[id].get("post_penetration_profile",{})
		if not (profile is Dictionary and not profile.is_empty()): undeclared.append(id)
	print("[CD06 T01] L4 undeclared internal-burst rounds: %s ; legacy id=%s explicit=%s" % [
		str(undeclared),str(legacy.get("id","")),str(legacy.get("explicit_legacy",""))])
	check(str(legacy.get("id",""))==ShellEffectPolicy.LEGACY_TEMPLATE_ID and bool(legacy.get("explicit_legacy",false)),
		"CD06 T01 L4 an undeclared round has a NAMED, explicitly-legacy template to resolve to: %s" % str(legacy.get("id","")))
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD06_SAME_PENETRATION_PAIR_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
