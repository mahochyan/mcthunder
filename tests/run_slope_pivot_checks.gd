extends SceneTree
## WT-039-E: neutral-steer pivot must work on sloped ground, not only on the flat.
##
## Evidence (WT-039-D): driving the drive model directly, or through the production actor path,
## turns the hull -176 degrees in 240 ticks on flat ground but only -20 degrees at the flank
## crest (11.6 degrees of slope) and -16.5 degrees further up (12.5 degrees), with the rotation
## decaying to zero after the first second while yaw_rate stays at its full -0.768 rad/s and
## every other input looks healthy (grounded, both supports 1.00, slope_blocked false, pitch 0).
## That suppression is what deadlocks the AI driver, which requests a pivot whenever the
## heading error exceeds 18 degrees.
##
## The flat case is the control: it proves the fixture, the command path and the drive model
## are all capable of the rotation, so a slope failure is a slope-specific defect.
const TICKS := 240
const FLAT_MIN_DEG := 150.0
const SLOPE_MIN_DEG := 150.0
const SECOND_HALF_MIN_DEG := 40.0
const STEP := 1.0/60.0
var count := 0
var failed := 0
var world: Node3D
var defs: VehicleDefs

class Pivot extends Node:
	var cam_rig: Node = null
	var gunner: Node = null
	func poll() -> VehicleCommand:
		var cmd := VehicleCommand.new()
		cmd.throttle = 0.0
		cmd.steer = -1.0
		return cmd
	func is_local_controller() -> bool: return false

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n:int=3)->void:
	for i in n: await physics_frame
func _heading(a: VehicleActor) -> float:
	var f := -a.tank.global_basis.z
	return rad_to_deg(atan2(f.x,f.z))

func _pivot_at(x: float, z: float, label: String, minimum: float) -> void:
	var actor := VehicleActor.new()
	world.add_child(actor)
	actor.setup(defs,"us_m4a3_75w_vvss_1944","slope_pivot",1,
		Transform3D(Basis(Vector3.UP,PI),Vector3(x,VillageDefinition.height(x,z)+0.5,z)),4,null)
	actor.set_physics_process(false)
	actor.gunner.aim_preview_enabled = false
	actor.cam_rig.set_process(false); actor.cam_rig.set_physics_process(false)
	for i in 200: actor.advance_standalone_tick(STEP)
	var control := Pivot.new()
	actor.add_child(control); actor.set_controller(control)
	await _frames(2)
	var slope := float(actor.tank.ground_state.slope_deg)
	var start := _heading(actor)
	var half := start
	for i in TICKS:
		actor.advance_standalone_tick(STEP)
		if i == TICKS/2: half = _heading(actor)
	var total := wrapf(_heading(actor)-start,-180.0,180.0)
	var second := wrapf(_heading(actor)-half,-180.0,180.0)
	_check(absf(total) >= minimum,"T039-E %s (slope %.1f deg): pivot turns %.1f deg in %d ticks (need >= %.0f), second half %.1f deg (need >= %.0f)"%[
		label,slope,total,TICKS,minimum,second,SECOND_HALF_MIN_DEG])
	actor.free()
	await _frames(2)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var watchdog := create_timer(300.0)
	watchdog.timeout.connect(func() -> void:
		print("[T039-E] WATCHDOG timeout")
		quit(3))
	defs = VehicleDefs.new(); defs.load_defaults()
	VehicleCatalog.new().load_all(defs)
	var map := VillageDefinition.create()
	world = Node3D.new(); root.add_child(world); current_scene = world
	VillageWorld.build(world,map,true)
	await _frames(8)
	await _pivot_at(-120.0,60.0,"flat control",FLAT_MIN_DEG)
	await _pivot_at(-121.6,29.1,"flank crest",SLOPE_MIN_DEG)
	await _pivot_at(-120.0,20.0,"upper slope",SLOPE_MIN_DEG)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("SLOPE_PIVOT_CHECKS_PASS" if failed == 0 else "SLOPE_PIVOT_CHECKS_FAIL")
	quit(1 if failed else 0)
