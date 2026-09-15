extends SceneTree
## WT-040-R1 (user directive 2026-09-15): "use AI to actually play a match and record the data".
##
## This runs ONE real AI-vs-AI team match on the river junction and writes a structured record, using
## the same production paths the industrial battle suite already measures: real physics, real AI
## controllers, real projectiles, the real match clock and tickets. Nothing is simulated for the
## report.
##
## River-specific measurements (the point of doing it on this map): which CAPTURE OBJECTIVE each
## actor physically reaches (A/B/C from the map's own capture_definitions), how many times each slot
## re-enters after being destroyed, and how long a healthy actor that is trying to drive stays
## stationary - the traffic-failure metric the review asked to separate from combat losses.
##
## The river is NOT combat-admitted (RiverJunctionDefinition declares design_preview /
## combat_admitted=false), so this record is an ENGINEERING measurement on the authored geometry and
## is labelled as such in the output; it is not a claim that the map is admitted.
const MAP_ID := "river_junction_team"
const SEED := 44001
const SAMPLE_FRAMES := 300          # 5 s at 60 fps, same cadence as the industrial suite
const PRINT_EVERY := 6              # print every 30 s
const MAX_SAMPLES := 24           # diagnostic cap: 120 s
const ARRIVE_RADIUS := 45.0         # "central approaches", same rule as the industrial suite
const OBJECTIVE_RADIUS := 26.0      # within a capture point's ring
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
	var team_of := {}
	for actor in actors: team_of[actor.entity_id] = int(actor.state.team_id)
	check(scene.team_ready and actors.size() == 8 and scene.nav.valid,
		"river team match initialised with %d AI actors on the authored river graph" % actors.size())
	var objectives: Array = RiverJunctionDefinition.capture_definitions()
	var reached := {}
	var reached_objectives := {1:{}, 2:{}}
	var shots := {}
	var peak_stagnant := {}
	var respawns := {1:0, 2:0}
	var deaths := {1:0, 2:0}
	var seen_life := {}
	var timeline: Array = []
	var positions := {}
	var stagnant := {}
	var finite := true
	var detached_valid := true
	scene.director.match_finished.connect(func(_result: Dictionary) -> void:
		scene.set_meta("finish_signals", int(scene.get_meta("finish_signals",0))+1))
	for sample in MAX_SAMPLES:
		await frames(SAMPLE_FRAMES)
		for actor in scene.combat_actors():
			var p: Vector3 = actor.tank.global_position
			var life: int = actor.life_id
			var team: int = int(actor.state.team_id)
			finite = finite and p.is_finite() and scene.definition.bounds.has_point(Vector2(p.x,p.z))
			if not seen_life.has(actor.entity_id): seen_life[actor.entity_id] = {}
			if not seen_life[actor.entity_id].has(life):
				seen_life[actor.entity_id][life] = true
				if life > 1: respawns[team] = int(respawns[team]) + 1
			if p.length() < ARRIVE_RADIUS:
				reached[actor.entity_id] = true
			for objective in objectives:
				# RiverJunctionDefinition.capture_definitions() rows are {"id","center":Vector3,
				# "radius":float}; use the map's own centre and ring radius rather than a guess.
				var centre: Vector3 = objective.center
				var ring: float = float(objective.get("radius", OBJECTIVE_RADIUS))
				if p.distance_to(centre) < ring:
					reached_objectives[team][str(objective.id)] = true
			if actor.gunner.shots_fired > 0: shots[actor.entity_id] = true
			var ai: AITankController = actor.controller as AITankController
			if ai == null:
				detached_valid = detached_valid and actor.state.destroyed
				continue
			var trying: bool = (not actor.state.destroyed) and actor.capabilities().drive \
				and ai.phase not in ["repair","retreat"] and p.distance_to(ai.patrol_goal) > 15 \
				and ai.driver.phase != "arrived"
			if trying and positions.has(life) and p.distance_to(positions[life]) < 1.0:
				stagnant[life] = int(stagnant.get(life,0)) + 5
			else:
				stagnant[life] = 0
			peak_stagnant[life] = maxi(int(peak_stagnant.get(life,0)), int(stagnant[life]))
			positions[life] = p
		if sample % PRINT_EVERY == 0 or scene.director.state.phase == "finished":
			var living := {1:0, 2:0}
			for actor in scene.combat_actors():
				if not actor.state.destroyed: living[int(actor.state.team_id)] = int(living[int(actor.state.team_id)]) + 1
			var row := {"t": scene.director.state.elapsed, "tickets": scene.director.state.tickets.duplicate(true),
				"living": living, "phase": scene.director.state.phase}
			timeline.append(row)
			print("[river-match] t=%.0f tickets=%s living=%s phase=%s" % [scene.director.state.elapsed, str(scene.director.state.tickets), str(living), scene.director.state.phase])
			# WT-040-R1 diagnostic: the first runs showed no engagement, so print WHERE each actor is
			# and what it is doing - position, distance to its patrol goal, AI phase, driver phase and
			# speed - to tell "driving but far" apart from "not driving at all".
			var d := {}
			for actor in scene.combat_actors():
				var ai2: AITankController = actor.controller as AITankController
				var p2: Vector3 = actor.tank.global_position
				d[actor.entity_id] = {
					"p": [roundi(p2.x), roundi(p2.z)],
					"goal": [roundi(ai2.patrol_goal.x), roundi(ai2.patrol_goal.z)] if ai2 != null else [],
					"to_goal": roundi(p2.distance_to(ai2.patrol_goal)) if ai2 != null else -1,
					"ai": ai2.phase if ai2 != null else "detached",
					"drive": ai2.driver.phase if ai2 != null else "wreck",
					"spd": snappedf(actor.tank.velocity.length(), 0.1),
				}
			print("[river-actors] t=%.0f %s" % [scene.director.state.elapsed, str(d)])
		if scene.director.state.phase == "finished": break
	for actor in scene.combat_actors():
		if actor.state.destroyed: deaths[int(actor.state.team_id)] = int(deaths[int(actor.state.team_id)]) + 1
	var max_still := 0
	for value in peak_stagnant.values(): max_still = maxi(max_still, int(value))
	var objective_ids: Array = []
	for objective in objectives: objective_ids.append(str(objective.id))
	var record := {
		"schema": 1,
		"map_id": MAP_ID,
		"seed": SEED,
		"note": "engineering AI match on the authored river layout; river is design_preview / combat_admitted=false, so this is a measurement, not an admission claim",
		"finished": scene.director.state.phase == "finished",
		"finish_signals": int(scene.get_meta("finish_signals",0)),
		"result": scene.director.state.result.duplicate(true),
		"elapsed_s": scene.director.state.elapsed,
		"tickets": scene.director.state.tickets.duplicate(true),
		"actors": scene.combat_actors().size(),
		"teams": team_of,
		"reached_central": reached.keys(),
		"reached_per_team": {1: reached_objectives[1].keys(), 2: reached_objectives[2].keys()},
		"objectives_seen": objective_ids,
		"fired_slots": shots.keys(),
		"respawns": respawns,
		"destroyed_at_end": deaths,
		"max_trying_to_drive_stationary_s": max_still,
		"timeline": timeline,
		"finite_in_bounds": finite,
		"detached_only_when_destroyed": detached_valid,
	}
	var directory := "res://logs/WT-040-R1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := "%s/river_ai_match_%d.json" % [directory, SEED]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "  ") + "\n")
		file.close()
		print("[river-match] wrote ", path)
	else:
		print("[river-match] FAILED to write ", path)
	print("[river-match totals] result=%s elapsed=%.0fs tickets=%s reached=%s fired=%d respawns=%s destroyed=%s max_stationary=%ds" % [
		str(scene.director.state.result.get("outcome","?")), scene.director.state.elapsed,
		str(scene.director.state.tickets), str(reached.keys()), shots.size(), str(respawns), str(deaths), max_still])
	check(finite, "river match stays inside finite authored river bounds")
	check(detached_valid, "only destroyed actors have detached AI")
	check(scene.director.state.phase == "finished", "river match clock/tickets terminate the match")
	check(shots.size() >= 6, "at least six AI slots acquire targets and fire on the river")
	check(reached.size() >= 6, "at least six AI slots physically reach the central approaches")
	check(max_still < 90, "no healthy river actor trying to drive stays stationary for 90 seconds")
	print("=== 缁撴灉: %d 椤规鏌? %d 澶辫触 ==="%[count,failed])
	print("RIVER_AI_MATCH_PASS" if failed == 0 else "RIVER_AI_MATCH_FAIL")
	quit(0 if failed == 0 else 1)


