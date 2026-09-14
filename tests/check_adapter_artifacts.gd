extends SceneTree
## WT-030D-R2 step 5 (the part that can be executed without author data): verify the adapter
## artifacts. The source GLBs are read-only and never modified; the adapter is our own derived
## artifact and must (a) really carry the MuzzlePoint node the binding validator requires and
## (b) let the role audit resolve the muzzle as an AUTHORED node instead of a measured frame,
## which is the difference the review asked us to record. check_scene()/check_file() additionally
## need an in-repo layout and packet data that external models do not have, so they stay blocked
## on author input and are NOT claimed here.
const ADAPTER_ROOT := "res://assets/vehicles/adapters"
const REPORT := "res://logs/WT-030D-r2/adapter_verification.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty(): ids = ["35t","KPz70","M48"]
	var rows: Array[Dictionary] = []
	for id in ids:
		var adapter := "%s/%s/vehicle_adapter.glb" % [ADAPTER_ROOT,str(id)]
		var row := {"id":str(id),"adapter_path":adapter,"exists":FileAccess.file_exists(adapter)}
		if not row.exists:
			rows.append(row); print("[adapter-check] ",id," MISSING"); continue
		row.adapter_sha256 = FileAccess.get_sha256(adapter)
		# (a) the node must be present in the artifact itself
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var node_names: Array[String] = []
		if document.append_from_file(adapter,state) == OK:
			var scene: Node = document.generate_scene(state)
			if scene != null:
				var stack: Array[Node] = [scene]
				while not stack.is_empty():
					var node: Node = stack.pop_back()
					node_names.append(str(node.name))
					for child in node.get_children(): stack.append(child)
				scene.free()
		row.node_names = node_names
		row.has_muzzle_node = node_names.has("MuzzlePoint")
		# (b) the role audit must now resolve the muzzle as an authored node
		var probe := ModelBindingProbe.probe(adapter)
		row.probe_ok = bool(probe.get("ok",false))
		if row.probe_ok:
			var mapping := RoleMappingAudit.resolve(probe)
			var muzzle: Dictionary = mapping.roles.get("muzzle",{})
			row.muzzle_kind = str(muzzle.get("kind",""))
			row.muzzle_method = str(muzzle.get("method",""))
			row.roles_resolved = 0
			for role in mapping.roles:
				if str(mapping.roles[role].get("kind","")) != "missing": row.roles_resolved += 1
		rows.append(row)
		print("[adapter-check] %s has_muzzle=%s probe_ok=%s muzzle_kind=%s method=%s roles_resolved=%d sha=%s" % [
			str(id),str(row.get("has_muzzle_node",false)),str(row.get("probe_ok",false)),
			str(row.get("muzzle_kind","")),str(row.get("muzzle_method","")),int(row.get("roles_resolved",0)),
			str(row.get("adapter_sha256","")).substr(0,16)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-030D-r2"))
	var file := FileAccess.open(REPORT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,"rows":rows,
			"note":"check_scene/check_file still need an in-repo layout and packet and are NOT claimed here"}, "  ")+"\n")
		file.close()
		print("[adapter-check] wrote ",REPORT)
	print("ADAPTER_VERIFY_DONE")
	quit(0)
