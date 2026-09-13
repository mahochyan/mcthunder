extends SceneTree
## Fixed-step integration fixture: actual common AI/controller/drive/collision execution.
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames() -> void:
	for i in 3: await physics_frame
	await process_frame
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var map := VillageDefinition.create()
	VillageWorld.build(world,map,true)
	var defs := VehicleDefs.new(); defs.load_defaults()
	check(VehicleCatalog.new().load_all(defs).ok,"all historical definitions admitted for physical road matrix")
	await frames()
	for id in VehicleCatalog.IDS:
		for team in [1,2]:
			for slot in [0,7]:
				var occupancy := RouteHarness.occupancy(world,map.spawns[team][slot].origin)
				check(occupancy == 0,"%s team %d slot %d starts on a clear spawn (%d bodies within margin)"%[id,team,slot,occupancy])
				var actor := VehicleActor.new(); world.add_child(actor)
				var setup := actor.setup(defs,id,"ROAD",team,map.spawns[team][slot],4,null)
				actor.set_physics_process(false)
				actor.gunner.aim_preview_enabled = false
				actor.cam_rig.set_process(false); actor.cam_rig.set_physics_process(false)
				# WT-039-R1: the M26 stalls on this route with the driver commanding 0.31 throttle on
				# flat ground while a fresh or long-run hull moves there, so the open question is
				# whether the command the actor actually consumes matches the driver's intent.
				actor.debug_command_trace = id == "us_m26_m3_1945"
				var navigator := DriveNavigator.new(); navigator.configure(map.graph)
				var driver := AIPathDriver.new(); actor.add_child(driver)
				driver.configure(actor,navigator); actor.set_controller(driver)
				driver.set_goal(TeamArena.goal(team,slot%4))
				await frames()
				var bounded := true; var reached_speed := 0.0
				var trace: Array = []
				var previous := actor.tank.global_position
				for i in 12000:
					actor.advance_standalone_tick(1.0/60)
					var point := actor.tank.global_position
					bounded = bounded and point.is_finite() and point.distance_to(previous) < actor.definition.forward_max_speed/60+0.2
					bounded = bounded and actor.tank.forward_speed <= actor.definition.forward_max_speed+0.001 and actor.tank.forward_speed >= -actor.definition.reverse_max_speed-0.001
					reached_speed = maxf(reached_speed,actor.tank.forward_speed)
					if i % 30 == 0: trace.append(RouteHarness.trace_line(i,driver,actor,TeamArena.goal(team,slot%4))+" bounded=%s"%str(bounded))
					previous = point
					if driver.phase in ["arrived","failed","unreachable"]: break
				print("[route] ",id," team=",team," slot=",slot," phase=",driver.phase," peak_speed=",reached_speed," endpoint=",previous)
				check(setup.ok and bounded and driver.phase == "arrived",id+": actual hull from team %d slot %d reaches capture via roads within movement bounds"%[team,slot])
				if not (setup.ok and bounded and driver.phase == "arrived"):
					print("[route] trace saved: ",RouteHarness.dump_trace("historical-%s-t%d-s%d"%[id,team,slot],trace))
				actor.free(); await frames()
	world.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("HISTORICAL_ROAD_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
