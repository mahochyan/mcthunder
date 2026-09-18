extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04-T06: long steps, invalid values and pausing. The case asks that splitting the same simulated
## period, pausing, and injecting illegal parameters all leave the result CONTROLLED - a pause must not be caught up later,
## and an illegal configuration must not fire. Three independent legs, each measured rather than argued:
##   L1 one big delta and many small ones covering the SAME time must agree, because the manager sub-steps internally.
##   L2 a zero delta must advance nothing at all, however many times it is asked, and a spawn while the tree is paused must
##      be refused by name.
##   L3 illegal spawn parameters are refused by name and an illegal delta on a live round ends it in a controlled way with
##      a reason, instead of producing a non-finite state.

const T06_SEED := 6100
const T06_STEP := 1.0/240.0
const T06_STEPS := 25
const T06_TOL_M := 0.01
const T06_TOL_MPS := 0.1

func _t06_launch(actor: VehicleActor, world: Node3D, round_id: int) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var layout := _single_plate_layout(1)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	snapshot["entity_id"] = "cd004_t06_target"
	snapshot["life_id"] = 11
	var spec := {"round_id":round_id,"shooter_id":"cd004_t06","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_t06",
		"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
		"position_world":Vector3(3,0,0),"velocity_world":Vector3(-900,0,0),"gravity_world":Vector3(0,-9.81,0),
		"max_age_s":0.2,"max_distance_m":100.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	return {"ok":true,"manager":manager,"state":manager.get_projectile_state(spawned.projectile_id),"snapshot":snapshot}

func _t06_report(tag: String, state: ProjectileState) -> Dictionary:
	var out := {"age_s":state.age_s,"travelled_m":state.travelled_m,"speed":state.velocity_world.length(),
		"x":state.position_world.x,"contacts":len(state.contacts),"terminal":str(state.terminal_reason)}
	print("[CD004 T06 %s] age=%.6f travelled=%.6f speed=%.4f x=%.4f contacts=%d terminal=%s" % [
		tag,float(out.age_s),float(out.travelled_m),float(out.speed),float(out.x),int(out.contacts),str(out.terminal)])
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t06_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T06 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t06_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T06 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t06",1,Transform3D.IDENTITY,2,null).ok,"CD004 T06 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	# ── L1: the same simulated period, once as one long delta and once as many short ones.
	var fine := _t06_launch(actor,world,T06_SEED+1)
	var coarse := _t06_launch(actor,world,T06_SEED+2)
	check(bool(fine.get("ok",false)) and bool(coarse.get("ok",false)),"CD004 T06 both L1 rounds launch")
	var fine_state: ProjectileState = fine.get("state")
	var coarse_state: ProjectileState = coarse.get("state")
	var space := world.get_world_3d().direct_space_state
	for i in T06_STEPS:
		fine.get("manager").advance_projectile(fine_state,T06_STEP,[fine.get("snapshot")],space)
	coarse.get("manager").advance_projectile(coarse_state,T06_STEP*float(T06_STEPS),[coarse.get("snapshot")],space)
	var fine_row := _t06_report("fine",fine_state)
	var coarse_row := _t06_report("coarse",coarse_state)
	print("[CD004 T06 L1] twenty-five substeps vs one long delta over the same %.4f s" % (T06_STEP*float(T06_STEPS)))
	check(absf(float(fine_row.travelled_m)-float(coarse_row.travelled_m))<=T06_TOL_M,
		"CD004 T06 L1 the same period advances the same distance whether split or not: %.6f vs %.6f" % [float(fine_row.travelled_m),float(coarse_row.travelled_m)])
	check(absf(float(fine_row.speed)-float(coarse_row.speed))<=T06_TOL_MPS,
		"CD004 T06 L1 the same period leaves the same speed: %.4f vs %.4f" % [float(fine_row.speed),float(coarse_row.speed)])
	check(int(fine_row.contacts)==int(coarse_row.contacts),
		"CD004 T06 L1 the same period meets the same surfaces: %d vs %d" % [int(fine_row.contacts),int(coarse_row.contacts)])

	# ── L2: a zero delta must advance nothing, however often it is asked; a paused tree must refuse a spawn by name.
	var before_zero := _t06_report("before_zero",fine_state)
	for i in 50:
		fine.get("manager").advance_projectile(fine_state,0.0,[fine.get("snapshot")],space)
	var after_zero := _t06_report("after_zero",fine_state)
	check(is_equal_approx(float(before_zero.age_s),float(after_zero.age_s)) and is_equal_approx(float(before_zero.travelled_m),float(after_zero.travelled_m)),
		"CD004 T06 L2 fifty zero-delta calls advance nothing: age %.6f -> %.6f, travelled %.6f -> %.6f" % [
			float(before_zero.age_s),float(after_zero.age_s),float(before_zero.travelled_m),float(after_zero.travelled_m)])
	# This probe IS the SceneTree, so pausing is a property of self rather than something fetched from a node.
	var was_paused: bool = paused
	paused = true
	var paused_launch := _t06_launch(actor,world,T06_SEED+3)
	paused = was_paused
	print("[CD004 T06 L2] spawn while paused: ok=%s reason=%s" % [str(paused_launch.get("ok",false)),str(paused_launch.get("reason",""))])
	check(not bool(paused_launch.get("ok",true)) and str(paused_launch.get("reason",""))=="manager_paused",
		"CD004 T06 L2 a spawn while the tree is paused is refused by name rather than silently queued")

	# ── L3: illegal parameters are refused by name, and an illegal delta ends a live round with a reason, not a NaN.
	var refusals := {}
	for bad in [{"max_age_s":-1.0},{"max_distance_m":-5.0},{"shell_id":""},{"gravity_world":Vector3(INF,0,0)}]:
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		var shell: ShellDefinition = actor.gunner.shell_options[0]
		var spec := {"round_id":T06_SEED+7,"shooter_id":"cd004_t06","shooter_life_id":1,"shot_id":T06_SEED+7,"shell_id":shell.id,
			"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
			"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
			"position_world":Vector3(3,0,0),"velocity_world":Vector3(-900,0,0),"gravity_world":Vector3(0,-9.81,0),
			"max_age_s":0.2,"max_distance_m":100.0}
		spec.merge(bad,true)
		var spawned := manager.try_spawn(spec)
		refusals[JSON.stringify(bad).substr(0,24)] = str(spawned.get("reason","accepted"))
		manager.queue_free()
	print("[CD004 T06 L3] refusals: %s" % JSON.stringify(refusals))
	for key in refusals.keys():
		check(str(refusals[key])!="accepted","CD004 T06 L3 an illegal configuration is refused rather than fired: %s => %s" % [key,str(refusals[key])])
	var doomed := _t06_launch(actor,world,T06_SEED+9)
	check(bool(doomed.get("ok",false)),"CD004 T06 L3 the round for the illegal-delta test launches")
	doomed.get("manager").advance_projectile(doomed.get("state"),-1.0,[doomed.get("snapshot")],space)
	var doomed_state: ProjectileState = doomed.get("state")
	print("[CD004 T06 L3] illegal delta: terminal=%s reason=%s finite_position=%s finite_velocity=%s" % [
		str(doomed_state.terminal_reason),str(doomed_state.is_terminal()),str(doomed_state.position_world.is_finite()),str(doomed_state.velocity_world.is_finite())])
	check(doomed_state.is_terminal() and doomed_state.position_world.is_finite() and doomed_state.velocity_world.is_finite(),
		"CD004 T06 L3 an illegal delta ends the round in a controlled way with a finite state (reason %s)" % str(doomed_state.terminal_reason))
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_LONGSTEP_PAUSE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
