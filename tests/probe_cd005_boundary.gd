extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05-T05: boundary equality, a seam, and firing from inside out. The order asks that the terminal
## state, the remaining budget and the continue-flight behaviour agree in all three. Three independent expectations:
##   L1 a penetration exactly equal to the resistance ends as perforated_stop, does NOT continue, and leaves EXACTLY zero
##      remaining budget - not a small positive number, and not a negative one.
##   L2 a round sent down the SEAM between two coplanar plates must neither slip through for free nor be charged twice: the
##      total consumed must be exactly one layer's worth, with at least one contact.
##   L3 fired from behind, the contact is a BACKFACE and a delay fuze must not arm on it, whatever the armour verdict says.

const CD5T5_SEED := 14100
const CD5T5_STEP := 1.0/240.0
const CD5T5_LAYER_MM := 100.0

func _cd5t5_passive() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-T05 probe fixture: the passive rule set for the boundary legs",
		"normalization_deg":0.0,"overmatch_ratio":0.0,"ricochet_deg":89.0,
		"material_coefficients":{"rolled":1.0,"cast":1.0}}

## Two coplanar plates that share their edge along y = 0, so a shot down that line lands exactly on the seam.
func _cd5t5_seam_layout() -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd005_t05_seam"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var rows := [{"id":"cd005_t05_upper","lo":0.0,"hi":1.0},{"id":"cd005_t05_lower","lo":-1.0,"hi":0.0}]
	for row in rows:
		var patch := ArmorPatchDefinition.new()
		patch.id = str(row.id); patch.plate_group_id = str(row.id)+"_zone"; patch.part_id = "hull"
		patch.vertices_local_m = PackedVector3Array([Vector3(0.0,float(row.lo),-1.0),Vector3(0.0,float(row.lo),1.0),
			Vector3(0.0,float(row.hi),-1.0),Vector3(0.0,float(row.hi),1.0)])
		patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
		patch.outward_normal_local = Vector3(-1,0,0)
		patch.has_thickness = true; patch.thickness_mm = CD5T5_LAYER_MM; patch.material_kind = "rolled"
		patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
		layout.armor_patches.append(patch)
	return layout

func _cd5t5_shot(actor: VehicleActor, world: Node3D, snapshot: Dictionary, from_world: Vector3, to_world: Vector3, round_id: int, fuze: Dictionary, aphe: Dictionary, expect_contact: bool) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var velocity := (to_world-from_world).normalized()*900.0
	var spec := {"round_id":round_id,"shooter_id":"cd005_t05","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_cd5t5",
		"effect_policy":("internal_burst" if not fuze.is_empty() else "kinetic"),"armor_policy":"resolve",
		"impact_profile":aphe,"post_penetration_profile":{},"fuze_policy":fuze.duplicate(true),
		"caliber_mm":shell.caliber_mm,"penetration_curve":PackedVector2Array([Vector2(0,900),Vector2(2000,900)]),
		"position_world":from_world,"velocity_world":velocity,"gravity_world":Vector3(0,-9.81,0),
		"max_age_s":0.3,"max_distance_m":200.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		print("[CD05 T05] launch refused: %s" % str(spawned.get("reason","")))
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 200:
		if state.is_terminal(): break
		manager.advance_projectile(state,CD5T5_STEP,[snapshot],space)
		if expect_contact and len(state.contacts) > 0 and state.terminal_reason.is_empty(): break
	var out := {"ok":true,"contacts":len(state.contacts),"consumed_mm":state.consumed_mm,"state":state,
		"verdict":str(state.contacts[0].get("result","")) if len(state.contacts) > 0 else "",
		"backface":bool(state.contacts[0].get("backface",false)) if len(state.contacts) > 0 else false,
		"after_mm":float(state.contacts[0].get("after_mm",-1.0)) if len(state.contacts) > 0 else -1.0,
		"continue":bool(state.contacts[0].get("continue_flight",false)) if len(state.contacts) > 0 else false,
		"fuze_armed":state.fuze_due_age_s>=0.0,"terminal":str(state.terminal_reason)}
	manager.queue_free()
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t05_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T05 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd005_t05_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD05 T05 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd005_t05",1,Transform3D.IDENTITY,2,null).ok,"CD05 T05 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var passive := _cd5t5_passive()

	# ── L1: exact equality, checked directly on the resolver so the budget is unambiguous.
	var exact := ArmorResolver.resolve({"has_thickness":true,"thickness_mm":CD5T5_LAYER_MM,"thickness_status":"estimated",
		"material_kind":"rolled","response_profile":{},"normal_world":Vector3(0,0,1)},Vector3(0,0,-1),
		{"base_mm":CD5T5_LAYER_MM,"impact_profile":passive,"effect_policy":"kinetic","caliber_mm":120.0})
	print("[CD05 T05] L1 exact equality => result=%s continue=%s after=%.6f consumed=%.6f effective=%.6f" % [
		str(exact.get("result","")),str(exact.get("continue_flight","")),float(exact.get("after_mm",-1.0)),
		float(exact.get("consumed_mm",-1.0)),float(exact.get("effective_mm",-1.0))])
	check(str(exact.get("result",""))=="perforated_stop",
		"CD05 T05 L1 a penetration exactly equal to the resistance ends as perforated_stop: %s" % str(exact.get("result","")))
	check(not bool(exact.get("continue_flight",true)),
		"CD05 T05 L1 a perforated stop does not continue the flight")
	check(absf(float(exact.get("after_mm",-1.0)))<=1e-6,
		"CD05 T05 L1 the remaining budget is EXACTLY zero, neither positive nor negative: %.9f mm" % float(exact.get("after_mm",-1.0)))

	# ── L2: the seam. Fire straight down the shared edge of two coplanar plates.
	var seam_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_cd5t5_seam_layout())
	seam_snapshot["entity_id"] = "cd005_t05_target"; seam_snapshot["life_id"] = 61
	seam_snapshot["part_world_transforms"]["hull"] = Transform3D(Basis(Vector3.UP,deg_to_rad(90.0)),Vector3(0,2.0,-10.0))
	var seam := _cd5t5_shot(actor,world,seam_snapshot,Vector3(0,2,-5),Vector3(0,2,-15),CD5T5_SEED+1,{},passive,true)
	print("[CD05 T05] L2 seam => contacts=%d consumed=%.6f verdicts=%s" % [
		int(seam.get("contacts",-1)),float(seam.get("consumed_mm",-1.0)),str(seam.get("verdict",""))])
	check(bool(seam.get("ok",false)),"CD05 T05 L2 the seam shot launches")
	check(int(seam.get("contacts",0))>=1,
		"CD05 T05 L2 the seam is NOT a free gap: the round is met by at least one plate, contacts=%d" % int(seam.get("contacts",-1)))
	check(absf(float(seam.get("consumed_mm",-1.0))-CD5T5_LAYER_MM)<=0.01,
		"CD05 T05 L2 the seam is not charged twice either: total consumed %.6f mm against one layer's %.1f mm" % [
			float(seam.get("consumed_mm",-1.0)),CD5T5_LAYER_MM])

	# ── L3: from inside out. The plate faces +Z, so a shot travelling +Z meets its BACK.
	var back_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_cd5t5_seam_layout())
	back_snapshot["entity_id"] = "cd005_t05_target"; back_snapshot["life_id"] = 62
	back_snapshot["part_world_transforms"]["hull"] = Transform3D(Basis(Vector3.UP,deg_to_rad(90.0)),Vector3(0,2.0,-10.0))
	var aphe := {"version":ArmorImpactProfile.VERSION,"family":"APHE","provenance":"game_rule",
		"reason":"CD05-T05 probe fixture: an APHE profile so a delay fuze can be attached",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}
	var fuze := {"mode":"penetration_delay","arming_thickness_mm":5.0,"delay_s":0.02,
		"provenance":"game_rule","reason":"CD05-T05 probe fixture: the delay fuze that must not arm on a backface"}
	# A true backface means travelling WITH the outward normal, which the measurement above established points along -Z after
	# the rotation: the resolver's rule is that a direction agreeing with the outward normal came from inside the armour. My
	# first version flew against it, which is an ordinary front hit, so the geometry was wrong rather than the rule.
	var inside_out := _cd5t5_shot(actor,world,back_snapshot,Vector3(0,2,-5),Vector3(0,2,-15),CD5T5_SEED+3,fuze,aphe,true)
	# Measure the facing rather than assume it: the geometric normal comes from the triangle winding, and my assumption about
	# which way that points after the ninety degree rotation is exactly the kind of thing this probe should not guess at.
	var probe_from := Vector3(0,2,-5)
	var probe_to := Vector3(0,2,-15)
	var facing := ShotQueryService.query({"query_id":"cd005_t05_facing","from_world":probe_from,"to_world":probe_to},[back_snapshot])
	for ev in facing.get("events",[]):
		print("[CD05 T05] L3 facing: surface=%s normal_world=%s flight_dir=%s dot=%.4f declared_outward_local=%s" % [
			str(ev.get("surface_id","")),str(ev.get("normal_world",Vector3.ZERO)),
			str((probe_to-probe_from).normalized()),float((ev.get("normal_world",Vector3.ZERO) as Vector3).normalized().dot((probe_to-probe_from).normalized())),
			str(_cd5t5_seam_layout().armor_patches[0].outward_normal_local)])
	print("[CD05 T05] L3 inside out => contacts=%d verdict=%s backface=%s fuze_armed=%s continue=%s" % [
		int(inside_out.get("contacts",-1)),str(inside_out.get("verdict","")),str(inside_out.get("backface","")),
		str(inside_out.get("fuze_armed","")),str(inside_out.get("continue",""))])
	check(bool(inside_out.get("ok",false)),"CD05 T05 L3 the inside-out shot launches")
	check(int(inside_out.get("contacts",0))>=1 and bool(inside_out.get("backface",false)),
		"CD05 T05 L3 the inside-out contact is marked as a backface: backface=%s" % str(inside_out.get("backface","")))
	check(not bool(inside_out.get("fuze_armed",true)),
		"CD05 T05 L3 a delay fuze does NOT arm on a backface, whatever the armour verdict says")
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_BOUNDARY_BACKFACE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
