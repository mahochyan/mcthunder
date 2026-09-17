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
var _traffic_blockers := {}
var _next_traffic_check := 0.0
var stuck := StuckDetector.new()
## WT-036-R1: seconds spent yielding to a physical obstacle without clearing it.
var yield_elapsed := 0.0
var events: Array[Dictionary] = []
var planning_counts := {"failed":0,"unreachable":0,"replanned":0}
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
	if value in ["failed","unreachable"]: planning_counts[value] += 1
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
	_traffic_blockers.clear()
	_last_plan = -INF
func on_detached() -> void: cancel("detached")

func set_goal(value: Vector3) -> Dictionary:
	var vehicle := actor()
	# A same-goal retry (the controller's bounded objective retry) must keep the
	# edges already proven unreachable or it re-runs the identical failed plan.
	var same_retry := goal == value and not _blocked_edges.is_empty()
	cancel("new_goal")
	if vehicle == null or not value.is_finite() or navigator == null: return {"ok":false,"reason":"invalid_goal"}
	goal = value
	has_goal = true
	attempts = 0
	_generation = vehicle.state.generation
	if not same_retry:
		_blocked_edges.clear()
		_traffic_blockers.clear()
	_last_plan = -INF
	return _plan()

func escape_goal(exclude: Vector3 = Vector3.INF, visited: Array[Vector3] = []) -> Vector3:
	# Nearest graph node to self: stepping back onto the graph is always one hop
	# and gives a repeatedly-unplannable goal a chance to be re-attempted from a
	# connected position instead of idling on the same failure. The exclude point
	# bounds the loop: hopping back onto the SAME no-progress node is never progress.
	var vehicle := actor()
	if vehicle == null or navigator == null: return Vector3.INF
	var best := Vector3.INF
	var best_d := INF
	for id in navigator.nodes:
		var node: Vector3 = navigator.nodes[id]
		if exclude.is_finite() and node.distance_to(exclude) < 1.0: continue
		var used := false
		for point in visited:
			if point.distance_to(node) < 1.0: used = true; break
		if used: continue
		var d: float = vehicle.tank.global_position.distance_to(node)
		if d <= GameConfig.AI_GOAL_RADIUS_M: continue
		if d < best_d:
			best_d = d
			best = node
	return best

func _plan() -> Dictionary:
	var vehicle := actor()
	if vehicle == null or not has_goal: return {"ok":false,"reason":"cancelled"}
	if clock-_last_plan < GameConfig.AI_REPLAN_INTERVAL_S: return {"ok":false,"reason":"rate_limited"}
	_last_plan = clock
	_release_vacated_traffic()
	planning_counts.replanned += 1
	var result := navigator.request_path(vehicle.tank.global_position,goal,vehicle.definition.drive_collision_size.x,_blocked_edges)
	if not result.ok:
		has_goal = false
		path.clear()
		path_ids.clear()
		_transition("unreachable",result.reason)
		return result
	# WT-040-R1: PRESERVE PROGRESS ACROSS A REPLAN. This used to set waypoint = 0 (or 1), which threw
	# away the entire route prefix every time _plan() was accepted - and _plan() is accepted as often
	# as AI_REPLAN_INTERVAL_S allows. Measured on the river: the waypoint index advanced 1, 4, 12 and
	# then fell back to 6 while the replanned counter climbed 2, 3, 3, 4, the path length changed
	# 69, 70, 70, 82 and the distance to goal oscillated 994, 1067, 976, 1071 instead of closing.
	# The vehicle was driving, the planner never failed (failed = unreachable = 0) - it simply kept
	# restarting the route. Resume at the nearest point of the NEW path, and never behind the point we
	# had already been heading for, so a replan may change the route but not the progress.
	var here := vehicle.tank.global_position
	var previous_target := Vector3.INF
	if path.size() > 0:
		previous_target = path[clampi(waypoint,0,path.size()-1)]
	path = result.points.duplicate()
	path_ids.assign(result.ids)
	var resume := 0
	if path.size() > 1:
		var best_d := INF
		for i in path.size():
			var d := here.distance_to(path[i])
			if d < best_d:
				best_d = d
				resume = i
		if previous_target.is_finite():
			for i in range(resume,path.size()):
				if path[i].distance_to(previous_target) <= 3.0:
					resume = maxi(resume,i)
					break
	waypoint = clampi(resume,0,maxi(path.size()-1,0))
	# WT-039-R1: do NOT reset the stuck window here. _plan() runs at most every
	# AI_REPLAN_INTERVAL_S (1.0 s) while the detector needs AI_STUCK_WINDOW_S (2.0 s) of no
	# progress, so resetting on every replan made the detector structurally unable to fire: a
	# hull wedged against world geometry (throttle commanded, slope_blocked false, position
	# frozen, phase following for hundreds of ticks - measured on the M26 road route) kept
	# replanning to a waypoint ~2.6 m away and never entered recovery. The window is reset only
	# on real progress (waypoint advance, observe()) and on a new goal (set_goal).
	_transition("following","path_ready")
	return {"ok":true}

func _remember_block(edge: String, blocker: VehicleActor = null) -> void:
	# Static obstructions retain the existing permanent memory. A live controlled
	# vehicle is a moving obstacle, and must not close this road after it leaves.
	var permanent: bool=_blocked_edges.has(edge) and not _traffic_blockers.has(edge)
	_blocked_edges[edge]=true
	if blocker==null or blocker.controller==null or blocker.state.destroyed:
		_traffic_blockers.erase(edge)
	elif not permanent:
		_traffic_blockers[edge]={"actor":weakref(blocker),"position":blocker.tank.global_position,
			"clearance":maxf(blocker.definition.drive_collision_size.z,actor().definition.drive_collision_size.z)+GameConfig.AI_NAV_MARGIN_M}

func _release_vacated_traffic() -> bool:
	var changed := false
	for edge in _traffic_blockers.keys():
		var row: Dictionary=_traffic_blockers[edge]
		var blocker: VehicleActor=row.actor.get_ref() as VehicleActor
		if is_instance_valid(blocker) and is_instance_valid(blocker.tank) and blocker.tank.global_position.distance_to(row.position)<=float(row.clearance): continue
		_traffic_blockers.erase(edge)
		_blocked_edges.erase(edge)
		changed=true
	return changed

func poll() -> VehicleCommand:
	last_command = update_command(get_physics_process_delta_time())
	return last_command

func _through_waypoint() -> bool:
	if not navigator.through_waypoints or waypoint >= path.size()-1: return false
	if waypoint == 0: return true
	var incoming := path[waypoint]-path[waypoint-1]
	var outgoing := path[waypoint+1]-path[waypoint]
	incoming.y=0; outgoing.y=0
	# A sharp bend needs the ordinary stop-and-turn approach. Advancing six metres
	# early at cruise speed lets the hull coast past the road before it can pivot.
	return incoming.normalized().dot(outgoing.normalized()) >= cos(deg_to_rad(18))

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
	if clock>=_next_traffic_check:
		_next_traffic_check=clock+GameConfig.AI_REPLAN_INTERVAL_S
		if _release_vacated_traffic() and phase in ["following","yielding"]:
			_plan()
			if not has_goal: return cmd
	if waypoint >= path.size():
		cancel("empty_path")
		return cmd
	var offset := path[waypoint]-vehicle.tank.global_position
	offset.y = 0
	var distance := offset.length()
	var speed := absf(vehicle.tank.forward_speed)
	var through := _through_waypoint()
	var arrival_radius := maxf(GameConfig.AI_GOAL_RADIUS_M,minf(6.0,speed*.6+2)) if through else GameConfig.AI_GOAL_RADIUS_M
	if distance <= arrival_radius and (through or speed < 0.35):
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
	if _through_waypoint():
		desired_speed=minf(vehicle.definition.forward_max_speed,8.0)
	elif navigator.through_waypoints and waypoint<path.size()-1:
		desired_speed=minf(desired_speed,8.0)
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
	# WT-036-R1: a yield that never clears is a deadlock. The measured case stood in front of a
	# parked vehicle for the whole 250 s budget where the untouched baseline recovered and arrived
	# in 84.9 s, and the acceptance check requires BOTH the arrival and a reverse event. Thresholds
	# cannot separate it from traffic, and "unowned" alone is wrong too because map geometry (walls,
	# buildings) is unowned as well and yielding to those is normal - treating them as dead ends
	# broke the village. The structural test is therefore a real VEHICLE with no controller: that is
	# exactly a parked hull.
	if phase == "yielding":
		var blocker: Object = obstacle.get("collider") if obstacle is Dictionary else null
		var mode := ""
		var limit := GameConfig.AI_YIELD_TIMEOUT_S
		# WT-040-R1 telemetry only (no behaviour change): remember WHO we are yielding to, so a
		# repeated block can be attributed to a specific opponent in the recorded match data.
		var blocker_id := ""
		var blocking_vehicle: VehicleActor = null
		if blocker is Node:
			var blocker_owner: Node = (blocker as Node).get_parent()
			if blocker_owner is VehicleActor:
				blocking_vehicle=blocker_owner as VehicleActor
				blocker_id = str(blocker_owner.get("entity_id"))
				if blocker_owner.get("controller") == null:
					# A parked hull is a dead end: recovery (reverse) is what the parked-vehicle
					# acceptance check requires, and a wreck cannot move aside by itself.
					mode = "recover"
				else:
					# On graph edges, try another road first. Stagger the two drivers'
					# decisions so an oncoming pair does not always replan symmetrically.
					mode = "replan"
					# Before the first graph node there is no incoming graph edge to
					# block. Replanning chooses the same occupied connector forever.
					# Use the existing bounded physical recovery to leave that connector;
					# ordinary road-edge rerouting and permanent block memory stay intact.
					if waypoint == 0: mode = "recover"
					if str(vehicle.entity_id) < str(blocker_owner.get("entity_id")):
						limit += GameConfig.AI_YIELD_PRIORITY_GRACE_S
		yield_elapsed = (yield_elapsed + delta) if mode != "" else 0.0
		if yield_elapsed >= limit:
			yield_elapsed = 0.0
			if waypoint > 0:
				var blocked_key := DriveNavigator.edge_key(path_ids[waypoint-1],path_ids[waypoint])
				# Release only a recorded moving-vehicle block after that same vehicle
				# actually leaves. No expiry applies to world geometry or parked wrecks.
				_remember_block(blocked_key,blocking_vehicle)
				# WT-040-R1 telemetry only: record every block creation, with its cause, so the
				# frequency and the counterparty can be measured before any further change is made.
				events.append({"time":clock,"phase":phase,"reason":"edge_blocked","edge":blocked_key,
					"mode":mode,"limit":limit,"blocker":blocker_id,"waypoint":waypoint,
					"blocked_total":_blocked_edges.size()})
			if mode == "recover":
				attempts += 1
				if attempts > GameConfig.AI_RECOVERY_ATTEMPTS:
					has_goal = false
					_transition("failed","recovery_limit")
					return VehicleCommand.new()
				_phase_left = GameConfig.AI_REVERSE_SECONDS
				_transition("reverse","insufficient_actual_progress")
			elif mode == "replan":
				# Marking the edge is the whole action: the periodic replan then routes around it.
				_last_plan = -INF
				_plan()
			return cmd
	else:
		yield_elapsed = 0.0
	# WT-039-R1: a no-progress window is only meaningful while the driver is actually asking the
	# hull to move. Counting idle or planning ticks made vehicles that legitimately wait enter
	# recovery, so the window now requires a real throttle command as well as an expectation of
	# progress - which still catches the wedged case (throttle 0.31 with a frozen position).
	if stuck.observe(vehicle.tank.global_position,expecting_progress and absf(cmd.throttle) > 0.1,delta):
		attempts += 1
		if attempts > GameConfig.AI_RECOVERY_ATTEMPTS:
			has_goal = false
			_transition("failed","recovery_limit")
			return VehicleCommand.new()
		if waypoint > 0: _remember_block(DriveNavigator.edge_key(path_ids[waypoint-1],path_ids[waypoint]))
		_phase_left = GameConfig.AI_REVERSE_SECONDS
		_transition("reverse","insufficient_actual_progress")
	return cmd

func _obstacle(vehicle: VehicleActor) -> Dictionary:
	var body := vehicle.tank
	# The nose rays follow the actual support plane. Horizontal rays treated a
	# perfectly drivable uphill road as a wall on longer village hill approaches.
	var up: Vector3 = body.ground_state.get("normal",Vector3.UP) if body.ground_state.get("grounded",false) else Vector3.UP
	var flat := VehiclePose.flat_forward(body.global_basis)
	var forward := (flat-up*flat.dot(up)).normalized()
	var side := forward.cross(up).normalized()
	var length := vehicle.definition.drive_collision_size.z/2+GameConfig.AI_OBSTACLE_LOOKAHEAD_M
	var space := body.get_world_3d().direct_space_state
	for sign in [-1,0,1]:
		var from: Vector3 = body.global_position+up*0.95+side*sign*vehicle.definition.drive_collision_size.x*0.43
		var query := PhysicsRayQueryParameters3D.create(from,from+forward*length,GameConfig.LAYER_WORLD|GameConfig.LAYER_VEHICLE,[body.get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): return hit
	return {}
