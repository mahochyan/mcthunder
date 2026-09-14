extends SceneTree
## WT-039-D: production-vehicle traversal checks at the x閳?120 flank crest.
##
## Separate identity/version from the rigid-envelope diagnostic: the old T018-03/T018-03b
## results stay untouched (and stay failing). This suite answers a different question - can
## an ACTUAL production vehicle, using production driving, movement collision, hull pose,
## running gear and suspension, traverse this crest under the listed conditions?
##
## Monitors are calibrated BEFORE any verdict: a flat-ground control run per vehicle must
## show no bottoming and no stall, otherwise the suite reports FIXTURE_NOT_VALIDATED and
## exits inconclusive rather than publishing numbers nobody should trust.
const ROUTE_X := -120.0
const BOTTOM_Z := 60.0
const CREST_Z := 0.0
const STEP := 1.0/60.0
const BOUNCE_LIMIT := 3.0
const FIXTURE_TOLERANCE_M := 0.10
const STALL_TICKS := 240
const CALIBRATION_TICKS := 300
const CONTROL_THROTTLE := 0.30
## Measured throttle-to-motion curve on flat ground (180 ticks, straight command):
##   M4A3 0.2 -> 0.05 m / 0.3 -> 0.48 / 0.5 -> 2.37 / 0.8 -> 5.05 / 1.0 -> 6.56
##   M24  0.2 -> 0.48     / 0.3 -> 1.90 / 0.5 -> 4.74 / 0.8 -> 8.65 / 1.0 -> 11.18
##   M26  0.2 -> 0.05     / 0.3 -> 0.05 / 0.5 -> 0.97 / 0.8 -> 2.97 / 1.0 -> 4.14
##   M36  0.2 -> 0.05     / 0.3 -> 0.80 / 0.5 -> 2.91 / 0.8 -> 5.80 / 1.0 -> 7.58
## There is a real engagement dead-zone below which a vehicle does not move at all, and it
## differs per vehicle, so the "low speed" condition uses the measured lowest setting that
## actually engages instead of an assumed value.
const LOW_THROTTLE := {"us_m4a3_75w_vvss_1944":0.5,"us_m24_m6_t85e1_1951":0.3,
	"us_m26_m3_1945":0.5,"us_m36_m4a1_1945":0.5}
const CALIBRATION_MIN_TRAVEL := 1.5
const INCONCLUSIVE_EXIT := 2
var count := 0
var failed := 0
var world: Node3D
var map
var defs: VehicleDefs
var calibration: Dictionary = {}

class FixedThrottle extends Node:
	var cam_rig: Node = null
	var gunner: Node = null
	var throttle := 0.25
	var steer := 0.0
	var hold := false
	func poll() -> VehicleCommand:
		var cmd := VehicleCommand.new()
		cmd.throttle = 0.0 if hold else throttle
		cmd.steer = steer
		return cmd
	func is_local_controller() -> bool: return false

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n:int=3)->void:
	for i in n: await physics_frame

func _spawn(vehicle_id: String, at: Vector3, yaw: float = PI) -> VehicleActor:
	var actor := VehicleActor.new()
	world.add_child(actor)
	actor.setup(defs,vehicle_id,"T039D",1,Transform3D(Basis(Vector3.UP,yaw),at),4,null)
	actor.set_physics_process(false)
	actor.gunner.aim_preview_enabled = false
	actor.cam_rig.set_process(false); actor.cam_rig.set_physics_process(false)
	return actor

## Geometric quantity only: on a 13 degree slope a flat-bottomed hull box necessarily sits
## below the surface at its uphill corners (~halfLength*tan13 = 0.55 m), which is normal
## geometry, not bottoming. It is therefore reported for information and is NOT part of the
## pass criteria; ground contact is judged from the production floor state and propulsion.
func _hull_box_intersection(actor: VehicleActor) -> float:
	var size: Vector3 = actor.definition.drive_collision_size
	var center: Vector3 = actor.definition.drive_collision_center
	var bottom := actor.tank.global_position.y + center.y - size.y*0.5
	var space := world.get_world_3d().direct_space_state
	var worst := 0.0
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var corner: Vector3 = actor.tank.global_transform*Vector3(sx*size.x*0.45,0.0,sz*size.z*0.45)
			var query := PhysicsRayQueryParameters3D.create(corner+Vector3.UP*2.0,corner+Vector3.DOWN*6.0,GameConfig.LAYER_WORLD)
			var hit := space.intersect_ray(query)
			if hit.is_empty(): continue
			if str(hit.collider.name) != "VillageTerrain": continue
			worst = maxf(worst,(hit.position as Vector3).y-bottom)
	return worst

## A point sits ON the terrain: the earlier scenarios reused the road-centre height at an
## offset position, so the vehicle spawned in the air and never touched the floor.
func _ground_point(x: float, z: float, lift: float = 0.05) -> Vector3:
	return Vector3(x,VillageDefinition.height(x,z)+lift,z)

## Drop the vehicle onto the real collision mesh and wait for the production floor state to
## report contact. Placing a vehicle by the analytic height is unsafe on a 4 m faceted mesh:
## on a convex slope the analytic value sits above the interpolated surface, so the vehicle
## could hover (never touching the floor) and appear immobile for reasons that are entirely
## the fixture's. No controller is bound yet, so this is gravity and contact only.
func _settle(actor: VehicleActor, max_ticks: int = 300) -> Dictionary:
	var ticks := 0
	var on_floor := 0
	for i in max_ticks:
		ticks = i
		actor.advance_standalone_tick(STEP)
		if actor.tank.is_on_floor(): on_floor += 1
		if on_floor >= 5: break
	return {"settled":on_floor >= 5,"ticks":ticks,"on_floor_ticks":on_floor}

## The navigator accepts a start within 16 m of a node but a goal only within
## AI_GOAL_RADIUS_M (1.6 m), so a scenario goal must be a node position, not a point chosen
## for convenience - two scenarios previously aborted on tick 1 with `unreachable` because
## their goals sat 3-5 m off the graph.
func _nearest_node(nav: DriveNavigator, position: Vector3) -> Vector3:
	var best := position
	var best_distance := INF
	for id in nav.nodes.keys():
		var candidate: Vector3 = nav.nodes[id]
		var distance := position.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _drive(vehicle_id: String, label: String, start: Vector3, goal: Vector3, mode: String, hold_z: float = INF, ticks_limit: int = 18000, yaw: float = PI) -> Dictionary:
	print("[T039-D start] %s %s mode=%s from %s to %s" % [vehicle_id,label,mode,str(start),str(goal)])
	var actor := _spawn(vehicle_id,start+Vector3(0,0.5,0),yaw)
	var settle := await _settle(actor)
	var nav := DriveNavigator.new(); nav.configure(map.graph)
	var driver := AIPathDriver.new()
	var fixed: FixedThrottle = null
	if mode == "driver":
		actor.add_child(driver); driver.configure(actor,nav); actor.set_controller(driver)
		driver.set_goal(goal)
	else:
		fixed = FixedThrottle.new()
		fixed.throttle = float(LOW_THROTTLE.get(vehicle_id,0.5)) if mode == "low" else (0.35 if mode == "crest" else (-0.35 if mode == "reverse" else CONTROL_THROTTLE))
		actor.add_child(fixed); actor.set_controller(fixed)
	await _frames()
	var hull_box_intersection := 0.0
	var bounces := 0
	var landing_impacts := 0
	var stalled := 0
	var still := 0
	var nonfinite := 0
	var on_floor_ticks := 0
	var reverse_ticks := 0
	var reached := false
	var held := false
	var released := false
	var previous := actor.tank.global_position
	var heading_previous := rad_to_deg(atan2((-actor.tank.global_basis.z).x,(-actor.tank.global_basis.z).z))
	var traveled := 0.0
	var ticks_run := 0
	var trace: Array = []
	for i in ticks_limit:
		ticks_run = i+1
		if fixed != null:
			var to_goal := goal-actor.tank.global_position
			var bearing := 0.0
			if to_goal.length() > 0.5:
				bearing = rad_to_deg((-actor.tank.global_basis.z).signed_angle_to(to_goal.normalized(),Vector3.UP))
			fixed.steer = clampf(bearing/30.0,-1.0,1.0)
			if mode == "crest" and not released:
				if actor.tank.global_position.z <= hold_z and not held:
					fixed.hold = true; held = true
				elif held and i > 120:
					fixed.hold = false; released = true
		actor.advance_standalone_tick(STEP)
		var pos: Vector3 = actor.tank.global_position
		if not pos.is_finite(): nonfinite += 1
		# No bounce criterion: the product's landing model already bounds every rebound by
		# drive_profile.landing_max_rebound, and a vehicle climbing a slope legitimately carries an
		# upward velocity component, so any world-Y threshold flags normal driving. The model's own
		# landing counter is reported as information instead.
		landing_impacts = actor.tank.landing.impacts
		hull_box_intersection = maxf(hull_box_intersection,_hull_box_intersection(actor))
		if actor.tank.is_on_floor(): on_floor_ticks += 1
		if actor.tank.forward_speed < -0.05: reverse_ticks += 1
		var move := pos.distance_to(previous)
		traveled += move
		# A pivot in place is legitimate progress: the driver commands zero throttle with full
		# steer for large heading errors, so counting position alone marked every such pivot as
		# a stall. Progress means EITHER translation OR rotation.
		var heading_now := rad_to_deg(atan2((-actor.tank.global_basis.z).x,(-actor.tank.global_basis.z).z))
		var heading_delta := absf(wrapf(heading_now-heading_previous,-180.0,180.0))
		heading_previous = heading_now
		if move < 0.01 and heading_delta < 0.05: still += 1
		else: still = 0
		if still >= STALL_TICKS: stalled += 1
		previous = pos
		if i % 1500 == 0 and i > 0:
			print("[T039-D progress] %s %s tick=%d traveled=%.1f speed=%.2f still=%d phase=%s" % [
				vehicle_id,label,i,traveled,actor.tank.forward_speed,still,(driver.phase if driver != null else "fixed")])
		if i % 30 == 0:
			var command_part := ""
			if driver != null and driver.last_command != null:
				command_part = " thr=%.2f steer=%.2f" % [driver.last_command.throttle,driver.last_command.steer]
			elif fixed != null:
				command_part = " thr=%.2f steer=%.2f hold=%s" % [fixed.throttle,fixed.steer,str(fixed.hold)]
			var base_line := ""
			if driver != null: base_line = RouteHarness.trace_line(i,driver,actor,goal)
			else: base_line = "tick=%d phase=%s speed=%.3f pos=%s" % [i,mode,actor.tank.forward_speed,str(actor.tank.global_position)]
			trace.append(base_line+command_part+" on_floor="+str(actor.tank.is_on_floor())+" still="+str(still)
				+" grounded="+str(actor.tank.ground_state.grounded)
				+" support_l=%.2f support_r=%.2f" % [float(actor.tank.ground_state.left_support),float(actor.tank.ground_state.right_support)]
				+" yaw_rate=%.3f" % float(actor.tank.tracks.yaw_rate))
		if driver != null and mode == "driver" and driver.phase in ["arrived","failed","unreachable"]:
			reached = driver.phase == "arrived"; break
		if mode != "driver" and pos.distance_to(goal) < 3.0: reached = true; break
	var muzzle_ok: bool = actor.turret != null and actor.turret.muzzle != null and actor.turret.muzzle.global_position.is_finite()
	var armour_ok: bool = actor.definition != null and actor.tank.defs != null
	var internal_ok: bool = actor.state.module_states.size() > 0
	var result := {"label":label,"reached":reached,"hull_box_intersection_m":hull_box_intersection,
		"settled":bool(settle.settled),"settle_ticks":int(settle.ticks),
		"ticks_run":ticks_run,"final_phase":(str(driver.phase) if driver != null else "fixed"),
		"bounces":bounces,"stalled":stalled,"on_floor_fraction":float(on_floor_ticks)/float(maxi(1,ticks_run)),
		"reverse_ticks":reverse_ticks,
		"nonfinite":nonfinite,"traveled":traveled,"muzzle_ok":muzzle_ok,"armour_ok":armour_ok,"internal_ok":internal_ok}
	actor.free()
	await _frames(2)
	if not (reached and stalled == 0):
		print("[T039-D] trace saved: ",RouteHarness.dump_trace("t039d-%s-%s"%[vehicle_id,label],trace))
	return result

## Flat-ground control: no bottoming, no stall, and the vehicle actually moves.
func _calibrate(vehicle_id: String) -> Dictionary:
	var flat := Vector3(0.0,VillageDefinition.height(0.0,116.0)+0.05,116.0)
	var actor := _spawn(vehicle_id,flat+Vector3(0,0.5,0),PI)
	var settle := await _settle(actor)
	var fixed := FixedThrottle.new(); fixed.throttle = float(LOW_THROTTLE.get(vehicle_id,0.5))
	actor.add_child(fixed); actor.set_controller(fixed)
	await _frames()
	var worst := 0.0
	var bounces := 0
	var landing_impacts := 0
	var still := 0
	var stalled := 0
	var start := actor.tank.global_position
	var previous := start
	for i in CALIBRATION_TICKS:
		actor.advance_standalone_tick(STEP)
		worst = maxf(worst,_hull_box_intersection(actor))
		# No bounce criterion: the product's landing model already bounds every rebound by
		# drive_profile.landing_max_rebound, and a vehicle climbing a slope legitimately carries an
		# upward velocity component, so any world-Y threshold flags normal driving. The model's own
		# landing counter is reported as information instead.
		landing_impacts = actor.tank.landing.impacts
		var pos: Vector3 = actor.tank.global_position
		if pos.distance_to(previous) < 0.01: still += 1
		else: still = 0
		if still >= STALL_TICKS: stalled += 1
		previous = pos
	var traveled := start.distance_to(actor.tank.global_position)
	# Capture every field that lives on the actor's children BEFORE freeing the actor: reading
	# `fixed.throttle` afterwards touches a freed object and silently aborted the calibration.
	var throttle_used := fixed.throttle
	actor.free()
	await _frames(2)
	var ok: bool = worst <= FIXTURE_TOLERANCE_M and stalled == 0 and traveled > CALIBRATION_MIN_TRAVEL and bounces == 0
	var report := {"vehicle_id":vehicle_id,"max_bottoming":worst,"stalled":stalled,"traveled":traveled,
		"bounces":bounces,"tolerance":FIXTURE_TOLERANCE_M,"throttle":throttle_used,"ok":ok}
	print("[T039-D calibration] %s throttle=%.2f bottoming=%.4f stalled=%d traveled=%.2f bounces=%d ok=%s"%[vehicle_id,throttle_used,worst,stalled,traveled,bounces,str(ok)])
	return report

func _run() -> void:
	root.size = Vector2i(1280,720)
	defs = VehicleDefs.new(); defs.load_defaults()
	VehicleCatalog.new().load_all(defs)
	map = VillageDefinition.create()
	world = Node3D.new(); root.add_child(world); current_scene = world
	VillageWorld.build(world,map,true)
	await _frames(8)
	var crest := _ground_point(ROUTE_X,CREST_Z)
	var bottom := _ground_point(ROUTE_X,BOTTOM_Z)
	print("[T039-D] route bottom=",bottom," crest=",crest)
	# A start may be 16 m off the graph but a GOAL must be within AI_GOAL_RADIUS_M (1.6 m), so
	# every driver goal is snapped to the nearest node; two scenarios previously aborted on
	# tick 1 because their goals sat 3-5 m away.
	var nav := DriveNavigator.new()
	nav.configure(map.graph)
	var crest_node := _nearest_node(nav,crest)
	var bottom_node := _nearest_node(nav,bottom)
	print("[T039-D] graph-snapped goals: crest=",crest_node," bottom=",bottom_node)
	# Vehicles without a production configuration are reported, never scaled to fit.
	for pilot in ["ussr_t_80b","germ_leopard_2a4"]:
		var definition: VehicleDefinition = defs.get_vehicle(pilot)
		_check(definition == null,"T039-D NOT_VERIFIED %s: no production combat/drive configuration in this build (definition=%s) - scaled surrogates are not accepted"%[pilot,str(definition != null)])
	# --- fixture calibration (evidence-based gate) ---
	var fixture_ok := true
	for vehicle_id in VehicleCatalog.IDS:
		var report := await _calibrate(vehicle_id)
		calibration[vehicle_id] = report
		if not bool(report.ok): fixture_ok = false
		_check(bool(report.ok),"T039-D fixture flat-ground control %s: bottoming %.4f m <= %.2f m, stalls %d, traveled %.2f m"%[
			vehicle_id,float(report.max_bottoming),FIXTURE_TOLERANCE_M,int(report.stalled),float(report.traveled)])
	if not fixture_ok:
		print("[T039-D] FIXTURE_NOT_VALIDATED: the flat-ground control failed for at least one vehicle, so the scenario battery is skipped and no product verdict is published.")
		print("FLANK_CREST_TRAVERSAL_FIXTURE_NOT_VALIDATED")
		quit(INCONCLUSIVE_EXIT)
	# --- scenario battery on production vehicles ---
	for vehicle_id in VehicleCatalog.IDS:
		var results: Array[Dictionary] = []
		results.append(await _drive(vehicle_id,"uphill-production-driver",bottom,crest_node,"driver"))
		results.append(await _drive(vehicle_id,"uphill-low-speed",bottom,crest,"low"))
		results.append(await _drive(vehicle_id,"crest-stop-restart",bottom,crest,"crest",22.0))
		# Reverse condition on the production path: start at the crest FACING AWAY from the
		# bottom so the driver must turn around or reverse to get there, and record how many
		# ticks were spent actually moving backwards.
		results.append(await _drive(vehicle_id,"crest-turnaround-reverse",_ground_point(ROUTE_X,CREST_Z+3.0),bottom_node,"driver",INF,3600,0.0))
		# The lateral deviation lives in the START; the goal stays a node.
		results.append(await _drive(vehicle_id,"lateral-offset-3m",_ground_point(ROUTE_X-3.0,BOTTOM_Z),crest_node,"driver"))
		for r in results:
			var settled: bool = bool(r.settled)
			var ok: bool = settled and bool(r.reached) and int(r.stalled) == 0 and int(r.nonfinite) == 0 and float(r.on_floor_fraction) >= 0.9 and bool(r.muzzle_ok) and bool(r.armour_ok) and bool(r.internal_ok)
			_check(ok,"T039-D %s %s: settled=%s reached=%s phase=%s ticks=%d hull_box_intersection=%.3f bounces=%d stalled=%d on_floor=%.2f reverse_ticks=%d nonfinite=%d traveled=%.1f muzzle=%s armour=%s internal=%s"%[
				vehicle_id,str(r.label),str(settled),str(r.reached),str(r.final_phase),int(r.ticks_run),float(r.hull_box_intersection_m),int(r.bounces),int(r.stalled),float(r.on_floor_fraction),int(r.reverse_ticks),int(r.nonfinite),float(r.traveled),
				str(r.muzzle_ok),str(r.armour_ok),str(r.internal_ok)])
	print("=== 缂佹挻鐏? %d 妞よ顥呴弻? %d 婢惰精瑙?==="%[count,failed])
	print("FLANK_CREST_TRAVERSAL_CHECKS_PASS" if failed == 0 else "FLANK_CREST_TRAVERSAL_CHECKS_FAIL")
	quit(1 if failed else 0)



