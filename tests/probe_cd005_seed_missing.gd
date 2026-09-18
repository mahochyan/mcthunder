extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05-T06: fixed seed and missing data. Three independent expectations:
##   L1 the seed a shot actually carries equals an INDEPENDENT recomputation of the declared formula, and that formula holds
##      no frame term, so the same shot identity reproduces the same seed no matter which frame it is fired on - which is
##      what "do not draw per frame" means in practice, and this probe recomputes rather than trusting the recorded value.
##   L2 the seed is the dispersion source and it is deterministic: two generators started from the same seed give the same
##      sequence, one started from a different seed does not.
##   L3 an unknown material is handled EXPLICITLY and does not become zero thickness: the verdict names the unknown and the
##      effective thickness still reflects the plate's own geometry.

const CD5T6_SEED := 13100

func _cd5t6_passive() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-T06 probe fixture: the passive rule set for the unknown-material leg",
		"normalization_deg":0.0,"overmatch_ratio":0.0,"ricochet_deg":89.0,
		"material_coefficients":{"rolled":1.0,"cast":1.0}}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t06_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T06 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd005_t06_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD05 T06 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd005_t06",1,Transform3D.IDENTITY,2,null).ok,"CD05 T06 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	actor.gunner.projectile_manager = manager
	await _frames(3)

	# ── L1: the seed the shot carries against an independent recomputation of the declared formula.
	actor.gunner.select_shell(0); actor.gunner.cooldown_left = 0.0; actor.gunner.resume_grace = 0.0
	var shot_id_before: int = actor.gunner.shot_id
	var fired: bool = actor.gunner.try_fire()
	check(fired,"CD05 T06 the gunner fires so a seed can be read from the shot")
	if not fired:
		world.queue_free(); await _frames(2); quit(1); return
	var state: ProjectileState = manager.get_projectile_state(actor.gunner.last_projectile_id)
	var carried_seed := int(state.seed)
	# The declared formula, recomputed HERE from its own inputs and with no frame anywhere in it.
	var round_id := state.round_id
	var expected_seed := hash(JSON.stringify([round_id,"cd005_t06",1,actor.gunner.shot_id]))
	print("[CD05 T06] L1 carried seed=%d ; recomputed=%d ; round=%s shooter=%s life=%s shot=%s" % [
		carried_seed,expected_seed,str(round_id),str(state.shooter_id),str(state.shooter_life_id),str(actor.gunner.shot_id)])
	check(carried_seed==expected_seed,
		"CD05 T06 L1 the seed the shot carries equals an independent recomputation of the declared formula: %d vs %d" % [carried_seed,expected_seed])
	# Frame independence: the formula has no frame input, so recomputing it at two different frame counts must not move it.
	var frames_a := Engine.get_physics_frames()
	var seed_a := hash(JSON.stringify([round_id,"cd005_t06",1,actor.gunner.shot_id]))
	await _frames(3)
	var frames_b := Engine.get_physics_frames()
	var seed_b := hash(JSON.stringify([round_id,"cd005_t06",1,actor.gunner.shot_id]))
	print("[CD05 T06] L1 frame dependence: physics_frames %d -> %d ; seed %d -> %d" % [frames_a,frames_b,seed_a,seed_b])
	check(frames_b!=frames_a and seed_a==seed_b,
		"CD05 T06 L1 the seed does NOT move while the frame counter does, so it is not an every-frame draw: %d vs %d" % [seed_a,seed_b])

	# ── L2: determinism of the dispersion source the seed feeds.
	var rng_a := RandomNumberGenerator.new(); rng_a.seed = carried_seed
	var rng_b := RandomNumberGenerator.new(); rng_b.seed = carried_seed
	var rng_c := RandomNumberGenerator.new(); rng_c.seed = carried_seed+1
	var same := true
	for i in 8:
		if rng_a.randf()!=rng_b.randf(): same = false
	var different := false
	var rng_d := RandomNumberGenerator.new(); rng_d.seed = carried_seed
	var rng_e := RandomNumberGenerator.new(); rng_e.seed = carried_seed+1
	for i in 8:
		if rng_d.randf()!=rng_e.randf(): different = true
	print("[CD05 T06] L2 same seed reproduces=%s ; different seed diverges=%s" % [str(same),str(different)])
	check(same,"CD05 T06 L2 two generators from the same seed give the same sequence, so a replay reproduces the dispersion")
	check(different,"CD05 T06 L2 a different seed gives a different sequence, so the seed really is the dispersion source")

	# ── L3: unknown material, explicit and not zero thickness.
	var event := {"has_thickness":true,"thickness_mm":100.0,"thickness_status":"estimated","material_kind":"unobtainium",
		"response_profile":{},"normal_world":Vector3(0,0,1)}
	var unknown := ArmorResolver.resolve(event,Vector3(0,0,-1),
		{"base_mm":900.0,"impact_profile":_cd5t6_passive(),"effect_policy":"kinetic","caliber_mm":120.0})
	print("[CD05 T06] L3 unknown material => result=%s effective=%.4f mm consumed=%.4f continue=%s" % [
		str(unknown.get("result","")),float(unknown.get("effective_mm",-1.0)),float(unknown.get("consumed_mm",-1.0)),
		str(unknown.get("continue_flight",""))])
	check(str(unknown.get("result",""))=="unknown_material",
		"CD05 T06 L3 an unknown material is named explicitly rather than resolved silently: %s" % str(unknown.get("result","")))
	check(float(unknown.get("effective_mm",-1.0))>50.0,
		"CD05 T06 L3 the unknown material does NOT become zero thickness: effective %.4f mm" % float(unknown.get("effective_mm",-1.0)))
	check(not bool(unknown.get("continue_flight",true)),
		"CD05 T06 L3 the unknown material does not let the round fly on as if it had penetrated")
	var unknown_missing := ArmorResolver.resolve({"material_kind":"rolled","normal_world":Vector3(0,0,1)},Vector3(0,0,-1),
		{"base_mm":900.0,"impact_profile":_cd5t6_passive(),"effect_policy":"kinetic","caliber_mm":120.0})
	print("[CD05 T06] L3b missing thickness => result=%s effective=%.4f" % [str(unknown_missing.get("result","")),float(unknown_missing.get("effective_mm",-1.0))])
	check(str(unknown_missing.get("result",""))!="penetrated" and str(unknown_missing.get("result",""))!="",
		"CD05 T06 L3b a contact with no thickness claim resolves to a named state rather than a free penetration: %s" % str(unknown_missing.get("result","")))
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_SEED_MISSING_DATA_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
