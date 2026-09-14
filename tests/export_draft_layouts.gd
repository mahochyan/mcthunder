extends SceneTree
## WT-030D-R2 step 5, path B as authorised by the user: generate DRAFT VehicleLayoutDefinitions
## for the three adapter samples.
##
## Every value comes from the model itself: part identity, parent/child structure, the local bind
## transform between a node and its parent, and the joint kind implied by the role. Anything that
## is author or documentary data - armour thickness and material, module volumes, crew stations,
## joint limits and evidence keys - is deliberately LEFT EMPTY and listed in the report as "needs
## author", because inventing it would be fabrication. The drafts live under assets/draft_layouts/
## and are marked content_tier "test" with an empty field_evidence_id; the report is the diff list
## the author signs off or corrects.
const ADAPTER_ROOT := "res://assets/vehicles/adapters"
const OUT_ROOT := "res://assets/draft_layouts"
const REPORT := "res://logs/WT-030D-r2/draft_layouts_report.json"
const ROLES := ["hull","turret","gun","muzzle","running_gear"]
const JOINT := {"hull":"fixed","turret":"yaw","gun":"pitch","muzzle":"fixed","running_gear":"fixed"}
const PARENT_ROLE := {"turret":"hull","gun":"turret","muzzle":"gun","running_gear":"hull"}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty(): ids = ["35t","KPz70","M48"]
	var rows: Array[Dictionary] = []
	for id in ids:
		var adapter := "%s/%s/vehicle_adapter.glb" % [ADAPTER_ROOT,str(id)]
		var row := {"id":str(id),"adapter_path":adapter,"draft_path":"","derived_parts":[],"needs_author":[]}
		if not FileAccess.file_exists(adapter):
			row.error = "adapter missing"; rows.append(row); print("[draft] ",id," ADAPTER MISSING"); continue
		var probe := ModelBindingProbe.probe(adapter)
		if not bool(probe.get("ok",false)):
			row.error = "probe failed"; rows.append(row); print("[draft] ",id," PROBE FAILED"); continue
		var mapping := RoleMappingAudit.resolve(probe)
		# Load the adapter scene to read real transforms (model-derived only).
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var scene: Node = null
		if document.append_from_file(adapter,state) == OK: scene = document.generate_scene(state)
		# WT-036-R1: global_position read off a scene that is NOT in the SceneTree returns (0,0,0) for
		# every node, which silently produced an all-zero draft. Put it in the tree while measuring.
		if scene != null: root.add_child(scene)
		if scene == null:
			row.error = "scene failed"; rows.append(row); print("[draft] ",id," SCENE FAILED"); continue
		var layout := VehicleLayoutDefinition.new()
		layout.schema_version = 1
		layout.id = str(id)
		layout.historical_identity_id = ""
		layout.content_tier = "test"                 # draft marker: test tier, no evidence id
		layout.display_name = str(id)
		layout.recovery_enabled = false
		layout.source_catalog_id = ""
		layout.field_evidence_id = ""                # no fabricated evidence
		layout.armor_patches = [] as Array[ArmorPatchDefinition]
		layout.modules = [] as Array[ModuleVolumeDefinition]
		layout.crew_stations = [] as Array[CrewStationDefinition]
		layout.allowed_overlaps = []
		var parts: Array[LayoutPartDefinition] = []
		var openings: Array[Dictionary] = []
		var node_of := {}
		for role in ROLES:
			var entry: Dictionary = mapping.roles.get(role,{})
			var path := ""
			if str(entry.get("kind","")) == "node": path = str(entry.get("path",""))
			node_of[role] = path
		for role in ROLES:
			var path: String = str(node_of.get(role,""))
			if path.is_empty():
				row.needs_author.append("%s: no node in the model" % role); continue
			var node: Node = scene.get_node_or_null(NodePath(path))
			if node == null:
				row.needs_author.append("%s: node path not found (%s)" % [role,path]); continue
			var part := LayoutPartDefinition.new()
			part.id = role
			part.parent_id = str(PARENT_ROLE.get(role,""))
			part.joint_kind = str(JOINT.get(role,"fixed"))
			var parent_role := str(PARENT_ROLE.get(role,""))
			if parent_role.is_empty():
				part.bind_local = Transform3D.IDENTITY
			else:
				var parent_path: String = str(node_of.get(parent_role,""))
				var parent_node: Node = scene.get_node_or_null(NodePath(parent_path)) if not parent_path.is_empty() else null
				if parent_node is Node3D and node is Node3D:
					part.bind_local = (parent_node as Node3D).global_transform.affine_inverse() * (node as Node3D).global_transform
				else:
					row.needs_author.append("%s: parent transform unavailable (%s)" % [role,parent_role])
			# Joint limits are author data: leave them at zero and say so.
			part.min_angle_deg = 0.0
			part.max_angle_deg = 0.0
			part.evidence_keys = PackedStringArray()
			parts.append(part)
			row.derived_parts.append(role)
			if node is Node3D:
				openings.append({"part_id":role,"origin_m":(node as Node3D).global_position,
					"kind":"turret_ring" if role == "turret" else ("muzzle" if role == "muzzle" else "structural")})
		layout.parts = parts
		layout.declared_openings = openings
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT))
		var out_path := "%s/%s_draft.tres" % [OUT_ROOT,str(id)]
		var saved := ResourceSaver.save(layout,out_path)
		row.draft_path = out_path
		row.save_result = saved
		row.needs_author.append_array([
			"armor_patches: thickness, material and plate grouping are documentary data (left empty)",
			"modules: volume boundaries and integrity are design data (left empty)",
			"crew_stations: roles and positions are design data (left empty)",
			"parts.min/max_angle_deg: joint limits are mechanism data (left at zero)",
			"historical_identity_id / source_catalog_id / field_evidence_id: no in-repo evidence (left empty)",
		])
		rows.append(row)
		print("[draft] %s parts=%d openings=%d save=%d draft=%s needs_author=%d" % [
			str(id),parts.size(),openings.size(),saved,out_path,row.needs_author.size()])
		if scene != null: scene.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-030D-r2"))
	var file := FileAccess.open(REPORT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"drafts derived only from the model's own structure; armour, modules, crew, joint limits and evidence are left empty and listed as needs_author",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[draft] wrote ",REPORT)
	print("DRAFT_LAYOUTS_DONE")
	quit(0)
