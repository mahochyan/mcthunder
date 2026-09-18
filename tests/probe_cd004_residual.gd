extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD004-T04: the post-penetration fuze must fire on the RESIDUAL trajectory, not on the speed the
## shot had before it met the plate. The case text is explicit: fly NATURALLY to the fuze time after penetrating plates of
## different thickness, and do not push the burst further out on a constant pre-penetration speed.
##
## Four independent expectations, none needing a reference implementation:
##   (1) a thicker plate leaves a LOWER residual speed;
##   (2) a thicker plate therefore puts the burst CLOSER to the plate;
##   (3) the burst distance is strictly LESS than entry speed times the delay - the forbidden constant-speed prediction;
##   (4) with no gravity and a vacuum profile the flight between plate and fuze is exactly linear, so the burst distance is
##       residual speed times the delay.
## Expectations (3) and (4) together place the burst on the residual trajectory rather than an invented one.

const T04_SEED := 5120
const T04_DELAY := 0.002
const T04_SPEED := 900.0

func _t04_fire(actor: VehicleActor, world: Node3D, thickness: int, fuze: Dictionary, round_id: int) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = null
	for candidate in actor.gunner.shell_options:
		if candidate.effect_policy == "internal_burst":
			shell = candidate
			break
	if shell == null:
		manager.queue_free()
		print("[CD004 T04] no internal_burst shell is available: a penetration-delay fuze is only valid on that policy")
		return {"ok":false,"reason":"no_internal_burst_shell"}
	# Use the shell's OWN fuze policy, which is already valid, and only shorten the delay. Writing a fuze by hand was
	# refused with invalid_fuze_policy, correctly: the validator requires the internal_burst policy, penetration_delay mode,
	# positive arming thickness and delay, game_rule provenance and a stated reason.
	var delay_fuze: Dictionary = shell.fuze_policy.duplicate(true)
	delay_fuze["delay_s"] = T04_DELAY
	var layout := _single_plate_layout(thickness)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var spec := {"round_id":round_id,"shooter_id":"cd004_t04","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id,
		"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile.duplicate(true),
		"post_penetration_profile":shell.post_penetration_profile.duplicate(true),"fuze_policy":delay_fuze.duplicate(true),
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
		"position_world":Vector3(-3,0,0),"velocity_world":Vector3(T04_SPEED,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.05,"max_distance_m":20.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		print("[CD004 T04] launch refused: reason=%s (effect=%s fuze=%s armor_policy=%s max_age=%s)" % [
			str(spawned.get("reason","")),str(shell.effect_policy),JSON.stringify(fuze),
			str(shell.armor_policy),str(spec.get("max_age_s",""))])
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var residual_speed := -1.0
	var plate_x := 0.0
	var previous := projectile.position_world
	var terminal := ""
	for i in 40:
		if projectile.is_terminal(): break
		previous = projectile.position_world
		manager.advance_projectile(projectile,1.0/240.0,[snapshot],world.get_world_3d().direct_space_state)
		if residual_speed < 0.0 and len(projectile.contacts) > 0:
			residual_speed = projectile.velocity_world.length()
			plate_x = previous.x
	terminal = str(projectile.terminal_reason)
	var burst_x := projectile.position_world.x
	manager.queue_free()
	return {"ok":true,"residual_speed":residual_speed,"plate_x":plate_x,"burst_x":burst_x,
		"burst_distance":burst_x-plate_x,"terminal":terminal,"contacts":len(projectile.contacts)}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t04_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T04 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t04_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T04 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t04",1,Transform3D.IDENTITY,2,null).ok,"CD004 T04 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var fuze: Dictionary = {}
	for candidate in actor.gunner.shell_options:
		if candidate.effect_policy == "internal_burst":
			fuze = candidate.fuze_policy.duplicate(true)
			break
	if not fuze.is_empty():
		fuze["delay_s"] = T04_DELAY
	print("[CD004 T04] fuze=%s ; zero gravity and a vacuum profile, so the flight after the plate is exactly linear" % JSON.stringify(fuze))

	var thin := _t04_fire(actor,world,1,fuze,T04_SEED+1)
	var thick := _t04_fire(actor,world,3,fuze,T04_SEED+3)
	print("[CD004 T04] thin(1 strip): residual=%.3f burst_from_plate=%.5f terminal=%s contacts=%d" % [
		float(thin.get("residual_speed",-1.0)),float(thin.get("burst_distance",-1.0)),str(thin.get("terminal","")),int(thin.get("contacts",-1))])
	print("[CD004 T04] thick(3 strips): residual=%.3f burst_from_plate=%.5f terminal=%s contacts=%d" % [
		float(thick.get("residual_speed",-1.0)),float(thick.get("burst_distance",-1.0)),str(thick.get("terminal","")),int(thick.get("contacts",-1))])

	check(bool(thin.get("ok",false)) and bool(thick.get("ok",false)),"CD004 T04 both shots launch")
	check(float(thin.get("residual_speed",-1.0))>0.0 and float(thick.get("residual_speed",-1.0))>0.0,
		"CD004 T04 both shots leave a measurable residual speed (thin %.3f, thick %.3f)" % [float(thin.get("residual_speed",-1.0)),float(thick.get("residual_speed",-1.0))])
	check(float(thick.get("residual_speed",-1.0)) < float(thin.get("residual_speed",-1.0)),
		"CD004 T04 a thicker plate leaves a LOWER residual speed: %.3f (3 strips) < %.3f (1 strip)" % [float(thick.get("residual_speed",-1.0)),float(thin.get("residual_speed",-1.0))])
	check(float(thick.get("burst_distance",-1.0)) < float(thin.get("burst_distance",-1.0)),
		"CD004 T04 the thicker plate also puts the burst CLOSER to the plate: %.5f m < %.5f m" % [float(thick.get("burst_distance",-1.0)),float(thin.get("burst_distance",-1.0))])
	var constant_prediction: float = T04_SPEED*T04_DELAY
	check(float(thin.get("burst_distance",INF)) < constant_prediction and float(thick.get("burst_distance",INF)) < constant_prediction,
		"CD004 T04 neither burst is pushed out on the pre-penetration speed (%.5f m): thin %.5f, thick %.5f" % [constant_prediction,float(thin.get("burst_distance",-1.0)),float(thick.get("burst_distance",-1.0))])
	var expected_thin: float = float(thin.get("residual_speed",0.0))*T04_DELAY
	var expected_thick: float = float(thick.get("residual_speed",0.0))*T04_DELAY
	check(absf(float(thin.get("burst_distance",-1.0))-expected_thin)<=0.01,
		"CD004 T04 the burst lies on the residual trajectory: thin measured %.5f m vs residual*delay %.5f m" % [float(thin.get("burst_distance",-1.0)),expected_thin])
	check(absf(float(thick.get("burst_distance",-1.0))-expected_thick)<=0.01,
		"CD004 T04 the burst lies on the residual trajectory: thick measured %.5f m vs residual*delay %.5f m" % [float(thick.get("burst_distance",-1.0)),expected_thick])
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_RESIDUAL_FUZE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
