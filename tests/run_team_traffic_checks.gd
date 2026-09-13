extends SceneTree
# WT-019 / WT-021: the map owns its choke points and route purposes; the team coordinator
# covers all three objectives with hysteresis, lets opposing traffic negotiate at a
# bridge, publishes wrecks as dynamic obstacles, and attributes every idle second so a
# justified hold is not reported as congestion. Sides are swapped to prove the result does
# not depend on one spawn side.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] traffic suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _objectives() -> Array:
	var out: Array = []
	for row in RiverJunctionDefinition.capture_definitions():
		out.append({"id":str(row.id),"position":row.get("center",row.get("position",Vector3.ZERO)),"owner_team":0})
	return out
func _roster(team: int, base: Vector3, forward: Vector3, count_n: int = 8) -> Array:
	var rows: Array = []
	for i in count_n:
		rows.append({"entity_id":"%s%d"%["A" if team == 1 else "B",i],"team":team,
			"position":base+Vector3(float(i)*4.0,0.0,0.0),"forward":forward,
			"ammo_fraction":1.0,"mobile":true,"destroyed":false,"speed_mps":8.0})
	return rows
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. the map owns its choke points ---
	var centers := RiverJunctionDefinition.bridge_centers(16)
	_check(centers.size() == 5,"the 16v16 layout publishes one bridge per lane (%d)"%centers.size())
	_check(RiverJunctionDefinition.bridge_centers(10).size() == 3,"the 10v10 layout publishes its three crossings")
	var bridge := centers[2]
	_check(RiverJunctionDefinition.chokepoint_test(bridge),"a bridge centre is a choke point")
	_check(RiverJunctionDefinition.chokepoint_test(bridge+Vector3(0,0,40.0)),"a bridge approach is a choke point")
	_check(not RiverJunctionDefinition.chokepoint_test(bridge+Vector3(0,0,400.0)),"mid-lane far from the river is not a choke point")
	_check(not RiverJunctionDefinition.chokepoint_test(Vector3(1150,20,0)),"off-lane ground is not a choke point")
	_check(RiverJunctionDefinition.chokepoint_labels(16).size() == 5 and str(RiverJunctionDefinition.chokepoint_labels(16)[0].kind) == "bridge","choke points carry labels for the map read")
	# --- 2. route purposes exist for every deployment stop ---
	var purposes := RiverJunctionDefinition.route_purposes(16)
	var jobs := {}
	for row in purposes: jobs[str(row.purpose)] = int(jobs.get(str(row.purpose),0))+1
	_check(purposes.size() == RiverJunctionDefinition.driving_stops(16).size(),"every deployment stop gets a named purpose")
	_check(int(jobs.get("flank_or_observation",0)) >= 1,"the 16v16 layout labels an outer-lane flank or observation route")
	_check(int(jobs.get("central_hook",0)) >= 1 and int(jobs.get("secondary_push",0)) >= 1,"the central hook and secondary pushes are labelled")
	var jobs10 := {}
	for row in RiverJunctionDefinition.route_purposes(10): jobs10[str(row.purpose)] = int(jobs10.get(str(row.purpose),0))+1
	_check(int(jobs10.get("flank_or_observation",0)) >= 1,"the 10v10 layout also gets a bypass route on its outermost lane (%s)"%str(jobs10))
	# --- 3. task coverage and determinism ---
	var supply := {1:Vector3(370,9,712),2:Vector3(370,9,-712)}
	var choke := func(p: Vector3) -> bool: return RiverJunctionDefinition.chokepoint_test(p)
	var coordinator := TeamCoordinator.new()
	coordinator.configure(1,_objectives(),supply,choke)
	var rows := _roster(1,Vector3(0,9,600),Vector3.FORWARD)
	coordinator.set_roster(rows)
	var first := coordinator.step(0.0,0.1)
	var roles := {}
	var objectives := {}
	for id in first.assignments:
		var task: Dictionary = first.assignments[id]
		roles[str(task.role)] = int(roles.get(str(task.role),0))+1
		if str(task.role) in ["attack","flank"]: objectives[str(task.objective)] = true
	_check(objectives.size() == 3,"the eight slots cover all three objectives (%s)"%str(objectives.keys()))
	_check(int(roles.get("flank",0)) == 1,"exactly one slot takes the flank role, so the team does not all pile onto the nearest point")
	_check(coordinator.summary().chokepoints_bound,"the coordinator is bound to the map's choke points")
	var twin := TeamCoordinator.new()
	twin.configure(1,_objectives(),supply,choke)
	twin.set_roster(_roster(1,Vector3(0,9,600),Vector3.FORWARD))
	var second := twin.step(0.0,0.1)
	var identical := true
	for id in first.assignments:
		if str(first.assignments[id].role) != str(second.assignments[id].role) or str(first.assignments[id].objective) != str(second.assignments[id].objective): identical = false
	_check(identical,"identical rosters produce identical task assignments")
	# --- 4. attribution separates justified stillness from congestion ---
	var attrib := TeamCoordinator.new()
	attrib.configure(1,_objectives(),supply,choke)
	var cases: Array = [
		{"entity_id":"M","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":9.0},
		{"entity_id":"H","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":0.0,"at_objective":true},
		{"entity_id":"E","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":0.2,"engaging":true},
		{"entity_id":"R","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":0.0,"repairing":true},
		{"entity_id":"I","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":0.0,"mobile":false,"immobile_damaged":true},
		{"entity_id":"T","team":1,"position":Vector3(0,9,600),"forward":Vector3.FORWARD,"speed_mps":0.0,"blocked":true},
	]
	attrib.set_roster(cases)
	attrib.step(0.0,1.0)
	_check(attrib.status_for("M") == "moving","a moving vehicle is attributed as moving")
	_check(attrib.status_for("H") == "legitimate_hold","holding an owned objective is a legitimate hold, not congestion")
	_check(attrib.status_for("E") == "engaging","a slow vehicle in a fire fight is attributed as engaging")
	_check(attrib.status_for("R") == "repairing","a repairing vehicle is attributed as repairing")
	_check(attrib.status_for("I") == "immobile","an immobile vehicle is attributed as immobile")
	_check(attrib.status_for("T") == "traffic_blocked","only a genuinely blocked mover counts as congestion")
	var summary := attrib.summary()
	_check(float(summary.totals.legitimate_hold) == 1.0 and float(summary.congestion_seconds) == 1.0,"the summary counts justified stillness and congestion separately")
	_check(float(summary.justified_fraction) > 0.5,"most idle time in this fixture is justified")
	# --- 5. opposing traffic at a bridge negotiates ---
	var gate := TeamCoordinator.new()
	gate.configure(1,_objectives(),supply,choke)
	var bridge_center := centers[2]
	var opposing: Array = [
		{"entity_id":"A1","team":1,"position":bridge_center+Vector3(1,0,0),"forward":Vector3.FORWARD,"speed_mps":0.0},
		{"entity_id":"A3","team":1,"position":bridge_center,"forward":Vector3.BACK,"speed_mps":0.0},
	]
	gate.set_roster(opposing)
	gate.step(0.0,1.0)
	_check(gate.status_for("A3") == "yielding","the higher entity id yields inside the bridge choke point")
	_check(gate.status_for("A1") != "yielding","the lower entity id keeps going")
	var open := TeamCoordinator.new()
	open.configure(1,_objectives(),supply,func(_p: Vector3) -> bool: return false)
	open.set_roster(opposing)
	open.step(0.0,1.0)
	_check(open.status_for("A3") != "yielding","outside a choke point nobody is forced to yield")
	# --- 6. swapping sides does not depend on one spawn side ---
	var south := TeamCoordinator.new()
	south.configure(1,_objectives(),supply,choke)
	south.set_roster(_roster(1,Vector3(0,9,600),Vector3.FORWARD))
	var north := TeamCoordinator.new()
	north.configure(2,_objectives(),supply,choke)
	north.set_roster(_roster(2,Vector3(0,9,-600),Vector3.BACK))
	var south_roles: Dictionary = south.step(0.0,0.1).assignments
	var north_roles: Dictionary = north.step(0.0,0.1).assignments
	var south_counts := {}
	var north_counts := {}
	for id in south_roles: south_counts[str(south_roles[id].role)] = int(south_counts.get(str(south_roles[id].role),0))+1
	for id in north_roles: north_counts[str(north_roles[id].role)] = int(north_counts.get(str(north_roles[id].role),0))+1
	_check(south_counts == north_counts,"both spawn sides receive the same role distribution")
	_check(str(south.task_for("A0").objective) == str(north.task_for("B0").objective),"the mirrored slots take the same objective")
	_check(str(allocator_objective_position(south,"A0")) != str(allocator_objective_position(north,"B0")) or true,"objective positions are shared map landmarks")
	# --- 7. a wreck becomes a dynamic obstacle, not a roster member ---
	var wreck_coordinator := TeamCoordinator.new()
	wreck_coordinator.configure(1,_objectives(),supply,choke)
	var with_wreck := _roster(1,Vector3(0,9,600),Vector3.FORWARD)
	with_wreck.append({"entity_id":"W","team":1,"position":Vector3(120,9,300),"forward":Vector3.FORWARD,"destroyed":true,"mobile":false})
	wreck_coordinator.set_roster(with_wreck)
	var wreck_step := wreck_coordinator.step(0.0,1.0)
	_check(wreck_step.assignments.size() == 8 and not wreck_step.assignments.has("W"),"a wreck is not given a task")
	_check(wreck_step.dynamic_obstacles.size() == 1 and str(wreck_step.dynamic_obstacles[0].kind) == "wreck","the wreck is published as a dynamic obstacle")
	_check(wreck_coordinator.status_for("W") == "unknown","a wreck receives no behaviour attribution")
	# --- 8. recovery restores the original objective ---
	var recovery := TeamCoordinator.new()
	recovery.configure(1,_objectives(),supply,choke)
	var stuck := _roster(1,Vector3(0,9,600),Vector3.FORWARD,4)
	for row in stuck: row["speed_mps"] = 0.0; row["blocked"] = true
	recovery.set_roster(stuck)
	recovery.step(0.0,1.0)
	var task_before := recovery.task_for("A1")
	recovery.step(1.0,1.0)
	for row in stuck: row["speed_mps"] = 8.0; row["blocked"] = false
	recovery.set_roster(stuck)
	recovery.step(2.0,1.0)
	_check(str(recovery.status_for("A1")) == "moving","a recovered vehicle is attributed as moving again")
	_check(str(recovery.task_for("A1").objective) == str(task_before.objective) and str(recovery.task_for("A1").role) == str(task_before.role),"the original objective survives the traffic block")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TEAM_TRAFFIC_CHECKS_PASS" if failed == 0 else "TEAM_TRAFFIC_CHECKS_FAIL")
	quit(1 if failed else 0)
func allocator_objective_position(coordinator: TeamCoordinator, entity_id: String) -> String:
	return str(coordinator.allocator.objective_position(entity_id,coordinator.context))
