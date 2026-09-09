extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ps := load("res://assets/art001/m4a3_pilot/m4a3_1k.glb") as PackedScene
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	var mi := inst.find_child("LOW_hull_Shell", true, false) as MeshInstance3D
	var tex := load("res://assets/art001/m4a3_pilot/normal_gl.png") as Texture2D
	print("ART001 NORM tex_ok=", tex != null, " size=", tex.get_width() if tex != null else -1)
	var mat := mi.get_active_material(0)
	var std := mat as StandardMaterial3D
	print("ART001 NORM glb_material_std=", std != null, " normal_enabled=", std != null and std.normal_enabled)
	var m := BakeComparison.material_for("C")
	print("ART001 NORM C normal_enabled=", m.normal_enabled, " tex_ok=", m.normal_texture != null, " scale=", m.normal_scale)
	quit()
