extends "res://tests/run_bound_model_package_checks.gd"
## Original modern combat envelopes exercised with clearly TEST ONLY generated art.
## Candidate models are never relabelled delivered and the real roster stays unchanged.
const MODERN := ["ussr_t_80b","germ_leopard_2a4"]
const PACKAGES := "res://authoring/reference_data/modern_vehicles/"

func candidate_case(id: String) -> void:
	var original := _read(PACKAGES+id+".json")
	check(original.id==id and original.completion.status=="candidate_only" and not original.historical_verified,"modern candidate retains exact source identity and incomplete status")
	check(ReferenceEvidenceGate.check(original).ok,"modern candidate has independent source/design field evidence")
	var checked := VehicleContentPipeline.validate_package(original)
	print("[CANDIDATE] ",id," ",checked.errors)
	check(not checked.ok and str(checked.errors).contains("model_binding"),"unbound modern candidate cannot enter production")
	var packet := original.duplicate(true)
	packet.id="test_combat_"+id
	packet.display_name="TEST ONLY combat geometry for "+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var validated := VehicleContentPipeline.validate_package(packet,sources)
	check(validated.ok,"complete candidate geometry and equipment validate with separate TEST ONLY visual artifact")
	if not validated.ok: print("[DETAIL] ",validated.errors); return
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(sources).register(packet,defs).ok,"modern combat engineering fixture registers transactionally")
	var world := Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(200,1,200))
	var actor := VehicleActor.new(); world.add_child(actor)
	var setup := actor.setup(defs,packet.id,"candidate_combat",1,Transform3D.IDENTITY,2,null)
	check(setup.ok,"actual Actor installs distinct modern combat hull and internal layout")
	if not setup.ok: print(setup.errors); world.queue_free(); await _frames(3); return
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager)
	manager.set_physics_process(false)
	manager.exclude_provider=func(_entity: String,_life: int) -> Array[RID]: return [actor.tank.get_rid()]
	actor.gunner.projectile_manager=manager; actor.gunner.round_provider=func() -> int: return 3032
	actor.gunner.aim_preview_enabled=false
	await _frames(25)
	check(actor.state.crew_states.size()==(4 if id=="germ_leopard_2a4" else 3),"actual crew runtime uses exact three/four-person roster")
	check(actor.gunner.rounds_remaining==packet.runtime.rounds and actor.gunner.inventory.conserved(),"actual typed inventory conserves source rack capacity")
	var initial_stowage: Dictionary=actor.gunner.inventory.snapshot().rack_shells.duplicate(true)
	var heat_id: String=actor.gunner.shell_options[1].id
	check(actor.gunner.inventory.available_in_rack("ammo_ready",heat_id)>0,"proportional initial stowage places selectable HEAT in real ready rack")
	check(actor.definition.loading_profile.mode==("crew" if id=="germ_leopard_2a4" else "automatic"),"actual actor installs explicit separate crew/automatic loading policy")
	var start := actor.tank.global_position
	for i in 90:
		var command := VehicleCommand.new(); command.throttle=1; actor.submit_command(command); await physics_frame
	check(actor.tank.global_position.distance_to(start)>1 and actor.tank.forward_speed>0.3,"candidate geometry drives on actual ground with authored modern tuning")
	actor.reset_vehicle(); await _frames(10)
	check(actor.gunner.select_shell(1),"modern HEAT selection enters actual loading inventory")
	var command := VehicleCommand.new(); command.fire_requested=true
	actor.submit_command(command); await _frames(2)
	var rod := manager.get_projectile_state(actor.gunner.last_projectile_id)
	check(rod!=null and rod.effect_policy=="long_rod" and rod.launch_position.distance_to(actor.turret.muzzle.global_position)<0.05,"normal command fires the chambered APFSDS from real modern-length muzzle")
	await _frames(ceili(packet.runtime.reload_time*60)+8)
	check(actor.gunner.shell.effect_policy=="chemical" and actor.gunner.cooldown_left==0,"independent shot reload chambers selected HEAT without using replenishment interval")
	actor.submit_command(command); await _frames(2)
	var heat := manager.get_projectile_state(actor.gunner.last_projectile_id)
	check(heat!=null and heat.effect_policy=="chemical" and heat.chemical_profile.penetration_mm==packet.shell_catalog.shells[1].chemical_profile.penetration_mm,"normal second shot uses explicit chemical budget and reference-derived carrier speed")
	check(actor.gunner.rounds_remaining==packet.runtime.rounds-2 and actor.gunner.inventory.conserved(),"modern APFSDS/HEAT normal firing conserves actual finite rack stock")
	for projectile in [rod,heat]:
		if projectile==null: continue
		var direction: Vector3=projectile.launch_velocity.normalized()
		var target := ArmorTrainingTargets.build([{"center":projectile.launch_position+direction*5,"thickness":30},{"center":projectile.launch_position+direction*7,"thickness":1000}],"modern_ammo_target",1)
		for patch in target.layout.armor_patches: patch.material_kind="rolled"
		manager.advance_projectile(projectile,0.05,[target],world.get_world_3d().direct_space_state)
		check(not projectile.contacts.is_empty() and projectile.contacts[0].result=="penetrated","normally fired "+projectile.effect_policy+" resolves real first armor plate")
		var record := manager.shot_records.get_record(manager.shot_records.count()-1)
		check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"modern "+projectile.effect_policy+" produces validated combat replay")
	manager.cancel_all("cancelled_modern_candidate")
	actor.reset_vehicle(); await _frames(3)
	check(actor.gunner.rounds_remaining==packet.runtime.rounds and actor.gunner.inventory.conserved() and actor.gunner.inventory.snapshot().rack_shells==initial_stowage,"reset restores exact modern candidate rack mix, chamber and loading state")
	await capture_bound(actor,1.0)
	world.queue_free(); await _frames(3)

func _run() -> void:
	stowage_cases()
	await garage_stowage_case()
	owned_directory="res://assets/vehicles/test_modern_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(not DirAccess.dir_exists_absolute(owned_directory) and DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"create isolated temporary engineering model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	for id in MODERN: await candidate_case(id)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	check(VehicleCatalog.IDS.size()==4 and not MODERN[0] in VehicleCatalog.IDS and not MODERN[1] in VehicleCatalog.IDS,"modern engineering run never promotes unfinished candidates to official roster")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("MODERN_CANDIDATE_CHECKS_PASS" if failures==0 else "MODERN_CANDIDATE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func stowage_cases() -> void:
	var inventory := AmmoInventory.new()
	check(inventory.configure_loadout({"ap":30,"heat":12},["ready","reserve"],{"ready":15,"reserve":27},"ap","proportional"),"proportional loading configures exact 42-round stock")
	check(inventory.snapshot().rack_shells=={"ready":{"ap":10,"heat":4},"reserve":{"ap":19,"heat":8}} and inventory.chamber_shell=="ap" and inventory.chamber_from=="ready","ready rack receives 11 AP including chamber and four HEAT without overcapacity")
	var before := inventory.snapshot()
	check(not inventory.configure_loadout({"ap":1},["ready"],{"ready":1},"ap","invented") and inventory.snapshot()==before,"invalid initial distribution rejects before changing live stock")
	var other := AmmoInventory.new()
	other.configure_loadout({"heat":12,"ap":30},["ready","reserve"],{"ready":15,"reserve":27},"ap","proportional")
	check(other.snapshot().rack_shells==before.rack_shells,"proportional rack allocation is independent of shell dictionary ordering")
	var all_conserved := true
	for amount in range(0,43):
		var counts := {"ap":ceili(amount*0.7),"heat":amount-ceili(amount*0.7)}
		all_conserved=all_conserved and other.configure_loadout(counts,["zero","ready","reserve"],{"zero":0,"ready":15,"reserve":27},"ap","proportional") and other.conserved() and other.shell_counts()==counts
	check(all_conserved,"partial and empty loadouts conserve every type across zero/full-capacity racks")
	check(not LoadingProfile.from_packet({"initial_distribution":"invented"}).ok,"loading profile rejects unsupported distribution policy")

func garage_stowage_case() -> void:
	# Isolated legacy ID permits the curated garage path without publishing a modern vehicle.
	var packet := _fixture(2)
	packet["loading_profile"]={"mode":"crew","initial_distribution":"proportional","shot_feed_rack_ids":["ammo_floor_right"]}
	packet.facts["loading.profile"]=_claim(packet.loading_profile.duplicate(true),"structured")
	packet.facts["equipment.loading"]=_claim({"mode":"crew","crew_role":"loader","required_module_ids":[]},"structured")
	var service := GarageService.new(); service.definitions.vehicles.erase(packet.id)
	var registered := service.catalog.register(packet,service.definitions)
	check(registered.ok,"isolated garage admits explicit proportional rack policy")
	if not registered.ok: print(registered.errors); return
	var loadout := service.default_loadout(packet.id)
	var preview := service.build_loadout(loadout)
	check(preview.ok and preview.inventory.chamber_from=="ammo_floor_right","garage reserves chamber from explicit ready rack rather than module array order")
	var actor := VehicleActor.new(); actor.presentation_enabled=false; root.add_child(actor)
	var setup := actor.setup(service.definitions,packet.id,"garage_stowage",1,Transform3D.IDENTITY,2,null)
	check(setup.ok and service.install(actor,loadout),"garage loadout installs through real actor and gunner")
	if setup.ok and preview.ok:
		check(actor.gunner.inventory.snapshot().rack_shells==preview.inventory.rack_shells and actor.gunner.inventory.chamber_from==preview.inventory.chamber_from,"garage preview and actual gunner use identical ready-rack order and typed stowage")
	actor.queue_free(); await _frames(3)

func capture_bound(actor: VehicleActor, _unit: float) -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): return
	check(DisplayServer.get_name()!="headless","modern geometry capture requires real window")
	if DisplayServer.get_name()=="headless": return
	# Replace only the temporary engineering fixture's running cuboids with the
	# actual track module envelopes; no external authoring model is edited.
	for side in ["left","right"]:
		var frame: Node3D=actor.tank.track_left_frame if side=="left" else actor.tank.track_right_frame
		var mesh := frame.find_child("RunningMesh",true,false) as MeshInstance3D
		var module: ModuleVolumeDefinition
		for entry in actor.damage_layout_override.modules:
			if entry.id=="track_"+side: module=entry
		if mesh!=null and module!=null:
			var box := BoxMesh.new(); box.size=module.size_m; mesh.mesh=box
			mesh.global_transform=frame.global_transform*module.local_box_transform
	var stage := Node3D.new(); root.add_child(stage)
	WorldLighting.build(stage)
	var camera := Camera3D.new(); stage.add_child(camera); camera.position=Vector3(8,5,-10)
	camera.look_at(Vector3(0,1.2,0)); camera.current=true
	var canvas := CanvasLayer.new(); stage.add_child(canvas)
	var label := Label.new(); canvas.add_child(label); label.position=Vector2(24,20); label.add_theme_font_size_override("font_size",20)
	label.text="CANDIDATE COMBAT GEOMETRY / GENERATED TEST ART\n"+actor.definition.id+"\nOriginal envelope and internal modules; external model NOT DELIVERED"
	actor.label3d.visible=false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[index+1])
	check(root.get_texture().get_image().save_png(str(args[index+1]).path_join(actor.definition.id+".png"))==OK,"actual distinct modern combat envelope image saved")
	stage.queue_free(); await process_frame
