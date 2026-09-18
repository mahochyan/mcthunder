extends "res://tests/run_chemical_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T06: many targets and finality. The order asks three things: one lawful effect per object,
## no damage to a target that is not permitted, and an explicit state when a shot is cancelled.
##
##   M1 within ONE shot an object receives at most one lawful effect - the records contain no repeated object - so a target
##      cannot be hit twice by the same explosion;
##   M2 a target the match policy refuses takes NO damage at all, and the refusal is its own terminal reason rather than a
##      silent no-op;
##   M3 a cancelled shot ends in the explicitly named cancelled state, not in an empty or guessed one.

func chemical_cases() -> void:
	super.chemical_cases()

	# ── M1: one lawful effect per object, judged from the shot's own records.
	var st := launch_chemical(compartment()); complete(st)
	if st.damage_records.size()>=1: print("[CD07 T06] M1 record keys=%s" % str((st.damage_records[0] as Dictionary).keys()))
	var keys: Array = []
	# The object identity is the target, the part and the module together; item_key was my guess and produced empty strings,
	# which would have made this leg pass without measuring anything.
	for record in st.damage_records: keys.append("%s|%s|%s" % [str(record.get("entity_id","")),str(record.get("part_id","")),str(record.get("module_id",""))])
	var unique := {}
	var repeats := 0
	for key in keys:
		if unique.has(key): repeats += 1
		unique[key] = true
	print("[CD07 T06] M1 records=%d keys=%s unique=%d repeats=%d" % [keys.size(),str(keys),unique.size(),repeats])
	check(keys.size()>=1 and not str(keys[0]).begins_with("||"),"CD07 T06 M1 the shot records the objects it lawfully affected, and the key really identifies an object: %s" % str(keys))
	check(repeats==0,
		"CD07 T06 M1 and NO object receives a second lawful effect within the same shot: repeats=%d" % repeats)
	check(unique.size()==keys.size(),
		"CD07 T06 M1 so the object count and the record count agree, which is what one-effect-per-object means: %d vs %d" % [unique.size(),keys.size()])

	# ── M2: a refused target takes no damage, and the refusal is named.
	# The previous leg already destroyed this module, so the baseline has to be a fresh layout; comparing against a
	# damaged starting point would have measured the earlier shot rather than this one.
	target.set_damage_layout(compartment())
	var before: float = float(target.state.module_states.jet_component.integrity)
	manager.contact_policy = func(_shooter: Dictionary,_event: Dictionary) -> Dictionary: return {"allow":false,"reason":"cd007_target_not_permitted"}
	var refused := launch_chemical(compartment()); complete(refused)
	var after: float = float(target.state.module_states.jet_component.integrity)
	print("[CD07 T06] M2 terminal=%s records=%d integrity %.4f -> %.4f" % [
		str(refused.terminal_reason),refused.damage_records.size(),before,after])
	check(refused.damage_records.is_empty(),
		"CD07 T06 M2 a target the policy refuses takes NO damage at all: %d records" % refused.damage_records.size())
	check(is_equal_approx(before,after),
		"CD07 T06 M2 and its components are untouched, so the refusal is real rather than a mislabelled hit: %.4f -> %.4f" % [before,after])
	check(str(refused.terminal_reason)=="cd007_target_not_permitted",
		"CD07 T06 M2 and the refusal is its OWN explicit terminal reason rather than a silent no-op: %s" % str(refused.terminal_reason))
	manager.contact_policy = Callable()

	# ── M3: cancellation is explicit.
	var cancelled := launch_chemical(compartment())
	manager.cancel_all("cancelled_match_finished")
	print("[CD07 T06] M3 terminal=%s" % str(cancelled.terminal_reason))
	check(cancelled.is_terminal(),
		"CD07 T06 M3 a cancelled shot is terminal rather than left in flight")
	check(str(cancelled.terminal_reason)=="cancelled_match_finished",
		"CD07 T06 M3 and it ends in the explicitly named cancelled state rather than an empty or guessed one: %s" % str(cancelled.terminal_reason))
	print("CD07_MULTI_TARGET_FINALITY_PASS" if failed==0 else "CD07_MULTI_TARGET_FINALITY_FAIL")
