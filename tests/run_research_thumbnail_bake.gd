extends SceneTree
## Capture real models with the same framing as the vehicle dossier.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(384,216)
	var view := ResearchModelView.new(); root.add_child(view); view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(VehicleResearchTree.DATA))
	var directory := "res://assets/research/thumbnails"
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest: Dictionary={}; var failures: Array=[]
	for row in catalog.vehicles:
		if not row.model is Dictionary: continue
		await process_frame
		if not view.show_vehicle(row): failures.append(row.id); continue
		await process_frame; await RenderingServer.frame_post_draw
		var path := directory.path_join(str(row.id)+".png")
		if view.viewport.get_texture().get_image().save_png(path)!=OK: failures.append(row.id)
		manifest[row.id]={"model_sha256":row.model.sha256,"path":path}
	var file := FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE); file.store_string(JSON.stringify(manifest,"\t")+"\n"); file.close()
	print("THUMBNAIL_BAKE: ",manifest.size()," captured, failures=",failures)
	print("RESEARCH_THUMBNAIL_CHECKS_PASS" if failures.is_empty() else "RESEARCH_THUMBNAIL_CHECKS_FAIL")
	view.free(); quit(0 if failures.is_empty() else 1)
