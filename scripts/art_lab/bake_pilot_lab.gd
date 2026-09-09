extends Node3D
## ART-001 烘焙试产实验室：同一低模几何上 A/B/C 变体切换、灯光切换、
## 炮塔旋转/火炮俯仰/相机距离。控制台参数模式用于自动截图对比板：
##   godot --path <root> scenes/art_lab/bake_pilot.tscn -- --shot user://art001_A.png --variant A
##   godot --path <root> scenes/art_lab/bake_pilot.tscn -- --shot user://art001_C.png --variant C --light daylight
## 按键：1/2/3 变体；L 灯光；T 炮塔档位循环 0°→90°→180°；G 火炮俯仰档位循环；滚轮相机距离。
## 约定：variant 是唯一材质状态源——命令行/按键共用；切灯/转炮/改距离不重设材质。

const DIR := "res://assets/art001/m4a3_pilot/m4a3_1k.glb"
const VARIANTS := ["A", "B", "C"]

var vehicle: Node3D
var cam: Camera3D
var studio: Node3D
var daylight: Node3D
var variant := "C"                 # 唯一材质状态源
var cam_dist := 9.0
var shot_path := ""
var turret_step := 0               # 姿态档位：0=0°, 1=90°, 2=180°
var gun_step := 0                  # 俯仰档位：0=0°, 1=+10°, 2=-5°
const TURRET_STEPS := [0.0, PI * 0.5, PI]
const GUN_STEPS := [0.0, 10.0 * PI / 180.0, -5.0 * PI / 180.0]

func _ready() -> void:
	var scene := load(DIR) as PackedScene
	if scene == null:
		push_error("bake_pilot_lab: missing " + DIR)
		return
	vehicle = scene.instantiate() as Node3D
	vehicle.name = "BakedVehicle"
	add_child(vehicle)
	var ground := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(40, 40)
	ground.mesh = gmesh
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.24, 0.25, 0.22)
	ground.material_override = gm
	add_child(ground)
	studio = _make_studio()
	daylight = _make_daylight()
	add_child(studio)
	add_child(daylight)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.4, cam_dist)
	add_child(cam)
	cam.make_current()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			shot_path = args[i + 1]
		if args[i] == "--variant" and i + 1 < args.size():
			variant = args[i + 1]          # 命令行与按键共用同一状态
		if args[i] == "--light" and i + 1 < args.size():
			_set_light(args[i + 1])
		if args[i] == "--dist" and i + 1 < args.size():
			cam_dist = float(args[i + 1])
		if args[i] == "--yaw" and i + 1 < args.size():
			vehicle.rotation.y = float(args[i + 1])
	cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)
	_apply_variant()
	for i in args.size():
		if args[i] == "--perf":
			_perf_mode(args)
			return
	if shot_path != "":
		await _autoshot()

func _apply_variant() -> void:
	BakeComparison.set_variant(_meshes(), variant)

## 8 车纯渲染性能采样：关 vsync，预热 10s，B/C 交错两轮各 15s，
## 记录每轮平均帧时间与 P95 + 引擎绘制统计；GPU 时间戳取不到则 NOT_CAPTURED。
func _perf_mode(args: Array) -> void:
	var out_path := "user://art001_perf.txt"
	for i in args.size():
		if args[i] == "--perf-out" and i + 1 < args.size():
			out_path = args[i + 1]
	# 恰好 8 辆、8 个独立格位（i=0..7，第一辆 = 默认 vehicle，无重合）
	var positions: Array[Vector3] = []
	for i in range(8):
		positions.append(Vector3(-10.5 + float(i % 4) * 7.0, 0.0, -4.0 + float(i / 4) * 10.0))
	var uniq := {}
	for p in positions:
		uniq[p] = true
	if uniq.size() != 8:
		push_error("perf grid has overlapping positions")
		get_tree().quit(1)
		return
	vehicle.position = positions[0]
	var scene := load(DIR) as PackedScene
	for i in range(7):
		var v := scene.instantiate() as Node3D
		v.name = "BakedVehicle_%d" % (i + 2)
		v.position = positions[i + 1]
		add_child(v)
	# 相机按车阵包围盒取景，并校验 8 辆都在视锥内
	var center := Vector3.ZERO
	for p in positions:
		center += p
	center = center / 8.0
	cam.position = center + Vector3(0, 6.5, 16.0)
	cam.look_at(center)
	_set_light("daylight")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # 解除 60fps 封顶
	var vehicles := []
	for c in get_children():
		if c.name.begins_with("BakedVehicle"):
			vehicles.append(c)
	# 真实入镜校验：8 辆位置都必须在相机视锥内
	var all_in_view := true
	for v in vehicles:
		if not cam.is_position_in_frustum((v as Node3D).global_position + Vector3(0, 1.0, 0)):
			all_in_view = false
	# 场景清点（网格节点数与三角累计，非引擎绘制统计）
	var visible_tris := 0
	var mesh_nodes := 0
	for v in vehicles:
		for mi in _collect_meshes(v):
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			mesh_nodes += 1
			for s in m.get_surface_count():
				var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				visible_tris += idx.size() / 3 if idx.size() > 0 else 0
	var plan := [["B", 15.0], ["C", 15.0], ["B", 15.0], ["C", 15.0]]  # 交错两轮
	var lines: Array[String] = []
	lines.append("ART001_PERF vehicles=8 positions_unique=%s all_in_frustum=%s scene_mesh_nodes=%d scene_tris=%d gpu_timestamps=NOT_CAPTURED vsync=disabled" % [str(uniq.size() == 8), str(all_in_view), mesh_nodes, visible_tris])
	print(lines[0])
	if not all_in_view:
		get_tree().quit(1)
		return
	await get_tree().create_timer(10.0).timeout   # 预热 10s（着色器编译/缓存）
	for round_cfg in plan:
		var tag: String = round_cfg[0]
		var secs: float = round_cfg[1]
		for v in vehicles:
			BakeComparison.set_variant(_collect_meshes(v), tag)
		var deltas: Array[float] = []
		var draw_sum := 0
		var draw_n := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			deltas.append(float(Time.get_ticks_usec() - f0) / 1000.0)
			draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			draw_n += 1
		deltas.sort()
		var avg := 0.0
		for d in deltas:
			avg += d
		avg = avg / maxf(float(deltas.size()), 1.0)
		var p95: float = deltas[int(float(deltas.size()) * 0.95)]
		var avg_draws := float(draw_sum) / maxf(float(draw_n), 1.0)
		var line := "ART001_PERF variant=%s frames=%d seconds=%.1f avg_frame_ms=%.2f p95_frame_ms=%.2f avg_fps=%.1f engine_draw_calls_avg=%.0f" % [
			tag, deltas.size(), secs, avg, p95, 1000.0 / maxf(avg, 0.01), avg_draws]
		print(line)
		lines.append(line)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		for l in lines:
			f.store_line(l)
		f.close()
	get_tree().quit()

func _collect_meshes(root: Node) -> Array:
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out

func _meshes() -> Array:
	return _collect_meshes(vehicle)

func _make_studio() -> Node3D:
	var rig := Node3D.new()
	rig.name = "StudioLights"
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 30, 0)
	key.light_energy = 1.2
	rig.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_energy = 0.5
	rig.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -90, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.85, 0.9, 1.0)
	rig.add_child(rim)
	return rig

func _make_daylight() -> Node3D:
	var rig := Node3D.new()
	rig.name = "Daylight"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 200, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.88)
	rig.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.75)
	e.ambient_light_energy = 0.8
	env.environment = e
	rig.add_child(env)
	return rig

func _set_light(mode: String) -> void:
	studio.visible = mode != "daylight"
	daylight.visible = mode == "daylight"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var variant_changed := false
		if k.keycode == KEY_1:
			variant = "A"
			variant_changed = true
		elif k.keycode == KEY_2:
			variant = "B"
			variant_changed = true
		elif k.keycode == KEY_3:
			variant = "C"
			variant_changed = true
		elif k.keycode == KEY_L:
			_set_light("daylight" if studio.visible else "studio")
		elif k.keycode == KEY_T:
			turret_step = (turret_step + 1) % TURRET_STEPS.size()
			var t := vehicle.find_child("turret", true, false)
			if t is Node3D:
				(t as Node3D).rotation.y = TURRET_STEPS[turret_step]
		elif k.keycode == KEY_G:
			gun_step = (gun_step + 1) % GUN_STEPS.size()
			var b := vehicle.find_child("barrel", true, false)
			if b is Node3D:
				(b as Node3D).rotation.x = GUN_STEPS[gun_step]
		elif k.keycode == KEY_UP:
			cam_dist = maxf(3.0, cam_dist - 1.0)
		elif k.keycode == KEY_DOWN:
			cam_dist = minf(30.0, cam_dist + 1.0)
		else:
			return
		if variant_changed:
			_apply_variant()   # 只有变体变化才重设材质；切灯/转炮/距离不动 B/C
		cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(3.0, cam_dist - 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(30.0, cam_dist + 1.0)
		cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)

func _autoshot() -> void:
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw   # 真实帧绘制完成后抓帧
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(shot_path)
	if err != OK:
		print("ART001_SHOT FAILED %s -> %s err=%d" % [variant, shot_path, err])
		get_tree().quit(1)
		return
	print("ART001_SHOT variant=%s cam_dist=%.1f fov=%.0f -> %s (%d)" % [variant, cam_dist, cam.fov, shot_path, err])
	get_tree().quit()