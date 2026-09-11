extends SceneTree
class ObserverController extends Node:
	var cam_rig: CameraRig
	var gunner: Gunner
	var harness: SceneTree
	var entity_id: String
	func is_local_controller() -> bool: return false
	func reset_pending() -> void: pass
	func poll() -> VehicleCommand:
		return harness.observe_poll(entity_id)
class BoundaryProbe extends Node:
	var harness: SceneTree
	var before := false
	func _physics_process(_delta: float) -> void:
		if before: harness.capture_start()
		else: harness.capture_end()
var count := 0
var failed := 0
var scene: TeamRange
var armed := false
var start_positions := {}
var end_positions := {}
var observations := {}
var aim_observations := {}
var aim_turrets := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func positions() -> Dictionary:
	var result := {}
	for actor in scene.combat_actors(): result[actor.entity_id]=actor.tank.global_position
	return result
func capture_start() -> void:
	if armed:
		if OS.get_cmdline_user_args().has("--stall"): OS.delay_msec(100)
		start_positions=positions()
func capture_end() -> void:
	if armed:
		end_positions=positions()
		armed=false
func observe_poll(id: String) -> VehicleCommand:
	if armed: observations[id]=positions()
	var cmd := VehicleCommand.new(); cmd.throttle=1; cmd.clear_aim=true
	return cmd
func observe_aim(id: String) -> Array:
	if armed:
		aim_observations[id]=positions()
		var angles := {}
		for actor in scene.combat_actors(): angles[actor.entity_id]=actor.turret.rotation.y
		aim_turrets[id]=angles
	return scene.query_snapshots()
func run() -> void:
	print("[runtime] display=",DisplayServer.get_name()," render_cap=",Engine.max_fps," physics_hz=",Engine.physics_ticks_per_second)
	scene=TeamRange.new(); root.add_child(scene); current_scene=scene
	await frames(190)
	for actor in scene.combat_actors():
		var controller := ObserverController.new()
		controller.harness=self; controller.entity_id=actor.entity_id
		actor.add_child(controller); actor.set_controller(controller)
		actor.cam_rig.snapshot_provider=observe_aim.bind(actor.entity_id)
		actor.cam_rig.aim_yaw=1.0
		actor.tank.forward_speed=3.0 # Explicit motion fixture; movement itself uses real drive code.
	var first := BoundaryProbe.new(); first.harness=self; first.before=true; first.process_physics_priority=-10; scene.add_child(first)
	var last := BoundaryProbe.new(); last.harness=self; last.process_physics_priority=50; scene.add_child(last)
	if OS.get_cmdline_user_args().has("--legacy-order"):
		scene.vehicle_simulation.set_physics_process(false)
		for actor in scene.combat_actors(): actor.simulation_driver=null
	armed=true; await frames(2)
	var polls_ok := observations.size()==8
	for observation in observations.values(): polls_ok=polls_ok and observation==start_positions
	check(polls_ok,"all eight actual controller polls observe the same pre-movement world")
	var aims_ok := aim_observations.size()==8
	for observation in aim_observations.values(): aims_ok=aims_ok and observation==end_positions
	check(aims_ok,"all eight actual camera aim queries observe all vehicles after movement")
	var turrets_ok := aim_turrets.size()==8
	for angles in aim_turrets.values(): turrets_ok=turrets_ok and angles==aim_turrets.values()[0]
	check(turrets_ok,"aim queries share one turret geometry stage before any mechanism advances")
	var moved := true
	for id in start_positions: moved=moved and start_positions[id].distance_to(end_positions[id])>0.001
	check(moved,"every observed vehicle actually moves during the sampled physical step")
	for actor in scene.combat_actors(): actor.set_controller(null)
	var a := scene.actor
	var b := scene.director.state.actor_for("B")
	var shots := a.gunner.shots_fired
	b.command_observer=func(_actor: VehicleActor,_cmd: VehicleCommand) -> void: a.clear_commands()
	var fire := VehicleCommand.new(); fire.fire_requested=true
	a.submit_command(fire); await frames(1)
	check(a.gunner.shots_fired==shots,"later command observer invalidates earlier actor work before firing")
	b.command_observer=Callable(scene.director,"observe_command")
	a.submit_command(fire); await frames(1)
	check(a.gunner.shots_fired==shots+1,"fresh command fires once after cross-actor invalidation")
	a.set_physics_process(false)
	var cooldown := a.gunner.cooldown_left
	var position := a.tank.global_position
	await frames(4)
	check(a.gunner.cooldown_left==cooldown and a.tank.global_position==position,"explicitly disabled actor is not advanced by world driver")
	var removed := scene.director.state.actor_for("B2")
	var removal_ref: WeakRef = weakref(removed)
	b.tank.forward_speed=3.0
	var survivor_position := b.tank.global_position
	b.command_observer=func(_actor: VehicleActor,_cmd: VehicleCommand) -> void:
		var target: VehicleActor=removal_ref.get_ref()
		if is_instance_valid(target): target.free()
	await frames(1)
	check(not is_instance_valid(removed) and b.tank.global_position.distance_to(survivor_position)>0.001,"entity removed by another observer is skipped without aborting survivors' movement")
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("WORLD_VEHICLE_PHASE_CHECKS_PASS" if failed==0 else "WORLD_VEHICLE_PHASE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
