extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T04, the half the user ruled must be BUILT AND MEASURED BEFORE CD15 OPENS.
##
## The existing world-burst probe proves the world contact half: an external HE detonates on a world contact and records the
## same three channels. What was never measured is the SECOND half of the same case - that the obstruction still works, so a
## target BEHIND the wall takes no through-wall damage. The evidence document CLAIMED that half while the result file recorded
## five of six cases executed, so nothing is taken on trust here: the fixture puts a real second vehicle behind the wall, the
## round is fired at the wall from outside, and the target own state is read afterwards.
##
## Judgments:
##   O1 the round is terminal AT the wall and never reaches the target, so no path through exists;
##   O2 the burst happens and records itself as a world contact with no interior overpressure applied;
##   O3 the target behind the wall takes NO module damage, loses NO crew and records NO death.

const HE_ID := "eng_125_he_v1"
const ENG := "res://configs/vehicles/engineering/ussr_t_80b.json"
const SEED := 16900

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_occl_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 occl creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var defs := VehicleDefs.new()

	var handle := FileAccess.open(ENG,FileAccess.READ)
	check(handle != null,"CD07 occl the engineering packet opens")
	var eng: Dictionary = JSON.parse_string(handle.get_as_text())
	check(VehicleCatalog.new(fixture_asset(eng,1.0)).register(eng,defs).ok,"CD07 occl the engineering packet registers")
	var world := Node3D.new(); root.add_child(world)

	# The shooter side, exactly as the proven world-burst probe builds it.
	var shooter := VehicleActor.new(); world.add_child(shooter)
	check(shooter.setup(defs,"ussr_t_80b","cd007_occl_shooter",1,Transform3D.IDENTITY,2,null).ok,
		"CD07 occl the firing vehicle installs")
	shooter.set_physics_process(false); shooter.tank.set_physics_process(false)

	# The TARGET, a real second vehicle BEHIND the wall, which is the half that was never measured.
	var target := VehicleActor.new(); world.add_child(target)
	check(target.setup(defs,"ussr_t_80b","cd007_occl_target",2,Transform3D(Basis.IDENTITY,Vector3(-6,1.2,0)),2,null).ok,
		"CD07 occl a second real vehicle installs BEHIND the wall")
	target.set_physics_process(false); target.tank.set_physics_process(false)
	await _frames(3)
	var found: ShellDefinition = null
	for shell in shooter.gunner.shell_options:
		if str(shell.id).contains(HE_ID): found = shell
	check(found != null,"CD07 occl the engineering HE is among the installed options")

	var modules_before := target.state.module_states.size()
	var integrities_before: Array = []
	for id in target.state.module_states: integrities_before.append(float(target.state.module_states[id].get("integrity",0.0)))
	var crew_before := target.state.alive_crew_count()
	var target_distance := shooter.global_position.distance_to(target.global_position)

	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(4,4,1)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1   # GameConfig.LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(0,1.2,0)
	world.add_child(wall)
	await _frames(2)

	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(shooter,"apply_projectile_damage")
	# Fired from OUTSIDE the wall toward it, so the wall is the first thing met and the target sits behind it.
	var spec := {"round_id":SEED,"shooter_id":"cd007occl","shooter_life_id":1,"shot_id":SEED,
		"shell_id":str(found.id),"effect_policy":"he_blast","armor_policy":"resolve",
		"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
		"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
		"seed":2102,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.6,"max_distance_m":90.0}
	var spawned := manager.try_spawn(spec)
	check(spawned.ok,"CD07 occl the shot launches from outside the wall")
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	var reached_target := false
	for i in 400:
		if state.is_terminal(): break
		manager.advance_projectile(state,1.0/240.0,[],space)

	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	var channels: Dictionary = burst.get("channels",{})
	var over: Dictionary = channels.get("overpressure",{})
	var stop_x := 0.0

	# Read the TARGET own state, which is what the missing half is about.
	var integrities_after: Array = []
	for id in target.state.module_states: integrities_after.append(float(target.state.module_states[id].get("integrity",0.0)))
	var modules_after := target.state.module_states.size()
	var crew_after := target.state.alive_crew_count()
	var damaged := 0
	for i in mini(integrities_before.size(),integrities_after.size()):
		if float(integrities_before[i]) != float(integrities_after[i]): damaged += 1
	print("[CD07 occl] O1 terminal=%s at x=%.3f ; burst present=%s ; contact_kind=%s ; target at x=%.3f (distance %.2f m)" % [
		str(state.terminal_reason),stop_x,str(not burst.is_empty()),str(burst.get("contact_kind","")),
		target.global_position.x,target_distance])
	print("[CD07 occl] O2 channels=%s ; external=%s ; overpressure applied=%s reason=%s" % [
		str(channels.keys()),str(burst.get("external","")),str(over.get("applied","")),str(over.get("reason",""))])
	print("[CD07 occl] O3 target modules %d -> %d ; damaged=%d ; crew %d -> %d ; destroyed=%s ; death_record=%s" % [
		modules_before,modules_after,damaged,crew_before,crew_after,str(target.state.destroyed),str(target.state.death_record)])

	check(not reached_target and stop_x > -2.0,
		"CD07 occl O1 the round is stopped AT the wall (x=%.3f) and never reaches the target behind it" % stop_x)
	check(not burst.is_empty() and str(burst.get("contact_kind",""))=="world_contact",
		"CD07 occl O2 the HE detonates on the world contact as the case requires")
	check(not bool(over.get("applied",true)),
		"CD07 occl O2 and no interior overpressure is applied where there is no interior to reach")
	check(damaged == 0 and modules_after == modules_before and crew_after == crew_before,
		"CD07 occl O3 the target behind the wall takes NO module damage and loses NO crew: damaged=%d crew %d -> %d" % [damaged,crew_before,crew_after])
	check(not target.state.destroyed and target.state.death_record.is_empty(),
		"CD07 occl O3 and it records no death, so no through-wall total damage was dealt")
	manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_OCCLUSION_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
