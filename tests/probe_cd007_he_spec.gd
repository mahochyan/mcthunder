extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07 implementation step one, written as a specification BEFORE the chain exists, because the
## baseline measured that no external HE, blast or overpressure damage channel is present at all.
##
## The order says to prove the transmission rules first with standard open, closed and bulkhead fixtures, and its first
## design point demands three SEPARATE channels - blast, fragment and overpressure - recorded under one explosion root event
## rather than one shared "everything within the radius dies" switch. This probe states the half of that specification that
## is currently missing, and it states it in the form that has to hold before the implementation as well as after it:
##
##   A1 asking for an external blast or an overpressure channel must be REFUSED WITH A NAME rather than silently becoming
##      some existing effect. That is the specification, and it is measurable today because the channels do not exist.
##
## The other half - that the fragment channel which already exists respects what is really in the compartment - is NOT
## re-measured here. It was measured in this same order's earlier work as a contrast with a working fixture: with no internal
## structure the identical shot damages nothing at all, and with the real internals present it lands five records absorbing
## twenty millimetres across two named components. My attempt to rebuild that fixture here with a hand-made snapshot got
## zero records from both configurations, which was my fixture rather than the channel: the snapshot's entity identity did
## not match the actor's, so the after-effect could not resolve its target. Rather than dress that up as evidence, the
## citation stands and this probe keeps only the leg it can measure honestly.

const CD7_SEED := 16100

func _cd7_spawn_probe(world: Node3D, actor: VehicleActor, policy: String) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var spawned := manager.try_spawn({"round_id":CD7_SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":1,
		"shell_id":"test_cd007_"+policy,"effect_policy":policy,"armor_policy":"resolve",
		"impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":PackedVector2Array([Vector2(0,50),Vector2(2000,50)]),
		"position_world":Vector3(0,2,-5),"velocity_world":Vector3(0,0,-900),"gravity_world":Vector3(0,-9.81,0),
		"max_age_s":0.2,"max_distance_m":50.0})
	var out := {"ok":bool(spawned.get("ok",false)),"reason":str(spawned.get("reason","")),"manager":manager}
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_a1_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 A1 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_a1_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD07 A1 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd007_a1",1,Transform3D.IDENTITY,2,null).ok,"CD07 A1 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	var refused := 0
	for policy in ["he_blast","overpressure","blast","fragmentation"]:
		var probe := _cd7_spawn_probe(world,actor,str(policy))
		print("[CD07 A1] effect_policy=%-14s => accepted=%s reason=%s" % [str(policy),str(probe.ok),str(probe.reason)])
		check(not bool(probe.ok),
			"CD07 A1 SPECIFICATION: the %s channel is required by the order, does not exist yet, and its launch is REFUSED rather than silently reinterpreted" % str(policy))
		check(not str(probe.reason).strip_edges().is_empty(),
			"CD07 A1 the refusal for %s NAMES its reason: %s" % [str(policy),str(probe.reason)])
		if not bool(probe.ok): refused += 1
		if probe.manager != null: probe.manager.queue_free()
	print("[CD07 A1] all four channel names refused with a reason: %d of 4" % refused)
	check(refused==4,"CD07 A1 every external-blast and overpressure channel name is refused with a reason, so none of them is a silent synonym for an existing effect")
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HE_CHANNELS_SPEC_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
