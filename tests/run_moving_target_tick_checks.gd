extends SceneTree
class TickStage extends Node:
	var harness: SceneTree
	var input_stage := false
	func _physics_process(_delta: float) -> void:
		if input_stage: harness.submit_tick()
		else: harness.capture_tick()
var scene: AICombatRange
var tick := 0
var active := false
var rows: Array = []
var contacts: Array = []
var terminals: Array = []
var accepted := true
var target_start := Vector3.ZERO
func _initialize() -> void: call_deferred("run")
func xyz(v: Vector3) -> Array: return [v.x,v.y,v.z]
func run() -> void:
	scene=AICombatRange.new(); root.add_child(scene); current_scene=scene
	scene.source_actor.set_controller(null); scene.target_actor.set_controller(null)
	for i in 30: await physics_frame
	scene.source_actor.tank.global_transform=Transform3D(Basis.IDENTITY,Vector3(18,0.03,6))
	scene.target_actor.tank.global_transform=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(8,0.03,-26))
	for i in 5: await physics_frame
	target_start=scene.target_actor.tank.global_position
	scene.source_actor.turret.rotation.y=0.5
	scene.projectiles.projectile_contact.connect(func(event: Dictionary) -> void:
		if event.get("entity_id","")!="B": return
		contacts.append({"tick":tick,"projectile":event.get("projectile_id",-1),"result":event.get("result",""),"point":xyz(event.get("point_world",Vector3.ZERO)),"target_speed":scene.target_actor.tank.velocity.length()}))
	scene.projectiles.projectile_finished.connect(func(event: Dictionary) -> void:
		terminals.append({"tick":tick,"reason":event.get("reason",""),"target":event.get("target_id","")}))
	var before := TickStage.new(); before.harness=self; before.input_stage=true; before.process_physics_priority=-10; scene.add_child(before)
	var after := TickStage.new(); after.harness=self; after.process_physics_priority=200; scene.add_child(after)
	active=true
func submit_tick() -> void:
	if not active or tick>=360: return
	tick+=1
	if OS.get_cmdline_user_args().has("--stall") and tick in [60,180,300]: OS.delay_msec(100)
	var target := scene.target_actor
	var target_cmd := VehicleCommand.new(); target_cmd.throttle=0.2
	# The controlled input fixture uses observable exterior position/velocity, no internal weak-point data.
	var shooter := scene.source_actor
	var cmd := VehicleCommand.new(); cmd.has_aim_point=true
	cmd.aim_world_point=AimSolver.solve(shooter.turret.muzzle.global_position,{"aim_point":target.tank.global_position+Vector3.UP*1.2,"velocity":target.tank.velocity},shooter.gunner.shell,shooter.tank.velocity,Vector2.ZERO)
	cmd.fire_requested=tick in [90,240]
	accepted=accepted and shooter.submit_command_envelope(VehicleCommandCodec.encode(cmd,shooter,tick,Engine.get_physics_frames())).ok
	if not target.state.destroyed:
		accepted=accepted and target.submit_command_envelope(VehicleCommandCodec.encode(target_cmd,target,tick,Engine.get_physics_frames())).ok
func capture_tick() -> void:
	if not active or tick==0: return
	var shooter := scene.source_actor
	var target := scene.target_actor
	rows.append({"tick":tick,"target_position":xyz(target.tank.global_position),"target_velocity":xyz(target.tank.velocity),"yaw":shooter.turret.rotation.y,"pitch":shooter.turret.barrel_pivot.rotation.x,"shots":shooter.gunner.shots_fired,"cooldown":shooter.gunner.cooldown_left,"rounds":shooter.gunner.rounds_remaining,"destroyed":target.state.destroyed})
	if tick==360:
		active=false
		call_deferred("finish")
func finish() -> void:
	var hit_shots := {}
	var moving_hit := false
	for contact in contacts:
		hit_shots[contact.projectile]=true
		moving_hit=moving_hit or contact.target_speed>0.1
	var shared: bool = scene.source_actor.simulation_driver.get_ref()==scene.vehicle_simulation and scene.target_actor.simulation_driver.get_ref()==scene.vehicle_simulation
	var ok: bool = shared and accepted and rows.size()==360 and scene.source_actor.gunner.shots_fired==2 and terminals.size()==2 and hit_shots.size()==2 and moving_hit and scene.target_actor.tank.global_position.distance_to(target_start)>1.0
	var output := {"ok":ok,"display":DisplayServer.get_name(),"render_cap":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"shared_driver":shared,"accepted":accepted,"rows":rows,"contacts":contacts,"terminals":terminals}
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size()>0 and args[0]!="--stall" else "res://logs/wt002-moving-probe.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: ok=false
	else: file.store_string(JSON.stringify(output)); file.close()
	print("[moving target] contacts=",contacts," terminals=",terminals," shots=",scene.source_actor.gunner.shots_fired)
	print("MOVING_TARGET_TICK_CHECKS_PASS" if ok else "MOVING_TARGET_TICK_CHECKS_FAIL")
	scene.free(); await process_frame
	quit(0 if ok else 1)
