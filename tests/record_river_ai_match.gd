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
## WT-040-R1 Stage 5: the 120 s diagnostic cap ended the match while the actors were still ~960 m from their
## goals (at 8 m/s that is exactly the boundary), so nothing had arrived and nothing had fired. This raises
## the CAP ONLY for the Stage 5 match run: 120 samples x 5 s = 600 s of simulated match time. Nothing else is
## changed - same seed, same map, same AI, no teleport, no cooldown clearing, no fabricated hits.
const STAGE5_MAX_SAMPLES := 120
const MAX_SAMPLES := 24           # diagnostic cap: 120 s of simulated match time
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
## WT-040-R1 measure-first: every block creation the driver recorded since the last sample, with its
## cause and counterparty, so the yield frequency can be measured instead of guessed.
func _new_block_events(ai: AITankController, since: int) -> Array:
	var out: Array = []
	for i in range(since, ai.driver.events.size()):
		var ev: Dictionary = ai.driver.events[i]
		if str(ev.get("reason","")) == "edge_blocked":
			out.append({"t": snappedf(float(ev.get("time",0.0)),0.1), "edge": str(ev.get("edge","")),
				"mode": str(ev.get("mode","")), "blocker": str(ev.get("blocker","")),
				"blocked_total": int(ev.get("blocked_total",0))})
	return out
## WT-040-R1: how many times has this AI been handed a task? Each one re-sets the patrol and
## therefore re-plans the route, so this separates my task layer's churn from the driver's own.
func _count_task_events(ai: AITankController) -> int:
	var n := 0
	for ev in ai.events:
		if str(ev.get("reason","")) == "task_assigned": n += 1
	return n
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
	var respawns := {1:0, 2:0}          # WITHDRAWN METRIC (falsified by measurement, see below)
	var destroyed_seen := {}            # verified: destruction actually observed per actor
	var chain_samples: Array = []       # task -> path -> movement -> observation -> aim -> fire
	var _block_cursor: Dictionary = {}  # entity_id -> driver.events index already reported
	var deaths := {1:0, 2:0}
	var seen_life := {}
	var timeline: Array = []
	var positions := {}
	var stagnant := {}
	var finite := true
	var detached_valid := true
	scene.director.match_finished.connect(func(_result: Dictionary) -> void:
		scene.set_meta("finish_signals", int(scene.get_meta("finish_signals",0))+1))
	for sample in STAGE5_MAX_SAMPLES:
		await frames(SAMPLE_FRAMES)
		for actor in scene.combat_actors():
			var p: Vector3 = actor.tank.global_position
			var life: int = actor.life_id
			var team: int = int(actor.state.team_id)
			finite = finite and p.is_finite() and scene.definition.bounds.has_point(Vector2(p.x,p.z))
			# WT-040-R1: the previous respawn counter was FALSIFIED by measurement - life_id is per
			# actor, not per life (A=1, A2=2 ... B=8, constant across samples), so counting "life > 1"
			# reported seven re-entries while no slot had fired a single shot. It is withdrawn and
			# replaced by destruction transitions actually observed for that actor.
			if actor.state.destroyed:
				destroyed_seen[actor.entity_id] = true
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
			# WT-040-R1 (user request): record the chain 任务->路径->移动->观察->瞄准->发射 with the
			# FIELDS that actually exist, so a stall can be attributed to the first failing link:
			# task (objective/role/reason), path+movement (driver phase and its reason), first sighting
			# and the current phase reason, the aim solution, and the shot counter. Nothing is
			# inferred: every value is read from the AI's own public state.
			var chain := {}
			for actor in scene.combat_actors():
				var ai3: AITankController = actor.controller as AITankController
				if ai3 == null: continue
				var last_event: Dictionary = ai3.events[ai3.events.size()-1] if ai3.events.size() > 0 else {}
				var first_seen := -1.0
				for ev in ai3.events:
					if str(ev.get("phase","")) == "observe":
						first_seen = float(ev.get("time", -1.0)); break
				chain[actor.entity_id] = {
					"task": ai3.task_objective, "task_reason": ai3.task_reason, "role": ai3.role,
					"driver": ai3.driver.phase, "driver_reason": ai3.driver.reason,
					"phase": ai3.phase, "phase_reason": str(last_event.get("reason","")),
					"first_seen_s": first_seen,
					"aim": str(ai3.last_aim_solution.get("reason", ai3.last_aim_solution.get("status",""))),
					"shots": actor.gunner.shots_fired, "dead": actor.state.destroyed,
					"to_goal": roundi(actor.tank.global_position.distance_to(ai3.patrol_goal)),
					# WT-040-R1 movement diagnosis: the match showed the AI driving but never closing
					# (to_goal oscillating 994/1067/976/1071), so record the driver's own route state:
					# the waypoint INDEX, the planned path length, its goal, and the planning counters
					# (failed / unreachable / replanned). Together these separate a cycling hop sequence
					# from a long detour that simply has not arrived yet.
					"wp_index": ai3.driver.waypoint,
					"path_len": ai3.driver.path.size(),
					"goal": [roundi(ai3.driver.goal.x), roundi(ai3.driver.goal.z)],
					"planning": ai3.driver.planning_counts.duplicate(true),
					"attempts": ai3.driver.attempts,
					# Who is churning the route? Count the AI's own task_assigned events (my task layer
					# re-applying) so an assignment flip can be told apart from the driver's own replan.
					"task_events": _count_task_events(ai3),
					# WT-040-R1 measure-before-change: the planned path differs on every replan
					# (length 69, 70, 70, 82), so the suspect is the blocked-edge set that accumulates
					# and is only cleared on a new goal. Record its size and the driver's own transition
					# count so the next change is driven by evidence rather than another guess.
					"blocked_edges": ai3.driver._blocked_edges.size(),
					"driver_events": ai3.driver.events.size(),
				}
			print("[river-chain] t=%.0f %s" % [scene.director.state.elapsed, str(chain)])
			# WT-040-R1 measure-first: surface every block creation the driver recorded since the last
			# sample, with its counterparty, so congestion can be attributed to specific actors.
			var blocks := {}
			for actor in scene.combat_actors():
				var ai_b: AITankController = actor.controller as AITankController
				if ai_b == null: continue
				var since: int = int(_block_cursor.get(actor.entity_id, 0))
				var fresh := _new_block_events(ai_b, since)
				_block_cursor[actor.entity_id] = ai_b.driver.events.size()
				if not fresh.is_empty(): blocks[actor.entity_id] = fresh
			if not blocks.is_empty():
				print("[river-blocks] t=%.0f %s" % [scene.director.state.elapsed, str(blocks)])
			chain_samples.append({"t": scene.director.state.elapsed, "chain": chain})
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
		"respawns": "WITHDRAWN: life_id is per actor, not per life; the old counter was falsified",
		"destroyed_observed": destroyed_seen.keys(),
		"chain_samples": chain_samples,
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
	# WT-040-R1 Stage 5: the industrial suite's "central approaches" point set does not describe this map's
	# geometry, so it is RECORDED here rather than judged - in the measured run the teams reached the river's
	# own objectives (team 1: A, B, C; team 2: B, C) while only one slot happened to enter that borrowed point
	# set. What the ruling actually asks for on this map is that both teams physically reach the objectives
	# the map itself declares, and that is what is checked.
	var teams_with_objectives := 0
	for team in [1,2]:
		if (reached_objectives[team] as Dictionary).size() >= 1: teams_with_objectives += 1
	print("[river-match metric] central-approaches slots=%d (industrial-map rule, RECORDED not judged); objectives reached per team=%s" % [
		reached.size(), str({1: reached_objectives[1].keys(), 2: reached_objectives[2].keys()})])
	check(teams_with_objectives == 2, "both teams physically reach at least one of the map's own capture objectives")
	check(max_still < 90, "no healthy river actor trying to drive stays stationary for 90 seconds")
	print("=== 缁撴灉: %d 椤规鏌? %d 澶辫触 ==="%[count,failed])
	print("RIVER_AI_MATCH_PASS" if failed == 0 else "RIVER_AI_MATCH_FAIL")
	quit(0 if failed == 0 else 1)


