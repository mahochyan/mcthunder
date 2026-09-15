extends SceneTree
## WT-040-R1 probe: two questions the river match raised.
## 1) Can the AI actually ROUTE to its patrol goal on the river graph? The match showed actors
##    crawling at 0.7-4.9 m/s, oscillating in place and never entering an objective ring, which is
##    the signature of "no usable path" rather than "slow vehicle". This asks the scene's own
##    navigator for a path from each actor to its patrol goal and prints the verdict.
## 2) Is my respawn metric real? The recorded match counted seven respawns while no slot ever fired,
##    which cannot both be true. This prints each actor's life_id and entity_id over three samples so
##    a life_id change can be checked against actual destruction.
func _initialize() -> void: call_deferred("_run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node = load(MapRegistry.scene_path("river_junction_team")).instantiate()
	scene.selected_vehicle_id = VehicleCatalog.IDS[0]
	scene.ai_only = true
	scene.match_seed = 44001
	root.add_child(scene); current_scene = scene
	await frames(195)
	print("[probe] team_ready=", scene.team_ready, " actors=", scene.combat_actors().size(),
		" nav_valid=", scene.nav.valid, " graph_nodes=", scene.definition.graph.get("nodes",[]).size(),
		" graph_edges=", scene.definition.graph.get("edges",[]).size())
	await frames(300)
	print("--- question 1: can each actor route to its patrol goal? ---")
	for actor in scene.combat_actors():
		var ai: AITankController = actor.controller as AITankController
		if ai == null:
			print("[probe] ", actor.entity_id, " no AI"); continue
		var p: Vector3 = actor.tank.global_position
		var goal: Vector3 = ai.patrol_goal
		var path: Dictionary = scene.nav.request_path(p, goal, 4.2)
		var ids: Array = path.get("ids", [])
		print("[probe] %s from=(%d,%d) goal=(%d,%d) ok=%s nodes=%d straight_m=%d" % [
			actor.entity_id, roundi(p.x), roundi(p.z), roundi(goal.x), roundi(goal.z),
			str(path.get("ok", false)), ids.size(), roundi(p.distance_to(goal))])
		if ids.size() > 0:
			var first: Variant = ids[0]
			var last: Variant = ids[ids.size()-1]
			print("        path first=%s last=%s" % [str(first), str(last)])
	print("--- question 2: life_id semantics over 3 samples ---")
	for sample in 3:
		await frames(300)
		var row := {}
		for actor in scene.combat_actors():
			row[actor.entity_id] = {"life": actor.life_id, "dead": actor.state.destroyed,
				"shots": actor.gunner.shots_fired, "p": [roundi(actor.tank.global_position.x), roundi(actor.tank.global_position.z)]}
		print("[probe-lives] t=%.0f %s" % [scene.director.state.elapsed, str(row)])
	print("RIVER_ROUTE_PROBE_DONE")
	quit(0)
