extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T03, the remaining branch: a thin plate is breached and an INDEPENDENT thick bulkhead behind it
## stops what is left. The base's own two-plate layout has equal plates that are both breached, so the thicknesses are the one
## thing this leg has to state for itself; everything else is the proven layout shape and the proven firing leg.
##
##   B1 the thin front plate and the thick bulkhead are separate contacts, each on its own plate group;
##   B2 their verdicts DIFFER - the front is breached and the rear does not share that verdict, which is what independent
##      segmentation means rather than one answer copied down the line;
##   B3 the armour consumed is less than the sum of both plates, because the shot stopped in the second one rather than
##      passing through everything.

func _cd07_unequal_plates(front_mm: float, rear_mm: float) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd007_unequal_plates"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var index := 0
	for spec in [[front_mm,-0.05,-1.0],[rear_mm,0.05,1.0]]:
		var patch := ArmorPatchDefinition.new()
		patch.id = "cd007_plate_%d" % index
		patch.plate_group_id = "cd007_zone_%d" % index
		patch.part_id = "hull"
		var x := float(spec[1])
		patch.vertices_local_m = PackedVector3Array([Vector3(x,-1,-1),Vector3(x,-1,1),Vector3(x,1,-1),Vector3(x,1,1)])
		patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
		patch.outward_normal_local = Vector3(float(spec[2]),0,0)
		patch.has_thickness = true; patch.thickness_mm = float(spec[0]); patch.material_kind = "rolled"
		patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
		layout.armor_patches.append(patch)
		index += 1
	return layout

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_t03c_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 T03c creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_t03c_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD07 T03c the fixture packet registers")
	var world := Node3D.new(); root.add_child(world)
	# The measured run consumed both plates whole - four hundred and five millimetres - so four hundred was still inside this
	# round's reach. The bulkhead has to be far beyond that reach for this branch to exist at all.
	var layout := _cd07_unequal_plates(5.0,5000.0)
	check(layout.armor_patches.size()==2
		and float(layout.armor_patches[0].thickness_mm)!=float(layout.armor_patches[1].thickness_mm),
		"CD07 T03c the rig states its own thicknesses: %.1f mm then %.1f mm" % [
			float(layout.armor_patches[0].thickness_mm),float(layout.armor_patches[1].thickness_mm)])
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd007_t03c",1,Transform3D.IDENTITY,2,null).ok,"CD07 T03c the actor installs")
	actor.set_damage_layout(layout)
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var leg := _fire_leg(actor,world,layout,7,0.030,17500)
	check(bool(leg.get("ok",false)),"CD07 T03c the shot is resolved: %s" % str(leg.get("reason","")))
	var results: Array = leg.get("results",[])
	print("[CD07 T03c] contacts=%d consumed_mm=%.4f results=%s" % [
		int(leg.get("contacts",-1)),float(leg.get("consumed_mm",-1.0)),str(results)])
	check(int(leg.get("contacts",0))>=2,
		"CD07 T03c B1 the thin plate and the thick bulkhead are separate contacts: %d" % int(leg.get("contacts",0)))
	check(results.size()>=2 and str(results[0])!=str(results[1]),
		"CD07 T03c B2 their verdicts DIFFER, so the rear does not inherit the front's answer: %s" % str(results))
	if results.size()>=2:
		check(str(results[0])=="penetrated",
			"CD07 T03c B2 the thin front plate is breached: %s" % str(results[0]))
		check(str(results[1]) != "penetrated",
			"CD07 T03c B2 and the thick bulkhead behind it does NOT share that verdict: %s" % str(results[1]))
	check(float(leg.get("consumed_mm",0.0))>0.0 and float(leg.get("consumed_mm",0.0))<5005.0,
		"CD07 T03c B3 the armour consumed is less than both plates together, because the shot stopped inside the second rather than passing through everything: %.4f" % float(leg.get("consumed_mm",-1.0)))
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_INDEPENDENT_BULKHEAD_PASS" if failures==0 else "CD07_INDEPENDENT_BULKHEAD_FAIL")
	quit(0 if failures==0 else 1)
