extends SceneTree
## WT-040-R1 target-mapping regression (user request 2026-09-15): guard the two things that were
## actually wrong in the river team match, so neither can silently come back.
##
## 1) Every AI slot's task must come from the RIVER map, not from the legacy TeamArena approach
##    points that TeamRange.objective_goal() returns by default.
## 2) Every task point must be ROUTABLE on the map's own navigation graph. The first version aimed
##    at capture centres that were not vehicle-usable graph points and only 2 of 8 actors could find
##    a path at all; that is what this asserts against.
##
## It asserts, it does not adjust: no speed, map, teleport, cooldown or hit changes are involved.
const MAP_ID := "river_junction_team"
const SEED := 44002
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node = load(MapRegistry.scene_path(MAP_ID)).instantiate()
	scene.selected_vehicle_id = VehicleCatalog.IDS[0]
	scene.ai_only = true
	scene.match_seed = SEED
	root.add_child(scene); current_scene = scene
	await frames(195)
	var actors: Array = scene.combat_actors()
	check(scene.team_ready and actors.size() == 8, "river match initialises eight AI actors")
	# The legacy arena's own goals: no slot may target one of these on this map.
	var legacy: Array[Vector3] = []
	for t in [1,2]:
		for i in 4: legacy.append(TeamArena.goal(t,i))
	var on_legacy := 0
	var routable := 0
	var table: Array[String] = []
	for actor in actors:
		var ai: AITankController = actor.controller as AITankController
		if ai == null:
			continue
		var goal: Vector3 = ai.patrol_goal
		var hit := false
		for g in legacy:
			if goal.distance_to(g) < 1.0: hit = true
		if hit: on_legacy += 1
		var path: Dictionary = scene.nav.request_path(actor.tank.global_position, goal, 4.2)
		var ok := bool(path.get("ok", false))
		if ok: routable += 1
		table.append("%s goal=(%d,%d) routable=%s nodes=%d" % [
			actor.entity_id, roundi(goal.x), roundi(goal.z), str(ok), path.get("ids",[]).size()])
	for row in table: print("[task-mapping] ", row)
	check(on_legacy == 0, "no river slot targets a legacy TeamArena goal (found %d)" % on_legacy)
	check(routable == actors.size(), "every river slot's task point is routable on the map graph (%d/%d)" % [routable, actors.size()])
	# The tasks must be the map's authored points, snapped to its graph - so they must be closer to
	# the map's own entrance/crossing rows than to the arena's tiny approach cluster.
	var near_authored := 0
	var authored: Array[Vector3] = []
	for stop in RiverJunctionDefinition.driving_stops(16):
		authored.append(RiverJunctionDefinition.point(stop.xz))
	for actor in actors:
		var ai2: AITankController = actor.controller as AITankController
		if ai2 == null: continue
		for a in authored:
			if ai2.patrol_goal.distance_to(a) < 40.0:
				near_authored += 1
				break
	check(near_authored >= 6, "river tasks sit on the map's authored driving stops (%d of %d)" % [near_authored, actors.size()])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("RIVER_TASK_MAPPING_PASS" if failed == 0 else "RIVER_TASK_MAPPING_FAIL")
	quit(0 if failed == 0 else 1)
