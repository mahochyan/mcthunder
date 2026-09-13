class_name ModelBindingProbe
extends RefCounted
## WT-031B-D: derive a model binding from the REAL GLB instead of guessing.
##
## The probe loads the asset with GLTFDocument (which works for byte-level GLBs that have no
## import companion as well as for imported ones), walks the actual node tree, measures the
## hull envelope, proposes a units scale, and resolves each role in
## `ModelBindingValidator.ROLES` against real node names.
##
## Everything it produces is a DRAFT plus a per-role report. It never writes a packet, never
## touches the registry and never installs a binding, so a missing or ambiguous role is
## reported by name instead of being papered over.

const ROLE_HINTS := {
	"hull":["hull","body","chassis","vehicle_root","root","tank","frame"],
	"turret":["turret","tower"],
	"gun":["gun","barrel","cannon","muzzlebrake"],
	"muzzle":["muzzle"],
	"running_left":["wheel_l","track_l","running_left","left_track","wheel_l_","tracks_l"],
	"running_right":["wheel_r","track_r","running_right","right_track","wheel_r_","tracks_r"],
}
const EXPECTED_LONGEST := {"min_m":3.0,"max_m":14.0}
const UNIT_CANDIDATES := {"m":1.0,"cm":0.01,"mm":0.001}

static func probe(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false,"reason":"asset_missing","path":path}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path,state)
	if error != OK:
		return {"ok":false,"reason":"glb_parse_failed","error":error,"path":path}
	var scene := document.generate_scene(state)
	if scene == null:
		return {"ok":false,"reason":"scene_generation_failed","path":path}
	var nodes: Array[Dictionary] = []
	_collect(scene,scene,nodes)
	var envelope := _envelope(scene)
	var longest := maxf(envelope.size.x,maxf(envelope.size.y,envelope.size.z))
	var unit := _unit_for(longest)
	var roles: Dictionary = {}
	var unresolved: Array[String] = []
	for role in ModelBindingValidator.ROLES:
		var matches: Array[String] = []
		for row in nodes:
			if _matches(str(row.name),role): matches.append(str(row.path))
		roles[role] = {"state":("resolved" if matches.size() == 1 else ("ambiguous" if matches.size() > 1 else "missing")),
			"candidates":matches}
		if matches.size() != 1: unresolved.append(role)
	var triangles := _triangles(scene)
	scene.free()
	return {"ok":true,"path":path,"sha256":FileAccess.get_sha256(path),
		"bytes":int(FileAccess.get_file_as_bytes(path).size()),
		"node_count":nodes.size(),"mesh_count":_mesh_count(nodes),"triangles":triangles,
		"envelope_m":[envelope.size.x,envelope.size.y,envelope.size.z],
		"longest_m":longest,"unit_candidate":unit.key,"meters_per_unit":unit.value,
		"roles":roles,"unresolved_roles":unresolved,
		"nodes":nodes}

## Every node is recorded, not only meshes: the author assets carry empty pivots
## (`TurretPivot`, `GunPivot`) that a mesh-only scan would miss. Full relative paths, the
## parent path, the local axis directions and (for meshes) the local AABB are recorded so a
## role can be checked against a real hierarchy, a real axis and a real muzzle position.
static func _collect(root: Node, node: Node, out: Array[Dictionary]) -> void:
	var kind := "node"
	var origin := [0.0,0.0,0.0]
	var forward := [0.0,0.0,-1.0]
	var up := [0.0,1.0,0.0]
	var aabb_min := [0.0,0.0,0.0]
	var aabb_max := [0.0,0.0,0.0]
	if node is Node3D:
		var n3: Node3D = node
		origin = [n3.position.x,n3.position.y,n3.position.z]
		forward = [(-n3.basis.z).x,(-n3.basis.z).y,(-n3.basis.z).z]
		up = [n3.basis.y.x,n3.basis.y.y,n3.basis.y.z]
		kind = "node3d"
	if node is MeshInstance3D:
		kind = "mesh"
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			var box := mi.mesh.get_aabb()
			aabb_min = [box.position.x,box.position.y,box.position.z]
			aabb_max = [box.end.x,box.end.y,box.end.z]
	var parent_path := ""
	if node != root and node.get_parent() != null:
		parent_path = str(root.get_path_to(node.get_parent()))
	out.append({"name":str(node.name),"path":str(root.get_path_to(node)),"type":kind,
		"parent":parent_path,"origin":origin,"forward":forward,"up":up,
		"aabb_min":aabb_min,"aabb_max":aabb_max})
	for child in node.get_children(): _collect(root,child,out)

static func _mesh_count(nodes: Array[Dictionary]) -> int:
	var total := 0
	for row in nodes:
		if str(row.type) == "mesh": total += 1
	return total

## Triangle count from the parsed meshes, so an author's stated budget can be checked.
static func _triangles(root: Node) -> int:
	var total := 0
	for node in _all_nodes(root):
		if not node is MeshInstance3D: continue
		var mesh: MeshInstance3D = node
		if mesh.mesh == null: continue
		total += int(mesh.mesh.get_faces().size()/3)
	return total

static func _envelope(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for node in _all_nodes(root):
		if not node is MeshInstance3D: continue
		var mesh: MeshInstance3D = node
		if mesh.mesh == null: continue
		var local := mesh.mesh.get_aabb()
		# compose the parent chain manually: the generated scene is not inside a tree, so
		# global_transform is not guaranteed here
		var pose := _pose_in_root(root,mesh)
		var transformed := pose*AABB(local.position,local.size)
		if first: box = transformed; first = false
		else: box = box.merge(transformed)
	return box

static func _pose_in_root(root: Node, node: Node) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node3D: pose = (current as Node3D).transform*pose
		current = current.get_parent()
	return pose

static func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children(): out.append_array(_all_nodes(child))
	return out

static func _matches(node_name: String, role: String) -> bool:
	var lowered := node_name.to_lower()
	for hint in ROLE_HINTS.get(role,[]):
		if lowered == str(hint) or lowered.begins_with(str(hint)) or lowered.contains("_"+str(hint)): return true
	return false

static func _unit_for(longest: float) -> Dictionary:
	if longest >= EXPECTED_LONGEST.min_m and longest <= EXPECTED_LONGEST.max_m: return {"key":"m","value":UNIT_CANDIDATES.m}
	var scaled_m := longest*UNIT_CANDIDATES.cm
	if scaled_m >= EXPECTED_LONGEST.min_m and scaled_m <= EXPECTED_LONGEST.max_m: return {"key":"cm","value":UNIT_CANDIDATES.cm}
	return {"key":"mm","value":UNIT_CANDIDATES.mm}

## A draft binding in the shape `BoundVehicleModel.check` expects. Never applied.
static func draft_binding(report: Dictionary) -> Dictionary:
	if not report.get("ok",false): return {}
	var nodes := {}
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = report.roles.get(role,{})
		if str(entry.get("state","missing")) == "resolved":
			nodes[role] = str(entry.candidates[0])
	return {"model":{"path":str(report.path),"sha256":str(report.sha256)},
		"units":{"meters_per_unit":float(report.meters_per_unit)},
		"nodes":nodes,"complete":nodes.size() == ModelBindingValidator.ROLES.size(),
		"missing_roles":report.unresolved_roles.duplicate(),
		"applied":false,"note":"draft only: this is not installed and no packet is modified"}

## The per-role report the delivery asks for.
static func role_report(report: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not report.get("ok",false): return rows
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = report.roles.get(role,{})
		rows.append({"role":role,"state":str(entry.get("state","missing")),
			"candidate_count":entry.get("candidates",[]).size(),
			"candidates":entry.get("candidates",[]).slice(0,4)})
	return rows

static func probe_all(paths: Dictionary) -> Dictionary:
	var reports := {}
	var resolved_total := 0
	var role_total := 0
	for id in paths:
		var report := probe(str(paths[id]))
		reports[id] = report
		if report.get("ok",false):
			var draft := draft_binding(report)
			resolved_total += int(draft.nodes.size())
			role_total += ModelBindingValidator.ROLES.size()
	return {"reports":reports,"resolved_roles":resolved_total,"role_slots":role_total,
		"complete_bindings":(resolved_total == role_total and role_total > 0)}
