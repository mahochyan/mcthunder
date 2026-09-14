extends SceneTree
## WT-030D-R2 step 4: build an INDEPENDENT adapter artifact for a source model.
##
## The source GLB is opened read-only and never modified. A copy of its scene is exported with a
## `MuzzlePoint` marker at the muzzle position the role audit measured from the barrel mesh, so
## the adapter carries its own hash and the binding can point at an artifact that really has the
## node the validator requires. The source and adapter hashes are both recorded, which is the
## separation the review asked for: an install-time addition cannot make the original GLB pass.
##
## Usage: godot --headless --path <project> -s res://tests/export_model_binding_adapter.gd -- <id> [<id>...]
## The source root stays outside the repository: nothing is copied whole, only the adapter is
## written (into the repository, since it is our own derived artifact).
const SOURCE_ROOT := "E:/AIprogram/aimodel/德国"
const ADAPTER_ROOT := "res://assets/vehicles/adapters"
const REPORT_PATH := "res://logs/WT-030D-r2/adapter_artifacts.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var ids: Array = args if not args.is_empty() else ["35t","KPz70"]
	var rows: Array[Dictionary] = []
	for id in ids:
		var source := "%s/%s/vehicle.glb" % [SOURCE_ROOT,str(id)]
		if not FileAccess.file_exists(source):
			print("[adapter] ",id," SOURCE MISSING"); continue
		var probe := ModelBindingProbe.probe(source)
		if not probe.get("ok",false):
			print("[adapter] ",id," UNPARSABLE"); continue
		var mapping := RoleMappingAudit.resolve(probe)
		var offset := Vector3.ZERO
		var method := "none"
		var entry: Dictionary = mapping.roles.get("muzzle",{})
		if str(entry.get("kind","")) == "measured_frame":
			var parts: Array = entry.get("offset_in_root_m",[0.0,0.0,0.0])
			offset = Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
			method = str(entry.get("method",""))
		elif str(entry.get("kind","")) == "node":
			method = "authored_node_already_present"
		# Build the adapter from a fresh parse so the source scene is never touched.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(source,state) != OK:
			print("[adapter] ",id," APPEND FAILED"); continue
		var scene: Node = document.generate_scene(state)
		if scene == null:
			print("[adapter] ",id," SCENE FAILED"); continue
		var marker := Marker3D.new()
		marker.name = "MuzzlePoint"
		marker.position = offset
		scene.add_child(marker)
		marker.owner = scene
		var out_document := GLTFDocument.new()
		var out_state := GLTFState.new()
		out_document.append_from_scene(scene,out_state)
		var directory := "%s/%s" % [ADAPTER_ROOT,str(id)]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var out_path := "%s/vehicle_adapter.glb" % directory
		var write := out_document.write_to_filesystem(out_state,out_path)
		var adapter_hash := FileAccess.get_sha256(out_path) if FileAccess.file_exists(out_path) else ""
		var row := {"id":str(id),"source_path":source,"source_sha256":str(probe.sha256),
			"adapter_path":out_path,"adapter_sha256":adapter_hash,
			"muzzle_offset_m":[offset.x,offset.y,offset.z],"muzzle_method":method,
			"write_result":write,"source_unchanged":FileAccess.get_sha256(source) == str(probe.sha256),
			"note":"source opened read-only; the adapter is our own derived artifact with its own hash"}
		rows.append(row)
		print("[adapter] %s source=%s adapter=%s offset=%s method=%s write=%d unchanged=%s" % [
			str(id),str(probe.sha256).substr(0,16),adapter_hash.substr(0,16),str(offset),method,write,str(row.source_unchanged)])
		scene.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-030D-r2"))
	var file := FileAccess.open(REPORT_PATH,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,"rows":rows,"source_root":SOURCE_ROOT}, "  ")+"\n")
		file.close()
		print("[adapter] wrote ",REPORT_PATH)
	print("MODEL_BINDING_ADAPTER_DONE")
	quit(0)
