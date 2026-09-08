extends SceneTree
## Export actual gameplay armor, with part-local coordinates, for Blender authoring.
func _initialize() -> void:
	var target := "res://authoring/vehicles/seeds"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	for id in VehicleCatalog.IDS:
		var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://configs/vehicles/historical/"+id+".json"))
		var result := VehicleContentPipeline.validate_package(packet)
		if not result.ok: push_error(str(result.errors)); quit(1); return
		var patches: Array = []
		for patch in result.layout.armor_patches:
			var vertices: Array = []
			for v in patch.vertices_local_m: vertices.append([v.x,v.y,v.z])
			patches.append({"id":patch.id,"part":patch.part_id,"zone":patch.plate_group_id,"vertices":vertices,"triangles":Array(patch.triangles)})
		var file := FileAccess.open(target+"/"+id+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"packet":packet,"armor":patches},"\t"))
		print("MODEL_SEED "+id+" patches="+str(patches.size()))
	quit(0)
