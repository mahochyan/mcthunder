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
func on_detached() -> void: reset_pending()
func set_patrol(point: Vector3, fallback: Vector3) -> void:
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
	if not driver.set_goal(patrol_goal).ok:
		var hop := driver.escape_goal()
		if hop.is_finite(): driver.set_goal(hop)

func update_command(delta: float) -> VehicleCommand:
	var cmd := VehicleCommand.new()
	var vehicle := actor()
	if vehicle == null or delta <= 0 or not is_finite(delta) or get_tree().paused: return cmd
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
	if vehicle.state.recovery_enabled:
		if not vehicle.state.fires.is_empty():
			phase = "repair"
			cmd.extinguish_requested = true
			return cmd
		if not caps.drive or not caps.fire or caps.turret_speed <= 0:
			recovering = true
			phase = "repair"
			if not vehicle.state.role_available("gunner") or not vehicle.state.role_available("driver"): cmd.replace_crew_requested = true
			else: cmd.repair_requested = true
			if not caps.fire: return cmd
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
		if driver.phase in ["failed","unreachable","idle"] and vehicle.tank.global_position.distance_to(patrol_goal)>GameConfig.AI_GOAL_RADIUS_M:
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
	cmd.has_aim_point = true
	cmd.aim_world_point = AimSolver.solve(vehicle.turret.muzzle.global_position,observation,vehicle.gunner.shell,vehicle.tank.velocity,_aim_error)
	var direction := (cmd.aim_world_point-vehicle.turret.muzzle.global_position).normalized()
	if phase == "engage" and caps.fire and vehicle.gunner.rounds_remaining != 0 and vehicle.gunner.cooldown_left <= 0 and vehicle.gunner.resume_grace <= 0 and vehicle.turret.barrel_direction().dot(direction) >= cos(deg_to_rad(0.3)):
		cmd.fire_requested = sensor.fire_lane_clear(vehicle,observation)
	return cmd
