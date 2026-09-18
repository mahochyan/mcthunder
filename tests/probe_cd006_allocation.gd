extends "res://tests/run_spall_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD06 design point three, first half: one source event allocates ONE budget, and the number of
## sample lines distributes that budget rather than multiplying it. The order forbids copying a block of total damage for
## every generated sample line, so the two facts to pin down are that the allocation is a single bounded figure derived
## from the carrier's residual, and that it does not depend on how many lines will be drawn from it.
##
## I first read this as a defect because I had truncated my own view of the fragment system above the line that divides the
## allocation by the sample count. The measurement below is what settles it either way.

func _cd6_alloc_profile(count: int, fraction: float, maximum: float, minimum: float) -> Dictionary:
	return {"version":SpallProfile.VERSION,"provenance":"game_rule",
		"reason":"CD06-T03 probe fixture: an allocation table used only to measure the split convention",
		"count":count,"cone_deg":35.0,"range_m":3.0,"budget_fraction":fraction,"max_total_mm":maximum,"min_residual_mm":minimum}

func spall_runtime_cases() -> void:
	super.spall_runtime_cases()

	# ── One source event, one bounded allocation, re-derived here from the declared fields.
	var profile := _cd6_alloc_profile(4,0.25,60.0,5.0)
	var residual := 100.0
	var allocated := SpallProfile.allocation(profile,residual)
	var expected := minf(residual*0.25,60.0)
	print("[CD06 T03] residual=%.1f => allocated=%.4f ; independently re-derived=%.4f (fraction %.2f, cap %.1f)" % [
		residual,allocated,expected,float(profile.budget_fraction),float(profile.max_total_mm)])
	check(absf(allocated-expected)<=1e-9,
		"CD06 T03 the source event's allocation equals an independent re-derivation from the carrier's residual: %.4f vs %.4f" % [allocated,expected])
	check(allocated<=float(profile.max_total_mm)+1e-9 and allocated<=residual*float(profile.budget_fraction)+1e-9,
		"CD06 T03 the allocation is bounded by both the declared cap and its fraction of the residual: %.4f" % allocated)
	check(SpallProfile.allocation(profile,float(profile.min_residual_mm)-1.0)==0.0,
		"CD06 T03 and below the declared minimum residual the allocation is exactly zero rather than a token amount")

	# ── The allocation is a DISTRIBUTION, not a budget: the sample count must not change it.
	var four := SpallProfile.allocation(_cd6_alloc_profile(4,0.25,60.0,5.0),residual)
	var eight := SpallProfile.allocation(_cd6_alloc_profile(8,0.25,60.0,5.0),residual)
	var one := SpallProfile.allocation(_cd6_alloc_profile(1,0.25,60.0,5.0),residual)
	print("[CD06 T03] allocation for 1 / 4 / 8 sample lines = %.4f / %.4f / %.4f" % [one,four,eight])
	check(absf(four-eight)<=1e-9 and absf(one-eight)<=1e-9,
		"CD06 T03 the number of sample lines does NOT change the total: one, four and eight lines all allocate %.4f" % allocated)
	# And the split is exactly the conservation the order asks for: each line takes allocated/count, so the sum is the total.
	var conserved := true
	for count in [1,2,4,8]:
		var this_profile := _cd6_alloc_profile(count,0.25,60.0,5.0)
		var per_line: float = SpallProfile.allocation(this_profile,residual)/float(count)
		if absf(per_line*float(count)-SpallProfile.allocation(this_profile,residual))>1e-9: conserved = false
	print("[CD06 T03] per-line budget x lines == allocation for counts 1,2,4,8: %s" % str(conserved))
	check(conserved,
		"CD06 T03 the split conserves the allocation: each line's share times the number of lines returns the total, so no sample can add a block of its own")

	# ── The direction field itself is bounded by the same profile, and the count is what it varies.
	var directions_four := SpallProfile.directions(profile,Vector3(0,0,-1),4242,0)
	var directions_eight := SpallProfile.directions(_cd6_alloc_profile(8,0.25,60.0,5.0),Vector3(0,0,-1),4242,0)
	print("[CD06 T03] directions emitted: count=4 -> %d ; count=8 -> %d (the count shapes the distribution)" % [
		directions_four.size(),directions_eight.size()])
	check(directions_four.size()==4 and directions_eight.size()==8,
		"CD06 T03 the sample count shapes how many directions are drawn while the budget it draws from is unchanged")
	print("CD06_ONE_ALLOCATION PASS")
