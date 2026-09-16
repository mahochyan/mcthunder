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
	var hull_node: Variant = roles["hull"]
	var turret_node: Variant = roles["turret"]
	var barrel_node: Variant = roles["barrel"]
	for node in world.keys():
		var nm := str((node as Node).name)
		if not nm.begins_with("Attachment_"):
			continue
		# The relative transform is computed HERE, before the scene is freed: a Node-keyed dictionary
		# outlives its nodes otherwise, and reading it afterwards silently returned garbage. Only plain
		# values leave this function.
		var rel := {}
		for pair in [["hull",hull_node],["turret",turret_node],["barrel",barrel_node]]:
			var part_node: Variant = pair[1]
			if part_node == null or not world.has(part_node): continue
			var local: Transform3D = (world[part_node] as Transform3D).affine_inverse() * (world[node] as Transform3D)
			rel[str(pair[0])] = {"position":local.origin, "basis":local.basis,
				"basis_is_identity":local.basis.is_equal_approx(Basis.IDENTITY),
				"part_node":str((part_node as Node).name)}
		anchors[nm] = {"parent":str(node.get_parent().name) if node.get_parent() != null else "", "relative":rel}
	scene.free()
	var role_names := {"hull":"", "turret":"", "barrel":""}
	for key in role_names.keys():
		var rn: Variant = roles.get(key,null)
		role_names[key] = str((rn as Node).name) if rn != null else ""
	return {"ok":true,"path":path,"anchors":anchors,"role_names":role_names,"roles":{},"by_name":{}}

## WT-040-R1: the three mount offsets the binding validator compares against the packet's geometry, taken
## from the model as RELATIVE transforms - the turret from the hull, the gun from the turret, and the
## muzzle from the gun along the gun's own -Z. Global positions are a different quantity, and using them is
## why the rest-pose and muzzle-reach checks failed. Every value is computed before the scene is freed.
static func role_offsets(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"reason":"asset_missing"}
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path,st) != OK: return {"ok":false,"reason":"glb_parse_failed"}
	var scene := doc.generate_scene(st)
	if scene == null: return {"ok":false,"reason":"scene_generation_failed"}
	var world := {}
	_accumulate(scene,Transform3D.IDENTITY,world)
	var hull: Variant = null
	var turret: Variant = null
	var gun: Variant = null
	var muzzle: Variant = null
	for node in world.keys():
		match str((node as Node).name):
			"TurretPivot": turret = node
			"GunPivot": gun = node
			"Muzzle": muzzle = node
	for child in scene.get_children():
		if child is Node3D:
			hull = child
			break
	var out := {"ok":false,"reason":"required node absent"}
	if hull != null and turret != null and gun != null and muzzle != null and world.has(hull) and world.has(turret) and world.has(gun) and world.has(muzzle):
		var t_from_h: Transform3D = (world[hull] as Transform3D).affine_inverse() * (world[turret] as Transform3D)
		var g_from_t: Transform3D = (world[turret] as Transform3D).affine_inverse() * (world[gun] as Transform3D)
		var m_from_g: Transform3D = (world[gun] as Transform3D).affine_inverse() * (world[muzzle] as Transform3D)
		out = {"ok":true,
			"turret_origin":t_from_h.origin, "gun_origin":g_from_t.origin,
			"muzzle_offset":m_from_g.origin, "barrel_length":absf(m_from_g.origin.z),
			"all_bases_identity":t_from_h.basis.is_equal_approx(Basis.IDENTITY)
				and g_from_t.basis.is_equal_approx(Basis.IDENTITY)
				and m_from_g.basis.is_equal_approx(Basis.IDENTITY),
			"turret_node":str((turret as Node).name), "gun_node":str((gun as Node).name),
			"muzzle_node":str((muzzle as Node).name), "hull_node":str((hull as Node).name)}
	scene.free()
	return out

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
	var role_key := "hull"
	if part == "turret": role_key = "turret"
	elif part == "barrel": role_key = "barrel"
	# drive and the running branches share the hull origin at rest, which is what the validator uses.
	if part == "drive": role_key = "hull"
	var rel: Dictionary = anchors[anchor_name]["relative"]
	if not rel.has(role_key):
		return {"ok":false,"reason":"part_kind_unavailable","position":Vector3.ZERO,"basis":Basis.IDENTITY,"part_node":"","anchor":anchor_name}
	var row: Dictionary = rel[role_key]
	return {"ok":true,"position":row["position"],"basis":row["basis"],"basis_is_identity":row["basis_is_identity"],
		"anchor":anchor_name,"part":part,"part_node":str(row["part_node"]),
		"anchor_parent":str(anchors[anchor_name]["parent"])}
