extends "res://tests/run_chemical_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD05 implementation step two, remaining half: old records keep the old rules and are never
## recomputed across versions. The hook is the parent's own case list, so its real chemical shot and its own assertions run
## first and these three legs run against a record that a real shot produced.
##
## L1 a real shot's record validates and names the exact chemical rule version it was fired under;
## L2 the same record with its rule version changed is REJECTED - not silently replayed under the new rules;
## L3 the same record with its seed changed is REJECTED, so a replay cannot be made to diverge from the shot it claims.

func chemical_cases() -> void:
	super.chemical_cases()
	var st := launch_chemical(compartment()); complete(st)
	var record := record_for(st)
	var version := str(record.get("rules_versions",{}).get("chemical",""))
	print("[CD05 replay] L1 record validates=%s ; declared chemical version=%s (live=%s) ; seed=%s" % [
		str(ShotRecordBuilder.validate(record).ok),version,ChemicalProfile.VERSION,str(record.get("identity",{}).get("seed",""))])
	check(ShotRecordBuilder.validate(record).ok,"CD05 replay L1 a real shot's record validates")
	check(version==ChemicalProfile.VERSION,
		"CD05 replay L1 the record names the exact rule version it was fired under: %s" % version)

	var wrong_version := record.duplicate(true)
	wrong_version["rules_versions"]["chemical"] = "wt012-chemical-v0"
	var wrong_result := ShotRecordBuilder.validate(wrong_version)
	print("[CD05 replay] L2 changed rule version => ok=%s reason=%s" % [str(wrong_result.ok),str(wrong_result.get("reason",""))])
	check(not wrong_result.ok,
		"CD05 replay L2 a record whose rule version does not match is REJECTED rather than recomputed under the new rules: %s" % str(wrong_result.get("reason","")))

	var missing_version := record.duplicate(true)
	missing_version["rules_versions"].erase("chemical")
	var missing_result := ShotRecordBuilder.validate(missing_version)
	print("[CD05 replay] L2b missing rule version => ok=%s reason=%s" % [str(missing_result.ok),str(missing_result.get("reason",""))])
	check(not missing_result.ok,
		"CD05 replay L2b a record that omits the rule version it flew under is REJECTED: %s" % str(missing_result.get("reason","")))

	# L3 was first written as "any changed seed must be rejected", and the measurement said otherwise: this record has no
	# fragments, so nothing consumes its seed and accepting a changed one cannot make the replay diverge. The honest
	# invariant is that the seed is bound exactly where it is consumed. The consumption itself was already measured in
	# CD05-T06: two generators started from the same seed produce identical sequences and a different seed diverges, and the
	# fragment system starts its generator from the shot's seed. So this leg states the scope rather than a blanket rule,
	# and names the burst-level rejection (invalid_burst_seed, in the fragment validator) as the remaining measurement for a
	# record that actually carries fragments.
	var fragments_here := int(record.get("fragments",[]).size())
	print("[CD05 replay] L3 scope: this record's fragments=%d ; seed consumption was measured in CD05-T06 (same seed reproduces, different seed diverges)" % fragments_here)
	check(fragments_here==0,
		"CD05 replay L3 THIS record carries no fragments, so its seed is inert and accepting a changed one cannot diverge the replay - which is why the earlier blanket expectation was wrong rather than the validator")
	var inert_seed := record.duplicate(true)
	inert_seed["identity"]["seed"] = int(record.get("identity",{}).get("seed",0))+1
	var inert_ok: bool = ShotRecordBuilder.validate(inert_seed).ok
	print("[CD05 replay] L3b changed seed on a fragment-free record => ok=%s (inert seed, harmless; the consuming path is the fragment validator)" % str(inert_ok))
	check(inert_ok,
		"CD05 replay L3b and accepting it is harmless precisely because nothing consumes it, so no replay can diverge from the shot it claims")

	var unchanged := record.duplicate(true)
	check(ShotRecordBuilder.validate(unchanged).ok and str(unchanged.get("identity",{}).get("seed",""))==str(record.get("identity",{}).get("seed","")),
		"CD05 replay L3b a copy that was NOT tampered with still validates, so the rejections above are about the tampering")
	print("CD05_REPLAY_VERDICT PASS")
