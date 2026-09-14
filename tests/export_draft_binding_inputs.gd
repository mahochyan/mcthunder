extends SceneTree
## WT-030D-R2 step 5, path B continued: emit the remaining inputs a full binding check needs, using
## only values that are actually derivable.
##
## source_record  - adapter path and its SHA256 (the binding must point at the adapter artifact, as
##                  the review required: an install-time node cannot make the original GLB pass).
## geometry       - turret/gun origins and barrel length measured from the adapter's own role nodes.
## binding draft  - the shape contract, pointing at the adapter, with the role node paths.
## runtime        - yaw/pitch limits are MECHANISM data, so they are left out and listed as
##                  needs_author rather than invented.
const ADAPTER_ROOT := "res://assets/vehicles/adapters"
const REPORT := "res://logs/WT-030D-r2/draft_binding_inputs.json"
const ROLES := ["hull","turret","gun","muzzle","running_gear"]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty(): ids = ["35t","KPz70","M48"]
	var rows: Array[Dictionary] = []
	for id in ids:
		var adapter := "%s/%s/vehicle_adapter.glb" % [ADAPTER_ROOT,str(id)]
		var row := {"id":str(id),"adapter_path":adapter,"needs_author":[]}
		if not FileAccess.file_exists(adapter):
			row.error = "adapter missing"; rows.append(row); print("[bind-draft] ",id," MISSING"); continue
		row.source_record = {"id":str(id),"path":adapter,"sha256":FileAccess.get_sha256(adapter)}
		var probe := ModelBindingProbe.probe(adapter)
		if not bool(probe.get("ok",false)):
			row.error = "probe failed"; rows.append(row); print("[bind-draft] ",id," PROBE FAILED"); continue
		var mapping := RoleMappingAudit.resolve(probe)
		var nodes := {}
		for role in ROLES:
			var entry: Dictionary = mapping.roles.get(role,{})
			if str(entry.get("kind","")) == "node": nodes[role] = str(entry.get("path",""))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var scene: Node = null
		if document.append_from_file(adapter,state) == OK: scene = document.generate_scene(state)
		# WT-036-R1: same off-tree trap as the layout drafts - measure inside the SceneTree.
		if scene != null: root.add_child(scene)
		if scene == null:
			row.error = "scene failed"; rows.append(row); print("[bind-draft] ",id," SCENE FAILED"); continue
		var turret_origin := Vector3.ZERO
		var gun_origin := Vector3.ZERO
		var muzzle_origin := Vector3.ZERO
		var have_turret := false
		var have_gun := false
		var have_muzzle := false
		if nodes.has("turret"):
			var n: Node = scene.get_node_or_null(NodePath(str(nodes.turret)))
			if n is Node3D: turret_origin = (n as Node3D).global_position; have_turret = true
		if nodes.has("gun"):
			var n: Node = scene.get_node_or_null(NodePath(str(nodes.gun)))
			if n is Node3D: gun_origin = (n as Node3D).global_position; have_gun = true
		if nodes.has("muzzle"):
			var n: Node = scene.get_node_or_null(NodePath(str(nodes.muzzle)))
			if n is Node3D: muzzle_origin = (n as Node3D).global_position; have_muzzle = true
		var barrel_length := 0.0
		if have_gun and have_muzzle: barrel_length = gun_origin.distance_to(muzzle_origin)
		# WT-036-R1: these models keep EMPTY pivots at the origin - TurretPivot, GunPivot and the
		# MuzzlePoint marker all sit at (0,0,0) and the visible geometry hangs off them - so node
		# positions alone give a zero barrel. The role audit already measures the muzzle from the
		# barrel mesh extremity through the parent chain, so fall back to that measured offset.
		var measured_muzzle := Vector3.ZERO
		var muzzle_entry: Dictionary = mapping.roles.get("muzzle",{})
		if str(muzzle_entry.get("kind","")) == "measured_frame":
			var parts: Array = muzzle_entry.get("offset_in_root_m",[0.0,0.0,0.0])
			measured_muzzle = Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
			if barrel_length <= 0.0001: barrel_length = measured_muzzle.length()
			row.muzzle_measured_from = "barrel_mesh_extremity"
		else:
			row.muzzle_measured_from = "node_position"
		row.geometry = {"turret_origin":[turret_origin.x,turret_origin.y,turret_origin.z],
			"gun_origin":[gun_origin.x,gun_origin.y,gun_origin.z],"barrel_length":barrel_length}
		row.have_turret = have_turret; row.have_gun = have_gun; row.have_muzzle = have_muzzle
		var missing: Array[String] = []
		for role in ["hull","turret","gun","muzzle"]:
			if not nodes.has(role): missing.append(role)
		row.nodes = nodes
		row.binding_draft = {"schema_version":1,"vehicle_id":str(id),
			"model":{"source_vehicle_id":str(id),"path":adapter,"sha256":row.source_record.sha256},
			"nodes":nodes,
			"note":"draft: shape contract only; units/axes/tolerance/attachments must come from the author"}
		row.needs_author.append_array([
			"runtime.yaw_min/max and pitch_min/max: mechanism limits (left out on purpose)",
			"binding.units / axes / tolerance_fraction / attachment_tolerance_m / internal_attachments: author data",
			"binding.nodes for roles with no node in the model: %s" % str(missing),
		])
		rows.append(row)
		print("[bind-draft] %s sha=%s turret=%s gun=%s muzzle=%s barrel=%.3f missing_roles=%d needs_author=%d" % [
			str(id),str(row.source_record.sha256).substr(0,16),str(have_turret),str(have_gun),str(have_muzzle),
			barrel_length,missing.size(),row.needs_author.size()])
		if scene != null: scene.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-030D-r2"))
	var file := FileAccess.open(REPORT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"source_record and geometry are measured from the adapter; runtime limits and the remaining binding fields are author data and are listed as needs_author",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[bind-draft] wrote ",REPORT)
	print("DRAFT_BINDING_INPUTS_DONE")
	quit(0)
