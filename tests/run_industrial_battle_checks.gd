extends SceneTree
## Explicit AI-only scenario configuration; real physics, perception, projectiles and match clock.
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
	for seed_value in [23023,23024]:
		var scene := load(MapRegistry.scene_path("industrial_edge")).instantiate() as IndustrialRange
		scene.selected_vehicle_id = VehicleCatalog.IDS[0]; scene.ai_only = true; scene.match_seed = seed_value
		root.add_child(scene); current_scene = scene; await frames(195)
		check(scene.team_ready and scene.combat_actors().size()==8 and scene.nav.valid,"seed %d actual industrial eight-AI match initialized"%seed_value)
		var positions := {}; var stagnant := {}; var peak_stagnant := {}; var reached := {}; var shots := {}; var finite := true; var detached_valid := true
		var reached_teams := {1:{},2:{}}
		scene.director.match_finished.connect(func(_result: Dictionary) -> void: scene.set_meta("finish_signals",int(scene.get_meta("finish_signals",0))+1))
		for sample in 121:
			await frames(300)
			for actor in scene.combat_actors():
				var p: Vector3 = actor.tank.global_position; var life: int = actor.life_id
				finite = finite and p.is_finite() and scene.definition.bounds.has_point(Vector2(p.x,p.z))
				if p.length()<45:
					reached[actor.entity_id] = true
					reached_teams[actor.state.team_id][actor.entity_id] = true
				if actor.gunner.shots_fired>0: shots[actor.entity_id] = true
				var ai := actor.controller as AITankController
				if ai == null:
					detached_valid = detached_valid and actor.state.destroyed
					continue
				var trying: bool = not actor.state.destroyed and actor.capabilities().drive and ai.phase not in ["repair","retreat"] and p.distance_to(ai.patrol_goal)>15 and ai.driver.phase != "arrived"
				if trying and positions.has(life) and p.distance_to(positions[life])<1.0: stagnant[life] = int(stagnant.get(life,0))+5
				else: stagnant[life] = 0
				peak_stagnant[life] = maxi(int(peak_stagnant.get(life,0)),stagnant[life]); positions[life] = p
			if sample%6 == 0 or scene.director.state.phase == "finished":
				var summary := {}
				for actor in scene.combat_actors():
					var ai := actor.controller as AITankController
					summary[actor.entity_id+"/"+str(actor.life_id)] = {"life":actor.life_id,"p":actor.tank.global_position,"dead":actor.state.destroyed,"ai":ai.phase if ai != null else "detached","drive":ai.driver.phase if ai != null else "wreck","stagnant":stagnant.get(actor.life_id,0)}
				print("[battle] seed=",seed_value," elapsed=",scene.director.state.elapsed," tickets=",scene.director.state.tickets," actors=",summary)
			if scene.director.state.phase == "finished": break
		var max_still := 0
		for value in peak_stagnant.values(): max_still = maxi(max_still,value)
		print("[battle totals] seed=",seed_value," result=",scene.director.state.result," reached=",reached," fired=",shots," maximum trying-to-drive stationary seconds=",max_still)
		check(finite,"T023-H01 full real battle remains inside finite industrial bounds")
		check(detached_valid,"only destroyed wrecks may have detached AI")
		check(scene.director.state.phase == "finished" and scene.get_meta("finish_signals",0)==1,"real match clock/tickets terminate exactly once")
		# Roster slot A/B can be killed before reaching the centre. Count actual teams,
		# requiring three distinct physical arrivals on each; route checks cover all slots.
		check(reached.size()>=6 and reached_teams[1].size()>=3 and reached_teams[2].size()>=3,"at least three actual slots from each team physically reach central approaches")
		check(shots.size()>=6,"at least six actual AI slots acquire targets and fire")
		check(max_still<90,"no healthy actor trying to drive stays stationary for 90 seconds")
		var frozen := scene.director.state.result.duplicate(true); var actor_positions := {}
		for actor in scene.combat_actors(): actor_positions[actor.life_id] = actor.tank.global_position
		await frames(90)
		var still := true
		for actor in scene.combat_actors(): still = still and actor_positions[actor.life_id].is_equal_approx(actor.tank.global_position)
		check(still and scene.director.state.result==frozen,"finished industrial match freezes vehicles and result")
		scene.free(); await frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("INDUSTRIAL_BATTLE_CHECKS_PASS" if failed == 0 else "INDUSTRIAL_BATTLE_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
