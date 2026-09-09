extends SceneTree
## 工作流包四车效果截图：侧/前/尾3/4 三视角，棚拍灯光
const SRC := "res://tests/tmp_workflow/"
const OUT := "docs/evidence/workflow-v1/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in ["us_m4a3_75w_vvss_1944", "us_m24_m6_t85e1_1951", "us_m26_m3_1945", "us_m36_m4a1_1945"]:
		var ps := load(SRC + f + ".glb") as PackedScene
		if ps == null:
			print("WORKFLOW_SHOT FAIL load " + f)
			continue
		for view in [["side", 1.5708], ["front", 3.1416], ["rear3q", 0.4]]:
			var root := Node3D.new()
			root.name = "ShotRoot"
			self.root.add_child(root)
			var v := ps.instantiate() as Node3D
			v.rotation.y = view[1]
			root.add_child(v)
			var cam := Camera3D.new()
			cam.position = Vector3(0, 2.6, 9.0)
			root.add_child(cam)
			cam.look_at(Vector3(0, 1.0, 0))
			cam.make_current()
			var key := DirectionalLight3D.new()
			key.rotation_degrees = Vector3(-45, 30, 0)
			key.light_energy = 0.9
			root.add_child(key)
			var fill := DirectionalLight3D.new()
			fill.rotation_degrees = Vector3(-30, 150, 0)
			fill.light_energy = 0.35
			root.add_child(fill)
			var env := WorldEnvironment.new()
			var e := Environment.new()
			e.background_mode = Environment.BG_COLOR
			e.background_color = Color(0.5, 0.55, 0.6)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(0.6, 0.65, 0.7)
			e.ambient_light_energy = 0.3
			e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.environment = e
			root.add_child(env)
			for i in range(6):
				await process_frame
			await RenderingServer.frame_post_draw
			var img := get_root().get_viewport().get_texture().get_image()
			var p: String = OUT + f + "_" + view[0] + ".png"
			var err := img.save_png(ProjectSettings.globalize_path(p))
			print("WORKFLOW_SHOT %s %s err=%d" % [f, view[0], err])
			root.free()
	quit(0)