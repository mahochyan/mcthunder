class_name BakedVisualAdapter
extends RefCounted
## ART-001 单车烘焙试产——仅测试模式使用：
## bind() 隐藏程序装配视觉（Skin_*/Cosmetic_*/TrackShoes），实例化烘焙低模 GLB
## （assets/art001/m4a3_pilot/m4a3_1k.glb），碰撞/射击/履带物理逻辑完全不动。
## restore() 完整还原。不写任何游戏运行时状态。

const BAKED_SCENE := "res://assets/art001/m4a3_pilot/m4a3_1k.glb"

var _hidden: Array[Node] = []
var _root: Node3D = null

func bind(actor: VehicleActor) -> Dictionary:
	_hidden.clear()
	if _root != null:
		return {"ok": false, "error": "already bound"}
	for parent in [actor.tank, actor.turret, actor.turret.barrel_pivot]:
		for child in parent.get_children():
			var n := str(child.name)
			if n.begins_with("Skin_") or n.begins_with("Cosmetic") or n.begins_with("TrackMotion"):
				child.visible = false
				_hidden.append(child)
	var scene := load(BAKED_SCENE) as PackedScene
	if scene == null:
		return {"ok": false, "error": "missing baked scene " + BAKED_SCENE}
	var source := scene.instantiate() as Node3D
	if source == null:
		return {"ok": false, "error": "cannot instantiate baked scene"}
	_root = Node3D.new()
	_root.name = "BakedPilotVisual"
	actor.tank.add_child(_root)
	var added := 0
	for part in ["hull", "turret", "barrel"]:
		var authored := source if str(source.name) == part else source.find_child(part, true, false)
		if authored == null:
			continue
		var parent2: Node3D = actor.tank if part == "hull" else (actor.turret if part == "turret" else actor.turret.barrel_pivot)
		for child in authored.get_children():
			var dup := child.duplicate() as Node3D
			parent2.add_child(dup)
			_set_layers(dup, actor.tank.visual_layer)
			added += 1
	source.free()
	return {"ok": true, "hidden": _hidden.size(), "added": added}

func restore(actor: VehicleActor) -> void:
	for child in _hidden:
		if is_instance_valid(child):
			child.visible = true
	_hidden.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null

## 烘焙低模网格实例清单（供材质变体切换）
func mesh_instances() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _root == null:
		return out
	_collect(_root, out)
	return out

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect(c, out)

## 对齐校验：烘焙低模装甲壳面顶点 vs 布局装甲面外表面角点（≤1cm）
static func audit_alignment(actor: VehicleActor, patches: Array, tolerance_m: float) -> Dictionary:
	var scene := load(BAKED_SCENE) as PackedScene
	if scene == null:
		return {"ok": false, "error": "missing baked scene"}
	var source := scene.instantiate() as Node3D
	var worst := 0.0
	var checked := 0
	var ok := true
	for part in ["hull", "turret", "barrel"]:
		var authored := source if str(source.name) == part else source.find_child(part, true, false)
		if authored == null:
			continue
		for child in authored.get_children():
			if not (child is MeshInstance3D) or not str(child.name).contains("Shell"):
				continue
			var m2 := (child as MeshInstance3D).mesh
			var arrays := m2.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for mv in verts:
				var best := INF
				for patch2 in patches:
					for v2 in patch2.vertices_local_m:
						var pv := Vector3(float(v2[0]), float(v2[1]), float(v2[2]))
						best = min(best, pv.distance_to(mv))
				checked += 1
				if best > worst:
					worst = best
				if best > tolerance_m:
					ok = false
	source.free()
	return {"ok": ok, "checked": checked, "worst_m": worst}

func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_layers(child, layer)