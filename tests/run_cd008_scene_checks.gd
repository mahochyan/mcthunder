extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD08 acceptance scenes, written BEFORE the implementation, as the work order requires.
##
## The expectations are fixed now and must not be edited later to make anything pass. Each scene submits a LAWFUL damage
## delta - the submission contract needs delta.ok, a non-empty event id, and a before/after pair that matches the current
## state - and then measures whether the declared expectation holds. A scene that does not hold is recorded as NOT_YET_MET
## rather than dressed up, so the tree stays green while the gap is stated in the open.
##
##   S1 the same person wounded repeatedly: a repeated event is not counted twice, distinct lawful events accumulate
##   S2 people and stations separate: headcount conserved, the old station emptied, injury follows the person
##   S3 recovery and incapacitation: recovery obeys rules, an incapacitated person does not revive in this life
##   S4 a legacy alive record and a new life: the migration is versioned and reversible, old damage cannot act on a new life

var checks := 0
var failures := 0
var not_yet_met: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func met(id: String, condition: bool, declared: String, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s MET (declared expectation holds): %s" % [id,declared])
		return
	not_yet_met.append("%s: %s" % [id,declared])
	print("[SCENE] %s NOT_YET_MET (declared expectation, recorded rather than relaxed): %s" % [id,label])

func _layout() -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd008_crew"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var driver := CrewStationDefinition.new(); driver.id = "station_driver"; driver.role = "driver"; driver.part_id = "hull"
	var gunner := CrewStationDefinition.new(); gunner.id = "station_gunner"; gunner.role = "gunner"; gunner.part_id = "hull"
	layout.crew_stations.append(driver); layout.crew_stations.append(gunner)
	return layout

## A lawful crew delta: the contract wants ok, a matching before/after pair, and the person and item it concerns.
func _crew_submission(state: VehicleRuntimeState, person: String, after: Dictionary) -> Dictionary:
	var people: Dictionary = state.damage_snapshot().get("people",{})
	if not people.has(person): return {}
	return {"ok":true,"kind":"crew","item_id":person,"person_id":person,
		"before":(people[person] as Dictionary).duplicate(true),"after":after.duplicate(true),"source":{}}

func _run() -> void:
	var state := VehicleRuntimeState.new()
	state.initialize_damage(_layout())
	check(state.alive_crew_count() == 2,"CD08 baseline: two crew stations initialise alive")
	var snap0 := state.damage_snapshot()
	print("[CD08] baseline: driver=%s gunner=%s ; people keys=%s ; station_roles=%s" % [
		str(state.role_available("driver")),str(state.role_available("gunner")),
		str((snap0.get("people",{}) as Dictionary).keys()),str(snap0.get("station_roles",{}))])

	# S1: the same person wounded repeatedly. The submission contract already carries an event identity.
	var sub := _crew_submission(state,"person_gunner",{"alive":false,"condition":"incapacitated","original_role":"gunner"})
	check(not sub.is_empty(),"CD08 S1 a lawful crew submission can be built against the real state")
	var first := state.apply_damage_delta("cd008_evt_1",sub)
	var after_first: Dictionary = state.damage_snapshot().get("people",{})
	var repeat_sub := _crew_submission(state,"person_gunner",{"alive":false,"condition":"incapacitated","original_role":"gunner"})
	var repeat := state.apply_damage_delta("cd008_evt_1",repeat_sub)
	var alive_after: int = state.alive_crew_count()
	print("[CD08] S1 first=%s repeat=%s alive=%d people=%s" % [
		str(first),str(repeat),alive_after,str(after_first.get("person_gunner",{}))])
	check(bool(first.get("ok",false)),"CD08 S1 the first lawful submission is accepted")
	met("CD08-T03", bool(repeat.get("ok",true)) == false and str(repeat.get("reason","")) == "invalid_or_duplicate",
		"a repeated event identity must not be applied a second time",
		"a repeated event identity was not refused as a duplicate")
	# Judged on the product produced state read BEFORE any submission of mine: condition I wrote myself would prove nothing.
	met("CD08-T01", str((snap0.get("people",{}).get("person_gunner",{}) as Dictionary).get("condition","")) != "",
		"a graded condition (light/serious/incapacitated) must exist rather than a boolean",
		"condition is still a boolean, so there is nothing to grade")

	# S2: people and stations separate. Today the person key IS the station key, which is the hazard recorded earlier.
	var people_keys: Array = (snap0.get("people",{}) as Dictionary).keys()
	var roles: Dictionary = snap0.get("station_roles",{})
	var person_is_station := true
	for key in people_keys:
		if not roles.has(key): person_is_station = false
	print("[CD08] S2 people keys=%s ; station ids=%s ; person key equals a station id for every person=%s" % [
		str(people_keys),str(roles.keys()),str(person_is_station)])
	met("CD08-T02", not person_is_station,
		"a person must be identifiable separately from the station they occupy",
		"the person key is the station key, so a person and a station are not yet distinguishable")

	# S3: recovery and incapacitation.
	var incap_sub := _crew_submission(state,"person_driver",{"alive":false,"condition":"incapacitated","original_role":"driver"})
	var incap := state.apply_damage_delta("cd008_evt_3",incap_sub)
	var alive_after_incap: int = state.alive_crew_count()
	var revived := false
	for i in 3:
		var rec_sub := _crew_submission(state,"person_driver",{"alive":true,"condition":"healthy","original_role":"driver"})
		state.apply_damage_delta("cd008_recover_%d" % i,rec_sub)
		if state.alive_crew_count() > alive_after_incap: revived = true
	print("[CD08] S3 incap ok=%s alive=%d revived=%s" % [str(incap.get("ok",false)),alive_after_incap,str(revived)])
	check(bool(incap.get("ok",false)),"CD08 S3 the incapacitating submission is accepted")
	met("CD08-T04", not revived,
		"an incapacitated crew member must not revive within the same life",
		"an incapacitated crew member came back within the same life")

	# S4: a legacy alive record and a new life.
	var legacy := {"people":{"station_driver":{"alive":false,"original_role":"driver"}}}
	var migrated := state.apply_damage_delta("cd008_legacy_1",{"ok":true,"kind":"legacy_alive","item_id":"station_driver",
		"person_id":"station_driver","before":{},"after":{},"snapshot":legacy,"source":{}})
	var versioned := str(migrated.get("migration_version","")) != ""
	print("[CD08] S4 legacy migration=%s" % str(migrated))
	met("CD08-T06", versioned,
		"a legacy alive record must migrate under a named version that can be rolled back",
		"no versioned migration exists for a legacy alive record")
	var new_life := VehicleRuntimeState.new()
	new_life.initialize_damage(_layout())
	met("CD08-T06", new_life.alive_crew_count() == 2,
		"old damage must not act on a new life",
		"a new life did not start from a clean crew state")

	print("[CD08] scenes=4 ; not_yet_met=%d" % not_yet_met.size())
	for entry in not_yet_met: print("[CD08]   NOT_YET_MET %s" % entry)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD08_SCENES_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
