extends SceneTree
## WT-040-R1: why can the muzzle not be measured on some models? RoleMappingAudit resolves the muzzle
## from the barrel mesh, and the T-80B came back with method "none" while the Leopard measured fine.
## This dumps every node of a source GLB - name, class, and whether it is a mesh - so the naming or
## structure difference between a working and a failing model can be seen directly instead of guessed.
## Usage: -s res://tests/probe_source_nodes.gd -- <absolute glb path> [<absolute glb path> ...]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		print("[nodes] no path given"); quit(1); return
	for path in paths:
		var p := str(path)
		print("[nodes] ===== ", p, " exists=", FileAccess.file_exists(p))
		if not FileAccess.file_exists(p): continue
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(p,state) != OK:
			print("[nodes] append failed"); continue
		var scene: Node = document.generate_scene(state)
		if scene == null:
			print("[nodes] scene failed"); continue
		root.add_child(scene)
		var stack: Array[Node] = [scene]
		var total := 0
		var meshes := 0
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			total += 1
			var kind := "node"
			if n is MeshInstance3D:
				kind = "mesh"
				meshes += 1
			elif n is Marker3D:
				kind = "marker"
			var depth := 0
			var parent := n.get_parent()
			while parent != null:
				depth += 1
				parent = parent.get_parent()
			if kind == "mesh" or str(n.name).to_lower().contains("gun") or str(n.name).to_lower().contains("barrel") or str(n.name).to_lower().contains("muzzle") or str(n.name).to_lower().contains("turret"):
				print("[nodes] ", "  ".repeat(depth), kind, " ", str(n.name))
			for child in n.get_children(): stack.append(child)
		print("[nodes] total=", total, " meshes=", meshes)
		root.remove_child(scene)
		scene.free()
	print("SOURCE_NODE_PROBE_DONE")
	quit(0)
