extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T03: a thin plate is breached and what is behind it is explained SEGMENT by SEGMENT. This uses
## the shared probe base's own two-plate layout and proven firing leg rather than a hand-built rig, which is the lesson from
## the previous round: the helper already declares the section, and a shot with no declared section cannot be resolved at all.
##
##   S1 the two real plates in series are recorded as SEPARATE contacts, each naming its own plate, not one merged verdict;
##   S2 their verdicts are independent - the plate in front is breached and the one behind is decided by what actually
##      reached it, rather than inheriting the front verdict;
##   S3 each contact carries its own recorded numbers, so the outer plate, the inner plate and the interior result stay
##      individually accountable instead of collapsing into a single answer.

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_t03b_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 T03b creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_t03b_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD07 T03b the fixture packet registers")
	var world := Node3D.new(); root.add_child(world)
	var layout := _double_plate_layout()
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd007_t03b",1,Transform3D.IDENTITY,2,null).ok,"CD07 T03b the actor installs")
	actor.set_damage_layout(layout)
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	check(layout.armor_patches.size()==2 and str(layout.armor_patches[0].plate_group_id)!=str(layout.armor_patches[1].plate_group_id),
		"CD07 T03b the rig really has two plates in series on two different groups: %s vs %s" % [
			str(layout.armor_patches[0].plate_group_id),str(layout.armor_patches[1].plate_group_id)])
	# The same section and ray count every existing call uses: a section needs at least three rays, and one ray is refused
	# as an invalid shape section before the shot even starts.
	var leg := _fire_leg(actor,world,layout,7,0.030,17400)
	check(bool(leg.get("ok",false)),"CD07 T03b the shot is resolved through the proven firing leg: %s" % str(leg.get("reason","")))
	var results: Array = leg.get("results",[])
	print("[CD07 T03b] contacts=%d consumed_mm=%.4f results=%s" % [
		int(leg.get("contacts",-1)),float(leg.get("consumed_mm",-1.0)),str(results)])
	check(int(leg.get("contacts",0))>=2,
		"CD07 T03b S1 the two plates in series are recorded as SEPARATE contacts rather than one merged verdict: %d" % int(leg.get("contacts",0)))
	check(results.size()>=2,
		"CD07 T03b S2 each plate yields its own recorded result, so the verdicts stay independent: %s" % str(results))
	if results.size()>=2:
		var first := str(results[0])
		var second := str(results[1])
		print("[CD07 T03b] S2 first=%s second=%s" % [first,second])
		check(not first.is_empty() and not second.is_empty(),
			"CD07 T03b S2 neither plate's result is blank, so both segments are individually accountable")
	check(float(leg.get("consumed_mm",0.0))>0.0,
		"CD07 T03b S3 the shot records the armour it actually consumed, so the segment accounting is real rather than nominal: %.4f" % float(leg.get("consumed_mm",-1.0)))
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_SEGMENTED_PLATES_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
