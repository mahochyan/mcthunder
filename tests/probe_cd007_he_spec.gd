extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07: the specification from last round, now with the external HE channel accepted and the explosion
## root event carrying its three channels separately.
##
## A1 was written last round as "asking for these channels must be REFUSED WITH A NAME because they do not exist yet". The
## implementation now makes the external HE channel exist, so that leg's expectation moves in the direction the specification
## asked for - he_blast is accepted - while the names that are still not channels stay refused by name. This is the
## implementation satisfying the requirement, not an expectation being relaxed to pass.
##
## A2 measures design point one's shape on a real shot: one explosion produces ONE root event which records its channels
## separately, and the channels that are declared but not yet applied say so in the record instead of pretending to work.

const CD7_SEED := 16200
const CD7_STEP := 1.0/240.0

func _cd7_spawn(world: Node3D, actor: VehicleActor, policy: String) -> Dictionary:
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

## The plate stands in the x = 0 plane with no rotation, so a shot along -X meets it; this is the fixture shape that worked.
func _cd7_plate(thickness_mm: float) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd007_plate"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var patch := ArmorPatchDefinition.new()
	patch.id = "cd007_plate_a"; patch.plate_group_id = "cd007_zone"; patch.part_id = "hull"
	patch.vertices_local_m = PackedVector3Array([Vector3(0,-1,-1),Vector3(0,-1,1),Vector3(0,1,-1),Vector3(0,1,1)])
	patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
	patch.outward_normal_local = Vector3(-1,0,0)
	patch.has_thickness = true; patch.thickness_mm = thickness_mm; patch.material_kind = "rolled"
	patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
	layout.armor_patches.append(patch)
	return layout

func _cd7_aphe() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"APHE","provenance":"game_rule",
		"reason":"CD07 probe fixture: an APHE rule set so the burst path can be driven and its root event inspected",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_a2_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_a2_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD07 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd007_a2",1,Transform3D.IDENTITY,2,null).ok,"CD07 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	# ── A1: the external HE channel now exists; the names that are not channels stay refused by name.
	var accepted := {}
	for policy in ["he_blast","overpressure","blast","fragmentation"]:
		var probe := _cd7_spawn(world,actor,str(policy))
		accepted[str(policy)] = {"ok":bool(probe.ok),"reason":str(probe.reason)}
		print("[CD07 A1] effect_policy=%-14s => accepted=%s reason=%s" % [str(policy),str(probe.ok),str(probe.reason)])
		if probe.manager != null: probe.manager.queue_free()
	check(bool(accepted["he_blast"].ok),
		"CD07 A1 the external HE channel REQUIRED by the order is now accepted at launch, which is the specification being satisfied")
	for still_absent in ["overpressure","blast","fragmentation"]:
		check(not bool(accepted[still_absent].ok) and not str(accepted[still_absent].reason).strip_edges().is_empty(),
			"CD07 A1 %s is still not a channel and is still refused BY NAME rather than silently becoming one: %s" % [still_absent,str(accepted[still_absent].reason)])

	# ── A2: one explosion, one root event, three separately recorded channels.
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var layout := _cd7_plate(100.0)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	snapshot["entity_id"] = "cd007_a2_target"; snapshot["life_id"] = 91
	snapshot["part_world_transforms"]["hull"] = Transform3D(Basis.IDENTITY,Vector3(0,2,-10))
	var spec := {"round_id":CD7_SEED+7,"shooter_id":"cd007","shooter_life_id":1,"shot_id":CD7_SEED+7,
		"shell_id":"test_cd007_burst","effect_policy":"internal_burst","armor_policy":"resolve",
		"impact_profile":_cd7_aphe(),
		"post_penetration_profile":{},"fuze_policy":{"mode":"penetration_delay","arming_thickness_mm":5.0,"delay_s":0.02,
			"provenance":"game_rule","reason":"CD07 probe fixture: a delay fuze below the plate thickness so the burst fires"},
		"caliber_mm":120,"penetration_curve":PackedVector2Array([Vector2(0,900),Vector2(2000,900)]),
		"position_world":Vector3(6,2,-10),"velocity_world":Vector3(-900,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.5,"max_distance_m":200.0}
	var spawned := manager.try_spawn(spec)
	check(spawned.ok,"CD07 A2 the burst fixture launches")
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 400:
		if state.is_terminal(): break
		manager.advance_projectile(state,CD7_STEP,[snapshot],space)
	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	var channels: Dictionary = burst.get("channels",{})
	print("[CD07 A2] terminal=%s ; burst keys=%s ; channels=%s" % [
		str(state.terminal_reason),str(burst.keys()),JSON.stringify(channels)])
	check(not burst.is_empty(),"CD07 A2 the shot really produces one explosion root event: terminal=%s" % str(state.terminal_reason))
	check(channels.size()==3 and channels.has("fragment") and channels.has("blast") and channels.has("overpressure"),
		"CD07 A2 the root event records THREE separate channels, not one shared switch: %s" % str(channels.keys()))
	check(bool(channels.get("fragment",{}).get("applied",false)),
		"CD07 A2 the fragment channel is really applied, on the existing bounded emitter the order tells us not to rewrite")
	var over: Dictionary = channels.get("overpressure",{})
	var recorded_outside := bool(over.get("burst_outside",true))
	var recorded_breached := bool(over.get("breached",false))
	var recorded_openings := int(over.get("declared_openings",-1))
	var rederived := (not recorded_outside) or recorded_breached or recorded_openings>0
	print("[CD07 A2] overpressure verdict=%s ; model=%s ; inputs burst_outside=%s breached=%s openings=%d ; re-derived=%s ; reason=%s" % [
		str(over.get("applied","")),str(over.get("model","")),str(recorded_outside),str(recorded_breached),recorded_openings,str(rederived),str(over.get("reason",""))])
	check(recorded_openings>=0,
		"CD07 A2 the opening count is on the record, so the path question is visible rather than implied: %d" % recorded_openings)
	check(str(over.get("model",""))=="cd07-bounded-connectivity-v1",
		"CD07 A2 the pressure channel is decided by a NAMED bounded-connectivity model rather than an in-radius switch: %s" % str(over.get("model","")))
	check(bool(over.get("applied",false))==rederived,
		"CD07 A2 the recorded verdict equals an independent re-derivation from its own recorded inputs, so the rule is visible and checkable: applied=%s re-derived=%s" % [
			str(over.get("applied","")),str(rederived)])
	check(recorded_breached and bool(over.get("applied",false)),
		"CD07 A2 this fixture's plate WAS breached, so the pressure has a path in and the channel is applied - the breach half of the rule")
	check(not bool(channels.get("blast",{}).get("applied",true)) and not str(channels.get("blast",{}).get("pending","")).is_empty(),
		"CD07 A2 while the blast channel still says plainly that it is declared and not yet applied: %s" % str(channels.get("blast",{}).get("pending","")))
	manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HE_ROOT_EVENT_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
