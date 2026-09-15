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
	var source_root := SOURCE_ROOT
	var targets: Array = args if not args.is_empty() else ["35t","KPz70"]
	var rows: Array[Dictionary] = []
	for target in targets:
		var token := str(target)
		if token.begins_with("root="):
			source_root = token.substr(5)
			print("[adapter] source root overridden to ",source_root)
			continue
		var id := token
		var source := ""
		if token.contains("=") and token.split("=",true,1)[1].contains("/"):
			# "<id>=<absolute source path>": the id cannot be the parent directory name when the
			# source tree names it something else (the T-80B lives in a folder called 制作中).
			var parts := token.split("=",true,1)
			id = parts[0]
			source = parts[1]
		elif token.contains("/"):
			source = token
			id = source.get_base_dir().get_file()
		else:
			source = "%s/%s/vehicle.glb" % [source_root,token]
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
		# WT-036-R1: a marker parented straight to the scene root did not survive the export with its
		# transform - the artifact's MuzzlePoint was measured at (0,0,0) on all three samples, which
		# defeats the point of the adapter. Parent it to the gun node instead, which is a real
		# exported node, and give it the transform that places it at the measured muzzle in root
		# space. It is verified after the write below.
		var row_parent := "<unset>"
		var gun_path := ""
		var gun_entry: Dictionary = mapping.roles.get("gun",{})
		if str(gun_entry.get("kind","")) == "node": gun_path = str(gun_entry.get("path",""))
		var gun_node: Node = scene.get_node_or_null(NodePath(gun_path)) if not gun_path.is_empty() else null
		var marker := Marker3D.new()
		marker.name = "MuzzlePoint"
		# WT-036-R1 corrected: the measured muzzle offset is expressed relative to the VEHICLE ROOT
		# (it is the barrel mesh extremity composed through the parent chain), so the anchor belongs
		# as a direct child of the root with exactly that position. Parenting it under GunPivot put
		# it a turret-and-gun pivot away from where it was measured, which the in-tree verification
		# below now shows as a delta of about 1.9 m. The earlier "marker is at the origin" reading was
		# my own measurement bug: global_position off-tree returned (0,0,0) for every node.
		# WT-040-R1 HARDENING (the blind spot the review of this tool exposed): the self-check used to
		# assert only that the artifact's marker matches the RECORDED offset, so a model whose muzzle
		# could not be measured at all - method "none", offset (0,0,0) - still reported verified. An
		# ARMED vehicle (the audit classifies single_turret / multi_launcher) with no measured muzzle is
		# now a FAILURE, and an unarmed one (support_unarmed: trucks, carriers, launchers with no gun)
		# gets no MuzzlePoint at all instead of a meaningless marker at the origin.
		var vehicle_class := str(mapping.get("vehicle_class","unknown"))
		var armed := vehicle_class in ["single_turret","multi_launcher"]
		var muzzle_missing := method == "none" or offset.length() <= 0.0001
		var row_failure := ""
		if muzzle_missing and armed:
			row_failure = "armed_vehicle_without_measured_muzzle"
			print("[adapter] ",id," FAILURE: armed (",vehicle_class,") but the muzzle was not measured")
		elif muzzle_missing:
			print("[adapter] ",id," no muzzle (unarmed ",vehicle_class,"): no marker is emitted")
		marker.position = offset
		# Only an adapter that actually carries a measured muzzle gets the marker; adding one at the
		# origin for a gun-less vehicle would be a false claim about the artifact.
		if not muzzle_missing:
			scene.add_child(marker)
			marker.owner = scene
			row_parent = "<scene root>"
		else:
			marker.free()
			row_parent = "<no marker: muzzle not measured>"
		var out_document := GLTFDocument.new()
		var out_state := GLTFState.new()
		out_document.append_from_scene(scene,out_state)
		var directory := "%s/%s" % [ADAPTER_ROOT,str(id)]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var out_path := "%s/vehicle_adapter.glb" % directory
		var write := out_document.write_to_filesystem(out_state,out_path)
		var adapter_hash := FileAccess.get_sha256(out_path) if FileAccess.file_exists(out_path) else ""
		# WT-036-R1 self-check: re-read the artifact and assert the muzzle node really sits where it
		# was measured. Without this the earlier artifact passed a "node exists" check while its
		# position was silently at the origin.
		var verified := false
		var verified_delta := -1.0
		var verify_document := GLTFDocument.new()
		var verify_state := GLTFState.new()
		if verify_document.append_from_file(out_path,verify_state) == OK:
			var verify_scene: Node = verify_document.generate_scene(verify_state)
			if verify_scene != null:
				# WT-036-R1: a freshly generated scene is NOT in the SceneTree, and reading
				# global_position off-tree returned (0,0,0) for every node - which made me report a
				# defect that does not exist. Add it to the tree first, then read.
				root.add_child(verify_scene)
				var found: Node = null
				var stack: Array[Node] = [verify_scene]
				while not stack.is_empty() and found == null:
					var node: Node = stack.pop_back()
					if str(node.name) == "MuzzlePoint": found = node
					for child in node.get_children(): stack.append(child)
				if found is Node3D:
					verified_delta = (found as Node3D).global_position.distance_to(offset)
					verified = verified_delta <= 0.001
				root.remove_child(verify_scene)
				verify_scene.free()
		# WT-040-R1: the verdict for a vehicle with no measured muzzle depends on whether it is armed.
		# An unarmed vehicle whose artifact carries NO marker is correct (there is no muzzle to place),
		# while an armed one without a measured muzzle is a failure - the case that used to slip through.
		if muzzle_missing:
			verified = not armed
			verified_delta = 0.0 if not armed else -1.0
		var row := {"id":str(id),"source_path":source,"source_sha256":str(probe.sha256),
			"adapter_path":out_path,"adapter_sha256":adapter_hash,
			"muzzle_offset_m":[offset.x,offset.y,offset.z],"muzzle_method":method,
			"muzzle_marker_parent":row_parent,"muzzle_verified_in_artifact":verified,
			"muzzle_verified_delta_m":verified_delta,
			"vehicle_class":vehicle_class,"armed":armed,"muzzle_missing":muzzle_missing,
			"failure":row_failure,
			"write_result":write,"source_unchanged":FileAccess.get_sha256(source) == str(probe.sha256),
			"note":"source opened read-only; the adapter is our own derived artifact with its own hash, and the muzzle position is re-read from the artifact and asserted"}
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
