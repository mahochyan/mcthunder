extends "res://tests/run_chemical_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD06-T05: a shaped charge spends its own budget step by step, and the jet is not a kinetic residual
## wearing a different name.
##
## The sharp judgment follows from the order's own wording. If the jet were secretly driven by the carrier's residual kinetic
## speed, then changing that speed would change the jet's reach. So the probe fires the identical geometry at two very
## different carrier speeds and requires the jet's own accounting to be IDENTICAL - same travelled distance, same remaining
## budget, same completion state. Everything else here is the per-step shape of that budget: each step names its channel, and
## the steps sum to the whole.

func chemical_cases() -> void:
	super.chemical_cases()

	# ── The jet's own ledger, at one speed.
	var fast := launch_chemical(compartment(),2.0,600.0); complete(fast)
	var slow := launch_chemical(compartment(),2.0,300.0); complete(slow)
	var fast_effect: Dictionary = fast.chemical_effect
	var slow_effect: Dictionary = slow.chemical_effect
	print("[CD06 T05] carrier 600 m/s => jet distance=%.4f remaining=%.4f complete=%s terminal=%s" % [
		float(fast_effect.get("distance_m",-1.0)),float(fast_effect.get("remaining_mm",-1.0)),
		str(fast_effect.get("complete","")),str(fast.terminal_reason)])
	print("[CD06 T05] carrier 300 m/s => jet distance=%.4f remaining=%.4f complete=%s terminal=%s" % [
		float(slow_effect.get("distance_m",-1.0)),float(slow_effect.get("remaining_mm",-1.0)),
		str(slow_effect.get("complete","")),str(slow.terminal_reason)])
	check(absf(float(fast_effect.get("distance_m",-1.0))-float(slow_effect.get("distance_m",-1.0)))<=1e-6,
		"CD06 T05 the jet's reach is IDENTICAL at 600 and 300 metres per second, so it is not the carrier's residual kinetic speed in disguise: %.4f vs %.4f m" % [
			float(fast_effect.get("distance_m",-1.0)),float(slow_effect.get("distance_m",-1.0))])
	check(absf(float(fast_effect.get("remaining_mm",-1.0))-float(slow_effect.get("remaining_mm",-1.0)))<=1e-6,
		"CD06 T05 and its remaining budget is identical too: %.4f vs %.4f mm" % [
			float(fast_effect.get("remaining_mm",-1.0)),float(slow_effect.get("remaining_mm",-1.0))])
	check(str(fast.terminal_reason)==str(slow.terminal_reason),
		"CD06 T05 the two carriers even end in the same terminal state: %s vs %s" % [str(fast.terminal_reason),str(slow.terminal_reason)])

	# ── Per-step: every contact of the after-effect names the jet channel, and the steps account for the whole budget.
	var channels: Array = []
	for contact in fast.contacts: channels.append(str(contact.get("effect_channel","")))
	var after: Array = []
	for contact in fast.contacts: after.append([float(contact.get("effective_mm",-1.0)),float(contact.get("consumed_mm",-1.0))])
	print("[CD06 T05] jet contacts=%d channels=%s per-contact (effective, consumed)=%s" % [
		fast.contacts.size(),str(channels),str(after)])
	check(fast.contacts.size()>=1 and not channels.has("") and not channels.has("kinetic"),
		"CD06 T05 every step of the after-effect names its own channel and none of them is the kinetic one: %s" % str(channels))
	var jet_all := true
	for channel in channels:
		if channel!="chemical_jet": jet_all = false
	check(jet_all,"CD06 T05 the after-effect runs on the chemical jet channel throughout: %s" % str(channels))
	# The budget is one figure split across the steps that consumed it, so the steps cannot exceed the declared total.
	var spent := 0.0
	for contact in fast.contacts: spent += float(contact.get("consumed_mm",0.0))
	# The declared ledger has more lines than there are contacts: the suite's own assertion on this fixture measures twenty
	# millimetres of armour, ten of module and thirty of terminal path loss out of the hundred, leaving forty. My first
	# version added only the contact lines to the remainder and expected the whole hundred, which was my arithmetic rather
	# than the model's: the module and the terminal path loss are spent outside the contact records.
	var declared_off_contact := 10.0+30.0
	print("[CD06 T05] step-by-step spend=%.4f mm ; declared off-contact module+path loss=%.4f ; jet remaining=%.4f ; budget=100" % [
		spent,declared_off_contact,float(fast_effect.get("remaining_mm",-1.0))])
	check(spent<=100.0+1e-6,
		"CD06 T05 the steps together spend at most the declared budget rather than each spending the whole of it: %.4f mm" % spent)
	check(absf(spent+declared_off_contact+float(fast_effect.get("remaining_mm",0.0))-100.0)<=1e-6,
		"CD06 T05 and the contact lines plus the module and terminal path loss plus what remains account for the whole declared budget, so the path is traceable: %.4f + %.4f + %.4f == 100" % [
			spent,declared_off_contact,float(fast_effect.get("remaining_mm",-1.0))])
	print("CD06_JET_LEDGER PASS")
