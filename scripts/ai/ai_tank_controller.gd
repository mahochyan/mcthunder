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
		var was_visible: bool = observation.get("visible",false)
		observation = {}
		for row in rows:
			if observation.is_empty() or (row.visible and not observation.visible): observation = row
		if observation.get("visible",false):
			if not was_visible or previous != observation.entity_id:
				_seen_since = clock
				_new_error()
		else: _seen_since = -1
	var caps := vehicle.capabilities()
	if vehicle.state.recovery_enabled:
		if not vehicle.state.fires.is_empty():
			phase = "repair"
			cmd.extinguish_requested = true
			return cmd
		if not caps.drive or not caps.fire:
			phase = "repair"
			if not vehicle.state.role_available("gunner") or not vehicle.state.role_available("driver"): cmd.replace_crew_requested = true
			else: cmd.repair_requested = true
			if not caps.fire: return cmd
	if vehicle.gunner.rounds_remaining == 0 and has_patrol:
		if phase != "retreat": driver.set_goal(retreat_goal)
		phase = "retreat"
		return driver.update_command(delta)
	if observation.is_empty():
		if not caps.drive: return cmd
		if phase != "patrol" and has_patrol: driver.set_goal(patrol_goal)
		phase = "patrol"
		return driver.update_command(delta)
	if not observation.visible:
		if not caps.drive: return cmd
		if phase != "search" and driver.navigator != null and not driver.navigator.nodes.is_empty():
			var id := driver.navigator.nearest(observation.position)
			driver.set_goal(driver.navigator.nodes[id])
		phase = "search"
		return driver.update_command(delta)
	if driver.has_goal: driver.cancel("enemy_visible")
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
