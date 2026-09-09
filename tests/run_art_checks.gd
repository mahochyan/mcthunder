extends SceneTree
var count:=0
var failed:=0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	count+=1
	if not value: failed+=1
	print(("[PASS] " if value else "[FAIL] ")+label)
func frames(n: int=2) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	var defs:=VehicleDefs.new(); defs.load_defaults(); check(VehicleCatalog.new().load_all(defs).ok,"historical definitions admitted unchanged")
	check(ArtPalette.definition().schema_version==1 and ArtPalette.definition().redistribute_source_allowed,"shared original palette has explicit provenance")
	check(AssetManifestValidator.world_art(true).ok,"all original scenery/effect source hashes and redistribution provenance validate")
	check(not AssetManifestValidator.vehicle("../escape",true).ok,"unknown or traversal vehicle IDs are rejected before file access")
	check(ArtPalette.material("olive")==ArtPalette.material("olive") and is_equal_approx(ArtPalette.material("olive").roughness,0.9),"palette materials are shared at the declared roughness")
	var world:=Node3D.new(); root.add_child(world)
	for id in VehicleCatalog.IDS:
		var manifest:=AssetManifestValidator.vehicle(id,true)
		check(manifest.ok,id+": source/GLB/palette hashes and relative import provenance validate "+str(manifest.errors))
		var actor:=VehicleActor.new(); world.add_child(actor)
		actor.setup(defs,id,"inspect",1,Transform3D.IDENTITY,2,null)
		var visuals:=RecoveryVisuals.new(); actor.add_child(visuals); visuals.setup(actor)
		await frames(3)
		var report:=GeometryOverlay.compare(actor)
		check(report.ok,id+": every visible skin triangle and normal equals current query geometry "+str(report.errors))
		var budget:=AssetBudgetReport.inspect(actor)
		var model_budget:=AssetBudgetReport.inspect_vehicle_model(actor)
		print("[vehicle model budget] ",id," ",JSON.stringify(model_budget))
		check(model_budget.triangles<=AssetBudgetReport.VEHICLE_MODEL_TRIANGLE_BUDGET and model_budget.triangles==int(manifest.manifest.actual_triangles),id+": complete visible vehicle including both tracks matches export count and stays within 1100 triangles")
		var tracks:=actor.tank.get_node_or_null("HistoricalTrackMotion") as HistoricalTrackMotion
		check(tracks!=null and tracks.tracks.size()==2 and VehicleAtlas.material().albedo_texture!=null,id+": actual low-poly track meshes use two independent texture-scroll materials")
		print("[asset budget] ",id," ",JSON.stringify(budget))
		check(budget.triangles<=AssetBudgetReport.VEHICLE_TRIANGLE_BUDGET and budget.draw_surfaces<=AssetBudgetReport.VEHICLE_DRAW_SURFACE_BUDGET,id+": actual vehicle including tracks and allocated wreck effects stays within recorded triangle/draw budget")
		var original:=actor.definition.drive_collision_size
		for tick in 90:
			var cmd:=VehicleCommand.new(); cmd.steer=0.4; cmd.has_aim_point=true; cmd.aim_world_point=Vector3(18,4,-22)
			actor.submit_command(cmd); await frames(1)
		report=GeometryOverlay.compare(actor)
		check(tracks!=null and absf(float(tracks.tracks[0].phase))>0.01 and absf(float(tracks.tracks[1].phase))>0.01,id+": real hull steering advances both track textures")
		check(report.ok and absf(actor.turret.rotation.y)>0.1,id+": real steering/slew preserves moving visual/query alignment")
		check(actor.definition.drive_collision_size==original and actor.turret.recoil_visual.get_parent()==actor.turret.barrel_pivot,id+": original driving envelope and cannon recoil hierarchy preserved")
		var phases: Array = tracks.tracks.map(func(row: Dictionary) -> float: return float(row.phase))
		paused=true
		for i in 3: await process_frame
		check(phases==tracks.tracks.map(func(row: Dictionary) -> float: return float(row.phase)),id+": pause freezes actual track texture phases")
		paused=false; actor.reset_vehicle(); await frames(3)
		check(tracks.tracks.all(func(row: Dictionary) -> bool: return is_zero_approx(float(row.phase))),id+": actual vehicle reset clears both track phases")
		actor.free(); await frames()
	world.free(); await frames()
	for map in [VillageDefinition.create(),IndustrialDefinition.create()]:
		world=Node3D.new(); root.add_child(world)
		if map.id=="hill_village_018": VillageWorld.build(world,map)
		else: IndustrialWorld.build(world,map)
		await frames(3)
		var budget:=AssetBudgetReport.inspect(world)
		print("[world budget] ",map.id," ",JSON.stringify(budget)," props=",WorldProps.placements(map).size())
		check(budget.triangles<65000 and budget.draw_surfaces<150,map.id+": actual world uses bounded mesh batches")
		var nav:=DriveNavigator.new(); nav.configure(map.graph)
		var clear:=true
		for row in WorldProps.placements(map): clear=clear and WorldProps.clear(map,nav,row.position)
		check(clear and WorldProps.placements(map).size()>=4,map.id+": repeatable trees/rocks remain outside driving corridors and structures")
		check(is_equal_approx(world.get_node("SharedDaylight").light_energy,0.85) and is_equal_approx(world.get_node("SharedAtmosphere").environment.ambient_light_energy,0.42),map.id+": both maps share authored daylight/ambient settings")
		for kind in ["tree","rock"]:
			var collision:=WorldCollisionRules.classify(kind)
			check(collision.known and collision.solid and collision.blocks_shell and collision.blocks_los,kind+": one consistent visible/drive/shot/LOS policy")
		world.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("ART_CHECKS_PASS")
	quit(0 if failed==0 else 1)
