class_name ModelAnchorReader
extends RefCounted
## WT-040-R1 (user ruling 2/3): read the AUTHORED attachment anchors out of the model that is going to be
## bound, so that placement and model agree BY CONSTRUCTION rather than by tolerance.
##
## Why this exists: the module and crew drafts used to derive their positions from measured boxes, which is
## a different derivation from the anchors the delivered model actually carries, and the binding validator
## correctly reported "actual anchor differs from layout local transform" and "wrong moving parent".
## The model that ships is the truth about where its own parts are.
##
## ARITHMETIC: this uses the SAME accumulation the validator uses - a manual walk of local transforms from
## the root - because an orphaned scene from GLTFDocument has no reliable global_transform, and because
## summing parent-local origins silently ignores any rotation on the way. A measurement made the second way
## produced a misleading zero. The relative transform is then inverse(part_transform) * anchor_transform,
## and its BASIS is returned too: the validator requires the basis to match, not only the origin.
##
## Nothing here is estimated: a missing anchor is reported as missing.

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false,"reason":"asset_missing","path":path,"anchors":{},"roles":{},"by_name":{}}
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path,st) != OK:
		return {"ok":false,"reason":"glb_parse_failed","path":path,"anchors":{},"roles":{},"by_name":{}}
	var scene := doc.generate_scene(st)
	if scene == null:
		return {"ok":false,"reason":"scene_generation_failed","path":path,"anchors":{},"roles":{},"by_name":{}}
	var world := {}
	_accumulate(scene,Transform3D.IDENTITY,world)
	var roles := {"hull":null,"turret":null,"barrel":null}
	var by_name := {}
	for node in world.keys():
		var nm := str((node as Node).name)
		by_name[nm] = node
		if nm == "TurretPivot": roles["turret"] = node
		elif nm == "GunPivot": roles["barrel"] = node
	if roles["hull"] == null:
		# The hull role is the topmost Node3D the model owns, which is also what makes turret, gun and the
		# running branches descend from it.
		for child in scene.get_children():
			if child is Node3D:
				roles["hull"] = child
				break
	var anchors := {}
	for node in world.keys():
		var nm := str((node as Node).name)
		if nm.begins_with("Attachment_"):
			anchors[nm] = {"node":node, "parent":str(node.get_parent().name) if node.get_parent() != null else "",
				"transform":world[node]}
	scene.free()
	return {"ok":true,"path":path,"anchors":anchors,"roles":roles,"by_name":by_name,"world":world}

## Every node's transform accumulated from the root, exactly as the validator walks it.
static func _accumulate(node: Node, acc: Transform3D, out: Dictionary) -> void:
	var here := acc
	if node is Node3D:
		here = acc * (node as Node3D).transform
		out[node] = here
	for child in node.get_children(): _accumulate(child,here,out)

## Position of an anchor relative to the part that owns it, in the space the layout uses. For the running
## and drive parts the validator uses the HULL transform at rest, so this does the same.
static func part_relative(path: String, anchor_name: String, part: String) -> Dictionary:
	var info := read(path)
	if not info.get("ok",false):
		return {"ok":false,"reason":str(info.get("reason","unreadable")),"position":Vector3.ZERO,"basis":Basis.IDENTITY,"part_node":""}
	var anchors: Dictionary = info["anchors"]
	if not anchors.has(anchor_name):
		return {"ok":false,"reason":"anchor_absent","position":Vector3.ZERO,"basis":Basis.IDENTITY,"part_node":"","anchor":anchor_name}
	var roles: Dictionary = info["roles"]
	var role_key := "hull"
	if part == "turret": role_key = "turret"
	elif part == "barrel": role_key = "barrel"
	var part_node: Variant = roles.get(role_key,null)
	if part == "drive" or part == "running_left" or part == "running_right": part_node = roles.get("hull",null)
	if part_node == null: part_node = roles.get("hull",null)
	if part_node == null:
		return {"ok":false,"reason":"no_part_node","position":Vector3.ZERO,"basis":Basis.IDENTITY,"part_node":"","anchor":anchor_name}
	var world: Dictionary = info["world"]
	if not world.has(part_node):
		return {"ok":false,"reason":"part_not_in_scene","position":Vector3.ZERO,"basis":Basis.IDENTITY,"part_node":"","anchor":anchor_name}
	var local: Transform3D = (world[part_node] as Transform3D).affine_inverse() * (anchors[anchor_name]["transform"] as Transform3D)
	return {"ok":true,"position":local.origin,"basis":local.basis,"anchor":anchor_name,"part":part,
		"part_node":str((part_node as Node).name),"anchor_parent":str(anchors[anchor_name]["parent"]),
		"basis_is_identity":local.basis.is_equal_approx(Basis.IDENTITY)}
