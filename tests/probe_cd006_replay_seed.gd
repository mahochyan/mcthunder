extends "res://tests/run_spall_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD06-T06: the same seed settles the same way, turning the presentation off does not move the
## settlement, and validating a replay applies nothing a second time.
##
## The suite's own fixture fires with a fixed seed, so the dispersion is reproducible by construction; what this probe
## measures is that the SETTLEMENT follows it - the fragment directions and the damage they commit - and that neither the
## presentation flag nor a replay pass changes any of it.

func _cd6t6_summary(st: ProjectileState) -> Dictionary:
	var directions: Array = []
	for fragment in st.fragments: directions.append(str(fragment.get("direction",Vector3.ZERO)))
	var records: Array = []
	for record in st.damage_records:
		records.append([str(record.get("target_key",record.get("target",""))),float(record.get("consumed_mm",0.0))])
	return {"fragments":directions,"records":records,"spall_events":st.spall_events.size(),
		"consumed_mm":st.consumed_mm,"seed":st.seed}

func spall_runtime_cases() -> void:
	super.spall_runtime_cases()

	# ── L1: the same seed settles the same way, to the digit.
	var first := launch_spall(compartment()); complete(first)
	var second := launch_spall(compartment()); complete(second)
	var a := _cd6t6_summary(first)
	var b := _cd6t6_summary(second)
	print("[CD06 T06] L1 seed=%d twice => fragments=%d/%d records=%d/%d consumed=%.4f/%.4f" % [
		int(a.seed),a.fragments.size(),b.fragments.size(),a.records.size(),b.records.size(),float(a.consumed_mm),float(b.consumed_mm)])
	check(int(a.seed)==int(b.seed) and a.fragments.size()>0,
		"CD06 T06 L1 both shots carry the same fixed seed and really produce fragments")
	check(a.fragments==b.fragments,
		"CD06 T06 L1 the same seed reproduces every fragment direction exactly, so a replay can reproduce the dispersion")
	check(a.records==b.records and absf(float(a.consumed_mm)-float(b.consumed_mm))<=1e-6,
		"CD06 T06 L1 and the settlement it produces is identical: records %d, consumed %.4f mm" % [a.records.size(),float(a.consumed_mm)])

	# ── L2: the presentation flag is presentation only.
	manager.presentation_enabled=false
	var without := launch_spall(compartment()); complete(without)
	var c := _cd6t6_summary(without)
	manager.presentation_enabled=true
	var with := launch_spall(compartment()); complete(with)
	var d := _cd6t6_summary(with)
	print("[CD06 T06] L2 presentation off => records=%d consumed=%.4f ; on => records=%d consumed=%.4f" % [
		c.records.size(),float(c.consumed_mm),d.records.size(),float(d.consumed_mm)])
	check(c.records==d.records and absf(float(c.consumed_mm)-float(d.consumed_mm))<=1e-6,
		"CD06 T06 L2 turning the presentation off does not move the settlement at all: %.4f vs %.4f mm" % [float(c.consumed_mm),float(d.consumed_mm)])
	check(c.fragments==d.fragments,
		"CD06 T06 L2 and the dispersion is the same either way, so the flag is presentation and not simulation")

	# ── L3: validating a replay applies nothing a second time.
	var replay_state := launch_spall(compartment()); complete(replay_state)
	var record := record_for(replay_state)
	var ammo_before := actor_inventory_snapshot()
	var modules_before := actor_module_snapshot()
	var validate_once := ShotRecordBuilder.validate(record)
	var validate_twice := ShotRecordBuilder.validate(record)
	var ammo_after := actor_inventory_snapshot()
	var modules_after := actor_module_snapshot()
	print("[CD06 T06] L3 validate once=%s twice=%s ; ammo unchanged=%s ; modules unchanged=%s" % [
		str(validate_once.ok),str(validate_twice.ok),str(ammo_before==ammo_after),str(modules_before==modules_after)])
	check(validate_once.ok and validate_twice.ok,
		"CD06 T06 L3 the record validates, twice, so the replay path is a check rather than an application")
	check(ammo_before==ammo_after,
		"CD06 T06 L3 replaying does NOT deduct ammunition a second time: inventory unchanged")
	check(modules_before==modules_after,
		"CD06 T06 L3 and it does not damage or consume anything a second time: module states unchanged")
	print("CD06_REPLAY_NO_REAPPLY PASS")

## The actor's own inventory and module state, read from the fixture's target the suite already drives.
func actor_inventory_snapshot() -> String:
	return JSON.stringify(target.gunner.inventory.snapshot()) if target != null and target.gunner != null else "<none>"

func actor_module_snapshot() -> String:
	if target == null: return "<none>"
	return JSON.stringify(target.state.module_states.keys().map(func(k): return [str(k),float(target.state.module_states[k].integrity)]))
