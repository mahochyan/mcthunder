class_name AITankController
extends Node
var cam_rig: CameraRig
var gunner: Gunner
var driver := AIPathDriver.new()
var sensor := AIPerception.new()
var difficulty := AIDifficulty.profile("normal")
var observation: Dictionary = {}
var events: Array[Dictionary] = []
var phase := "patrol":
	set(value):
		if phase == value: return
		phase = value
		events.append({"time":clock,"phase":value,"reason":{"patrol":"no_enemy_memory","observe":"reaction_delay","engage":"visible_enemy_reaction_complete","search":"lost_sight_last_seen_only","repair":"own_capability_or_fire","retreat":"own_ammunition_empty","destroyed":"own_vehicle_destroyed"}.get(value,value),"target":observation.get("entity_id",""),"visible":observation.get("visible",false)})
		if events.size() > 64: events.pop_front()
var clock := 0.0
var last_command := VehicleCommand.new()
var patrol_goal := Vector3.ZERO
var _last_hop := Vector3.INF   # navigation sub-target from the last hop (never re-hopped onto)
var _task_hops: Array[Vector3] = []
var objective_blocked := false
var retreat_goal := Vector3.ZERO
var has_patrol := false
var advance_while_engaged := false # Objective match policy; does not supply enemy information.
var _next_objective_retry := 0.0
var _actor_ref: WeakRef
var _generation := -1
var _next_scan := 0.0
var _seen_since := -1.0
var _aim_error := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _last_shots := 0
var last_aim_solution: Dictionary = {}
var _next_fire_lane_check := 0.0
var _fire_candidate_tick := -1
var _polled_delta := 0.0
var last_fire_authorization: Dictionary = {}

func configure(vehicle: VehicleActor, nav: DriveNavigator, provider: Callable, level: String = "normal", random_seed: int = 14) -> void:
	_actor_ref = weakref(vehicle)
	_generation = vehicle.state.generation
	if driver.get_parent() == null: add_child(driver)
	driver.configure(vehicle,nav)
	sensor.actor_provider = provider
	difficulty = AIDifficulty.profile(level)
	_rng.seed = random_seed
	reset_pending()

func is_local_controller() -> bool: return false
func actor() -> VehicleActor: return _actor_ref.get_ref() as VehicleActor if _actor_ref != null else null
func reset_pending() -> void:
	_task_hops.clear()
	objective_blocked = false
	sensor.clear()
	sensor.preferred_sample = 0
	var vehicle := actor()
	if vehicle != null: _last_shots = vehicle.gunner.shots_fired
	observation.clear()
	driver.reset_pending()
	_seen_since = -1
	_next_scan = clock
	phase = "patrol"
	last_command = VehicleCommand.new()
	last_aim_solution.clear()
	_next_fire_lane_check=clock
	_fire_candidate_tick=-1
	_polled_delta=0.0
	last_fire_authorization.clear()
func on_detached() -> void: reset_pending()
func set_patrol(point: Vector3, fallback: Vector3) -> void:
	if not has_patrol or point != patrol_goal:
		_task_hops.clear()
		objective_blocked = false
	patrol_goal = point
	retreat_goal = fallback
	has_patrol = true
	driver.set_goal(point)

func _new_error() -> void:
	var amplitude := deg_to_rad(float(difficulty.error_degrees))
	_aim_error = Vector2(_rng.randf_range(-amplitude,amplitude),_rng.randf_range(-amplitude,amplitude))

func poll() -> VehicleCommand:
	last_command = update_command(get_physics_process_delta_time())
	return last_command

func _drive_patrol_or_hop() -> void:
	# Normal patrol order, with one bounded fallback: if the objective is not
	# plannable from the current pocket, hop onto the nearest graph node so the
	# vehicle keeps making real progress instead of idling on the failed goal.
	# The hop NEVER replaces the objective: patrol_goal stays the task and the
	# retry loop re-attempts it from every new position (GPT Q2 ruling). Reusing
	# the same hop node is excluded, so repeated hops always move onto new ground.
	if driver.set_goal(patrol_goal).ok:
		objective_blocked = false
		_last_hop = Vector3.INF
		return
	if _task_hops.size() >= GameConfig.AI_TASK_HOP_LIMIT:
		objective_blocked = true
		return
	var hop := driver.escape_goal(_last_hop,_task_hops)
	if hop.is_finite():
		_last_hop = hop
		_task_hops.append(hop)
		driver.set_goal(hop)
	else: objective_blocked = true

func update_command(delta: float) -> VehicleCommand:
	var cmd := VehicleCommand.new()
	_fire_candidate_tick=-1
	var vehicle := actor()
	if vehicle == null or delta <= 0 or not is_finite(delta) or get_tree().paused: return cmd
	_polled_delta=delta
	clock += delta
	if vehicle.state.generation != _generation:
		_generation = vehicle.state.generation
		reset_pending()
		return cmd
	if vehicle.state.destroyed:
		reset_pending()
		phase = "destroyed"
		return cmd
	if clock >= _next_scan:
		_next_scan = clock+float(difficulty.period)
		var rows := sensor.scan(vehicle,clock)
		var previous := str(observation.get("entity_id",""))
		var previous_life := int(observation.get("life_id",-1))
		var was_visible: bool = observation.get("visible",false)
		observation = {}
		var nearest := INF
		var retained := {}
		for row in rows:
			if row.visible:
				var distance: float = vehicle.tank.global_position.distance_to(row.position)
				if distance < nearest:
					nearest = distance
					observation = row
				if row.entity_id == previous and row.life_id == previous_life: retained = row
			elif observation.is_empty(): observation = row
		if not retained.is_empty() and vehicle.tank.global_position.distance_to(retained.position) <= nearest*1.25:
			observation = retained # Hysteresis prevents rapid target changes between nearby visible opponents.
		if observation.get("visible",false):
			if not was_visible or previous != observation.entity_id or previous_life != observation.life_id:
				_seen_since = clock
				_new_error()
		else: _seen_since = -1
	var caps := vehicle.capabilities()
	var recovering := false
	# A loaded round remains usable after loading machinery fails. Once the
	# chamber is empty, request the same capability-based recovery as other own
	# damage; do not leave the AI permanently trying to engage with no feed.
	var loading_recovery: bool=not caps.get("can_load",true) and vehicle.gunner.inventory.chamber<=0
	if vehicle.state.recovery_enabled:
		if not vehicle.state.fires.is_empty():
			phase = "repair"
			cmd.extinguish_requested = true
			return cmd
		if not caps.drive or not caps.fire or caps.turret_speed <= 0 or loading_recovery:
			recovering = true
			phase = "repair"
			if not vehicle.state.role_available("gunner") or not vehicle.state.role_available("driver") or (loading_recovery and caps.get("loading_mode","")=="crew" and not vehicle.state.role_available("loader")): cmd.replace_crew_requested = true
			else: cmd.repair_requested = true
			if not caps.fire or loading_recovery: return cmd
	if vehicle.gunner.rounds_remaining == 0 and has_patrol:
		# A recovery request must never be swallowed by the dry-ammo retreat return:
		# when the vehicle cannot drive, retreating yields a neutral command and the
		# repair/crew request would be lost. Hold position on the recovery command
		# instead; the goal is already set so retreat resumes once drive returns.
		if not caps.drive:
			phase = "repair"
			return cmd
		if phase != "retreat": driver.set_goal(retreat_goal)
		phase = "retreat"
		return driver.update_command(delta)
	# The objective order survives a temporary traffic failure or a completed repair.
	# Individual path attempts remain bounded; retry uses only own state and the public point.
	if advance_while_engaged and has_patrol and caps.drive and not recovering and clock >= _next_objective_retry:
		_next_objective_retry = clock+10.0
		# "arrived" matters when the last goal was a HOP sub-target: arriving there
		# does not complete the task, so the original objective must be re-attempted
		# from the new position. Arriving at the real objective fails the distance
		# guard below, which keeps legitimate holding untouched (GPT Q2 ruling).
		if driver.phase in ["failed","unreachable","idle","arrived"] and vehicle.tank.global_position.distance_to(patrol_goal)>GameConfig.AI_GOAL_RADIUS_M:
			# If the objective stays unplannable from here (disconnected pocket or
			# width-blocked edges), hop onto the nearest graph node instead of
			# idling ten seconds at a time on the identical failed plan (023 stall).
			_drive_patrol_or_hop()
	if observation.is_empty():
		if not caps.drive or recovering: return cmd
		if phase != "patrol" and has_patrol: _drive_patrol_or_hop()
		phase = "patrol"
		return driver.update_command(delta)
	if not observation.visible:
		if not caps.drive or recovering: return cmd
		if phase != "search" and driver.navigator != null and not driver.navigator.nodes.is_empty():
			var id := driver.navigator.nearest(observation.position)
			driver.set_goal(patrol_goal if advance_while_engaged and has_patrol else driver.navigator.nodes[id])
		phase = "search"
		return driver.update_command(delta)
	if driver.has_goal:
		if advance_while_engaged and caps.drive and not recovering:
			var movement := driver.update_command(delta)
			cmd.throttle = movement.throttle
			cmd.steer = movement.steer
		else: driver.cancel("enemy_visible")
	phase = "observe" if clock-_seen_since < float(difficulty.reaction) else "engage"
	if vehicle.gunner.shots_fired != _last_shots:
		_last_shots = vehicle.gunner.shots_fired
		# Alternate visible exterior regions without consulting enemy modules or crew.
		sensor.preferred_sample = {0:4,4:5,5:3,3:0}.get(sensor.preferred_sample,0)
		_new_error()
	var observed_age := clock-float(observation.get("last_seen",-INF))
	last_aim_solution=AimSolver.solve_intercept(vehicle.turret.muzzle.global_position,observation,vehicle.gunner.shell,vehicle.tank.velocity,_aim_error,observed_age)
	if not last_aim_solution.ok: return cmd
	cmd.has_aim_point = true
	# The mechanism rotates about its pivot; this target preserves the solved
	# barrel direction while retaining finite slew and the actual muzzle origin.
	var direction: Vector3=last_aim_solution.direction
	var tracking_direction := _tracking_direction(vehicle,last_aim_solution,delta)
	# Poll precedes drive. Constant own translation predicts where the pivot
	# will consume this point; authorization later checks its actual position.
	cmd.aim_world_point = vehicle.turret.barrel_pivot.global_position+vehicle.tank.velocity*delta+tracking_direction*float(last_aim_solution.aim_distance_m)
	if phase == "engage" and caps.fire and vehicle.gunner.inventory.chamber>0 and vehicle.gunner.cooldown_left <= 0 and vehicle.gunner.resume_grace <= 0 and vehicle.turret.barrel_direction().dot(direction) >= cos(deg_to_rad(0.3)) and clock>=_next_fire_lane_check:
		# Pure aiming is per physical tick. Full trajectory queries only occur at
		# the existing decision cadence when a real shot is otherwise ready.
		_next_fire_lane_check=clock+maxf(0.01,float(difficulty.period))
		_fire_candidate_tick=Engine.get_physics_frames()
		cmd.fire_requested=true
	return cmd

func _tracking_direction(vehicle: VehicleActor, solution: Dictionary, delta: float) -> Vector3:
	# Point-following actuators need a position offset to maintain a nonzero
	# angular rate. Estimate that rate from two solutions of ONE observation,
	# never from successive scan points (surface/target/shell changes can jump).
	# This affects motor demand only, not the true intercept or firing gate.
	var direction: Vector3=solution.direction
	var target_velocity: Vector3=solution.target_velocity
	var own_velocity := vehicle.tank.velocity
	if target_velocity==own_velocity or delta<=0.0 or delta>AimSolver.MAX_OBSERVATION_AGE_S: return direction
	var future_observation := {"aim_point":solution.target_point_now,"velocity":target_velocity}
	var future := AimSolver.solve_intercept(vehicle.turret.muzzle.global_position+own_velocity*delta,future_observation,vehicle.gunner.shell,own_velocity,_aim_error,delta)
	if not future.ok: return direction
	var hull := vehicle.turret.get_parent() as Node3D
	var inverse := hull.global_basis.inverse()
	var current_angles := TurretMechanismState.angles_for(inverse*direction)
	var future_angles := TurretMechanismState.angles_for(inverse*future.direction)
	var rate := Vector2(future_angles.x-current_angles.x,wrapf(future_angles.y-current_angles.y,-PI,PI))/delta
	var caps := vehicle.capabilities()
	var scales := Vector2(TurretMechanismState.axis_scale(caps,"pitch_scale"),TurretMechanismState.axis_scale(caps,"yaw_scale"))
	var profile := vehicle.definition.fire_control_profile
	var braking := profile.braking()*scales
	var speeds := Vector2(deg_to_rad(vehicle.definition.turret_pitch_speed),deg_to_rad(vehicle.definition.turret_yaw_speed))*scales
	var demand := current_angles
	for axis in 2:
		if speeds[axis]<=0.0 or braking[axis]<=0.0: continue
		var speed := clampf(rate[axis],-speeds[axis],speeds[axis])
		# Invert BOTH limits used by TurretMechanismState.following: error/tau
		# and stopping speed. Acceleration, brakes, axis damage and stops remain
		# authoritative in the actual mechanism; this cannot move an axis itself.
		var response_error := absf(speed)*profile.response_time_s
		var stopping_error := speed*speed/(2.0*braking[axis])+absf(speed)*delta
		var offset := maxf(response_error,stopping_error)
		# A demand past the opposite hemisphere has no unambiguous shortest
		# steering direction; retain direct pursuit instead of wrapping a jump.
		if offset>=PI: continue
		demand[axis]+=signf(speed)*offset
	return hull.global_basis*TurretMechanismState.direction(demand)

func authorize_fire(cmd: VehicleCommand) -> bool:
	# Actor invokes this after drive, loading and finite mechanism advancement.
	# Poll only proposes a candidate; this hook is the sole full-lane query.
	if not cmd.fire_requested or _fire_candidate_tick!=Engine.get_physics_frames(): return _fire_veto("no_current_candidate")
	_fire_candidate_tick=-1
	var vehicle := actor()
	if vehicle==null or vehicle.state.destroyed or get_tree().paused: return _fire_veto("actor_unavailable")
	var caps := vehicle.capabilities()
	var gun := vehicle.gunner
	if not caps.fire or gun.inventory.chamber<=0 or gun.cooldown_left>0.0 or gun.resume_grace>0.0: return _fire_veto("weapon_not_ready")
	if gun.shell==null or last_aim_solution.get("shell_id","")!=gun.shell.id: return _fire_veto("shell_changed")
	# Scans were sampled during poll, before the shared drive phase. The
	# authorization muzzle and targets now belong to the end of that step.
	var age := clock-float(observation.get("last_seen",-INF))+_polled_delta
	var current := AimSolver.solve_intercept(vehicle.turret.muzzle.global_position,observation,gun.shell,vehicle.tank.velocity,_aim_error,age)
	if not current.ok: return _fire_veto(str(current.reason))
	last_aim_solution=current
	if vehicle.turret.barrel_direction().dot(current.direction)<cos(deg_to_rad(0.3)): return _fire_veto("mechanism_not_aligned")
	var allowed := sensor.fire_lane_clear(vehicle,observation,current)
	last_fire_authorization=sensor.last_lane_result.duplicate(true)
	return allowed

func _fire_veto(reason: String) -> bool:
	last_fire_authorization={"ok":false,"reason":reason,"segments":0}
	return false
