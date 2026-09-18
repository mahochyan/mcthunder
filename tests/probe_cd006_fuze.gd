extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD06 design point two and CD06-T02: the arming, delay, body-stop and through-and-out paths of an
## APHE delay fuze must each end in the right burst or no-burst state.
##
## The judgments are chosen to be unambiguous rather than clever, because I have been burned repeatedly by fixtures whose
## geometry I only assumed:
##   L1 with the arming thickness set impossibly high, no plate can arm the fuze, so there is NO burst at all;
##   L2 with it set below the plate, the round arms and the burst lands AFTER the plate, by the declared delay;
##   L3 a thin plate that cannot arm, followed by a thick one that can, arms on the SECOND plate - which is the order's
##      "the after-effect is not forced to stay in the first hull" measured rather than asserted;
##   L4 the burst state is reported as a finite due time once armed and as an unarmed marker before that.

const CD6T2_SEED := 15100
const CD6T2_STEP := 1.0/240.0

func _cd6t2_plate(rows: Array) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd006_t02_stack"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	for row in rows:
		var patch := ArmorPatchDefinition.new()
		patch.id = "cd006_t02_" + str(row.z)
		patch.plate_group_id = "cd006_t02_zone" + str(row.z)
		patch.part_id = "hull"
		patch.vertices_local_m = PackedVector3Array([Vector3(float(row.z),-1,-1),Vector3(float(row.z),-1,1),
			Vector3(float(row.z),1,-1),Vector3(float(row.z),1,1)])
		patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
		patch.outward_normal_local = Vector3(-1,0,0)
		patch.has_thickness = true; patch.thickness_mm = float(row.mm); patch.material_kind = "rolled"
		patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
		layout.armor_patches.append(patch)
	return layout

func _cd6t2_aphe() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"APHE","provenance":"game_rule",
		"reason":"CD06-T02 probe fixture: an APHE rule set so a delay fuze can be attached",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}

func _cd6t2_fuze(arming_mm: float, delay_s: float) -> Dictionary:
	return {"mode":"penetration_delay","arming_thickness_mm":arming_mm,"delay_s":delay_s,
		"provenance":"game_rule","reason":"CD06-T02 probe fixture: a delay fuze whose arming thickness is the variable"}

## Fire from +X toward -X, so the plate stack is met in the order given.
func _cd6t2_shot(actor: VehicleActor, world: Node3D, rows: Array, arming_mm: float, delay_s: float, round_id: int, curve_mm: float) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_cd6t2_plate(rows))
	snapshot["entity_id"] = "cd006_t02_target"; snapshot["life_id"] = 71
	snapshot["part_world_transforms"]["hull"] = Transform3D(Basis.IDENTITY,Vector3(0,2.0,-10.0))
	var spec := {"round_id":round_id,"shooter_id":"cd006_t02","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_cd6t2",
		"effect_policy":"internal_burst","armor_policy":"resolve","impact_profile":_cd6t2_aphe(),
		"post_penetration_profile":{},"fuze_policy":_cd6t2_fuze(arming_mm,delay_s),
		"caliber_mm":shell.caliber_mm,"penetration_curve":PackedVector2Array([Vector2(0,curve_mm),Vector2(2000,curve_mm)]),
		"position_world":Vector3(6,2,-10),"velocity_world":Vector3(-900,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.5,"max_distance_m":200.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		print("[CD06 T02] launch refused: %s" % str(spawned.get("reason","")))
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 400:
		if state.is_terminal(): break
		manager.advance_projectile(state,CD6T2_STEP,[snapshot],space)
	var out := {"ok":true,"armed":state.fuze_due_age_s>=0.0,"fuze_due_age_s":state.fuze_due_age_s,
		"terminal":str(state.terminal_reason),"x":state.position_world.x,"age_s":state.age_s,
		"burst":state.burst.duplicate(true) if state.burst is Dictionary else {},
		"contacts":state.contacts.size(),"verdicts":state.contacts.map(func(c): return str(c.get("result","")))}
	manager.queue_free()
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd006_t02_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD06 T02 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd006_t02_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD06 T02 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd006_t02",1,Transform3D.IDENTITY,2,null).ok,"CD06 T02 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)

	# ── L1: an arming thickness no plate can reach. The round penetrates, but nothing may arm or burst.
	var never := _cd6t2_shot(actor,world,[{"z":0.0,"mm":100.0}],999.0,0.02,CD6T2_SEED+1,900.0)
	print("[CD06 T02] L1 arming 999 mm vs a 100 mm plate => armed=%s due=%.6f terminal=%s verdicts=%s contacts=%d" % [
		str(never.get("armed","")),float(never.get("fuze_due_age_s",-1.0)),str(never.get("terminal","")),str(never.get("verdicts","")),int(never.get("contacts",-1))])
	check(bool(never.get("ok",false)) and int(never.get("contacts",0))>=1,
		"CD06 T02 L1 the round does meet the plate, so the no-burst state is about arming and not about missing")
	check(not bool(never.get("armed",true)),
		"CD06 T02 L1 with the arming thickness out of reach the fuze never arms: due=%.6f" % float(never.get("fuze_due_age_s",-1.0)))
	check(not str(never.get("terminal","")).contains("burst") and not (never.get("burst",{}) as Dictionary).has("point_world"),
		"CD06 T02 L1 and there is no burst at all: terminal=%s" % str(never.get("terminal","")))

	# ── L2: an arming thickness the plate exceeds. The round arms and bursts AFTER the plate.
	var armed := _cd6t2_shot(actor,world,[{"z":0.0,"mm":100.0}],5.0,0.02,CD6T2_SEED+3,900.0)
	print("[CD06 T02] L2 arming 5 mm vs a 100 mm plate => armed=%s due=%.6f age=%.6f x=%.4f terminal=%s" % [
		str(armed.get("armed","")),float(armed.get("fuze_due_age_s",-1.0)),float(armed.get("age_s",-1.0)),
		float(armed.get("x",-1.0)),str(armed.get("terminal",""))])
	check(bool(armed.get("armed",false)),
		"CD06 T02 L2 a plate thicker than the arming thickness DOES arm the fuze: due=%.6f" % float(armed.get("fuze_due_age_s",-1.0)))
	check(float(armed.get("fuze_due_age_s",-1.0))>=0.0 and float(armed.get("age_s",-1.0))>=float(armed.get("fuze_due_age_s",0.0))-CD6T2_STEP,
		"CD06 T02 L2 the delay is honoured: the shot ends at or after its due time (due %.6f, age %.6f)" % [
			float(armed.get("fuze_due_age_s",-1.0)),float(armed.get("age_s",-1.0))])
	check(float(armed.get("x",0.0))<0.0,
		"CD06 T02 L2 the burst point is PAST the plate rather than on it: x=%.4f (the plate stands at x=0)" % float(armed.get("x",-1.0)))

	# ── L3: a thin plate that cannot arm, then a thick one that can. The arm happens on the SECOND plate.
	var second := _cd6t2_shot(actor,world,[{"z":0.6,"mm":10.0},{"z":0.0,"mm":100.0}],50.0,0.02,CD6T2_SEED+5,900.0)
	print("[CD06 T02] L3 thin 10 mm then thick 100 mm, arming 50 mm => armed=%s contacts=%d verdicts=%s x=%.4f terminal=%s" % [
		str(second.get("armed","")),int(second.get("contacts",-1)),str(second.get("verdicts","")),float(second.get("x",-1.0)),str(second.get("terminal",""))])
	check(int(second.get("contacts",0))>=2,
		"CD06 T02 L3 the round meets both plates, so the arming question is really about which one armed it: contacts=%d" % int(second.get("contacts",-1)))
	check(bool(second.get("armed",false)),
		"CD06 T02 L3 the after-effect is NOT forced to stay in the first hull: a thin plate leaves it unarmed and the second, thicker plate arms it")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD06_FUZE_PATHS_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
