extends SceneTree
## WT-039-D: production-vehicle traversal checks at the x≈-120 flank crest.
##
## Separate identity and version from the rigid-envelope diagnostic: this suite keeps the old
## T018-03/T018-03b results untouched (they stay failing) and answers a different question -
## can an ACTUAL production vehicle, using production driving, movement collision, hull pose,
## running gear and suspension, traverse this crest under the listed conditions?
##
## Assertion prefix: T039-D. Vehicles without a production combat/drive configuration are
## reported as NOT_VERIFIED rather than scaled up to pretend an 8.5 m envelope passed.
const ROUTE_X := -120.0
const BOTTOM_Z := 60.0
const CREST_Z := 0.0
const STEP := 1.0/60.0
const BOUNCE_LIMIT := 3.0
const PENETRATION_TOLERANCE := 0.02
## The monitors below are NOT yet validated: on the 4 m faceted terrain the flat box bottom
## is intersected by the ground on ordinary road surfaces, so the penetration counter fires
## on flat ground too and the scenario results cannot be cited as product evidence. Until a
## fixture validation pass proves each monitor (flat-ground control run, known-good route,
## tolerance calibration) this suite refuses to report a verdict.
const FIXTURE_VALIDATED := false
const INCONCLUSIVE_EXIT := 2
var count := 0
var failed := 0
var world: Node3D
var map
var defs: VehicleDefs

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

func _penetrating(actor: VehicleActor) -> bool:
	var space := world.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = actor.definition.drive_collision_size - Vector3(0,PENETRATION_TOLERANCE,0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = Transform3D(actor.tank.global_basis,actor.tank.global_position+actor.definition.drive_collision_center)
	params.collision_mask = GameConfig.LAYER_WORLD
	var hits := space.intersect_shape(params,4)
	for hit in hits:
		if str(hit.collider.name) == "VillageTerrain": return true
	return false

## Drive one scenario with per-tick production monitoring.
func _scenario(vehicle_id: String, label: String, start: Vector3, goal: Vector3, mode: String, hold_z: float = INF) -> Dictionary:
	var actor := _spawn(vehicle_id,start)
	var nav := DriveNavigator.new(); nav.configure(map.graph)
	var driver := AIPathDriver.new()
	var fixed: FixedThrottle = null
	if mode == "driver":
		actor.add_child(driver); driver.configure(actor,nav); actor.set_controller(driver)
		driver.set_goal(goal)
	else:
		fixed = FixedThrottle.new()
		if mode == "low": fixed.throttle = 0.25
		elif mode == "crest": fixed.throttle = 0.35
		elif mode == "reverse": fixed.throttle = -0.35
		actor.add_child(fixed); actor.set_controller(fixed)
	await _frames()
	var penetrations := 0
	var bounces := 0
	var stalls := 0
	var nonfinite := 0
	var held := false
	var released := false
	var reached := false
	var ticks := 0
	var previous := actor.tank.global_position
	for i in 6000:
		ticks = i
		if fixed != null:
			var to_goal := goal-actor.tank.global_position
			var bearing := 0.0
			if to_goal.length() > 0.5:
				bearing = rad_to_deg((-actor.tank.global_basis.z).signed_angle_to(to_goal.normalized(),Vector3.UP))
			fixed.steer = clampf(bearing/30.0,-1.0,1.0) if mode != "reverse" else clampf(-bearing/30.0,-1.0,1.0)
			if mode == "crest" and not released:
				if actor.tank.global_position.z <= hold_z and not held:
					fixed.hold = true; held = true
				elif held and i > 120:
					fixed.hold = false; released = true
		else:
			if driver.phase in ["arrived","failed","unreachable"]: reached = driver.phase == "arrived"; break
		actor.advance_standalone_tick(STEP)
		var pos: Vector3 = actor.tank.global_position
		if not pos.is_finite(): nonfinite += 1
		if absf(actor.tank.get_real_velocity().y) > BOUNCE_LIMIT: bounces += 1
		if _penetrating(actor): penetrations += 1
		var commanded := 0.0
		if fixed != null: commanded = absf(fixed.throttle)
		elif driver.last_command != null: commanded = absf(driver.last_command.throttle)
		if commanded > 0.2 and absf(actor.tank.forward_speed) < 0.2: stalls += 1
		previous = pos
		if mode != "driver" and pos.distance_to(goal) < 3.0:
			reached = true; break
	var muzzle_ok: bool = actor.turret != null and actor.turret.muzzle != null and actor.turret.muzzle.global_position.is_finite()
	var armour_ok: bool = actor.definition != null and actor.tank.defs != null
	var internal_ok: bool = actor.state.module_states.size() > 0
	var result := {"reached":reached,"ticks":ticks,"penetrations":penetrations,"bounces":bounces,
		"stalls":stalls,"nonfinite":nonfinite,"muzzle_ok":muzzle_ok,"armour_ok":armour_ok,"internal_ok":internal_ok,
		"end":actor.tank.global_position}
	actor.free()
	await _frames(2)
	var ok: bool = reached and penetrations == 0 and bounces == 0 and nonfinite == 0 and (stalls < 120) and muzzle_ok and armour_ok and internal_ok
	_check(ok,"T039-D %s %s: reached=%s ticks=%d penetration=%d bounce=%d stall=%d nonfinite=%d muzzle=%s armour=%s internal=%s"%[
		vehicle_id,label,str(reached),ticks,penetrations,bounces,stalls,nonfinite,str(muzzle_ok),str(armour_ok),str(internal_ok)])
	return result

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
	if FIXTURE_VALIDATED:
		for vehicle_id in VehicleCatalog.IDS:
			await _scenario(vehicle_id,"uphill-production-driver",bottom,crest,"driver")
			await _scenario(vehicle_id,"uphill-low-speed",bottom,crest,"low")
			await _scenario(vehicle_id,"crest-stop-restart",bottom,crest,"crest",22.0)
			await _scenario(vehicle_id,"downhill-reverse",crest+Vector3(0,0,5),bottom,"reverse")
			await _scenario(vehicle_id,"lateral-offset-3m",bottom+Vector3(3,0,0),crest+Vector3(3,0,0),"driver")
	else:
		print("[T039-D] scenario battery skipped: fixture monitors are not validated yet")
	# Vehicles without a production configuration are reported, never scaled to fit.
	for pilot in ["ussr_t_80b","germ_leopard_2a4"]:
		var definition: VehicleDefinition = defs.get_vehicle(pilot)
		_check(definition == null,"T039-D NOT_VERIFIED %s: no production combat/drive configuration in this build (definition=%s) - scaled surrogates are not accepted"%[pilot,str(definition != null)])
	if not FIXTURE_VALIDATED:
		print("[T039-D] FIXTURE_NOT_VALIDATED: monitors (penetration/bounce/stall) have not been calibrated against a flat-ground control and a known-good route, so this run is INCONCLUSIVE and must not be cited as a product verdict.")
		print("=== 结果: %d 项检查, %d 失败（场景判定不计入） ==="%[count,failed])
		print("FLANK_CREST_TRAVERSAL_FIXTURE_NOT_VALIDATED")
		quit(INCONCLUSIVE_EXIT)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("FLANK_CREST_TRAVERSAL_CHECKS_PASS" if failed == 0 else "FLANK_CREST_TRAVERSAL_CHECKS_FAIL")
	quit(1 if failed else 0)
