extends SceneTree
## Rebuild explicit model mount candidates from project-frozen sources. No roster promotion.
const Adapter := preload("res://scripts/content/modern_model_mount_adapter.gd")
const ART := "res://assets/vehicles/modern_bound"
const OUT := "res://authoring/reference_data/modern_bound"

func _initialize() -> void: call_deferred("run")

func owners(root_node: Node, node: Node) -> void:
	for child in node.get_children(): child.owner=root_node; owners(root_node,child)

func save_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("Cannot write "+path); return false
	file.store_string(JSON.stringify(value,"  ",true,true)+"\n"); file.close()
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ART); DirAccess.make_dir_recursive_absolute(OUT)
	var ignore := FileAccess.open(ART.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/research/soviet_german_tree.json"))
	var sources := {}; var reports := {}; var failures: Array=[]
	for id in Adapter.SPECS:
		var row: Dictionary={}
		for candidate in catalog.vehicles:
			if candidate.id==id: row=candidate; break
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/reference_data/modern_vehicles/"+id+".json"))
		var prepared := Adapter.prepare(original,row)
		if not prepared.ok: failures.append({"id":id,"errors":prepared.errors}); continue
		var path := ART.path_join(id+".glb")
		owners(prepared.scene,prepared.scene)
		var document := GLTFDocument.new(); var state := GLTFState.new()
		var saved := document.append_from_scene(prepared.scene,state)==OK and document.write_to_filesystem(state,path)==OK
		prepared.scene.free()
		if not saved: failures.append({"id":id,"errors":["derived GLB export failed"]}); continue
		var packet: Dictionary=prepared.packet
		packet.model_binding=prepared.binding; packet.model_binding.model.path=path; packet.model_binding.model.sha256=FileAccess.get_sha256(path)
		var source := {"id":id,"path":path,"sha256":packet.model_binding.model.sha256,"resource_version":"ENGINEERING-MOUNT-ADAPTER-v1","delivery_status":"delivered","provenance":"authored_asset"}
		var checked := VehicleContentPipeline.validate_package(packet,{id:source})
		if not checked.ok: failures.append({"id":id,"errors":checked.errors}); continue
		sources[id]=source
		packet.admission_status="candidate"
		packet.completion["model_mount_binding"]="engineering_checked"
		packet.completion["armor_surface_fit"]="pending"
		packet.completion["combat_admitted"]=false
		if not save_json(OUT.path_join(id+".json"),packet): failures.append({"id":id,"errors":["candidate packet write failed"]}); continue
		reports[id]={"source":prepared.source,"derived":source,"source_meshes_preserved":prepared.source_meshes_preserved,"muzzle_tip_vertices":prepared.muzzle_tip_vertices,"measured":prepared.measured,"geometry_mounts":{"turret_origin":packet.geometry.turret_origin,"gun_origin":packet.geometry.gun_origin,"barrel_length":packet.geometry.barrel_length},"engineering_checked":true,"combat_admitted":false,"historical_verified":false,"human":"NOT_RUN","remaining":["Armor surface fit","Complete self-damage and restoration matrix","Final battle and trial admission"]}
	if failures.is_empty() and sources.size()==Adapter.SPECS.size():
		if not save_json(OUT.path_join("model_sources.json"),sources) or not save_json(OUT.path_join("mount_report.json"),reports): quit(1); return
		print("MODERN_MODEL_BINDINGS_BUILD_PASS ",sources.keys()); quit(0)
	else:
		print("MODERN_MODEL_BINDINGS_BUILD_FAIL ",failures); quit(1)
