extends SceneTree
## Synthetic binding fixtures are game rules; they are not complete or historical vehicles.
const ID := "test_binding_vehicle"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("[PASS] " if value else "[FAIL] ")+label)

func child(parent: Node3D, name: String, position: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new(); node.name=name; node.position=position; parent.add_child(node)
	return node

func fixture(unit_scale: float = 1.0) -> Dictionary:
	var model := Node3D.new(); model.name="SameSharedFilename"
	var hull := child(model,"Vehicle")
	var mesh := MeshInstance3D.new(); mesh.name="HullMesh"
	var box := BoxMesh.new(); box.size=Vector3(2,1,4)/unit_scale; mesh.mesh=box; mesh.position.y=0.5/unit_scale; hull.add_child(mesh)
	var turret := child(hull,"Turret",Vector3(0,1,0)/unit_scale)
	var gun := child(turret,"Gun",Vector3(0,0.5,-0.3)/unit_scale)
	child(gun,"Muzzle",Vector3(0,0,-3)/unit_scale)
	child(hull,"RunningLeft",Vector3(-1.2,0,0)/unit_scale)
	child(hull,"RunningRight",Vector3(1.2,0,0)/unit_scale)
	child(hull,"EngineAnchor",Vector3(0,0.3,1)/unit_scale)
	child(turret,"GunnerAnchor",Vector3(0.3,0.2,0)/unit_scale)
	var layout := VehicleLayoutDefinition.new(); layout.id=ID+"_layout"; layout.historical_identity_id=ID
	var engine := ModuleVolumeDefinition.new(); engine.id="engine"; engine.kind="engine"; engine.part_id="hull"; engine.local_box_transform.origin=Vector3(0,0.3,1)
	layout.modules.append(engine)
	var gunner := CrewStationDefinition.new(); gunner.id="gunner"; gunner.role="gunner"; gunner.part_id="turret"; gunner.local_box_transform.origin=Vector3(0.3,0.2,0)
	layout.crew_stations.append(gunner)
	var armor := ArmorPatchDefinition.new(); armor.id="test_plate"; armor.part_id="hull"; layout.armor_patches.append(armor)
	var binding := {"schema_version":1,"vehicle_id":ID,
		"model":{"source_vehicle_id":ID,"path":"user://test_binding_vehicle.glb","sha256":"1".repeat(64)},
		"units":{"source_unit":"m" if unit_scale==1.0 else "cm","meters_per_unit":unit_scale,"dimensions_m":[2,1,4],"tolerance_fraction":0.001,"attachment_tolerance_m":0.001},
		"nodes":{"hull":"Vehicle","turret":"Vehicle/Turret","gun":"Vehicle/Turret/Gun","muzzle":"Vehicle/Turret/Gun/Muzzle","running_left":"Vehicle/RunningLeft","running_right":"Vehicle/RunningRight"},
		"axes":{"turret":{"space":"local","axis":[0,1,0],"limits_deg":[-180,180]},"gun":{"space":"local","axis":[1,0,0],"limits_deg":[-10,20]}},
		"internal_attachments":{"modules":{"engine":"Vehicle/EngineAnchor"},"crew":{"gunner":"Vehicle/Turret/GunnerAnchor"}}}
	return {"model":model,"layout":layout,"binding":binding}

func scene_cases() -> void:
	for scale in [1.0,0.01]:
		var f := fixture(scale)
		var original := JSON.stringify(f.binding)
		var parsed: Variant=JSON.parse_string(original)
		var result := ModelBindingValidator.check_scene(parsed,ID,f.model,f.layout)
		if not result.ok: print("[DETAIL] ",result.errors)
		check(result.ok and result.measured.dimensions_m==[2.0,1.0,4.0],"explicit %s conversion binds actual synthetic geometry"%str(scale))
		check(not result.artifact_verified and not result.historical_verified and result.vehicle_admission=="unchanged","structural success never attests file bytes/history or promotes a vehicle")
		check(JSON.stringify(f.binding)==original and f.model.get_node("Vehicle/Turret/Gun/Muzzle").position==Vector3(0,0,-3)/scale,"validation does not mutate binding arrays or scene transforms")
		f.model.free()
	var defects := ["non_dictionary","schema","unknown_field","vehicle_id","model_id","hash_shape","artifact_path","unit_name","unit_scale","unit_nan","dimensions_nan","dimensions_zero","dimensions_wrong","tolerance","attachment_tolerance","missing_role","wrong_path","absolute_path","parent_path","property_path","unique_path","duplicate_role","axis_space","axis_vector","axis_nan","axis_limits","node_scale","node_shear","node_reflection","node_nan","top_level","gun_parent","muzzle_parent","running_parent","running_sides","muzzle_mesh","muzzle_behind","muzzle_direction","turret_orientation","gun_orientation","missing_layout","layout_identity","layout_empty","missing_attachment","unknown_attachment","attachment_path","attachment_parent","attachment_position","attachment_orientation"]
	for defect in defects:
		var f := fixture()
		var binding: Variant=f.binding
		var model: Node3D=f.model
		var layout: VehicleLayoutDefinition=f.layout
		match defect:
			"non_dictionary": binding=[]
			"schema": binding.schema_version=2
			"unknown_field": binding.historical_verified=true
			"vehicle_id": binding.vehicle_id="same_filename_wrong_variant"
			"model_id": binding.model.source_vehicle_id="different_vehicle"
			"hash_shape": binding.model.sha256="not_a_hash"
			"artifact_path": binding.model.path="vehicle.txt"
			"unit_name": binding.units.source_unit="unknown"
			"unit_scale": binding.units.meters_per_unit=100
			"unit_nan": binding.units.meters_per_unit=NAN
			"dimensions_nan": binding.units.dimensions_m=[2,NAN,4]
			"dimensions_zero": binding.units.dimensions_m=[0,1,4]
			"dimensions_wrong": binding.units.dimensions_m=[200,100,400]
			"tolerance": binding.units.tolerance_fraction=99
			"attachment_tolerance": binding.units.attachment_tolerance_m=99
			"missing_role": binding.nodes.erase("muzzle")
			"wrong_path": binding.nodes.muzzle="Vehicle/Turret/Gun/MuzzleSimilar"
			"absolute_path": binding.nodes.muzzle="/root/Muzzle"
			"parent_path": binding.nodes.muzzle="../Muzzle"
			"property_path": binding.nodes.muzzle="Vehicle:position"
			"unique_path": binding.nodes.muzzle="%Muzzle"
			"duplicate_role": binding.nodes.running_right=binding.nodes.running_left
			"axis_space": binding.axes.gun.space="world"
			"axis_vector": binding.axes.turret.axis=[0,-1,0]
			"axis_nan": binding.axes.gun.axis=[NAN,0,0]
			"axis_limits": binding.axes.gun.limits_deg=[20,-10]
			"node_scale": model.get_node("Vehicle/Turret").scale=Vector3.ONE*2
			"node_shear": model.get_node("Vehicle/Turret").transform=Transform3D(Basis(Vector3.RIGHT,Vector3(0.2,1,0),Vector3.BACK),Vector3(0,1,0))
			"node_reflection": model.get_node("Vehicle/Turret").scale=Vector3(-1,1,1)
			"node_nan": model.get_node("Vehicle/Turret").position=Vector3(NAN,0,0)
			"top_level": model.get_node("Vehicle/Turret").top_level=true
			"gun_parent": binding.nodes.gun="Vehicle/RunningLeft"
			"muzzle_parent": binding.nodes.muzzle="Vehicle/EngineAnchor"
			"running_parent": binding.nodes.running_left="Vehicle/Turret/GunnerAnchor"
			"running_sides": model.get_node("Vehicle/RunningLeft").position.x=1.2
			"muzzle_mesh":
				var marker := model.get_node("Vehicle/Turret/Gun/Muzzle"); marker.free()
				var mesh := MeshInstance3D.new(); mesh.name="Muzzle"; mesh.position=Vector3(0,0,-3); model.get_node("Vehicle/Turret/Gun").add_child(mesh)
			"muzzle_behind": model.get_node("Vehicle/Turret/Gun/Muzzle").position.z=3
			"muzzle_direction": model.get_node("Vehicle/Turret/Gun/Muzzle").rotation.y=PI
			"turret_orientation": model.get_node("Vehicle/Turret").rotation.x=0.5
			"gun_orientation": model.get_node("Vehicle/Turret/Gun").rotation.y=0.5
			"missing_layout": layout=null
			"layout_identity": layout.historical_identity_id="other_vehicle"
			"layout_empty": layout.armor_patches.clear()
			"missing_attachment": binding.internal_attachments.modules.erase("engine")
			"unknown_attachment": binding.internal_attachments.modules.foreign_engine="Vehicle/EngineAnchor"
			"attachment_path": binding.internal_attachments.modules.engine="Vehicle/AbsentAnchor"
			"attachment_parent": binding.internal_attachments.modules.engine="Vehicle/Turret/GunnerAnchor"
			"attachment_position": model.get_node("Vehicle/EngineAnchor").position.z=0
			"attachment_orientation": model.get_node("Vehicle/EngineAnchor").rotation.y=0.3
		check(not ModelBindingValidator.check_scene(binding,ID,model,layout).ok,"reject binding defect: "+defect)
		model.free()

func file_cases() -> void:
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/reference_data/MODEL_INSPECTION_INPUT.json"))
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/reference-models/20260912-170125/MODEL_INSPECTION.json"))
	for source in input.models:
		var f := fixture(); var binding: Dictionary=f.binding
		binding.vehicle_id=source.id; binding.model={"source_vehicle_id":source.id,"path":source.path,"sha256":source.sha256}
		var hull: String="VehicleRoot" if source.id=="germ_leopard_2a4" else "ussr_t_80b"
		binding.nodes={"hull":hull,"turret":hull+"/TurretPivot","gun":hull+"/TurretPivot/GunPivot","muzzle":hull+"/TurretPivot/GunPivot/Muzzle","running_left":hull+"/RunningLeft","running_right":hull+"/RunningRight"}
		for inspected in report.models:
			if inspected.id==source.id: binding.units.dimensions_m=inspected.measured.dimensions_m.duplicate()
		# These are deliberately incomplete expectations, not author-approved bindings.
		binding.internal_attachments={"modules":{},"crew":{}}
		var result := ModelBindingValidator.check_file(binding,source.id,source,null)
		print("[CANDIDATE_GAPS] ",source.id," ",result.errors)
		check(not result.ok and result.artifact_verified and str(result.errors).contains("nodes.muzzle") and str(result.errors).contains("layout:"),source.id+": exact frozen GLB remains rejected for missing muzzle/combat layout")
		check(FileAccess.get_sha256(source.path)==source.sha256 and source.admission=="candidate_only" and result.vehicle_admission=="unchanged",source.id+": reading preserves artifact hash and candidate status")
		var wrong_source: Dictionary=source.duplicate(true); wrong_source.id="different_variant_same_filename"
		check(not ModelBindingValidator.check_file(binding,source.id,wrong_source,null).artifact_verified,"same artifact filename/hash cannot override wrong registry vehicle ID")
		var changed: Dictionary=binding.duplicate(true); changed.model.sha256="0".repeat(64)
		wrong_source=source.duplicate(true); wrong_source.sha256=changed.model.sha256
		var changed_result := ModelBindingValidator.check_file(changed,source.id,wrong_source,null)
		check(not changed_result.ok and not changed_result.artifact_verified and str(changed_result.errors).contains("actual bytes differ"),"binding and registry cannot assert a fabricated hash over actual model bytes")
		f.model.free()

func run() -> void:
	scene_cases(); file_cases()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	if failures==0: print("MODEL_BINDING_CHECKS_PASS")
	quit(0 if failures==0 else 1)
