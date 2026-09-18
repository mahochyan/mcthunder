extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07: the runtime version of the weapon limit, and what firing the engineering HE really does.
## The previous attempt extended SceneTree directly, where the project's fixture helper does not exist, so engineering
## packets never registered; this one extends the probe base like every other probe here and uses its proven helper.
##
## R1 the runtime option list per engineering vehicle, read from the production install path: the round that carries the
##    125 mm gun must be offered by the vehicle that carries it and by no other.
## R2 firing it, reported exactly as measured.

const HE_ID := "eng_125_he_v1"
const ENG_DIR := "res://configs/vehicles/engineering/"
const SEED := 16700

func _cd7_eng(id: String) -> Dictionary:
	var handle := FileAccess.open(ENG_DIR+id+".json",FileAccess.READ)
	if handle == null: return {}
	return JSON.parse_string(handle.get_as_text())

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_landed_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 landed creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_landed_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(sources).register(packet,defs).ok,"CD07 landed the fixture packet registers")
	var world := Node3D.new(); root.add_child(world)

	# ── R1: the runtime option list, per engineering vehicle.
	var offers := {}
	var index := 0
	for vid in VehicleCatalog.ENGINEERING_IDS:
		index += 1
		var eng := _cd7_eng(str(vid))
		check(not eng.is_empty(),"CD07 landed R1 the engineering packet %s loads" % str(vid))
		if eng.is_empty(): continue
		# The identity is left alone: renaming a delivered engineering packet invalidates its sources and its delivered
		# artefact gates, which is exactly the mistake recorded in the previous rounds.
		var eng_sources := fixture_asset(eng,1.0)
		var registered := VehicleCatalog.new(eng_sources).register(eng,defs)
		check(registered.ok,"CD07 landed R1 %s registers" % str(vid))
		if not registered.ok: continue
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,str(vid),str(vid),index,Transform3D.IDENTITY,2,null)
		check(installed.ok,"CD07 landed R1 %s installs" % str(vid))
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		await _frames(2)
		var ids: Array = []
		for shell in actor.gunner.shell_options: ids.append(str(shell.id))
		offers[str(vid)] = ids
		print("[CD07 landed] R1 %-16s gun=%s options=%s" % [str(vid),str(eng.assembly.get("gun","")),str(ids)])
	var offering: Array = []
	for vid in offers:
		var has := false
		for sid in offers[vid]: if str(sid).contains(HE_ID): has = true
		if has: offering.append(str(vid))
	print("[CD07 landed] R1 vehicles offering %s: %s" % [HE_ID,str(offering)])
	check(offering.size()>=1,
		"CD07 landed R1 the engineering HE IS offered at runtime by the vehicle carrying its gun: %s" % str(offering))
	check(offering.size()<offers.size(),
		"CD07 landed R1 and it is LIMITED at runtime rather than handed to every vehicle: %d of %d offer it" % [offering.size(),offers.size()])

	# ── R2: fire it and record what happens.
	if offering.is_empty():
		print("[CD07 landed] R2 skipped: nothing offers the round at runtime")
	else:
		var vid := str(offering[0])
		var eng := _cd7_eng(vid)
		var eng_sources2 := fixture_asset(eng,1.0)
		var defs2 := VehicleDefs.new()
		var reg2 := VehicleCatalog.new(eng_sources2).register(eng,defs2)
		check(reg2.ok,"CD07 landed R2 the firing vehicle registers")
		var actor2 := VehicleActor.new(); world.add_child(actor2)
		var installed2 := actor2.setup(defs2,str(vid),str(vid),7,Transform3D.IDENTITY,2,null)
		check(installed2.ok,"CD07 landed R2 the firing vehicle installs")
		actor2.set_physics_process(false); actor2.tank.set_physics_process(false)
		await _frames(3)
		var found: ShellDefinition = null
		for shell in actor2.gunner.shell_options:
			if str(shell.id).contains(HE_ID): found = shell
		check(found != null,"CD07 landed R2 the round is among the installed options")
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor2,"apply_projectile_damage")
		var spec := {"round_id":SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED,
			"shell_id":str(found.id),"effect_policy":"he_blast","armor_policy":"resolve",
			"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
			"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
			"seed":2101,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
			"max_age_s":0.6,"max_distance_m":90.0}
		var spawned := manager.try_spawn(spec)
		check(spawned.ok,"CD07 landed R2 the engineering HE launches with its landed configuration")
		if spawned.ok:
			var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
			var space := world.get_world_3d().direct_space_state
			for i in 400:
				if state.is_terminal(): break
				manager.advance_projectile(state,1.0/240.0,[],space)
			var burst: Dictionary = state.burst if state.burst is Dictionary else {}
			print("[CD07 landed] R2 OUTCOME terminal=%s contacts=%d verdicts=%s burst=%s" % [
				str(state.terminal_reason),state.contacts.size(),
				str(state.contacts.map(func(cc): return str(cc.get("result","")))),("none" if burst.is_empty() else "present")])
			if burst.is_empty():
				print("[CD07 landed] R2 RECORDED HONESTLY: the contact HE stops without bursting, because an external blast has no fuze or burst-on-contact path in this version; that path is the named next piece per design point three")
			else:
				var channels: Dictionary = burst.get("channels",{})
				check(channels.size()==3,"CD07 landed R2 the burst records three channels: %s" % str(channels.keys()))
		manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HE_RUNTIME_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
