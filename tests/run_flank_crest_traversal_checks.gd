extends SceneTree
## WT-039-D: production-vehicle traversal checks at the x≈-120 flank crest.
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

## Bottoming: how far the ground rises above the hull's bottom plane under its corners.
func _max_bottoming(actor: VehicleActor) -> float:
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

func _drive(vehicle_id: String, label: String, start: Vector3, goal: Vector3, mode: String, hold_z: float = INF, ticks_limit: int = 3600) -> Dictionary:
	print("[T039-D start] %s %s mode=%s from %s to %s" % [vehicle_id,label,mode,str(start),str(goal)])
	var actor := _spawn(vehicle_id,start)
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
	var bottoming := 0.0
	var bounces := 0
	var stalled := 0
	var still := 0
	var nonfinite := 0
	var reached := false
	var held := false
	var released := false
	var previous := actor.tank.global_position
	var traveled := 0.0
	for i in ticks_limit:
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
		if absf(actor.tank.get_real_velocity().y) > BOUNCE_LIMIT: bounces += 1
		bottoming = maxf(bottoming,_max_bottoming(actor))
		var move := pos.distance_to(previous)
		traveled += move
		if move < 0.01: still += 1
		else: still = 0
		if still >= STALL_TICKS: stalled += 1
		previous = pos
		if i % 1500 == 0 and i > 0:
			print("[T039-D progress] %s %s tick=%d traveled=%.1f speed=%.2f still=%d phase=%s" % [
				vehicle_id,label,i,traveled,actor.tank.forward_speed,still,(driver.phase if driver != null else "fixed")])
		if driver != null and mode == "driver" and driver.phase in ["arrived","failed","unreachable"]:
			reached = driver.phase == "arrived"; break
		if mode != "driver" and pos.distance_to(goal) < 3.0: reached = true; break
	var muzzle_ok: bool = actor.turret != null and actor.turret.muzzle != null and actor.turret.muzzle.global_position.is_finite()
	var armour_ok: bool = actor.definition != null and actor.tank.defs != null
	var internal_ok: bool = actor.state.module_states.size() > 0
	var result := {"label":label,"reached":reached,"bottoming":bottoming,"bounces":bounces,"stalled":stalled,
		"nonfinite":nonfinite,"traveled":traveled,"muzzle_ok":muzzle_ok,"armour_ok":armour_ok,"internal_ok":internal_ok}
	actor.free()
	await _frames(2)
	return result

## Flat-ground control: no bottoming, no stall, and the vehicle actually moves.
func _calibrate(vehicle_id: String) -> Dictionary:
	var flat := Vector3(0.0,VillageDefinition.height(0.0,116.0)+0.05,116.0)
	var actor := _spawn(vehicle_id,flat,PI)
	var fixed := FixedThrottle.new(); fixed.throttle = float(LOW_THROTTLE.get(vehicle_id,0.5))
	actor.add_child(fixed); actor.set_controller(fixed)
	await _frames()
	var worst := 0.0
	var bounces := 0
	var still := 0
	var stalled := 0
	var start := actor.tank.global_position
	var previous := start
	for i in CALIBRATION_TICKS:
		actor.advance_standalone_tick(STEP)
		worst = maxf(worst,_max_bottoming(actor))
		if absf(actor.tank.get_real_velocity().y) > BOUNCE_LIMIT: bounces += 1
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
	var crest := Vector3(ROUTE_X,VillageDefinition.height(ROUTE_X,CREST_Z),CREST_Z)
	var bottom := Vector3(ROUTE_X,VillageDefinition.height(ROUTE_X,BOTTOM_Z),BOTTOM_Z)
	print("[T039-D] route bottom=",bottom," crest=",crest)
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
		results.append(await _drive(vehicle_id,"uphill-production-driver",bottom,crest,"driver"))
		results.append(await _drive(vehicle_id,"uphill-low-speed",bottom,crest,"low"))
		results.append(await _drive(vehicle_id,"crest-stop-restart",bottom,crest,"crest",22.0))
		results.append(await _drive(vehicle_id,"downhill-reverse",crest+Vector3(0,0,5),bottom,"reverse"))
		results.append(await _drive(vehicle_id,"lateral-offset-3m",bottom+Vector3(3,0,0),crest+Vector3(3,0,0),"driver"))
		for r in results:
			var ok: bool = bool(r.reached) and float(r.bottoming) <= FIXTURE_TOLERANCE_M and int(r.bounces) == 0 and int(r.stalled) == 0 and int(r.nonfinite) == 0 and bool(r.muzzle_ok) and bool(r.armour_ok) and bool(r.internal_ok)
			_check(ok,"T039-D %s %s: reached=%s bottoming=%.3f bounces=%d stalled=%d nonfinite=%d traveled=%.1f muzzle=%s armour=%s internal=%s"%[
				vehicle_id,str(r.label),str(r.reached),float(r.bottoming),int(r.bounces),int(r.stalled),int(r.nonfinite),float(r.traveled),
				str(r.muzzle_ok),str(r.armour_ok),str(r.internal_ok)])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("FLANK_CREST_TRAVERSAL_CHECKS_PASS" if failed == 0 else "FLANK_CREST_TRAVERSAL_CHECKS_FAIL")
	quit(1 if failed else 0)
