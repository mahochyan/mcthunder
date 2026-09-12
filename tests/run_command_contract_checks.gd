extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	var scene := AICombatRange.new()
	root.add_child(scene); current_scene = scene
	var actor := scene.source_actor
	actor.set_controller(null); scene.target_actor.set_controller(null)
	await frames(30)
	var cmd := VehicleCommand.new(); cmd.fire_requested=true; cmd.throttle=0.5
	var packet := VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames())
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(packet))
	check(VehicleCommandCodec.decode(roundtrip).ok,"JSON roundtrip preserves strict command types")
	var start := actor.tank.global_position
	var consumed := {"peak_speed":0.0,"throttle":0.0,"fire":false}
	actor.command_observer=func(current: VehicleActor, input: VehicleCommand) -> void:
		consumed.peak_speed=maxf(consumed.peak_speed,current.tank.forward_speed)
		if input.fire_requested:
			consumed.throttle=input.throttle; consumed.fire=true
	check(actor.submit_command_envelope(roundtrip).ok,"versioned input enters real actor mailbox")
	check(not actor.submit_command_envelope(roundtrip).ok,"duplicate sequence is rejected before consumption")
	roundtrip.command.throttle=-1; roundtrip.command.fire_requested=false
	await frames(2)
	actor.command_observer=Callable()
	# One input pulse can coast back to zero by the second tick. Observe its actual
	# positive speed before that tick, rather than requiring persistent throttle.
	check(actor.gunner.shots_fired==1 and consumed.peak_speed>0 and consumed.throttle==0.5 and consumed.fire,"copied command drives and fires once despite caller mutation")
	check(actor.tank.global_position.distance_to(start)<1,"accepted input advances normally without teleporting")
	var invalids: Array = []
	for key in ["version","life_id","generation","control_epoch"]:
		var bad := VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames()); bad[key]+=1; invalids.append(bad)
	for tick in [Engine.get_physics_frames()+1,Engine.get_physics_frames()-GameConfig.COMMAND_MAX_AGE_TICKS-1]:
		invalids.append(VehicleCommandCodec.encode(cmd,actor,2,tick))
	var bad := VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames()); bad.command.throttle=2; invalids.append(bad)
	bad=VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames()); bad.command.fire_requested=1; invalids.append(bad)
	bad=VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames()); bad.command.aim_world_point=[0,NAN,0]; invalids.append(bad)
	bad=VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames()); bad.command["declare_kill"]="B"; invalids.append(bad)
	for value in invalids: check(not actor.submit_command_envelope(value).ok,"malformed/stale command rejected: "+str(value))
	check(actor._last_input_sequence==1,"rejected higher sequence cannot poison subsequent valid input")
	cmd.fire_requested=false
	check(actor.submit_command_envelope(VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames())).ok,"valid next sequence remains accepted")
	for transition in ["pause","reset","detach","clear"]:
		var old := VehicleCommandCodec.encode(cmd,actor,100,Engine.get_physics_frames())
		match transition:
			"pause": actor.pause_block(true); actor.pause_block(false)
			"reset": actor.reset_vehicle()
			"detach": actor.set_controller(null)
			"clear": actor.clear_commands()
		check(not actor.submit_command_envelope(old).ok,transition+" invalidates earlier control epoch")
	# A valid envelope can age while this actor is temporarily not processing.
	actor.reset_vehicle(); actor.set_physics_process(false)
	var shots_before := actor.gunner.shots_fired
	cmd.fire_requested=true; cmd.throttle=0
	check(actor.submit_command_envelope(VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames())).ok,"valid fire can be staged before suspension")
	await frames(GameConfig.COMMAND_MAX_AGE_TICKS+3)
	actor.set_physics_process(true)
	await frames(3)
	check(actor.gunner.shots_fired==shots_before,"staged fire expires before resumed physical consumption")
	# Production observer may change focus/control without changing generation.
	actor.command_observer = func(_a: VehicleActor, _c: VehicleCommand) -> void: actor.clear_commands()
	check(actor.submit_command(cmd),"observer race fixture enters original command path")
	await frames(3)
	check(actor.gunner.shots_fired==shots_before,"observer control-epoch change cancels already-consumed fire")
	actor.command_observer = Callable()
	check(actor.submit_command_envelope(VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames())).ok,"fresh epoch accepts a new legitimate command")
	await frames(3)
	check(actor.gunner.shots_fired==shots_before+1,"fresh input still fires after invalidation")
	await frames(150)
	actor.set_physics_process(false)
	var before_merge := actor.gunner.shots_fired
	check(actor.submit_command_envelope(VehicleCommandCodec.encode(cmd,actor,2,Engine.get_physics_frames())).ok,"old fire staged for merge-expiration case")
	await frames(GameConfig.COMMAND_MAX_AGE_TICKS+3)
	cmd.fire_requested=false; cmd.throttle=0.5
	check(actor.submit_command_envelope(VehicleCommandCodec.encode(cmd,actor,3,Engine.get_physics_frames())).ok,"fresh driving replaces expired pending input")
	actor.set_physics_process(true)
	await frames(1)
	check(actor.gunner.shots_fired==before_merge and actor.tank.forward_speed>0,"fresh drive survives without inheriting expired fire edge")
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("COMMAND_CONTRACT_CHECKS_PASS" if failed==0 else "COMMAND_CONTRACT_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
