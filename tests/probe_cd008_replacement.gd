extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD08-T02: does the replacement path really leave one non-empty person holding two roles? This probe
## builds its OWN actor and its own layout - it borrows nothing from a suite, which is the mistake that aborted the previous
## attempt before it could print - and it measures the state level semantics the delivered leg asserts.
##
##   R0 the baseline assignment map, printed;
##   R1 after a lawful replacement (assign the person who holds one role into another role), no non-empty person holds two;
##   R2 and the role the person left is empty, the headcount is unchanged, and the person keeps their own state.

func _cd008_layout() -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd008_replace"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	for role in ["assistant_driver","commander","loader","gunner","driver"]:
		var station := CrewStationDefinition.new()
		station.id = role; station.role = role; station.part_id = "hull"
		layout.crew_stations.append(station)
	return layout

func _duplicates(assignments: Dictionary) -> Array:
	var seen := {}
	var dupes: Array = []
	for role in assignments.keys():
		var person := str(assignments[role])
		if person == "": continue
		if seen.has(person): dupes.append(person + " in " + str(seen[person]) + " and " + str(role))
		seen[person] = role
	return dupes

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd008_rep_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD08 replace creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd008_rep_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD08 replace the fixture packet registers")
	var actor := VehicleActor.new(); root.add_child(actor)
	check(actor.setup(defs,packet.id,"cd008_replace",1,Transform3D.IDENTITY,2,null).ok,"CD08 replace the actor installs")
	actor.set_damage_layout(_cd008_layout())
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	var base: Dictionary = actor.state.crew_assignments.duplicate(true)
	print("[CD08 rep] R0 assignments=%s" % str(base))
	print("[CD08 rep] R0 people keys=%s" % str(actor.state.crew_states.keys()))
	print("[CD08 rep] R0 duplicates=%s" % str(_duplicates(base)))

	# Incapacitate the gunner, then move the commander into the gunner role: the delivered replacement pattern.
	var gunner_person := str(base.get("gunner",""))
	var commander_person := str(base.get("commander",""))
	var gunner_state: Dictionary = (actor.state.crew_states.get(gunner_person,{}) as Dictionary).duplicate(true)
	gunner_state["alive"] = false
	gunner_state["condition"] = CrewDamageProfile.CONDITION_INCAPACITATED
	var down := actor.state.apply_damage_delta("cd008_rep_down",{"ok":true,"kind":"crew","item_id":gunner_person,
		"person_id":gunner_person,"before":(actor.state.crew_states.get(gunner_person,{}) as Dictionary).duplicate(true),
		"after":gunner_state,"source":{}})
	check(bool(down.get("ok",false)),"CD08 replace the incapacitating submission is accepted")
	var commander_before: Dictionary = (actor.state.crew_states.get(commander_person,{}) as Dictionary).duplicate(true)
	var count_before: int = actor.state.alive_crew_count()
	var moved := actor.state.assign_crew("gunner",commander_person)
	var after: Dictionary = actor.state.crew_assignments.duplicate(true)
	print("[CD08 rep] R1 moved=%s assignments=%s" % [str(moved),str(after)])
	print("[CD08 rep] R1 duplicates=%s" % str(_duplicates(after)))
	print("[CD08 rep] R1 commander kept own state=%s ; alive %d -> %d" % [
		str(actor.state.crew_states.get(commander_person,{}) == commander_before),count_before,actor.state.alive_crew_count()])
	check(moved,"CD08 replace R1 the replacement itself succeeds")
	check(_duplicates(after).is_empty(),
		"CD08 replace R1 NO non-empty person holds two roles after the replacement: %s" % str(_duplicates(after)))
	check(str(after.get("commander","")) == "" or str(after.get("commander","")) == commander_person,
		"CD08 replace R2 either the person left the old role or they never held it: commander slot=%s" % str(after.get("commander","")))
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD08_REPLACE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
