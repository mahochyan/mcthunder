extends SceneTree
## Capture real models with the same framing as the vehicle dossier.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(384,216)
	var view := ResearchModelView.new(); root.add_child(view); view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(VehicleResearchTree.DATA))
	var directory := "res://assets/research/thumbnails"
	DirAccess.make_dir_recursive_absolute(directory)
	var previous: Dictionary={}
	var manifest_path:=directory.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: previous=parsed
	var manifest: Dictionary={}; var failures: Array=[]; var reused:=0; var captured:=0
	for row in catalog.vehicles:
		if not row.model is Dictionary: continue
		var selected_model: Dictionary=row.model
		if row.get("combat_package") is Dictionary and row.combat_package.get("runtime_model") is Dictionary:
			selected_model=row.combat_package.runtime_model
		var old: Variant=previous.get(str(row.id))
		if old is Dictionary and str(old.get("model_sha256",""))==str(selected_model.sha256) and FileAccess.file_exists(str(old.get("path",""))):
			manifest[row.id]=old; reused+=1; continue
		await process_frame
		if not view.show_vehicle(row): failures.append(row.id); continue
		await process_frame; await RenderingServer.frame_post_draw
		var path := directory.path_join(str(row.id)+".png")
		if view.viewport.get_texture().get_image().save_png(path)!=OK: failures.append(row.id)
		else: manifest[row.id]={"model_sha256":selected_model.sha256,"path":path}; captured+=1
	var file := FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE); file.store_string(JSON.stringify(manifest,"\t")+"\n"); file.close()
	print("THUMBNAIL_BAKE: ",manifest.size()," total, ",captured," captured, ",reused," reused, failures=",failures)
	print("RESEARCH_THUMBNAIL_CHECKS_PASS" if failures.is_empty() else "RESEARCH_THUMBNAIL_CHECKS_FAIL")
	view.free(); quit(0 if failures.is_empty() else 1)
