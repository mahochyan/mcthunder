class_name AIPathDriver
extends Node
## Generates commands only; VehicleActor owns all movement, damage and weapon execution.
signal state_changed(record: Dictionary)
var cam_rig: CameraRig
var gunner: Gunner
var navigator: DriveNavigator
var _actor_ref: WeakRef
var goal := Vector3.ZERO
var has_goal := false
var path := PackedVector3Array()
var path_ids: Array[String] = []
var waypoint := 0
var phase := "idle"
var reason := ""
var attempts := 0
var clock := 0.0
var _last_plan := -INF
var _phase_left := 0.0
var _generation := -1
var _blocked_edges := {}
var stuck := StuckDetector.new()
var events: Array[Dictionary] = []
var last_command := VehicleCommand.new()
var debug_log := false

func configure(actor: VehicleActor, nav: DriveNavigator) -> void:
	_actor_ref = weakref(actor)
	navigator = nav
	_generation = actor.state.generation
	reset_pending()

func is_local_controller() -> bool: return false
func actor() -> VehicleActor:
	return _actor_ref.get_ref() as VehicleActor if _actor_ref != null else null
func _transition(value: String, why: String = "") -> void:
	if phase == value and reason == why: return
	phase = value
	reason = why
	var vehicle := actor()
	var event := {"time":clock,"phase":phase,"reason":reason,"attempts":attempts,"waypoint":waypoint,"goal":goal,"position":vehicle.tank.global_position if vehicle != null and is_instance_valid(vehicle.tank) and vehicle.tank.is_inside_tree() else Vector3.ZERO}
	events.append(event.duplicate(true))
	if events.size() > 64: events.pop_front()
	if debug_log: print("[ai-drive] ",event)
	state_changed.emit(event.duplicate(true))

func cancel(why: String = "cancelled") -> void:
	has_goal = false
	path.clear()
	path_ids.clear()
	waypoint = 0
	_phase_left = 0
	last_command = VehicleCommand.new()
	_transition("idle",why)
func reset_pending() -> void:
	cancel("reset")
	attempts = 0
	_blocked_edges.clear()
	_last_plan = -INF
func on_detached() -> void: cancel("detached")

func set_goal(value: Vector3) -> Dictionary:
	var vehicle := actor()
	cancel("new_goal")
	if vehicle == null or not value.is_finite() or navigator == null: return {"ok":false,"reason":"invalid_goal"}
	goal = value
	has_goal = true
	attempts = 0
	_generation = vehicle.state.generation
	_blocked_edges.clear()
	_last_plan = -INF
	return _plan()

func _plan() -> Dictionary:
	var vehicle := actor()
	if vehicle == null or not has_goal: return {"ok":false,"reason":"cancelled"}
	if clock-_last_plan < GameConfig.AI_REPLAN_INTERVAL_S: return {"ok":false,"reason":"rate_limited"}
	_last_plan = clock
	var result := navigator.request_path(vehicle.tank.global_position,goal,vehicle.definition.drive_collision_size.x,_blocked_edges)
	if not result.ok:
		has_goal = false
		path.clear()
		path_ids.clear()
		_transition("unreachable",result.reason)
		return result
	path = result.points.duplicate()
	path_ids.assign(result.ids)
	waypoint = 0
	if path.size() > 1 and vehicle.tank.global_position.distance_to(path[0]) < 3: waypoint = 1
	stuck.reset(vehicle.tank.global_position)
	_transition("following","path_ready")
	return {"ok":true}

func poll() -> VehicleCommand:
	last_command = update_command(get_physics_process_delta_time())
	return last_command

func update_command(delta: float) -> VehicleCommand:
	var cmd := VehicleCommand.new()
	var vehicle := actor()
	if vehicle == null or not is_finite(delta) or delta <= 0 or get_tree().paused: return cmd
	clock += delta
	if vehicle.state.generation != _generation:
		_generation = vehicle.state.generation
		cancel("generation_changed")
		return cmd
	if vehicle.state.destroyed:
		cancel("destroyed")
		_transition("destroyed")
		return cmd
	if not has_goal: return cmd
	if not vehicle.capabilities().drive:
		_transition("disabled","drive_capability")
		return cmd
	if phase == "disabled": _transition("following","drive_recovered")
	if phase == "reverse":
		_phase_left -= delta
		cmd.throttle = -0.75
		if _phase_left <= 0:
			_phase_left = GameConfig.AI_TURN_RECOVERY_SECONDS
			_transition("turn_recovery","reverse_complete")
		return cmd
	if phase == "turn_recovery":
		_phase_left -= delta
		cmd.steer = 1.0 if attempts%2 == 1 else -1.0
		if _phase_left <= 0: _plan()
		return cmd
	if waypoint >= path.size():
		cancel("empty_path")
		return cmd
	var offset := path[waypoint]-vehicle.tank.global_position
	offset.y = 0
	var distance := offset.length()
	var speed := absf(vehicle.tank.forward_speed)
	if distance <= GameConfig.AI_GOAL_RADIUS_M and speed < 0.35:
		if waypoint == path.size()-1:
			has_goal = false
			_transition("arrived","goal_reached")
			return cmd
		waypoint += 1
		offset = path[waypoint]-vehicle.tank.global_position
		offset.y = 0
		distance = offset.length()
		stuck.reset(vehicle.tank.global_position)
	var forward := VehiclePose.flat_forward(vehicle.tank.global_basis)
	var heading := atan2(-forward.x,-forward.z)
	var angle := wrapf(atan2(-offset.x,-offset.z)-heading,-PI,PI)
	cmd.steer = clampf(angle/deg_to_rad(25),-1,1)
	if absf(angle) < deg_to_rad(0.8): cmd.steer = 0
	var desired_speed := minf(vehicle.definition.forward_max_speed,sqrt(2*vehicle.definition.coast_decel*maxf(distance-GameConfig.AI_GOAL_RADIUS_M*0.8,0)))
	if absf(angle) > deg_to_rad(18): desired_speed = 0
	cmd.throttle = desired_speed/vehicle.definition.forward_max_speed
	cmd.has_aim_point = true
	cmd.aim_world_point = vehicle.tank.global_position+offset.normalized()*35+Vector3.UP*2.3
	var obstacle := _obstacle(vehicle)
	var expecting_progress := absf(angle) < deg_to_rad(18) and distance > GameConfig.AI_GOAL_RADIUS_M
	if not obstacle.is_empty() and expecting_progress:
		cmd.throttle = 0
		_transition("yielding","physical_obstacle")
	elif phase == "yielding": _transition("following","obstacle_cleared")
	if stuck.observe(vehicle.tank.global_position,expecting_progress,delta):
		attempts += 1
		if attempts > GameConfig.AI_RECOVERY_ATTEMPTS:
			has_goal = false
			_transition("failed","recovery_limit")
			return VehicleCommand.new()
		if waypoint > 0: _blocked_edges[DriveNavigator.edge_key(path_ids[waypoint-1],path_ids[waypoint])] = true
		_phase_left = GameConfig.AI_REVERSE_SECONDS
		_transition("reverse","insufficient_actual_progress")
	return cmd

func _obstacle(vehicle: VehicleActor) -> Dictionary:
	var body := vehicle.tank
	var forward := VehiclePose.flat_forward(body.global_basis)
	var side := forward.cross(Vector3.UP)
	var length := vehicle.definition.drive_collision_size.z/2+GameConfig.AI_OBSTACLE_LOOKAHEAD_M
	var space := body.get_world_3d().direct_space_state
	for sign in [-1,0,1]:
		var from: Vector3 = body.global_position+Vector3.UP*0.95+side*sign*vehicle.definition.drive_collision_size.x*0.43
		var query := PhysicsRayQueryParameters3D.create(from,from+forward*length,GameConfig.LAYER_WORLD|GameConfig.LAYER_VEHICLE,[body.get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): return hit
	return {}
