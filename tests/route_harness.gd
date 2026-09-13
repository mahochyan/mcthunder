class_name RouteHarness
extends RefCounted
## WT-039-R1: test-side hardening for long route batteries.
##
## The investigation showed the seven failing checks could not be reproduced in isolation
## and that the failing slot drifts between runs, so the harness gains diagnostics WITHOUT
## touching a single assertion or threshold:
##   * `occupancy()` makes "the next route starts on a clear spawn" an explicit, named check
##     instead of an assumption;
##   * `trace_line()` / `dump_trace()` keep a per-tick trail so any future intermittent
##     failure is diagnosable rather than mysterious.
##
## Nothing here changes what a route is expected to achieve.

const TRACE_DIR := "res://logs/route-traces"

## Any vehicle body inside `radius` of the spawn (0 means the slot is clear).
static func occupancy(world: Node3D, position: Vector3, radius: float = 8.0) -> int:
	if world == null or not world.is_inside_tree(): return -1
	var space := world.get_world_3d().direct_space_state
	if space == null: return -1
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY,position+Vector3(0,1.0,0))
	params.collision_mask = GameConfig.LAYER_VEHICLE
	params.collide_with_areas = false
	return space.intersect_shape(params,16).size()

## One diagnostic line for a tick.
static func trace_line(tick: int, driver: AIPathDriver, actor: VehicleActor, goal: Vector3) -> String:
	if driver == null or actor == null: return ""
	var position: Vector3 = actor.tank.global_position
	var target := goal
	if driver.path.size() > driver.waypoint: target = driver.path[driver.waypoint]
	var to_target := target-position
	# Measure the bearing in the horizontal plane: `signed_angle_to` about UP is unstable when
	# the target vector carries a large height difference, which made a rotating hull look as
	# though its bearing were frozen.
	var flat_target := Vector2(to_target.x,to_target.z)
	var flat_forward := Vector2(-actor.tank.global_basis.z.x,-actor.tank.global_basis.z.z)
	var bearing := 0.0
	if flat_target.length() > 0.01:
		bearing = rad_to_deg(flat_target.angle_to(flat_forward))
	# Command columns matter when a vehicle stops while the terrain is fine: they separate "the
	# driver asked for nothing" from "the driver asked and the hull did not respond".
	var command := ""
	if driver != null and driver.last_command != null:
		command = " thr=%.2f steer=%.2f blocked=%s attempts=%d stuck_s=%.2f consumed=(%.2f,%.2f) submit_ok=%s" % [driver.last_command.throttle,driver.last_command.steer,
			str(actor.tank.slope_blocked),driver.attempts,driver.stuck.elapsed,
			actor.last_consumed_throttle,actor.last_consumed_steer,str(actor.last_submit_accepted)]
	# Pose and contact columns decide what a frozen hull is frozen by: a pose dug into the mesh,
	# a body pressed against world geometry, or neither.
	var contacts: Array[String] = []
	for index in actor.tank.get_slide_collision_count():
		var collision := actor.tank.get_slide_collision(index)
		if collision == null: continue
		var collider := collision.get_collider()
		contacts.append(str(collider.name) if collider != null else "?")
	var pose := " pitch=%.2f roll=%.2f normal_y=%.2f contacts=%d[%s]" % [
		rad_to_deg(actor.tank.global_basis.get_euler().x),rad_to_deg(actor.tank.global_basis.get_euler().z),
		float(actor.tank.ground_state.normal.y),contacts.size(),",".join(contacts)]
	return "tick=%d phase=%s reason=%s wp=%d dist_wp=%.2f bearing_deg=%.2f speed=%.3f pos=(%.3f,%.3f,%.3f)%s%s" % [
		tick,str(driver.phase),str(driver.reason),driver.waypoint,to_target.length(),bearing,
		actor.tank.forward_speed,position.x,position.y,position.z,command,pose]

## Write the collected trace and return its path (empty when there was nothing to write).
static func dump_trace(name: String, lines: Array) -> String:
	if lines.is_empty(): return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRACE_DIR))
	var path := "%s/%s-%d.log" % [TRACE_DIR,name,Time.get_ticks_msec()]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return ""
	for line in lines: file.store_line(str(line))
	file.close()
	return path
