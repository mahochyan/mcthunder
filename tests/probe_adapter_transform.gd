extends SceneTree
## WT-036-R1 diagnostic: the adapter artifact's MuzzlePoint measures at the origin after export, and
## two export styles both reproduced it. This probe separates the two possible causes: whether the
## transform is missing from the file itself (exporter dropped it) or whether it is in the file but
## the imported scene's global differs (parenting/import). It reads the glTF node list first, then
## the generated scene's local and global transforms.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var adapter := str(args[0]) if args.size() > 0 else "res://assets/vehicles/adapters/35t/vehicle_adapter.glb"
	print("[probe] artifact=",adapter," exists=",FileAccess.file_exists(adapter))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var loaded := document.append_from_file(adapter,state)
	print("[probe] append_result=",loaded)
	# 1) What the FILE says (glTF node list).
	var nodes: Array = state.get_nodes()
	print("[probe] gltf nodes=",nodes.size())
	for i in nodes.size():
		var node: Variant = nodes[i]
		var node_name := str(node.get("name")) if node is Object and node.get("name") != null else ("#%d"%i)
		var transform := ""
		if node is Object:
			var t: Variant = node.get("transform")
			if t is Transform3D: transform = str(t)
			else:
				var tr: Variant = node.get("translation")
				if tr is Vector3: transform = "translation=" + str(tr)
		if node_name.contains("Muzzle") or node_name.contains("Gun") or node_name.contains("Turret") or i < 4:
			print("[probe]   file-node[%d] name=%s %s" % [i,node_name,transform])
	# 2) What the SCENE says (local and global).
	var scene: Node = document.generate_scene(state)
	if scene == null:
		print("[probe] scene generation failed"); quit(1); return
	print("[probe] scene root=",scene.name," type=",scene.get_class())
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			var n3 := n as Node3D
			if str(n.name).contains("Muzzle") or str(n.name).contains("Gun") or str(n.name).contains("Turret") or n == scene:
				print("[probe]   scene-node %s parent=%s local_pos=%s global_pos=%s" % [
					str(n.name),str(n.get_parent().name) if n.get_parent() != null else "-",
					str(n3.position),str(n3.global_position)])
		for child in n.get_children(): stack.append(child)
	print("ADAPTER_TRANSFORM_PROBE_DONE")
	quit(0)
