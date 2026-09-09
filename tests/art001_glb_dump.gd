extends SceneTree
## GLB 树全量 dump：每个节点的 name/class/局部 pos/rot(度)/scale + MeshInstance 的 AABB 尺寸
const GLB := "res://assets/art001/m4a3_pilot/m4a3_1k.glb"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ps := load(GLB) as PackedScene
	var root: Node = ps.instantiate()
	root.add_child(self.root)
	_dump(root, 0)
	quit(0)
func _dump(n: Node, depth: int) -> void:
	var ind := "  ".repeat(depth)
	var t := ""
	if n is Node3D:
		var x := (n as Node3D).transform
		var pos := x.origin
		var basis := x.basis.get_rotation_quaternion().get_euler()
		var scl := x.basis.get_scale()
		t = " pos=(%.3f,%.3f,%.3f) rot=(%.1f,%.1f,%.1f)deg scale=(%.2f,%.2f,%.2f)" % [pos.x, pos.y, pos.z, rad_to_deg(basis.x), rad_to_deg(basis.y), rad_to_deg(basis.z), scl.x, scl.y, scl.z]
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.get_aabb()
		extra = " aabb_size=(%.2f,%.2f,%.2f) tris=%d" % [aabb.size.x, aabb.size.y, aabb.size.z, _tri(mi)]
	print("%s%s [%s]%s%s" % [ind, n.name, n.get_class(), t, extra])
	for c in n.get_children():
		_dump(c, depth + 1)
func _tri(mi: MeshInstance3D) -> int:
	var m := mi.mesh
	if m == null:
		return 0
	var t := 0
	for s in m.get_surface_count():
		var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		t += idx.size() / 3 if idx.size() > 0 else 0
	return t