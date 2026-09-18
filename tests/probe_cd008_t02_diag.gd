extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD08-T02 diagnostic: why does a crew station stop resolving once a person identity is decoupled from
## the station? Nothing in production is changed here - the decoupled state is built as a snapshot and handed to the resolver -
## so the answer comes from measurement rather than from another edit that a green run could hide.
##
##   D1 with the CURRENT state, every station resolves;
##   D2 with a DECOUPLED state (people keyed by person_1..person_N, assignments mapping role -> person_N), the resolver is
##      asked again and exactly which stations stop resolving is printed.

func _cd008_layout() -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd008_five"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	for role in ["assistant_driver","commander","loader","gunner","driver"]:
		var station := CrewStationDefinition.new()
		station.id = role          # the training layout names a station by its role, which is why the two were conflated
		station.role = role
		station.part_id = "hull"
		layout.crew_stations.append(station)
	return layout

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd008_diag_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD08 diag creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd008_diag_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD08 diag the fixture packet registers")
	var actor := VehicleActor.new(); root.add_child(actor)
	check(actor.setup(defs,packet.id,"cd008_diag",1,Transform3D.IDENTITY,2,null).ok,"CD08 diag the actor installs")
	actor.set_damage_layout(_cd008_layout())
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var roles := ["assistant_driver","commander","loader","gunner","driver"]
	var current := actor.state.damage_snapshot()
	print("[CD08 diag] CURRENT people=%s assignments=%s station_roles=%s" % [
		str((current.get("people",{}) as Dictionary).keys()),str(current.get("assignments",{})),str(current.get("station_roles",{}))])
	var ok_current := 0
	for role in roles:
		var d := DamageResolver.resolve({"kind":"crew","crew_id":role},70,current)
		if bool(d.get("ok",false)): ok_current += 1
	print("[CD08 diag] D1 current: resolved %d of %d" % [ok_current,roles.size()])
	check(ok_current == roles.size(),"CD08 diag D1 with the current state every station resolves: %d of %d" % [ok_current,roles.size()])

	# Build the DECOUPLED state exactly as the reverted implementation would have produced it, and ask the resolver again.
	var decoupled := current.duplicate(true)
	var people := {}
	var assignments := {}
	var station_roles: Dictionary = decoupled.get("station_roles",{})
	var index := 0
	for station_id in station_roles.keys():
		index += 1
		var pid := "person_%d" % index
		var role := str(station_roles[station_id])
		people[pid] = CrewDamageProfile.fresh_person(role)
		assignments[role] = pid
	decoupled["people"] = people
	decoupled["assignments"] = assignments
	print("[CD08 diag] DECOUPLED people=%s assignments=%s" % [str(people.keys()),str(assignments)])
	var ok_decoupled := 0
	var missed: Array = []
	for role in roles:
		var d2 := DamageResolver.resolve({"kind":"crew","crew_id":role},70,decoupled)
		var good := bool(d2.get("ok",false))
		if good: ok_decoupled += 1
		else: missed.append(role + ":" + str(d2.get("reason","")))
		print("[CD08 diag] D2 role=%-16s ok=%s reason=%-18s person_id=%s" % [
			role,str(good),str(d2.get("reason","")),str(d2.get("person_id",""))])
	print("[CD08 diag] D2 decoupled: resolved %d of %d ; missed=%s" % [ok_decoupled,roles.size(),str(missed)])
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD08_T02_DIAG_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
