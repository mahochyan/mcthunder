extends SceneTree
## T-34 像素级对齐：正交白底侧/前/后视（供程序化 alpha 叠加对比）
const SRC := "res://tests/tmp_t34/t34_replica.glb"
const OUT := "docs/evidence/t34/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ps := load(SRC) as PackedScene
	if ps == null:
		print("ORTHO FAIL load")
		quit(1)
		return
	var root := Node3D.new()
	root.name = "ShotRoot"
	self.root.add_child(root)
	var v := ps.instantiate() as Node3D
	root.add_child(v)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 25, 0)
	key.light_energy = 1.1
	root.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-15, -150, 0)
	back.light_energy = 0.7
	root.add_child(back)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(1, 1, 1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.87)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	for view in [["oside", Vector3(9, 1.15, 0), Vector3(0, 1.15, 0), 4.4],
			["ofront", Vector3(0, 1.15, -9), Vector3(0, 1.15, 0), 4.4],
			["orear", Vector3(0, 1.15, 9), Vector3(0, 1.15, 0), 4.4]]:
		cam.position = view[1]
		cam.look_at_from_position(view[1], view[2], Vector3.UP)
		cam.size = view[3]
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_viewport().get_texture().get_image()
		var p: String = OUT + "t34_" + view[0] + ".png"
		var err := img.save_png(ProjectSettings.globalize_path(p))
		print("ORTHO_SHOT %s err=%d" % [view[0], err])
	quit(0)
