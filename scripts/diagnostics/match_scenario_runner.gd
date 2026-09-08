class_name MatchScenarioRunner
extends RefCounted
var ended_shots := 0
var vehicle_contacts := 0
var damage_events := 0
var stop_reasons := {}
func run(tree: SceneTree, match_seed: int) -> Dictionary:
	ended_shots = 0
	vehicle_contacts = 0
	damage_events = 0
	stop_reasons.clear()
	var scene := VillageRange.new()
	scene.match_seed = match_seed
	scene.ai_only = true
	tree.root.add_child(scene)
	tree.current_scene = scene
	scene.projectiles.projectile_finished.connect(_on_finished)
	scene.projectiles.projectile_contact.connect(func(_record: Dictionary) -> void: vehicle_contacts += 1)
	scene.projectiles.projectile_damage.connect(func(_record: Dictionary) -> void: damage_events += 1)
	var max_values := {"actors":0,"live":0,"wrecks":0,"projectiles":0,"records":0,"nodes":0,"objects":0,"resources":0,"static_memory_bytes":0}
	var approached := {}
	var path_failures := {}
	var seen_path_events := {}
	var samples: Array = []
	var invariant_errors: Array[String] = []
	var start_wall := Time.get_ticks_msec()
	var next_sample := 0.0
	var sample_index := 0
	# Actual engine physics ticks; no artificial tickets, death events, clock advance or damage.
	for tick in int((TeamMatchState.TIME_LIMIT+5)*60):
		await tree.physics_frame
		if scene.director.state.elapsed+0.00001 >= next_sample:
			next_sample += 2.0
			var sample := TelemetrySnapshot.capture(scene)
			for key in max_values: max_values[key] = maxi(max_values[key],int(sample[key]))
			if sample.live>8 or sample.actors>8+RecoveryRules.WRECK_MAX_COUNT or sample.wrecks>RecoveryRules.WRECK_MAX_COUNT or sample.projectiles>ProjectileManager.MAX_ACTIVE or sample.records>ShotRecordStore.LIMIT: invariant_errors.append("object_budget")
			if sample.local_controllers != 0 or sample.vehicle_cameras != 0 or not sample.observer_camera: invariant_errors.append("ai_scenario_binding")
			var actors := {}
			for actor in scene.combat_actors():
				var p: Vector3 = actor.tank.global_position
				if not p.is_finite() or not scene.definition.bounds.has_point(Vector2(p.x,p.z)): invariant_errors.append("world_bounds")
				if absf(p.z)<45: approached[actor.entity_id] = true
				if actor.controller is AITankController:
					for event in actor.controller.driver.events:
						if event.phase not in ["failed","unreachable"]: continue
						var key := "%d:%s:%s"%[actor.life_id,event.time,event.phase]
						if seen_path_events.has(key): continue
						seen_path_events[key] = true
						path_failures[event.reason] = int(path_failures.get(event.reason,0))+1
				actors[actor.entity_id+":"+str(actor.life_id)] = {"p":[p.x,p.y,p.z],"destroyed":actor.state.destroyed,"ammo":actor.gunner.rounds_remaining,"drive_phase":actor.controller.driver.phase if actor.controller is AITankController else "none","ai_phase":actor.controller.phase if actor.controller is AITankController else "none"}
			if sample_index%5 == 0: sample.actor_status = actors; samples.append(sample)
			if sample_index%30 == 0: print("[match seed=%d t=%.1f] tickets=%s active=%d wreck=%d shots=%d"%[match_seed,sample.seconds,scene.director.state.tickets,sample.live,sample.wrecks,sample.accepted_shots])
			sample_index += 1
		if scene.director.state.phase == "finished": break
	var final := TelemetrySnapshot.capture(scene)
	var result := scene.director.state.result.duplicate(true)
	var unique_deaths := scene.director.state.seen_deaths.size()
	var deaths := 0
	var spawns := 0
	for row in scene.director.state.roster.values(): deaths += row.deaths; spawns += row.spawns
	var report := {"seed":match_seed,"result":result,"finished_once":scene.director.state.finish_count == 1,"bounded":invariant_errors.is_empty(),"invariant_errors":invariant_errors,"approached":approached.keys(),"shots":final.accepted_shots,"ended_shots":ended_shots,"vehicle_contacts":vehicle_contacts,"damage_events":damage_events,"stop_reasons":stop_reasons.duplicate(),"deaths":deaths,"unique_deaths":unique_deaths,"spawns":spawns,"max":max_values,"final":final,"path_failures":path_failures,"samples":samples,"wall_seconds":(Time.get_ticks_msec()-start_wall)/1000.0}
	if scene.director.state.phase != "finished": report.invariant_errors.append("did_not_finish"); report.bounded = false
	scene.free()
	for i in 4: await tree.process_frame
	report.cleanup = {"nodes":tree.get_node_count(),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
	return report
func _on_finished(record: Dictionary) -> void:
	ended_shots += 1
	var reason := str(record.get("terminal_reason",record.get("reason","unknown")))
	stop_reasons[reason] = int(stop_reasons.get(reason,0))+1
