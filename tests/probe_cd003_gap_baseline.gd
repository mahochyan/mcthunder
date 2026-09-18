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

func _gap_shot(snapshot: Dictionary, y: float) -> Dictionary:
	var result := ShotQueryService.query({"query_id":"cd003_gap","from_world":Vector3(-3.0,y,0.0),"to_world":Vector3(3.0,y,0.0)},[snapshot])
	var armour := 0
	var first := {}
	for event in result.get("events",[]):
		if str(event.get("surface_id","")).begins_with("cd003_"):
			armour += 1
			if first.is_empty(): first = event
	return {"ok":bool(result.get("ok",false)),"complete":bool(result.get("complete",false)),"armour_contacts":armour,
		"surface_id":str(first.get("surface_id","")),"query_complete":bool(result.get("complete",false))}

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
	for gap_mm in [20.0,50.0,200.0]:
		var gap_m: float = float(gap_mm)/1000.0
		var layout := _synthetic_layout(gap_m)
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
		var through := _gap_shot(snapshot,0.0)
		var edge := _gap_shot(snapshot,gap_m*0.5)
		var square := _gap_shot(snapshot,gap_m*0.5+0.15)
		print("[CD003 baseline] gap=%.0f mm | line through the slit: contacts=%d | line on the edge: contacts=%d | line 150 mm inboard: contacts=%d" % [
			gap_mm,int(through.armour_contacts),int(edge.armour_contacts),int(square.armour_contacts)])
		for kind in sections.keys():
			var expect := _expected(float(sections[kind]),gap_m)
			var measured_contacts := int(through.armour_contacts)
			var fits := measured_contacts == 0
			var expected_fits := expect == "pass_through"
			print("[CD003 baseline] gap=%.0f mm %-12s section=%.0f mm expect=%-14s line_result=%s  match=%s" % [
				gap_mm,kind,float(sections[kind])*1000.0,expect,("pass" if fits else "contact(%d)"%measured_contacts),str(fits==expected_fits)])
			if fits != expected_fits:
				mismatches.append({"gap_mm":gap_mm,"kind":kind,"section_mm":float(sections[kind])*1000.0,
					"expected":expect,"measured":"pass" if fits else "contact"})
	print("[CD003 baseline] sections that do NOT match the independently computed geometry: %d of 9 ; %s" % [
		mismatches.size(),JSON.stringify(mismatches)])
	print("[CD003 baseline] NOTE: the current query is a line, so a shot down the middle of the slit always passes and the "
		+ "projectile's declared section never enters the result. This is the gap 3A has to close, measured rather than assumed.")
	world.queue_free(); await _frames(2)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD003_GAP_BASELINE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
