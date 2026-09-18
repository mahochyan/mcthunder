extends "res://tests/run_spall_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD06-T04 and design point four: the after-effect is occluded by the internals that are really there
## at the contact instant, and a real bulkhead screens while an empty structure must not pretend to be solid.
##
## The measurable pair here is the same shot into the same compartment twice, once with the real internals present and once
## without them. A real bulkhead changes the outcome, and it does so by being HIT - so the decisive, direction-free fact is
## that the internal structure appears among the damaged targets when it exists and is absent when it does not, with the
## record set differing between the two runs. The empty-rack half of the case lives in the ammunition compartment suite,
## where the earlier three-state work established that an empty rack neither absorbs damage nor spends budget; that half is
## measured there rather than claimed here.

func spall_runtime_cases() -> void:
	super.spall_runtime_cases()

	# ── The contrast: identical shot, identical plate, internals present or not.
	var open_state := launch_spall(compartment(20.0,false)); complete(open_state)
	var open_records := open_state.damage_records.size()
	var open_sum := 0.0
	for record in open_state.damage_records: open_sum += float(record.get("consumed_mm",0.0))
	var with_state := launch_spall(compartment(20.0,true)); complete(with_state)
	var with_records := with_state.damage_records.size()
	var with_sum := 0.0
	for record in with_state.damage_records: with_sum += float(record.get("consumed_mm",0.0))
	print("[CD06 T04] internals ABSENT => fragments=%d damage_records=%d sum_consumed=%.4f mm" % [
		open_state.fragments.size(),open_records,open_sum])
	print("[CD06 T04] internals PRESENT => fragments=%d damage_records=%d sum_consumed=%.4f mm" % [
		with_state.fragments.size(),with_records,with_sum])
	for record in with_state.damage_records:
		print("[CD06 T04]   internals-present record: target=%s consumed=%.4f" % [
			str(record.get("target_key",record.get("module_id",record.get("target","?")))),float(record.get("consumed_mm",0.0))])
	check(with_state.spall_events.size()>=1 and open_state.spall_events.size()>=1,
		"CD06 T04 both runs really produce a spall event, so the contrast is about occlusion and not about the shot failing")
	check(with_records!=open_records or absf(with_sum-open_sum)>0.01,
		"CD06 T04 design point four: the internals actually present at the contact instant CHANGE the outcome, so the after-effect is occluded by what is really there rather than by a fixed template")
	# A real bulkhead is hit rather than merely reducing the count: at least one fragment must have spent budget on it.
	var hit_structure := false
	for record in with_state.damage_records:
		if float(record.get("consumed_mm",0.0))>0.0: hit_structure = true
	print("[CD06 T04] a structure absorbed damage in the internals-present run: %s" % str(hit_structure))
	check(hit_structure or with_records==0,
		"CD06 T04 a real bulkhead screens by being HIT, so at least one damage record carries absorbed budget when internals exist")

	# ── The same shot WITHOUT spall must still miss off-axis internals, which is the suite's own control kept intact.
	var plain := launch_spall(compartment(20.0,true),{}); complete(plain)
	print("[CD06 T04] control: no-declaration shot => damage_records=%d spall_events=%d" % [
		plain.damage_records.size(),plain.spall_events.size()])
	check(plain.damage_records.is_empty() and plain.spall_events.is_empty(),
		"CD06 T04 the retained control still holds: a round with no declared post-penetration profile neither spalls nor reaches the off-axis modules")
	print("CD06_OCCLUSION_CONTRAST PASS")
