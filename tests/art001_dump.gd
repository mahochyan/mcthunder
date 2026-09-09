extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ps := load("res://assets/art001/m4a3_pilot/m4a3_1k.glb") as PackedScene
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	_dump(inst, 0)
	inst.free()
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		var n3 := n as Node3D
		extra = " pos=%s" % str(n3.position)
	print("ART001GLB", "  ".repeat(d), n.name, extra)
	for c in n.get_children():
		_dump(c, d + 1)
