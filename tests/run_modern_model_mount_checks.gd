extends "res://tests/run_bound_model_package_checks.gd"
const Adapter := preload("res://scripts/content/modern_model_mount_adapter.gd")

func _run() -> void:
	owned_directory="res://assets/vehicles/test_mount_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(not DirAccess.dir_exists_absolute(owned_directory) and DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"create isolated adapter output directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var catalog := _read("res://assets/research/soviet_german_tree.json")
	var persisted_sources := _read("res://authoring/reference_data/modern_bound/model_sources.json")
	for id in Adapter.SPECS:
		var persisted := _read("res://authoring/reference_data/modern_bound/"+str(id)+".json")
		check(VehicleContentPipeline.validate_package(persisted,persisted_sources).ok and not persisted.completion.combat_admitted,"persisted model candidate validates without combat admission: "+str(id))
		check(FileAccess.get_sha256(persisted.sources.mount_recipe.artifact)==persisted.sources.mount_recipe.sha256,"persisted binding records current recipe hash")
		for row in catalog.vehicles:
			if row.id==id: await actual_model_case(row)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	check(VehicleCatalog.IDS.size()==4 and not "ussr_t_80b" in VehicleCatalog.IDS and not "germ_leopard_2a4" in VehicleCatalog.IDS,"binding increment does not bypass complete-vehicle admission")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("MODERN_MODEL_MOUNT_CHECKS_PASS" if failures==0 else "MODERN_MODEL_MOUNT_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func actual_model_case(row: Dictionary) -> void:
	var original := _read("res://authoring/reference_data/modern_vehicles/"+str(row.id)+".json")
	var prepared := Adapter.prepare(original,row)
	print("[ADAPTER] ",row.id," ",prepared.get("errors"))
	check(prepared.ok,"exact published model receives explicit articulated mounts: "+str(row.id))
	if not prepared.ok: return
	check(not original.has("model_binding") and not prepared.combat_admitted,"adapter does not mutate original candidate or mark combat complete")
	var packet: Dictionary=prepared.packet
	check(prepared.source_meshes_preserved>30 and prepared.muzzle_tip_vertices>=3,"all original visible meshes retain neutral world poses and muzzle uses actual gun tip")
	if row.id=="germ_leopard_2a4": check(absf(packet.geometry.gun_origin[0])>0.05,"Leopard actual lateral gun-pivot offset is retained")
	for defect in ["axes","running_mesh"]:
		var raw_document := GLTFDocument.new(); var raw_state := GLTFState.new()
		raw_document.append_from_buffer(FileAccess.get_file_as_bytes(row.model.path),"",raw_state)
		var altered := raw_document.generate_scene(raw_state) as Node3D
		if defect=="axes": Adapter.unique(altered,"GunPivot").rotation.z=0.1
		else: Adapter.unique(altered,"track_l").free()
		check(not Adapter.adapt_scene(original,altered,Adapter.SPECS[row.id]).ok,"changed source rig is rejected: "+defect)
		altered.free()
	var source_before := FileAccess.get_sha256(row.model.path)
	var binding: Dictionary=prepared.binding
	binding.model.path=owned_directory.path_join(str(row.id)+".glb")
	assign_owner(prepared.scene,prepared.scene)
	var document := GLTFDocument.new(); var state := GLTFState.new()
	check(document.append_from_scene(prepared.scene,state)==OK and document.write_to_filesystem(state,binding.model.path)==OK,"adapted real model exports to its own artifact")
	prepared.scene.free(); artifact_paths.append(binding.model.path)
	binding.model.sha256=FileAccess.get_sha256(binding.model.path); packet.model_binding=binding
	var registry := {row.id:{"id":row.id,"path":binding.model.path,"sha256":binding.model.sha256,"resource_version":"ENGINEERING-MOUNT-ADAPTER-v1","delivery_status":"delivered","provenance":"authored_asset"}}
	var checked := VehicleContentPipeline.validate_package(packet,registry)
	print("[PIPELINE] ",row.id," ",checked.errors)
	check(checked.ok,"real model and measured mounts pass complete engineering package validation")
	if not checked.ok: return
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new(registry)
	check(catalog.register(packet,defs).ok,"isolated catalog registers real bound modern model")
	var world := Node3D.new(); root.add_child(world); TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(200,1,200))
	var actor := VehicleActor.new(); world.add_child(actor)
	var setup := actor.setup(defs,row.id,"bound_modern_test",1,Transform3D.IDENTITY,2,null)
	check(setup.ok,"real Actor installs source hull, turret, cannon and running branches")
	if not setup.ok: print(setup.errors); world.free(); return
	await _frames(20)
	var before := actor.tank.position
	for tick in 60:
		var command := VehicleCommand.new(); command.throttle=1; actor.submit_command(command); await physics_frame
	check(actor.tank.position.distance_to(before)>0.3,"ordinary driving command moves the actual bound model")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	actor.turret.rotation.y=0.4; actor.turret.barrel_pivot.rotation.x=0.1
	var source_muzzle := actor.turret.recoil_visual.find_child("Muzzle",true,false) as Node3D
	check(source_muzzle!=null and source_muzzle.global_position.distance_to(actor.turret.muzzle.global_position)<0.001,"authored and live muzzle remain coincident after yaw and pitch")
	var visual_turrets := actor.find_children("Bound_turret","Node3D",true,false)
	check(visual_turrets.size()==1 and visual_turrets[0].get_child(0).name=="TurretPivot" and actor.tank.track_left_frame.find_child("track_l",true,false)!=null and actor.tank.track_right_frame.find_child("track_r",true,false)!=null,"articulated source turret is unique and real tracks move on independent frames")
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	manager.exclude_provider=func(_id: String,_life: int) -> Array[RID]: return [actor.tank.get_rid()]
	actor.gunner.projectile_manager=manager; actor.gunner.round_provider=func() -> int: return 3033; actor.gunner.aim_preview_enabled=false
	var rounds := actor.gunner.rounds_remaining
	var fire := VehicleCommand.new(); fire.fire_requested=true; actor.submit_command(fire); actor.advance_standalone_tick(1.0/60.0)
	var projectile := manager.get_projectile_state(actor.gunner.last_projectile_id)
	check(projectile!=null and projectile.launch_position.distance_to(actor.turret.muzzle.global_position)<0.001 and actor.gunner.rounds_remaining==rounds-1,"normal fire consumes one round at actual source cannon muzzle")
	await capture_actual(actor,row.id)
	manager.cancel_all("cancelled_mount_test"); world.queue_free(); await _frames(3)
	check(FileAccess.get_sha256(row.model.path)==source_before,"source delivery bytes remain unchanged")
	for defect in ["identity","hash","status"]:
		var bad := row.duplicate(true)
		if defect=="identity": bad.id="nearby_variant"
		elif defect=="hash": bad.model.sha256="1".repeat(64)
		else: bad.model.status="work_in_progress"
		check(not Adapter.prepare(original,bad).ok,"adapter rejects "+defect+" before source mutation")

func capture_actual(actor: VehicleActor, identity: String) -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size() or DisplayServer.get_name()=="headless": return
	var stage := Node3D.new(); root.add_child(stage); WorldLighting.build(stage)
	var camera := Camera3D.new(); stage.add_child(camera); camera.position=actor.tank.position+Vector3(8,5,10); camera.look_at(actor.tank.position+Vector3(0,1.3,0)); camera.current=true
	var canvas := CanvasLayer.new(); stage.add_child(canvas); var label := Label.new(); canvas.add_child(label); label.position=Vector2(24,20)
	label.text="ACTUAL MODEL / MEASURED MOUNTS\n"+identity+"\nCandidate armor fit and complete combat admission pending"
	await _frames(4); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[index+1])
	check(root.get_texture().get_image().save_png(str(args[index+1]).path_join(identity+".png"))==OK,"capture actual articulated source model")
	stage.queue_free(); await _frames(2)
