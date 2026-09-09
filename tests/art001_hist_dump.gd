extends SceneTree
## 历史模型基准 dump：每个 MeshInstance 的世界 AABB 尺寸（Y-up Godot 空间）
const GLB := "res://assets/vehicles/us_m4a3_75w_vvss_1944.glb"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ps := load(GLB) as PackedScene
	var root: Node = ps.instantiate()
	self.root.add_child(root)
	_dump(root, 0)
	quit(0)
func _dump(n: Node, depth: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.global_transform * mi.get_aabb()
		var pos := (n as Node3D).position
		print("ART001_HIST %s parent=%s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f) tris=%d" % [
			n.name, n.get_parent().name, pos.x, pos.y, pos.z, aabb.size.x, aabb.size.y, aabb.size.z, _tri(mi)])
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