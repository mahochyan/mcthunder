extends SceneTree
## WT-040-R1: measure the two quantities the last runtime-mount checks compare, using the validator's own
## arithmetic - the muzzle's transform relative to the gun pivot, and the gun's OWN visible meshes' forward
## extent along its -Z. Also reads the geometry draft's barrel_length so the comparison is explicit.
const IDS := ["ussr_t_80b","germ_leopard_2a4"]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var geo := _read("res://logs/WT-040-R1/modern_geometry_draft.json")
	for id in IDS:
		var path := "res://assets/vehicles/modern_bound/%s.glb" % id
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(path,st) != OK: print("[mount] ",id," PARSE_FAILED"); continue
		var scene := doc.generate_scene(st)
		var world := {}; _accum(scene,Transform3D.IDENTITY,world)
		var gun: Variant = null; var muzzle: Variant = null; var turret: Variant = null
		for node in world.keys():
			match str((node as Node).name):
				"GunPivot": gun = node
				"Muzzle": muzzle = node
				"TurretPivot": turret = node
		if gun == null or muzzle == null: print("[mount] ",id," MISSING gun/muzzle"); continue
		var m_from_g: Transform3D = (world[gun] as Transform3D).affine_inverse() * (world[muzzle] as Transform3D)
		var declared := 0.0
		for row in geo.get("rows",[]):
			if str(row.get("id","")) == id: declared = float((row.get("fields",{}) as Dictionary).get("barrel_length",0.0))
		# the gun's OWN visible meshes: under the gun pivot but not inside another articulated part
		var forward := 0.0; var count := 0
		for node in world.keys():
			var mesh := node as MeshInstance3D
			if mesh == null or mesh.mesh == null: continue
			if mesh != gun and not (gun as Node).is_ancestor_of(mesh): continue
			var separate := false
			for other in [turret]:
				if other != null and (gun as Node).is_ancestor_of(other) and (mesh == other or (other as Node).is_ancestor_of(mesh)): separate = true
			if separate: continue
			count += 1
			var rel: Transform3D = (world[gun] as Transform3D).affine_inverse() * (world[mesh] as Transform3D)
			var bounds: AABB = rel * mesh.mesh.get_aabb()
			forward = maxf(forward,-bounds.position.z)
		print("[mount] ",id)
		print("      muzzle relative to gun: x=%.3f y=%.3f z=%.3f  |z|=%.3f  basis_identity=%s" % [m_from_g.origin.x,m_from_g.origin.y,m_from_g.origin.z,absf(m_from_g.origin.z),str(m_from_g.basis.is_equal_approx(Basis.IDENTITY))])
		print("      gun own meshes=%d  gun_forward=%.3f m   geometry.barrel_length=%.3f m   difference=%.3f m" % [count,forward,declared,absf(forward-declared)])
		scene.free()
	print("MODERN_MOUNT_MEASUREMENT_DONE")
	quit(0)
func _accum(node: Node, acc: Transform3D, out: Dictionary) -> void:
	var here := acc
	if node is Node3D:
		here = acc * (node as Node3D).transform
		out[node] = here
	for child in node.get_children(): _accum(child,here,out)
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}