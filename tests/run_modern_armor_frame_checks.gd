extends SceneTree
## Compare admitted query armor with the delivered GLB's own articulated frame.
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	check(catalog.load_all(defs).ok and catalog.load_engineering(defs).ok,"corrected packets retain production admission")
	for id in VehicleCatalog.ENGINEERING_IDS:
		if not defs.vehicles.has(id): check(false,"missing modern packet "+id); continue
		var packet: Dictionary=defs.content_packets[id]
		var invalid: Dictionary=packet.duplicate(true)
		invalid.geometry.turret_top=invalid.geometry.turret_bottom
		invalid.facts["geometry.exterior"].value=invalid.geometry.duplicate(true)
		check(not VehicleContentPipeline.validate_package(invalid,catalog.model_sources).ok,"zero-height turret remains rejected")
		invalid.geometry.turret_bottom=NAN
		check(not VehicleContentPipeline.validate_package(invalid,catalog.model_sources).ok,"nonfinite local coordinate remains rejected")
		var layout: VehicleLayoutDefinition=defs.layouts[defs.vehicles[id].layout_id]
		var bound := BoundVehicleModel.check(packet,layout,catalog.model_sources[id],true)
		check(bound.ok,"original model identity and binding remain valid: "+id)
		if not bound.ok: continue
		var source: Node3D=bound.scene
		var pivot: Node3D=source.get_node(packet.model_binding.nodes.turret)
		var armor := pivot.find_child("TurretArmour",true,false) as MeshInstance3D
		check(armor!=null,"delivered model contains its authored turret armor mesh")
		if armor==null: source.free(); continue
		var relative := BoundVehicleModel._relative_pose(source,pivot).affine_inverse()*BoundVehicleModel._relative_pose(source,armor)
		var box: AABB=relative*armor.mesh.get_aabb()
		var unit := float(packet.model_binding.units.meters_per_unit)
		check(absf(packet.geometry.turret_bottom-box.position.y*unit)<.001 and absf(packet.geometry.turret_top-box.end.y*unit)<.001,"combat turret height matches model in pivot-local metres: "+id)
		source.free()
		var actor := VehicleActor.new(); actor.presentation_enabled=false; root.add_child(actor)
		check(actor.setup(defs,id,id,1,Transform3D.IDENTITY,2,null).ok,"actual modern actor installs corrected layout")
		for yaw in [0.0,37.0]:
			actor.turret.rotation_degrees.y=yaw
			var station: CrewStationDefinition=layout.crew_stations[0]
			var part := DamageTrainingLayout.part_node(actor,station.part_id)
			var center: Vector3=part.global_transform*station.local_box_transform.origin
			var lateral := part.global_basis.x.normalized()*6
			var query := ShotQueryService.query({"query_id":"modern_side_probe","from_world":center+lateral,"to_world":center-lateral,"include_modules":true,"include_crew":true},[QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)])
			var exterior := ExternalContactSelector.select_contact(query)
			var crew_distance := INF
			for event in query.get("events",[]):
				if event.get("crew_id","")==station.id: crew_distance=minf(crew_distance,event.distance_m)
			check(exterior.status=="vehicle" and crew_distance<INF and exterior.event.distance_m<crew_distance,"side ray reaches turret armor before occupied crew, yaw=%s: %s"%[yaw,id])
		actor.free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("MODERN_ARMOR_FRAME_CHECKS_PASS" if failed==0 else "MODERN_ARMOR_FRAME_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
