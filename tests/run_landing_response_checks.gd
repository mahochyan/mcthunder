extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"real historical actors ready")
	for actor in world.actors:
		var rebounds: Array[float]=[]
		for height in [0.02,0.5,2.0]:
			actor.reset_vehicle(); actor.tank.global_position=Vector3(world.actors.find(actor)*16,height,0)
			var tank: TankVehicle=actor.tank
			var max_rebound := 0.0
			var max_pending := 0.0
			var landed_y := INF
			var max_rise := 0.0
			var min_y: float = height
			for tick in 180:
				await physics_frame
				if tank.is_on_floor() and is_inf(landed_y): landed_y=tank.global_position.y
				if not is_inf(landed_y): max_rise=maxf(max_rise,tank.global_position.y-landed_y)
				max_rebound=maxf(max_rebound,tank.velocity.y)
				max_pending=maxf(max_pending,tank.landing.pending_velocity.length())
				min_y=minf(min_y,tank.global_position.y)
			print("[LANDING] ",actor.entity_id," height=",height," impact=",tank.landing.last_impact_speed," pending=",max_pending," up_velocity=",max_rebound," rise=",max_rise," impacts=",tank.landing.impacts)
			if height==0.02: check(tank.landing.impacts==0 and max_pending==0,"minor settling does not trigger rebound "+actor.entity_id)
			else:
				check(tank.landing.impacts==1 and max_rebound>0 and max_rise>0.001,"one actual landing produces bounded physical rebound "+actor.entity_id+str(height))
				check(max_pending<=actor.definition.drive_profile.landing_max_rebound+0.0001,"configured rebound cap respected "+actor.entity_id+str(height))
			check(tank.is_on_floor() and absf(tank.velocity.y)<0.01 and min_y>=-0.01,"vehicle settles without recurring bounce or ground penetration "+actor.entity_id+str(height))
			rebounds.append(max_pending)
		check(rebounds[2]>rebounds[1] and rebounds[1]>rebounds[0],"larger drop produces stronger response "+actor.entity_id)
		actor.reset_vehicle()
		check(actor.tank.landing.impacts==0 and actor.tank.landing.pending_velocity==Vector3.ZERO,"reset clears pending landing impulse "+actor.entity_id)
	var response := LandingResponse.new(); var profile := DriveProfile.new()
	response.contact(Vector3(5,-100,0),Vector3.UP,profile)
	var result := response.consume(Vector3(5,-1,0))
	check(result==Vector3(5,profile.landing_max_rebound,0) and response.consume(result)==result,"impulse consumed once and preserves tangent motion")
	profile.landing_restitution=1
	check(not profile.validate().is_empty(),"out-of-range landing restitution rejected")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("LANDING_RESPONSE_CHECKS_PASS" if failed==0 else "LANDING_RESPONSE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
