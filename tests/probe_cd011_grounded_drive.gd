extends SceneTree
## CD11 open question, settled in one measurement: does a grounded hull accelerate through its OWN production command path?
##
## The collision case could not reverse out, and the trace said the reason is that the grounded branch of the drive never
## hands the throttle to the powertrain. That reading contradicts the project note that the tank is drivable, so it is not
## assumed in either direction: this probe runs the production entry (VehicleActor.advance_simulation_drive, the same call the
## game makes) against a real actor from the production catalog, and prints the speed trace. Nothing here writes forward speed.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func _run() -> void:
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	print("[settle] defs=%s load_all=%s load_engineering=%s" % [
		str(defs.load_defaults().ok),str(catalog.load_all(defs).ok),str(catalog.load_engineering(defs).ok)])
	var vid := "ussr_t_80b"
	var actor := VehicleActor.new(); root.add_child(actor)
	var admitted: Dictionary = actor.setup(defs,vid,"settle",1,Transform3D.IDENTITY,2,null)
	print("[settle] setup ok=%s errors=%s" % [str(admitted.get("ok",false)),str(admitted.get("errors",[]))])
	if not admitted.ok: quit(1); return
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	# A FLOOR, so the hull is actually grounded: the previous reading was floating with no support at all, and the powertrain
	# scales its traction by the support the ground probe reports, which was zero.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new(); floor_box.size = Vector3(60.0,1.0,60.0)
	floor_shape.shape = floor_box; floor_body.add_child(floor_shape)
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	floor_body.global_position = Vector3(0,-0.5,0)
	root.add_child(floor_body)
	await process_frame
	await process_frame
	print("[settle] grounded=%s forward_speed=%.4f" % [str(actor.tank.is_on_floor()),actor.tank.forward_speed])

	# The production step shape, taken from the actor own validator rather than guessed.
	var step := {"cmd":null,"throttle":1.0,"steer":0.0,"delta":1.0/60.0,"generation":actor.state.generation,"epoch":actor.control_epoch}
	print("[settle] simulation_step_valid=%s" % str(actor.simulation_step_valid(step)))
	print("[settle] provider valid=%s" % str(actor.tank.capabilities_provider.is_valid()))
	var cd011_caps: Dictionary = VehicleCapabilities.compute(actor.state)
	print("[settle] computed caps drive=%s steer=%s reasons=%s" % [str(cd011_caps.get("drive")),str(cd011_caps.get("steer")),str(cd011_caps.get("reasons"))])
	if actor.tank.capabilities_provider.is_valid():
		var provider_caps: Dictionary = actor.tank.capabilities_provider.call()
		print("[settle] provider caps drive=%s steer=%s" % [str(provider_caps.get("drive")),str(provider_caps.get("steer"))])
	else:
		print("[settle] NO PROVIDER INJECTED: apply_drive will force throttle to zero because caps is empty")
	for i in 120:
		actor.advance_simulation_drive(step,1.0/60.0)
		await physics_frame
		if i == 0 or i == 60: print("[settle] inner valid=%s drive_calls=%d support=%.3f grounded=%s" % [str(actor.simulation_step_valid(step)),actor.tank.drive_call_count(),float(actor.tank.ground_state.get("traction_support",-1.0)),str(actor.tank.is_on_floor())])
		if i % 30 == 0:
			print("[settle] t=%3d speed=%.4f on_floor=%s velocity=%s traction=%.4f" % [
				i,actor.tank.forward_speed,str(actor.tank.is_on_floor()),str(actor.tank.velocity),actor.tank.powertrain.traction_acceleration])
	var after_throttle := actor.tank.forward_speed

	# And the same actor stepped by the powertrain DIRECTLY, to show what the missing call would have produced.
	var direct := actor.tank.powertrain.step(0.0,1.0,0.0,true,1.0/60.0,actor.definition,0.0,1.0)
	print("[settle] after 2 s: speed=%.4f ; drive_calls=%d" % [after_throttle,actor.tank.drive_call_count()])
	print("[settle] the powertrain, called directly with the same throttle for one step, returns %.4f" % direct)
	check(after_throttle > 0.01 or direct > 0.01,"settle one of the two readings produced motion")
	if after_throttle <= 0.01:
		print("[settle] CONFIRMED: the production command path left a grounded hull at rest, so the grounded branch does not hand the throttle to the powertrain, while the powertrain itself returns %.4f for the same throttle." % direct)
	else:
		print("[settle] REFUTED: the production command path does accelerate a grounded hull, so the throttle reaches the powertrain through a path this probe found.")
	actor.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD11_SETTLE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
