extends "res://tests/run_reference_admission_checks.gd"
## TEST ONLY generated GLB uses an existing authored layout; never publishes a vehicle.
var owned_directory := ""
var artifact_paths: Array[String] = []

func node(parent: Node3D, label: String, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var result := Node3D.new(); result.name=label; result.position=origin; parent.add_child(result)
	return result

func assign_owner(root_node: Node, parent: Node) -> void:
	for child in parent.get_children():
		child.owner=root_node; assign_owner(root_node,child)

func fixture_asset(packet: Dictionary, unit: float, include_tube: bool = true) -> Dictionary:
	var layout := HistoricalVehicleGeometry.build(packet)
	var root_node := Node3D.new(); root_node.name="BindingFixture"
	var hull := node(root_node,"Vehicle")
	var turret := node(hull,"Turret",HistoricalVehicleGeometry.vec(packet.geometry.turret_origin)/unit)
	var gun := node(turret,"Gun",HistoricalVehicleGeometry.vec(packet.geometry.gun_origin)/unit)
	var muzzle := node(gun,"Muzzle",Vector3(0,0,-float(packet.geometry.barrel_length))/unit)
	var left := node(hull,"RunningLeft",Vector3(-1,0,0)/unit)
	var right := node(hull,"RunningRight",Vector3(1,0,0)/unit)
	var roots := {"hull":hull,"turret":turret,"barrel":gun,"running_left":left,"running_right":right,"drive":hull}
	if include_tube:
		var tube:=MeshInstance3D.new(); tube.name="GunTube"
		var shape:=BoxMesh.new(); shape.size=Vector3(0.15,0.15,float(packet.geometry.barrel_length))/unit
		tube.mesh=shape; tube.position.z=-shape.size.z*0.5; gun.add_child(tube)
	for patch in layout.armor_patches:
		var vertices := PackedVector3Array()
		for vertex in patch.vertices_local_m: vertices.append(vertex/unit)
		var mesh := MeshInstance3D.new(); mesh.name="Plate_"+patch.id
		mesh.mesh=ArmorPatchMesh.build_surface(vertices,patch.triangles,patch.outward_normal_local)
		roots[patch.part_id].add_child(mesh)
	for branch in [left,right]:
		var mesh := MeshInstance3D.new(); mesh.name="RunningMesh"
		var box := BoxMesh.new(); box.size=Vector3(0.2,0.2,3)/unit; mesh.mesh=box; branch.add_child(mesh)
	var attachments := {"modules":{},"crew":{}}
	for kind in ["modules","crew"]:
		for item in (layout.modules if kind=="modules" else layout.crew_stations):
			var parent: Node3D=roots[item.part_id]
			var marker := node(parent,"Anchor_"+item.id)
			marker.transform=item.local_box_transform; marker.position/=unit
			if item.part_id in ["running_left","running_right"]: marker.position-=parent.position
			attachments[kind][item.id]=str(root_node.get_path_to(marker))
	var stats := {"meshes":0,"bounds":AABB()}; var transforms := {}; var errors: Array[String]=[]
	ModelBindingValidator._walk(root_node,Transform3D.IDENTITY,transforms,stats,errors)
	var size: Vector3=stats.bounds.size*unit
	var binding := {"schema_version":1,"vehicle_id":packet.id,
		"model":{"source_vehicle_id":packet.id,"path":owned_directory.path_join("fixture_"+str(artifact_paths.size())+".glb"),"sha256":"0".repeat(64)},
		"units":{"source_unit":"m" if unit==1 else "cm","meters_per_unit":unit,"dimensions_m":[size.x,size.y,size.z],"tolerance_fraction":0.001,"attachment_tolerance_m":0.001},
		"nodes":{},"axes":{"turret":{"space":"local","axis":[0,1,0],"limits_deg":[packet.runtime.get("yaw_min",-180),packet.runtime.get("yaw_max",180)]},
		"gun":{"space":"local","axis":[1,0,0],"limits_deg":[packet.runtime.pitch_min,packet.runtime.pitch_max]}},"internal_attachments":attachments}
	for role in ["hull","turret","gun","muzzle","running_left","running_right"]:
		binding.nodes[role]=str(root_node.get_path_to(muzzle if role=="muzzle" else roots["barrel" if role=="gun" else role]))
	assign_owner(root_node,root_node)
	var document := GLTFDocument.new(); var state := GLTFState.new()
	check(document.append_from_scene(root_node,state)==OK and document.write_to_filesystem(state,binding.model.path)==OK,"real Godot GLB export creates isolated test artifact")
	root_node.free(); artifact_paths.append(binding.model.path)
	binding.model.sha256=FileAccess.get_sha256(binding.model.path)
	packet.model_binding=binding
	return {packet.id:{"id":packet.id,"path":binding.model.path,"sha256":binding.model.sha256,
		"resource_version":"TEST-ONLY-binding-fixture-v1","delivery_status":"delivered","provenance":"authored_asset"}}

func package_case(unit: float) -> void:
	var packet := _fixture(2)
	packet.id="test_bound_vehicle_m" if unit==1 else "test_bound_vehicle_cm"
	packet.sources.fixture.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,unit)
	var validated := VehicleContentPipeline.validate_package(packet,sources)
	if not validated.ok: print("[DETAIL] ",validated.errors)
	check(validated.ok and validated.model_check.artifact_verified and not validated.model_check.historical_verified,"full pipeline binds actual artifact without historical promotion")
	if not validated.ok: return
	for defect in ["source_missing","source_malformed","source_candidate","source_version","source_hash","source_id","missing_binding","missing_muzzle","limits","pivot","external_path"]:
		var bad := packet.duplicate(true); var registry := sources.duplicate(true)
		match defect:
			"source_missing": registry.clear()
			"source_malformed": registry[packet.id]=[]
			"source_candidate": registry[packet.id].delivery_status="candidate_only"
			"source_version": registry[packet.id].resource_version=""
			"source_hash": registry[packet.id].sha256="1".repeat(64)
			"source_id": registry[packet.id].id="nearby_variant"
			"missing_binding": bad.erase("model_binding")
			"missing_muzzle": bad.model_binding.nodes.muzzle="Vehicle/Missing"
			"limits": bad.model_binding.axes.gun.limits_deg=[-1,1]
			"pivot":
				bad.geometry.barrel_length+=0.2
				bad.facts["geometry.exterior"].value=bad.geometry.duplicate(true)
			"external_path": bad.model_binding.model.path="E:/external/model.glb"
		var failed_registration := VehicleCatalog.new(registry); var rejected_defs := VehicleDefs.new()
		check(not failed_registration.register(bad,rejected_defs).ok and rejected_defs.vehicles.is_empty() and failed_registration.packages.is_empty(),"real registration transaction rejects "+defect)
	var catalog := VehicleCatalog.new(sources); var defs := VehicleDefs.new()
	check(catalog.register(packet,defs).ok,"real catalog registers complete bound reference fixture")
	# Source file has a different filename than assets/vehicles/<id>.glb.
	var actor := VehicleActor.new(); actor.presentation_enabled=false; root.add_child(actor)
	var setup := actor.setup(defs,packet.id,"bound_fixture",1,Transform3D.IDENTITY,GameConfig.VIS_LAYER_VEHICLE,null)
	if not setup.ok: print("[DETAIL] setup ",setup.errors)
	check(setup.ok,"actual Actor.setup loads checked explicit source instead of fixed legacy filename")
	if setup.ok:
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		var hull := actor.tank.hull_frame.get_node("Bound_hull") as Node3D
		var running := actor.tank.track_left_frame.get_node("Bound_running_left") as Node3D
		check(hull.get_meta("model_sha256")==packet.model_binding.model.sha256 and _near(hull.scale.x,unit),"runtime visual uses admitted hash and real meter conversion")
		check(hull.find_child("Turret",true,false)==null and hull.find_child("RunningLeft",true,false)==null,"articulated source subtrees are installed exactly once")
		check(actor.turret.recoil_visual!=null and actor.turret.recoil_visual.get_node("Bound_gun")!=null,"gun visual attaches to actual recoil carrier")
		var visual := hull.find_child("Plate_hull_0_0",true,false) as MeshInstance3D
		var patch: ArmorPatchDefinition=validated.layout.armor_patches[0]
		var vertex: Vector3=visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
		check((visual.global_transform*vertex).distance_to(actor.tank.hull_frame.global_transform*patch.vertices_local_m[0])<0.001,"decoded visible armor matches actual query geometry after unit conversion")
		var initial := running.global_position
		actor.tank.hull_frame.position.y=0.08
		check(running.global_position.is_equal_approx(initial) and _near(hull.global_position.y,0.08),"sprung hull motion leaves independent running frame stationary")
		actor.turret.rotation.y=0.4; actor.turret.barrel_pivot.rotation.x=0.1
		var source_marker := actor.turret.recoil_visual.find_child("Muzzle",true,false) as Node3D
		check(source_marker.global_position.distance_to(actor.turret.muzzle.global_position)<0.001,"actual yaw/pitch keeps authored muzzle and live firing marker coincident")
		var manager := ProjectileManager.new(); manager.presentation_enabled=false; root.add_child(manager); manager.set_physics_process(false)
		actor.gunner.projectile_manager=manager; actor.gunner.round_provider=func() -> int: return 3031
		actor.turret.clear_aim_point(); actor.turret.snap_to_aim()
		var before_rounds := actor.gunner.rounds_remaining
		var command := VehicleCommand.new(); command.fire_requested=true
		check(actor.submit_command(command),"bound vehicle accepts ordinary fire command")
		actor.advance_standalone_tick(1.0/60.0)
		var launched := manager.get_projectile_state(actor.gunner.last_projectile_id)
		check(launched!=null and launched.launch_position.distance_to(actor.turret.muzzle.global_position)<0.001 and actor.gunner.rounds_remaining==before_rounds-1,"ordinary vehicle command fires from bound physical muzzle and consumes one round")
		manager.cancel_all("cancelled_binding_fixture"); manager.queue_free()
		var pose := actor.turret.transform
		actor.state.destroy_once("ammo_detonation",{"fixture":"binding_lifecycle_only"}); actor._commit_death()
		check(is_instance_valid(actor.wreck_turret) and actor.turret.get_parent()==actor.wreck_turret,"explicit lifecycle fixture detaches complete bound turret subtree")
		actor.wreck_turret.position.y+=1.0
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)
		check(snapshot.part_world_transforms.turret.is_equal_approx(actor.turret.global_transform) and source_marker.global_position.distance_to(actor.turret.muzzle.global_position)<0.001,"detached bound turret keeps visible cannon, muzzle and query frame together")
		actor.reset_vehicle()
		check(not actor.state.destroyed and actor.turret.get_parent()==actor.tank.hull_frame and actor.turret.transform.is_equal_approx(pose) and actor.gunner.rounds_remaining==before_rounds,"actual reset restores bound turret, stock and original hull parent")
		await capture_bound(actor,unit)
	actor.queue_free(); await _frames(2)
	var original := FileAccess.get_file_as_bytes(packet.model_binding.model.path)
	var file := FileAccess.open(packet.model_binding.model.path,FileAccess.WRITE); file.store_buffer(original); file.store_8(0); file.close()
	var stale := VehicleActor.new(); stale.presentation_enabled=false; root.add_child(stale)
	check(not stale.setup(defs,packet.id,"stale",1,Transform3D.IDENTITY,2,null).ok and not stale.is_physics_processing(),"changed artifact after admission cannot spawn an active vehicle")
	stale.queue_free(); await _frames(2)
	file=FileAccess.open(packet.model_binding.model.path,FileAccess.WRITE); file.store_buffer(original); file.close()

func _near(a: float,b: float) -> bool: return absf(a-b)<0.0001

func capture_bound(actor: VehicleActor, unit: float) -> void:
	var args:=OS.get_cmdline_user_args(); var index:=args.find("--shot-dir")
	if index<0 or index+1>=args.size(): return
	check(DisplayServer.get_name()!="headless","bound model capture uses real window")
	if DisplayServer.get_name()=="headless": return
	root.size=Vector2i(1280,720)
	var stage:=Node3D.new(); root.add_child(stage)
	WorldArtKit.box(stage,Vector3(0,-0.25,0),Vector3(24,0.5,24),"earth"); WorldLighting.build(stage)
	var camera:=Camera3D.new(); stage.add_child(camera); camera.position=Vector3(7,4,8)
	camera.look_at(Vector3(0,1.5,0)); camera.current=true
	var canvas:=CanvasLayer.new(); stage.add_child(canvas)
	var label:=Label.new(); canvas.add_child(label); label.position=Vector2(24,20)
	label.add_theme_font_override("font",CoreUI.FONT); label.add_theme_font_size_override("font_size",20)
	label.text="模型绑定工程夹具（不代表苏德模型验收）\n原文件单位："+("米" if unit==1 else "厘米")+"；运行时已换算为米\n实际GLB、炮塔／炮口与左右行走机构独立装配"
	actor.label3d.visible=false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[index+1])
	check(root.get_texture().get_image().save_png(str(args[index+1]).path_join("bound_m.png" if unit==1 else "bound_cm.png"))==OK,"actual bound model screenshot saved")
	stage.queue_free(); await process_frame

func _run() -> void:
	owned_directory="res://assets/vehicles/test_binding_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(not DirAccess.dir_exists_absolute(owned_directory) and DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"test creates fresh isolated artifact directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	for unit in [1.0,0.01]: await package_case(unit)
	var invisible := _fixture(); invisible.id="test_missing_gun_visual"; invisible.sources.fixture.applies_to_identity_ids=[invisible.id]
	var sources := fixture_asset(invisible,1.0,false)
	var incomplete := VehicleContentPipeline.validate_package(invisible,sources)
	check(not incomplete.ok and str(incomplete.errors).contains("visible gun envelope"),"complete markers without visible cannon cannot pass package admission")
	var external := _fixture(); external.id="test_external_buffer"; external.sources.fixture.applies_to_identity_ids=[external.id]
	sources=fixture_asset(external,1.0)
	var bytes := FileAccess.get_file_as_bytes(external.model_binding.model.path)
	var json_end := 20+int(bytes.decode_u32(12))
	var manifest: Dictionary=JSON.parse_string(bytes.slice(20,json_end).get_string_from_utf8())
	manifest.buffers[0].uri="outside.bin"
	var encoded := JSON.stringify(manifest).to_utf8_buffer()
	while encoded.size()%4!=0: encoded.append(32)
	var file := FileAccess.open(external.model_binding.model.path,FileAccess.WRITE)
	file.store_32(0x46546c67); file.store_32(2); file.store_32(20+encoded.size()+bytes.size()-json_end)
	file.store_32(encoded.size()); file.store_32(0x4e4f534a); file.store_buffer(encoded); file.store_buffer(bytes.slice(json_end)); file.close()
	external.model_binding.model.sha256=FileAccess.get_sha256(external.model_binding.model.path)
	sources[external.id].sha256=external.model_binding.model.sha256
	incomplete=VehicleContentPipeline.validate_package(external,sources)
	check(not incomplete.ok and str(incomplete.errors).contains("external GLB dependencies"),"matching source hashes cannot admit external buffer dependencies")
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("BOUND_MODEL_PACKAGE_CHECKS_PASS" if failures==0 else "BOUND_MODEL_PACKAGE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
