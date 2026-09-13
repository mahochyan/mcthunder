extends SceneTree
# WT-032-R1 reachability regression (headless):
#  - road graph contract per layout (schema, map id, node/edge counts)
#  - every spawn -> A/B/C and every spawn -> own resupply is reachable
#  - a flank route survives closing the central crossing
#  - wreck-occupied ground is reported and avoided by spawn selection
#  - survey and formal entries read the same map data (deterministic graph)
# No teleporting is used anywhere: only graph planning and physical occupancy.
var count := 0
var failed := 0
var world: Node3D
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _on_central_lane(p: Vector3) -> bool:
	return absf(p.x-RiverJunctionDefinition.lane_x(0.0,p.z)) < 40.0
func _without_central_crossing(graph: Dictionary) -> Dictionary:
	var copy: Dictionary = graph.duplicate(true)
	var positions := {}
	for row in copy.nodes: positions[row.id] = Vector3(row.position[0],row.position[1],row.position[2])
	var keep: Array = []
	for edge in copy.edges:
		var a: Vector3 = positions[edge.a]
		var b: Vector3 = positions[edge.b]
		if _on_central_lane(a) and _on_central_lane(b): continue
		keep.append(edge)
	copy.edges = keep
	return copy
func _run() -> void:
	root.size = Vector2i(1280,720)
	var expected := {10:{"nodes":408,"edges":417},16:{"nodes":857,"edges":880}}
	for size in [10,16]:
		var nav := RiverJunctionNavigation.new()
		var graph := nav.build(size)
		_check(int(graph.get("schema_version",0)) == 1,"layout %d graph declares schema version 1" % size)
		_check(str(graph.get("map_id","")) == "river_junction_%dv%d"%[size,size],"layout %d graph carries the map id" % size)
		_check(nav.nodes.size() == expected[size].nodes,"layout %d has %d graph nodes" % [size,expected[size].nodes])
		_check(nav.edges.size() == expected[size].edges,"layout %d has %d graph edges" % [size,expected[size].edges])
		_check(bool(graph.get("through_waypoints",false)),"layout %d graph keeps through-waypoint semantics" % size)
		# graph node heights must follow the bridge deck / terrain, never a flat constant
		var distinct_heights := {}
		for id in nav.nodes: distinct_heights[snappedf((nav.nodes[id] as Vector3).y,0.01)] = true
		_check(distinct_heights.size() > 10,"layout %d graph heights follow terrain and bridge decks" % size)
		var navigator := DriveNavigator.new()
		var configured := navigator.configure(graph)
		_check(configured.get("ok",false) and navigator.valid,"layout %d graph loads into the production navigator" % size)
		# every spawn of both teams reaches A/B/C and its own resupply
		var objective_ok := 0
		var objective_total := 0
		var supply_ok := 0
		var supply_total := 0
		for team in [1,2]:
			var supply_goal: Variant = nav.supply_goals.get("supply%d"%team,null)
			for pose in RiverJunctionDefinition.spawns(size,team):
				for id in ["A","B","C"]:
					objective_total += 1
					var path := navigator.request_path(pose.origin,nav.goals[id],3.8)
					if path.get("ok",false): objective_ok += 1
				supply_total += 1
				if supply_goal is Vector3:
					var supply_path := navigator.request_path(pose.origin,supply_goal,3.8)
					if supply_path.get("ok",false): supply_ok += 1
		_check(objective_ok == objective_total,"layout %d: all %d spawn->objective routes are reachable" % [size,objective_total])
		_check(not nav.supply_goals.is_empty(),"layout %d exposes a resupply goal per team" % size)
		_check(supply_total > 0 and supply_ok == supply_total,"layout %d: all %d spawn->resupply routes are reachable" % [size,supply_total])
		# flank: with the central crossing removed, an outer route must still reach an objective
		var flank_graph := _without_central_crossing(graph)
		_check(flank_graph.edges.size() < graph.edges.size(),"layout %d central crossing edges exist to close" % size)
		var flank := DriveNavigator.new()
		flank.configure(flank_graph)
		var flank_reached := 0
		for pose in RiverJunctionDefinition.spawns(size,1):
			for id in ["A","C"]:
				if flank.request_path(pose.origin,nav.goals[id],3.8).get("ok",false): flank_reached += 1
		_check(flank_reached > 0,"layout %d keeps an outer flank route when the central crossing is closed (%d routes)" % [size,flank_reached])
	# deterministic graph: survey and formal entries derive the same data
	var first := JSON.stringify(RiverJunctionNavigation.new().build(16))
	var second := JSON.stringify(RiverJunctionNavigation.new().build(16))
	_check(first == second,"the road graph is deterministic across builders")
	for path in ["res://scripts/maps/river_junction_range.gd","res://scripts/ui/river_junction_survey.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text.contains("RiverJunctionDefinition"),"survey and formal entries share RiverJunctionDefinition (%s)" % path.get_file())
	var survey_text := FileAccess.get_file_as_string("res://scripts/ui/river_junction_survey.gd")
	var range_text := FileAccess.get_file_as_string("res://scripts/maps/river_junction_range.gd")
	_check(survey_text.contains("layout(") and range_text.contains("supply_points("),"both entries derive layout and resupply from the same definition")
	# wreck occupancy
	world = Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(120,1,120))
	var defs := VehicleDefs.new(); defs.load_defaults()
	VehicleCatalog.new().load_all(defs)
	var wrek := WreckRegistry.new(); world.add_child(wrek)
	var dead := VehicleActor.new(); world.add_child(dead)
	dead.setup(defs,VehicleCatalog.IDS[0],"W",1,Transform3D(Basis.IDENTITY,Vector3(6,0.2,0)),2,null)
	for i in 3: await physics_frame
	dead.state.destroyed = true
	_check(wrek.register(dead),"a destroyed actor registers as a wreck")
	var wreck_positions := wrek.wreck_positions()
	_check(wreck_positions.size() == 1 and wreck_positions[0].distance_to(dead.tank.global_position) < 0.001,"wreck positions expose the actual ground position")
	var space := world.get_world_3d().direct_space_state
	var candidates: Array[Transform3D] = []
	for i in 4: candidates.append(Transform3D(Basis.IDENTITY,Vector3(float(i)*6.0,0.3,0)))
	var size_box := Vector3(2.85,1.68,5.45)
	var free_pick := SpawnSelector.evaluate(space,candidates,size_box,[])
	_check(free_pick.get("ok",false),"spawn selection accepts an unobstructed slot")
	var occupied: Array[Vector3] = [free_pick.transform.origin]
	var blocked_pick := SpawnSelector.evaluate(space,candidates,size_box,occupied)
	var different: bool = bool(blocked_pick.get("ok",false)) and (blocked_pick.get("transform") as Transform3D).origin.distance_to((free_pick.get("transform") as Transform3D).origin) > 0.5
	var bounded_wait: bool = not bool(blocked_pick.get("ok",true)) and str(blocked_pick.get("reason","")) == "spawn_blocked"
	_check(different or bounded_wait,"an occupied slot yields another slot or a bounded spawn_blocked (%s)" % ("moved" if different else "wait"))
	var all_occupied: Array[Vector3] = []
	for candidate in candidates: all_occupied.append(candidate.origin)
	var stuck := SpawnSelector.evaluate(space,candidates,size_box,all_occupied)
	_check(not stuck.get("ok",true) and str(stuck.get("reason","")) == "spawn_blocked","every slot occupied reports spawn_blocked instead of stacking vehicles")
	wrek.clear_tracking()
	_check(wrek.count() == 0 and wrek.wreck_positions().is_empty(),"clearing the registry removes every wreck position")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("RIVER_REACHABILITY_CHECKS_PASS" if failed == 0 else "RIVER_REACHABILITY_CHECKS_FAIL")
	world.free()
	quit(1 if failed else 0)
