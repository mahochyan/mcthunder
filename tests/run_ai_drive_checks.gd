extends SceneTree
var count := 0
var failed := 0
var scene: AIDriveRange
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _simulate(limit: int = 9000) -> Dictionary:
	var actor := scene.target_actor
	var previous := actor.tank.global_position
	var max_x := absf(previous.x)
	var bounded := true
	var steps := 0
	for i in limit:
		actor._physics_process(1.0/60) # Actual poll -> submit -> consume -> apply once, fixed physical-step fixture.
		var now := actor.tank.global_position
		bounded = bounded and now.is_finite() and now.distance_to(previous) <= actor.definition.forward_max_speed/60+0.12
		previous = now
		max_x = maxf(max_x,absf(now.x))
		steps += 1
		if scene.driver.phase in ["arrived","unreachable","failed","destroyed"]: break
	return {"bounded":bounded,"max_x":max_x,"steps":steps,"position":previous,"phase":scene.driver.phase}
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = AIDriveRange.new()
	root.add_child(scene)
	current_scene = scene
	await _frames(8)
	_check(scene.ai_ready and scene.navigator.valid,"actual AI laboratory loads bundled navigation graph")
	if not scene.ai_ready: scene.free(); quit(1); return
	_check(scene.target_actor.controller == scene.driver and not scene.target_actor.cam_rig.cam.current,"AI binds command controller without claiming local camera")
	_check(scene.source_actor.controller == null and scene.overview.current,"spectator view does not poll hidden player input")
	scene.set_watching(false)
	_check(scene.source_actor.controller == scene.controller and scene.source_actor.cam_rig.cam.current and scene.target_actor.controller == scene.driver,"player camera switch does not steal AI binding")
	scene.set_watching(true)
	for actor in [scene.source_actor,scene.target_actor]: actor.set_physics_process(false)
	var nav := scene.navigator
	var narrow := nav.request_path(Vector3(0,0,6),Vector3(24,0,-30),scene.target_actor.definition.drive_collision_size.x)
	_check(not narrow.ok and narrow.reason == "unreachable_or_insufficient_width","authored two-metre corridor rejects full-width tank")
	var invalid := DriveNavigator.new()
	_check(not invalid.configure({"schema_version":1,"nodes":[{"id":"bad","position":[0,NAN,0]}],"edges":[]}).ok,"nonfinite authored position rejected before path search")
	_check(not nav.request_path(Vector3.ZERO,Vector3(999,0,999),3).ok,"goal outside authored map returns explicit failure")
	var one := nav.request_path(Vector3(0,0,6),Vector3(0,0,-42),3)
	var two := nav.request_path(Vector3(0,0,6),Vector3(0,0,-42),3)
	_check(one.ok and two.ok and one.ids == two.ids,"A-star route choice is deterministic on equal-cost alternatives")
	for index in 5:
		scene.select_trial(index)
		await _frames(3)
		await physics_frame
		var result := _simulate()
		print("[route %d] %s"%[index,result])
		_check(result.bounded,"route %d uses bounded real movement without teleporting"%index)
		if index == 3:
			_check(result.phase == "unreachable" and scene.target_actor.tank.forward_speed == 0,"narrow trial stops explicitly without trying to squeeze through")
		else:
			_check(result.phase == "arrived","route %d arrives through actual VehicleActor executor"%index)
			_check(scene.target_actor.tank.global_position.distance_to(scene.driver.goal) < 2 and absf(scene.target_actor.tank.forward_speed) < 0.4,"route %d actually parks inside goal area"%index)
		if index in [2,4]: _check(result.max_x > 7,"route %d physically travels around the box footprint"%index)
		if index == 4:
			var reversed := false
			for event in scene.driver.events: reversed = reversed or event.phase == "reverse"
			_check(reversed and scene.driver.attempts <= GameConfig.AI_RECOVERY_ATTEMPTS,"actual player-car blockage causes bounded reverse recovery")
	scene.select_trial(0)
	await _frames(3)
	await physics_frame
	var before := scene.target_actor.tank.global_position
	scene.target_actor.state.module_states.engine.integrity = 0 # Explicit state fixture, actual drive command chain below.
	for i in 240: scene.target_actor._physics_process(1.0/60)
	var displacement := scene.target_actor.tank.global_position-before
	_check(scene.driver.phase == "disabled" and Vector2(displacement.x,displacement.z).length() < 0.03 and scene.target_actor.tank.forward_speed == 0,"AI cannot bypass destroyed engine capability")
	var generation := scene.target_actor.state.generation
	scene.target_actor.reset_vehicle()
	scene.target_actor._physics_process(1.0/60)
	_check(scene.target_actor.state.generation > generation and not scene.driver.has_goal and scene.driver.path.is_empty(),"reset clears old AI goal and generation-bound route")
	scene.driver.set_goal(Vector3(0,0,-8))
	var requests := nav.request_count
	var limited := scene.driver._plan()
	_check(not limited.ok and limited.reason == "rate_limited" and nav.request_count == requests,"path recomputation rate gate prevents duplicate search")
	scene.target_actor.set_controller(null)
	_check(not scene.driver.has_goal and scene.driver.path.is_empty(),"controller detach cancels old goal")
	scene.target_actor.set_controller(scene.driver)
	scene.driver.set_goal(Vector3(0,0,-8))
	scene.target_actor.state.destroyed = true
	scene.target_actor._physics_process(1.0/60)
	_check(scene.driver.phase == "destroyed" and not scene.driver.has_goal,"destroyed actor cancels AI path rather than retrying")
	# A permanently blocked graph must terminate; all alternatives explicitly blocked in this fixture.
	scene.select_trial(4)
	await _frames(3)
	await physics_frame
	for edge in nav.edges:
		if edge.a != "start" or edge.b != "approach": scene.driver._blocked_edges[edge.key] = true
	var blocked := _simulate(3000)
	_check(blocked.phase in ["unreachable","failed"] and scene.driver.attempts <= GameConfig.AI_RECOVERY_ATTEMPTS+1,"permanent obstacle reaches bounded explicit failure")
	var where := scene.target_actor.tank.global_position
	for i in 600: scene.target_actor._physics_process(1.0/60)
	_check(scene.target_actor.tank.global_position.distance_to(where) < 3 and absf(scene.target_actor.tank.forward_speed)<0.01,"failed AI stops sending drive intent and coasts to rest")
	_check(scene.driver.events.size() <= 64,"diagnostic transition history remains bounded")
	# Two independent real actors meet on the same road, without either owning player input.
	scene.select_trial(0)
	var c := VehicleActor.new()
	scene.add_child(c)
	var created := c.setup(scene.defs,"player_tank","C",2,Transform3D(Basis(Vector3.UP,PI),Vector3(0,0.03,-8)),8,null)
	_check(created.ok,"second AI actor instantiates real vehicle and independent runtime")
	M4EngineeringProfile.apply(c)
	c.set_physics_process(false)
	var other := AIPathDriver.new()
	scene.add_child(other)
	other.configure(c,nav)
	c.set_controller(other)
	other.set_goal(Vector3(0,0,6))
	await _frames(3)
	await physics_frame
	var closest := INF
	for i in 8000:
		await physics_frame # Moving bodies require actual PhysicsServer synchronization between steps.
		scene.target_actor._physics_process(1.0/60)
		c._physics_process(1.0/60)
		closest = minf(closest,c.tank.global_position.distance_to(scene.target_actor.tank.global_position))
		if not scene.driver.has_goal and not other.has_goal: break
	_check(not scene.driver.has_goal and not other.has_goal,"two oncoming AI actors arrive or explicitly fail within bounded simulation")
	print("[oncoming] closest=%f B=%s C=%s Bphase=%s Cphase=%s"%[closest,scene.target_actor.tank.global_position,c.tank.global_position,scene.driver.phase,other.phase])
	_check(closest > 2.6 and c.tank.global_position.is_finite() and scene.target_actor.tank.global_position.is_finite(),"oncoming full-size vehicles remain separate and finite")
	_check(not c.cam_rig.cam.current and not scene.target_actor.cam_rig.cam.current and scene.overview.current,"multiple AI actors do not steal spectator camera")
	c.free()
	_check(not other.has_goal and other.path.is_empty(),"freeing an actor detaches and cancels its surviving AI controller")
	other.free()
	scene.select_trial(0)
	await _frames(3)
	await physics_frame
	var ordinary := scene.driver.update_command(1.0/60)
	Input.action_press("turn_right")
	Input.action_press("fire")
	var with_player_keys := scene.driver.update_command(1.0/60)
	Input.action_release("turn_right")
	Input.action_release("fire")
	_check(ordinary.steer == with_player_keys.steer and not with_player_keys.fire_requested,"AI does not read or steal global player steering and fire")
	scene.select_trial(4)
	await _frames(3)
	await physics_frame
	var reset_during_poll := [false]
	scene.driver.state_changed.connect(func(event: Dictionary) -> void:
		if event.phase == "yielding" and not reset_during_poll[0]:
			reset_during_poll[0] = true
			scene.target_actor.reset_vehicle())
	for i in 300:
		scene.target_actor._physics_process(1.0/60)
		if reset_during_poll[0]: break
	_check(reset_during_poll[0] and not scene.driver.has_goal and scene.target_actor.tank.forward_speed == 0,"reset callback during AI poll prevents committing stale command")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AI_DRIVE_CHECKS_PASS" if failed == 0 else "AI_DRIVE_CHECKS_FAIL")
	scene.free()
	quit(0 if failed == 0 else 1)
