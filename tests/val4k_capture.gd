extends SceneTree
## VAL-4K 概念图目检截图：hero/side/front/rear/底盘特写/炮塔特写
const SRC := "res://tests/tmp_workflow/us_m4a3_val4k.glb"
const OUT := "docs/evidence/val4k/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ps := load(SRC) as PackedScene
	if ps == null:
		print("VAL4K_SHOT FAIL load")
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
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_energy = 0.95
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 160, 0)
	fill.light_energy = 0.4
	root.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.82, 0.83)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	for view in [["hero", Vector3(6.5, 3.2, -6.5), Vector3(0, 1.1, 0)],
			["side", Vector3(-10.5, 1.4, .3), Vector3(0, .9, 0)],
			["front", Vector3(0, 1.7, -10.0), Vector3(0, 1.1, 0)],
			["rear", Vector3(.5, 2.0, 10.0), Vector3(0, 1.2, 0)],
			["chassis", Vector3(-2.2, .9, -7.0), Vector3(-1.0, .6, 1.0)],
			["turret", Vector3(2.8, 3.0, -2.6), Vector3(.3, 2.5, -.3)]]:
		cam.position = view[1]
		cam.look_at_from_position(view[1], view[2], Vector3.UP)
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_viewport().get_texture().get_image()
		var p: String = OUT + "val4k_" + view[0] + ".png"
		var err := img.save_png(ProjectSettings.globalize_path(p))
		print("VAL4K_SHOT %s err=%d" % [view[0], err])
	quit(0)
