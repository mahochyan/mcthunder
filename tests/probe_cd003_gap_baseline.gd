extends "res://tests/run_cd002_geometry_probe.gd"
## MCT-COMBAT-DEEPEN-01 CD003, implementation order step 1: the independent gap baseline.
##
## A synthetic pair of plates leaves a vertical gap of width d and the shot runs along +X. Whether the projectile fits is
## pure geometry - the projectile's declared EFFECTIVE section against d - so the EXPECTATION below is computed from those
## numbers alone and never from the query under test. What is measured is what the current line query does, which is the
## gap that step 2 (3A static finite section) has to close.
##
## The synthetic layout is built in code and only borrows a real actor's part transforms; no production layout, packet or
## model is touched, and nothing here asserts that the line behaviour is acceptable.

const GAP_PROBE_ENTITY := "cd003_gap_target"

func _synthetic_layout(gap_m: float) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd003_gap_layout"
	layout.schema_version = 1
	layout.content_tier = "test"
	var part := LayoutPartDefinition.new()
	part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	# Two plates in the YZ plane at X=0: upper occupies Y in [d/2, 2], lower is its mirror, so the slit is Y in (-d/2, d/2).
	_add_plate(layout,"cd003_upper",gap_m*0.5,2.0)
	_add_plate(layout,"cd003_lower",-2.0,-gap_m*0.5)
	return layout

func _add_plate(layout: VehicleLayoutDefinition, id: String, y0: float, y1: float) -> void:
	var patch := ArmorPatchDefinition.new()
	patch.id = id
	patch.plate_group_id = "cd003_test_plate"
	patch.part_id = "hull"
	patch.vertices_local_m = PackedVector3Array([Vector3(0,y0,-1.0),Vector3(0,y1,-1.0),Vector3(0,y1,1.0),Vector3(0,y0,1.0)])
	patch.triangles = PackedInt32Array([0,1,2, 0,2,3])
	patch.outward_normal_local = Vector3(-1,0,0)
	patch.has_thickness = true
	patch.thickness_mm = 100.0
	patch.material_kind = "rolled"
	patch.geometry_status = "estimated"
	patch.thickness_status = "estimated"
	layout.armor_patches.append(patch)

## Independent expectation: does the declared effective section fit through a gap of width d? Tangency is named as its own
## outcome because the sub-order expects a contact that still goes through material resolution rather than an automatic
## stop.
func _expected(section_m: float, gap_m: float) -> String:
	if section_m < gap_m - 1e-9: return "pass_through"
	if section_m > gap_m + 1e-9: return "contact"
	return "tangent_contact"

func _gap_shot(snapshot: Dictionary, y: float, section: Dictionary = {}) -> Dictionary:
	var request := {"query_id":"cd003_gap","from_world":Vector3(-3.0,y,0.0),"to_world":Vector3(3.0,y,0.0)}
	if not section.is_empty(): request["shape_section"] = section
	var result := ShotQueryService.query(request,[snapshot])
	var armour := 0
	var first := {}
	for event in result.get("events",[]):
		if str(event.get("surface_id","")).begins_with("cd003_"):
			armour += 1
			if first.is_empty(): first = event
	return {"ok":bool(result.get("ok",false)),"complete":bool(result.get("complete",false)),"armour_contacts":armour,
		"surface_id":str(first.get("surface_id","")),"query_complete":bool(result.get("complete",false))}

## A single physical plate: one patch, one quad in the YZ plane at X=0, subdivided into `strips` bands so the triangle
## count can be varied without changing the geometry at all.
func _single_plate_layout(strips: int, x: float = 0.0) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd003_single_plate"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var patch := ArmorPatchDefinition.new()
	patch.id = "cd003_single"; patch.plate_group_id = "cd003_single_zone"; patch.part_id = "hull"
	var vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	for i in strips+1:
		var y := -1.0+2.0*float(i)/float(strips)
		vertices.append(Vector3(x,y,-1.0)); vertices.append(Vector3(x,y,1.0))
	for i in strips:
		var a := i*2; var b := i*2+1; var c := (i+1)*2; var d := (i+1)*2+1
		triangles.append_array(PackedInt32Array([a,c,b, b,c,d]))
	patch.vertices_local_m = vertices; patch.triangles = triangles
	patch.outward_normal_local = Vector3(-1,0,0)
	patch.has_thickness = true; patch.thickness_mm = 100.0; patch.material_kind = "rolled"
	patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
	layout.armor_patches.append(patch)
	return layout

## Two REAL plates in series: two separate patches, each a single band, so two layers must act separately.
func _double_plate_layout() -> VehicleLayoutDefinition:
	var layout := _single_plate_layout(1,-0.05)
	var second := _single_plate_layout(1,0.05)
	var patch: ArmorPatchDefinition = second.armor_patches[0]
	patch.id = "cd003_second"; patch.plate_group_id = "cd003_second_zone"
	patch.outward_normal_local = Vector3(1,0,0)
	layout.armor_patches.append(patch)
	return layout

## One real projectile through the manager with a declared section, so the ray count is the only thing that changes.
func _fire_leg(actor: VehicleActor, world: Node3D, layout: VehicleLayoutDefinition, rays: int, section_m: float, round_id: int, delta: float = 1.0/120.0) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var from_world := Vector3(-3.0,0.0,0.0)
	var to_world := Vector3(3.0,0.0,0.0)
	var spec := {"round_id":round_id,"shooter_id":"cd003_t03","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id,
		"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile.duplicate(true),
		"post_penetration_profile":shell.post_penetration_profile.duplicate(true),"fuze_policy":shell.fuze_policy.duplicate(true),
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
		"position_world":from_world,"velocity_world":(to_world-from_world).normalized()*1000.0,"gravity_world":Vector3.ZERO,
		"max_age_s":0.05,"max_distance_m":20.0,"section_radius_m":section_m*0.5,"section_rays":rays}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		return {"ok":false,"reason":str(spawned.get("reason","")),"contacts":-1,"consumed_mm":-1.0,"results":[]}
	var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	for i in 30:
		if projectile.is_terminal(): break
		manager.advance_projectile(projectile,delta,[snapshot],world.get_world_3d().direct_space_state)
	var results: Array = []
	for row in projectile.contacts: results.append(str(row.get("result","")))
	var out := {"ok":true,"contacts":projectile.contacts.size(),"consumed_mm":float(projectile.consumed_mm),
		"results":results,"damage":projectile.damage_records.size(),"source":str(projectile.shape_source)}
	manager.queue_free()
	return out

## CD03-T05 / 3B: one moving target, one contact time. The target translates along +Z across the swept step and the shell
## runs along +X, so the crossing is analytically at t = 0.5 (from -3 to +3 through a plate at X=0), the target's Z at that
## instant is lerp(z_start, z_end, 0.5), and the hit expressed in the PLATE's own frame must therefore be minus that. If
## the query used a stale or fixed frame the local value would be off by the motion inside the step, which is exactly the
## cross-tick bias the case forbids. No function under test computes the expectation.
func _moving_leg(actor: VehicleActor, z_start: float, z_end: float) -> Dictionary:
	var layout := _single_plate_layout(1)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	snapshot["part_world_transforms"]["hull"] = Transform3D(Basis.IDENTITY,Vector3(0,0,z_end))
	snapshot[TranslationSweep.PREVIOUS_KEY] = {"hull":Transform3D(Basis.IDENTITY,Vector3(0,0,z_start))}
	var result := ShotQueryService.query({"query_id":"cd003_move","from_world":Vector3(-3,0,0),"to_world":Vector3(3,0,0),
		"motion_fraction":Vector2(0,1)},[snapshot])
	var first := {}
	for event in result.get("events",[]):
		if str(event.get("surface_id",""))=="cd003_single": first = event
	if first.is_empty(): return {"ok":false,"t":-1.0,"fraction":-1.0,"local_z":INF}
	var fraction := float(first.get("motion_fraction",float(first.get("t",0.0))))
	var part_at_contact: Transform3D = TranslationSweep.part_transform(snapshot,"hull",fraction)
	var local: Vector3 = part_at_contact.affine_inverse()*Vector3(first.get("point_world",Vector3.ZERO))
	return {"ok":true,"t":float(first.get("t",-1.0)),"fraction":fraction,"local_z":local.z,
		"expected_z":-lerpf(z_start,z_end,0.5)}

## The same moving target, but with a declared section and a grazing line so that a RING ray meets the plate. The recorded
## local offset is then the section offset converted into the part's frame, and its length must still be the radius: if the
## conversion used a stale frame it would be short or long by the part's motion during the step.
func _moving_section_leg(actor: VehicleActor, rot_deg: float) -> Dictionary:
	var layout := _single_plate_layout(1)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var basis := Basis(Vector3.UP,deg_to_rad(rot_deg))
	snapshot["part_world_transforms"]["hull"] = Transform3D(basis,Vector3.ZERO)
	snapshot[TranslationSweep.PREVIOUS_KEY] = {"hull":Transform3D(basis,Vector3.ZERO)}
	var radius := 0.030
	# Rotation about Y, which is PERPENDICULAR to the flight direction. Rotating about the flight axis instead leaves the
	# flight direction invariant, so the plate turns relative to the section and the experiment compares two different
	# relative geometries - which is what my previous attempt did and why it could only ever disagree.
	var line: Vector3 = basis*Vector3(0,0,1.0+0.015)
	var from_world: Vector3 = basis*Vector3(-3.0,0.0,1.0+0.015)
	var to_world: Vector3 = basis*Vector3(3.0,0.0,1.0+0.015)
	var result := ShotQueryService.query({"query_id":"cd003_move_section","from_world":from_world,
		"to_world":to_world,"motion_fraction":Vector2(0,1),
		"shape_section":{"section_radius_m":radius,"rays":13}},[snapshot])
	var contacts := 0
	var offset := Vector3.ZERO
	for event in result.get("events",[]):
		if str(event.get("surface_id",""))!="cd003_single": continue
		contacts += 1
		if offset == Vector3.ZERO: offset = event.get("section_offset_local_m",Vector3.ZERO)
	var local_seg: PackedVector3Array = TranslationSweep.local_segment(snapshot,"hull",from_world,to_world,Vector2(0,1))
	var inside := ShotQueryService.query({"query_id":"cd003_inside","from_world":basis*Vector3(-3,0,0.985),"to_world":basis*Vector3(3,0,0.985)},[snapshot])
	var inside_contacts := 0
	for event in inside.get("events",[]):
		if str(event.get("surface_id",""))=="cd003_single": inside_contacts += 1
	var outside_contacts := 0
	var outside := ShotQueryService.query({"query_id":"cd003_outside","from_world":from_world,"to_world":to_world},[snapshot])
	for event in outside.get("events",[]):
		if str(event.get("surface_id",""))=="cd003_single": outside_contacts += 1
	print("[CD03-T05]   controls: centre line at local Z=0.985 (inside) => %d ; centre line at the graze (outside) => %d" % [inside_contacts,outside_contacts])
	return {"contacts":contacts,"offset":offset,"offset_len":offset.length(),"radius":radius,
		"offset_dir":(offset.normalized() if offset.length()>1e-9 else Vector3.ZERO)}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd003_gap_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD003 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd003_gap_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD003 the fixture packet registers so a real actor can supply part transforms ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,GAP_PROBE_ENTITY,1,Transform3D.IDENTITY,2,null).ok,"CD003 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	# The three declared engineering sections, straight from the profile data.
	var sections := {}
	for kind in ["long_rod","full_caliber","chemical"]:
		var resolved := ProjectileShapeProfile.resolve({"shape_kind":kind})
		check(bool(resolved.get("ok",false)),"CD003 the declared profile resolves for "+kind)
		sections[kind] = float(resolved.get("profile",{}).get("core_diameter_m",0.0))
	print("[CD003 baseline] declared effective sections: long_rod=%.0f mm full_caliber=%.0f mm chemical=%.0f mm" % [
		sections.long_rod*1000.0,sections.full_caliber*1000.0,sections.chemical*1000.0])
	var mismatches: Array = []
	var line_mismatches: Array = []
	for gap_mm in [20.0,50.0,200.0]:
		var gap_m: float = float(gap_mm)/1000.0
		var layout := _synthetic_layout(gap_m)
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
		var line := _gap_shot(snapshot,0.0)
		var edge := _gap_shot(snapshot,gap_m*0.5)
		var square := _gap_shot(snapshot,gap_m*0.5+0.15)
		print("[CD003 baseline] gap=%.0f mm | v1 LINE through the slit: contacts=%d | line on the edge: contacts=%d | line 150 mm inboard: contacts=%d" % [
			gap_mm,int(line.armour_contacts),int(edge.armour_contacts),int(square.armour_contacts)])
		for kind in sections.keys():
			var profile: Dictionary = ProjectileShapeProfile.resolve({"shape_kind":kind}).get("profile",{})
			var plan: Dictionary = ProjectileShapeProfile.sampling_plan(profile)
			var section := {"section_radius_m":float(plan.get("section_radius_m",0.0)),"rays":int(plan.get("rays",0))}
			var measured := _gap_shot(snapshot,0.0,section)
			var expect := _expected(float(sections[kind]),gap_m)
			var fits := int(measured.armour_contacts) == 0
			var expected_fits := expect == "pass_through"
			var line_fits := int(line.armour_contacts) == 0
			print("[CD003 3A] gap=%.0f mm %-12s section=%.0f mm rays=%d bound=%.2f mm expect=%-14s 3A=%s v1_line=%s" % [
				gap_mm,kind,float(sections[kind])*1000.0,int(plan.get("rays",0)),float(plan.get("error_bound_mm",-1.0)),expect,
				("pass" if fits else "contact(%d)"%int(measured.armour_contacts)),("pass" if line_fits else "contact")])
			check(fits == expected_fits,"CD003-T01 3A agrees with the independently computed geometry: gap=%.0f mm %s (section %.0f mm) expected %s but measured %s" % [
				gap_mm,kind,float(sections[kind])*1000.0,expect,("pass_through" if fits else "contact")])
			if fits != expected_fits:
				mismatches.append({"gap_mm":gap_mm,"kind":kind,"expected":expect})
			if line_fits != expected_fits:
				line_mismatches.append({"gap_mm":gap_mm,"kind":kind,"expected":expect})
	print("[CD003 3A] with the declared section: %d of 9 disagree with the geometry" % mismatches.size())
	print("[CD003 v1 CONTROL] the same geometry through the v1 line rule: %d of 9 disagree - the legacy entry is kept as the comparison, not replaced" % line_mismatches.size())
	# ── Manager leg: the section must travel ShellDeclaration -> state -> manager -> query, a round that declares nothing
	# must be a VISIBLE legacy line round, and a declaration that cannot be resolved must refuse the launch by name.
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var gap_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_synthetic_layout(0.020))
	var real_shell: ShellDefinition = actor.gunner.shell_options[0]
	var base := {"round_id":3100,"shooter_id":"cd003_chain","shooter_life_id":1,"shot_id":1,"shell_id":real_shell.id,
		"effect_policy":real_shell.effect_policy,"impact_profile":real_shell.impact_profile.duplicate(true),
		"post_penetration_profile":real_shell.post_penetration_profile.duplicate(true),
		"fuze_policy":real_shell.fuze_policy.duplicate(true),"caliber_mm":real_shell.caliber_mm,
		"penetration_curve":real_shell.penetration_curve,
		"position_world":Vector3(-3,0,0),"velocity_world":Vector3(1000,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.05,"max_distance_m":20.0}
	var engineering := base.duplicate(true); engineering["shape_kind"] = "long_rod"
	var spawned := manager.try_spawn(engineering)
	check(spawned.get("ok",false),"CD003 the engineering round launches with a declared shape ("+str(spawned.get("reason",""))+")")
	if spawned.get("ok",false):
		var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
		check(str(projectile.shape_source)!="legacy_line","CD003 the engineering round carries a resolved shape source: "+str(projectile.shape_source))
		for i in 20:
			if projectile.is_terminal(): break
			manager.advance_projectile(projectile,1.0/120.0,[gap_snapshot],world.get_world_3d().direct_space_state)
		var radius_seen := -1.0
		var ray_seen := -1
		for row in projectile.contacts:
			radius_seen = maxf(radius_seen,float(row.get("section_radius_m",-1.0)))
			ray_seen = maxi(ray_seen,int(row.get("section_ray_index",-1)))
		print("[CD003 chain] engineering round: contacts=%d section_radius=%s ray_index=%s source=%s" % [
			projectile.contacts.size(),str(radius_seen),str(ray_seen),str(projectile.shape_source)])
		check(radius_seen > 0.0,"CD003 the section reached the query through the manager: a contact records radius %.4f m" % radius_seen)
		check(ray_seen >= 1,"CD003 the contact that met a 20 mm slit came from a ring ray, not the centre: index %d" % ray_seen)
	var legacy := base.duplicate(true); legacy["round_id"] = 3101
	var legacy_spawn := manager.try_spawn(legacy)
	check(legacy_spawn.get("ok",false),"CD003 a round that declares nothing still launches, as the legacy line round")
	if legacy_spawn.get("ok",false):
		var st2: ProjectileState = manager.get_projectile_state(legacy_spawn.projectile_id)
		check(str(st2.shape_source)=="legacy_line","CD003 the legacy round is marked as the legacy line round, visibly: "+str(st2.shape_source))
		check(st2.shape_sampling.is_empty(),"CD003 the legacy round carries no section")
	var refused_spec := base.duplicate(true)
	refused_spec["round_id"] = 3102; refused_spec["shot_id"] = 3; refused_spec["shape_kind"] = "unknown_round"
	var refused := manager.try_spawn(refused_spec)
	print("[CD003 chain] refusal for an unresolvable declaration: ok=%s reason=%s" % [str(refused.get("ok",false)),str(refused.get("reason",""))])
	check(not refused.get("ok",false) and str(refused.get("reason",""))=="no_shape_profile","CD003 a declaration that cannot be resolved refuses the launch by name")
	manager.queue_free(); await _frames(2)
	# ── CD03-T03: one physical plate must not become thicker with the ray count or the triangle count, while two real
	# plates in series must keep two separate effects. The expectation is geometric: one plate is one effect.
	var single := _single_plate_layout(1)
	var fine := _single_plate_layout(8)
	var rays3 := _fire_leg(actor,world,single,3,0.030,3303)
	var rays7 := _fire_leg(actor,world,single,7,0.030,3307)
	var rays13 := _fire_leg(actor,world,single,13,0.030,3313)
	print("[CD03-T03] single plate, ray count 3/7/13: contacts=%d/%d/%d consumed=%.6f/%.6f/%.6f" % [
		int(rays3.contacts),int(rays7.contacts),int(rays13.contacts),float(rays3.consumed_mm),float(rays7.consumed_mm),float(rays13.consumed_mm)])
	check(int(rays3.contacts)==1 and int(rays7.contacts)==1 and int(rays13.contacts)==1,
		"CD03-T03 a single physical plate is met exactly once whatever the ray count (1 plate = 1 effect)")
	check(absf(float(rays3.consumed_mm)-float(rays7.consumed_mm))<=1e-6 and absf(float(rays3.consumed_mm)-float(rays13.consumed_mm))<=1e-6,
		"CD03-T03 the same plate costs the same whatever the ray count: %.6f / %.6f / %.6f mm" % [float(rays3.consumed_mm),float(rays7.consumed_mm),float(rays13.consumed_mm)])
	var tri2 := _fire_leg(actor,world,single,7,0.030,3322)
	var tri16 := _fire_leg(actor,world,fine,7,0.030,3316)
	print("[CD03-T03] same plate, 2 vs 16 triangles: contacts=%d/%d consumed=%.6f/%.6f" % [
		int(tri2.contacts),int(tri16.contacts),float(tri2.consumed_mm),float(tri16.consumed_mm)])
	check(int(tri2.contacts)==int(tri16.contacts),
		"CD03-T03 subdividing one plate does not change how many times it is met: %d vs %d" % [int(tri2.contacts),int(tri16.contacts)])
	check(absf(float(tri2.consumed_mm)-float(tri16.consumed_mm))<=1e-6,
		"CD03-T03 subdividing one plate does not make it thicker: %.6f vs %.6f mm" % [float(tri2.consumed_mm),float(tri16.consumed_mm)])
	var doubled := _fire_leg(actor,world,_double_plate_layout(),7,0.030,3340)
	print("[CD03-T03] two real plates in series: contacts=%d consumed=%.6f results=%s" % [
		int(doubled.contacts),float(doubled.consumed_mm),JSON.stringify(doubled.results)])
	check(int(doubled.contacts)==2,"CD03-T03 two separate plates stay two effects rather than one: %d contacts" % int(doubled.contacts))
	check(float(doubled.consumed_mm) > float(tri2.consumed_mm),
		"CD03-T03 the second real layer costs more than a single plate: %.6f > %.6f mm" % [float(doubled.consumed_mm),float(tri2.consumed_mm)])
	# ── CD03-T02: an edge contact must go through material resolution rather than being an automatic stop or a pass.
	var edge_leg := _fire_leg(actor,world,_single_plate_layout(1),7,0.030,3350)
	print("[CD03-T02] edge/centre contact resolution: contacts=%d consumed=%.6f results=%s terminal_ok" % [
		int(edge_leg.contacts),float(edge_leg.consumed_mm),JSON.stringify(edge_leg.results)])
	check(int(edge_leg.contacts)==1 and float(edge_leg.consumed_mm) > 0.0,
		"CD03-T02 meeting a plate with a declared section goes through material resolution with a consumed budget, not an automatic verdict")
	check(not edge_leg.results.is_empty() and str(edge_leg.results[0]) in ["penetrated","stopped","ricochet","partial"],
		"CD03-T02 the terminal result comes from the material rule vocabulary: "+JSON.stringify(edge_leg.results))
	# ── CD03-T05 / 3B: the moving target must use ONE contact time for shell and target, with the analytic crossing and
	# the analytic local hit, at two different tick phases.
	for phase in [[0.0,1.0],[-0.5,0.5],[-1.0,1.0]]:
		var z0: float = float(phase[0]); var z1: float = float(phase[1])
		var leg := _moving_leg(actor,z0,z1)
		print("[CD03-T05] phase z %.2f -> %.2f : ok=%s t=%.6f fraction=%.6f local_z=%.6f expected=%.6f" % [
			z0,z1,str(leg.ok),float(leg.get("t",-1.0)),float(leg.get("fraction",-1.0)),
			float(leg.get("local_z",INF)),float(leg.get("expected_z",INF))])
		check(bool(leg.ok),"CD03-T05 the moving target is met at all (z %.2f -> %.2f)" % [z0,z1])
		if not leg.ok: continue
		check(absf(float(leg.fraction)-0.5)<=0.02,"CD03-T05 shell and target use the same contact time, the analytic crossing at t=0.5 (z %.2f -> %.2f): got %.6f" % [z0,z1,float(leg.fraction)])
		check(absf(float(leg.local_z)-float(leg.expected_z))<=0.02,"CD03-T05 the hit in the plate's own frame matches the analytic value (z %.2f -> %.2f): %.6f vs %.6f" % [z0,z1,float(leg.local_z),float(leg.expected_z)])
	# 3B residual: with a section and a ROTATING part the ring offset must be expressed in the frame at the CONTACT instant.
	# The same relative grazing geometry is used at two different part rotations, so the offset expressed in the part's own
	# frame must be the same at both phases; a stale-frame conversion would rotate with the part and disagree.
	var spin_a := _moving_section_leg(actor,0.0)
	var spin_b := _moving_section_leg(actor,20.0)
	var dot := float(spin_a.offset_dir.dot(spin_b.offset_dir))
	print("[CD03-T05] section under a perpendicular rotation: A contacts=%d len=%.6f dir=%s | B contacts=%d len=%.6f dir=%s | dir_dot=%.6f" % [
		int(spin_a.contacts),float(spin_a.offset_len),str(spin_a.offset_dir),
		int(spin_b.contacts),float(spin_b.offset_len),str(spin_b.offset_dir),dot])
	check(int(spin_a.contacts)>=1 and int(spin_b.contacts)>=1,"CD03-T05 the grazing shot with a section meets the plate at both rotations")
	check(absf(float(spin_a.offset_len)-0.030)<=0.002,"CD03-T05 the recorded ring offset has the declared radius: %.6f" % float(spin_a.offset_len))
	check(dot>=0.999,"CD03-T05 with the flight direction rotated together with the plate, the same relative geometry gives the same local offset: dot=%.6f" % dot)
	# ── CD03-T04: the same comparable scenario at different internal step sizes must agree within the declared tolerance,
	# and exhausting the declared ray budget must report incomplete rather than a clear path.
	for step in [1.0/60.0,1.0/120.0,1.0/240.0]:
		var leg := _fire_leg(actor,world,_single_plate_layout(1),7,0.030,3400+int(step*100000.0),step)
		print("[CD03-T04] step=1/%.0f contacts=%d consumed=%.6f" % [1.0/step,int(leg.get("contacts",-1)),float(leg.get("consumed_mm",-1.0))])
		check(int(leg.get("contacts",0))==1,"CD03-T04 a comparable shot meets one plate at step 1/%.0f" % (1.0/step))
	var budget_layout := _double_plate_layout()
	var budget_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,budget_layout)
	# The budget must be reached by work, not by a number in a request: the ray loop stops as soon as the CENTRE ray hits, so
	# a line down the middle casts one ray per patch and never approaches the budget. A grazing line makes the loop walk the
	# whole ring on both plates, which is 400 rays each and exceeds the declared 512.
	var budget_result := ShotQueryService.query({"query_id":"cd003_budget","from_world":Vector3(-3,0,1.015),"to_world":Vector3(3,0,1.015),
		"motion_fraction":Vector2(0,1),"shape_section":{"section_radius_m":0.03,"rays":400}},[budget_snapshot])
	var budget_diag := JSON.stringify(budget_result.get("diagnostics",[]))
	print("[CD03-T04] ray budget: rays=400 over %d plates => complete=%s diagnostic=%s" % [
		budget_layout.armor_patches.size(),str(budget_result.get("complete",true)),budget_diag])
	check(not bool(budget_result.get("complete",true)) and budget_diag.contains("ray_budget_exhausted"),
		"CD03-T04 exhausting the declared ray budget reports incomplete with a diagnostic instead of a clear path")
	world.queue_free(); await _frames(2)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD003_GAP_BASELINE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
