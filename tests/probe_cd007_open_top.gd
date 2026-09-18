extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07: which reconstruction path turns a declared open top into declared openings, measured rather
## than grepped, and what the content gate does when a modern packet is forced open.
##
##   R1 a real packet of the modern class ALREADY declares openings through its own geometry, so the route into the
##      connectivity rule is live on the path this game loads. My earlier zero-opening reading came from a hand-made
##      single-plate layout of mine, not from a delivered packet.
##   R2 forcing open_top on that modern packet is REFUSED by the content gate, with the reason that the geometry's actual
##      content differs from its field record. That is design point five enforced by the code: no modern tank gets quietly
##      turned into an open-top for testing, so the open-versus-covered contrast has to use the historical open-top
##      representative the same order permits.

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_open_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 open-top creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var base := _read(PACKAGES+id+".json")
	var defs := VehicleDefs.new()
	var world := Node3D.new(); root.add_child(world)

	var tag_closed := "test_cd007_open_closed"
	var closed_packet := base.duplicate(true)
	closed_packet.id = tag_closed
	for source in closed_packet.sources.values(): source.applies_to_identity_ids=[closed_packet.id]
	var closed_sources := fixture_asset(closed_packet,1.0)
	var closed_registered := VehicleCatalog.new(closed_sources).register(closed_packet,defs)
	check(closed_registered.ok,"CD07 open-top the delivered packet registers as it stands")
	var closed_actor := VehicleActor.new(); world.add_child(closed_actor)
	var closed_installed := closed_actor.setup(defs,tag_closed,tag_closed,1,Transform3D.IDENTITY,2,null)
	check(closed_installed.ok,"CD07 open-top its actor installs, so the reading below is real")
	closed_actor.set_physics_process(false); closed_actor.tank.set_physics_process(false)
	await _frames(2)
	var layout: VehicleLayoutDefinition = closed_actor.state._damage_layout
	var openings: Array = layout.declared_openings if layout != null else []
	var opening_ids: Array = []
	for opening in openings: opening_ids.append(str(opening.get("id","")))
	print("[CD07 open-top] R1 delivered packet => layout=%s ; armor_patches=%d ; declared_openings=%d %s" % [
		str(layout.id) if layout != null else "<none>",layout.armor_patches.size() if layout != null else -1,
		openings.size(),str(opening_ids)])
	check(openings.size()>0,
		"CD07 open-top R1 a real packet of this class ALREADY declares %d openings through its own geometry, so the route into the connectivity rule is live on the loaded path" % openings.size())
	check(layout != null and layout.armor_patches.size()>10,
		"CD07 open-top R1 and it is a full layout rather than a hand-made plate, with %d armour patches: my earlier zero-opening reading was my own fixture, not a delivered packet" % (layout.armor_patches.size() if layout != null else -1))

	var tag_open := "test_cd007_open_forced"
	var open_packet := base.duplicate(true)
	open_packet.id = tag_open
	open_packet.geometry["open_top"] = true
	for source in open_packet.sources.values(): source.applies_to_identity_ids=[open_packet.id]
	var open_sources := fixture_asset(open_packet,1.0)
	var open_registered := VehicleCatalog.new(open_sources).register(open_packet,defs)
	print("[CD07 open-top] R2 forcing open_top=true => ok=%s ; %s" % [str(open_registered.ok),JSON.stringify(open_registered)])
	check(not open_registered.ok,
		"CD07 open-top R2 ENFORCED CONSTRAINT: forcing open_top on a modern packet is REFUSED, exactly as design point five requires rather than being quietly allowed for a test")
	check(JSON.stringify(open_registered).contains("actual content differs from field record"),
		"CD07 open-top R2 and the refusal names why: the geometry actual content no longer matches its field record")
	print("[CD07 open-top] conclusion: the open-versus-covered contrast belongs to the HISTORICAL open-top representative the order permits, not to a modern packet forced open")
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_OPEN_TOP_ROUTE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)