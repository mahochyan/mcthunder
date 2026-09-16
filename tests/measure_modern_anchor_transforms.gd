extends SceneTree
## WT-040-R1: measure each anchor's transform relative to its owning part using the SAME accumulation the
## validator uses (a manual walk of local transforms from the root), because an orphaned scene generated
## by GLTFDocument has no reliable global_transform and measuring with it produced a misleading zero.
const PATHS := ["res://assets/vehicles/modern_bound/ussr_t_80b.glb", "res://assets/vehicles/modern_bound/germ_leopard_2a4.glb"]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for path in PATHS:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(path, st) != OK:
			print("[rel] ", path, " PARSE_FAILED")
			continue
		var scene := doc.generate_scene(st)
		if scene == null:
			print("[rel] ", path, " NO_SCENE")
			continue
		var world := {}
		_accum(scene, Transform3D.IDENTITY, world)
		print("[rel] === ", path, " nodes=", world.size())
		var keys: Array = world.keys()
		for node in keys:
			var nm := str((node as Node).name)
			if not nm.begins_with("Attachment_"):
				continue
			var part: Node = _part_for(node, world)
			if part == null:
				print("      ", nm, " NO_PART")
				continue
			var local: Transform3D = (world[part] as Transform3D).affine_inverse() * (world[node] as Transform3D)
			var e := local.basis.get_euler()
			print("      %-28s part=%-14s rel_origin=(%.3f, %.3f, %.3f) basis_euler=(%.3f, %.3f, %.3f)" % [
				nm, str(part.name), local.origin.x, local.origin.y, local.origin.z, e.x, e.y, e.z])
		scene.free()
	print("MODERN_RELATIVE_TRANSFORM_DONE")
	quit(0)
func _accum(node: Node, acc: Transform3D, out: Dictionary) -> void:
	var here := acc
	if node is Node3D:
		here = acc * (node as Node3D).transform
		out[node] = here
	for child in node.get_children(): _accum(child, here, out)
## PART_ROLES chooses the role node: barrel parts hang off the gun pivot, turret parts off the turret
## pivot, running parts off the running branch (the validator then uses the hull transform for those), and
## everything else off the hull.
func _part_for(node: Node, world: Dictionary) -> Node:
	var nm := str(node.name)
	var chain: Array[Node] = []
	var cur: Node = node.get_parent()
	while cur != null:
		if world.has(cur): chain.append(cur)
		cur = cur.get_parent()
	if chain.is_empty(): return null
	for parent in chain:
		if str(parent.name) == "GunPivot": return parent
	if nm.contains("ammo_ready") or nm.contains("gunner") or nm.contains("commander") or nm.contains("loader"):
		for parent in chain:
			if str(parent.name) == "TurretPivot": return parent
	for parent in chain:
		if str(parent.name).begins_with("Running"): return parent
	return chain[chain.size() - 1]