extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var args := OS.get_cmdline_user_args()
	var scene := AICombatRange.new()
	root.add_child(scene); current_scene = scene
	scene.source_actor.set_controller(null)
	scene.target_actor.set_controller(null)
	var actor := scene.source_actor
	var rows: Array = []
	var hits: Array = []
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void:
		hits.append({"reason":record.get("reason",""),"target":record.get("target_id","")}))
	for i in 30: await physics_frame
	var aim := scene.target_actor.tank.global_position+Vector3.UP*1.2
	# Start to one side, then track exactly the same fixed-tick world-space order.
	actor.turret.rotation.y = 0.5
	for tick in 360:
		if args.has("--stall") and tick in [60,180,300]: OS.delay_msec(100)
		var cmd := VehicleCommand.new()
		cmd.has_aim_point = true; cmd.aim_world_point = aim
		if args.has("--local-intent"):
			# Replay view input before this tick, exercising the player's clear-aim
			# path rather than bypassing the camera with a scripted world target.
			actor.cam_rig.set_aim(0.4*sin(tick*0.015),0.05*cos(tick*0.01))
			cmd.has_aim_point = false; cmd.clear_aim = true
			cmd.aim_held = tick>=180
		cmd.fire_requested = tick in [90,240]
		actor.submit_command(cmd)
		await physics_frame
		rows.append([actor.turret.rotation.y,actor.turret.barrel_pivot.rotation.x,actor.gunner.shots_fired,actor.gunner.cooldown_left])
	var yaw := actor.turret.rotation.y
	actor.turret.set_aim_point(aim+Vector3.RIGHT*40)
	actor.turret._process(1.0)
	var render_safe := is_equal_approx(yaw,actor.turret.rotation.y)
	var path := args[0] if args.size()>0 else "res://logs/wt002-tick.json"
	var output := {"rows":rows,"shots":actor.gunner.shots_fired,"hits":hits,"render_does_not_turn":render_safe,"physics_hz":Engine.physics_ticks_per_second,"render_cap":Engine.max_fps}
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: scene.free(); quit(1); return
	file.store_string(JSON.stringify(output)); file.close()
	var ok := render_safe and actor.gunner.shots_fired==2 and hits.size()==2
	print("TURRET_TICK_CHECKS_PASS" if ok else "TURRET_TICK_CHECKS_FAIL")
	scene.free(); await process_frame
	quit(0 if ok else 1)
