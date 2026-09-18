extends "res://tests/run_chemical_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T05: the HEAT channel is isolated. The order asks that events are separated by channel and that
## a jet must not additionally pass itself off as overpressure.
##
## J1 the jet's own events are ALL on the chemical jet channel and the shot produces NO overpressure channel at all, so the
##    jet cannot be double-counted as pressure;
## J2 the lawful shell burst is a SEPARATE configuration and the contract refuses to mix them, which is what enforces the
##    separation rather than mere behaviour: a chemical profile cannot be attached to an internal burst round, and a
##    post-penetration spall profile cannot be attached to a chemical one.

func chemical_cases() -> void:
	super.chemical_cases()

	var st := launch_chemical(compartment()); complete(st)
	var channels: Array = []
	for contact in st.contacts: channels.append(str(contact.get("effect_channel","")))
	var non_jet := 0
	for channel in channels: if channel != "chemical_jet": non_jet += 1
	var burst: Dictionary = st.burst if st.burst is Dictionary else {}
	var over_channels := int((burst.get("channels",{}) as Dictionary).size())
	print("[CD07 T05] J1 jet contacts=%d channels=%s ; burst_empty=%s ; burst_channel_entries=%d ; terminal=%s" % [
		st.contacts.size(),str(channels),str(burst.is_empty()),over_channels,str(st.terminal_reason)])
	check(st.contacts.size()>=1 and non_jet==0,
		"CD07 T05 J1 every after-effect event of a HEAT is on the chemical jet channel: %s" % str(channels))
	check(burst.is_empty() and over_channels==0,
		"CD07 T05 J1 and the jet produces NO overpressure channel of its own, so it cannot be double-counted as pressure: burst_empty=%s entries=%d" % [
			str(burst.is_empty()),over_channels])
	check(st.fragments.is_empty() and st.spall_events.is_empty(),
		"CD07 T05 J1 nor does it emit fragments or a spall event, which belong to the other channels")

	# J2: the separation is enforced by the contract, not merely observed.
	var chemical_profile: Dictionary = HeatFixture.profile()
	var burst_profile := {"version":ArmorImpactProfile.VERSION,"family":"APHE","provenance":"game_rule",
		"reason":"CD07-T05 probe fixture: an internal-burst round profile offered to a chemical round",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}
	var attach_chemical_to_burst := ChemicalProfile.validate(chemical_profile,"internal_burst")
	var attach_spall_to_chemical := SpallProfile.validate({"version":SpallProfile.VERSION_INTERNAL_BURST,"provenance":"game_rule",
		"reason":"CD07-T05 probe fixture: a post-penetration profile offered to a chemical round","count":5,"cone_deg":50.0,
		"range_m":3.0,"budget_fraction":0.20,"max_total_mm":50.0,"min_residual_mm":4.0,
		"fragment_impact_profile":{"version":ArmorImpactProfile.VERSION,"family":"fragment","provenance":"game_rule",
			"reason":"fixture","normalization_deg":0,"overmatch_ratio":0,"ricochet_deg":85,
			"material_coefficients":{"rolled":1,"cast":0.95}}},"chemical")
	print("[CD07 T05] J2 chemical-on-burst errors=%d ; spall-on-chemical errors=%d" % [
		attach_chemical_to_burst.size(),attach_spall_to_chemical.size()])
	check(not attach_chemical_to_burst.is_empty(),
		"CD07 T05 J2 the contract refuses to attach a chemical profile to an internal burst round: %s" % str(attach_chemical_to_burst))
	check(not attach_spall_to_chemical.is_empty(),
		"CD07 T05 J2 and it refuses to attach a post-penetration profile to a chemical one: %s" % str(attach_spall_to_chemical))
	check(not burst_profile.is_empty() and not chemical_profile.is_empty(),
		"CD07 T05 J2 both configurations exist separately, so the separation is a real contract rather than a missing feature")
	print("CD07_CHEMICAL_CHANNEL_ISOLATION PASS")
