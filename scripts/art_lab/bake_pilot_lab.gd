extends Node3D
## ART-001 烘焙试产实验室：同一低模几何上 A/B/C 变体切换、灯光切换、
## 炮塔旋转/火炮俯仰/相机距离。控制台参数模式用于自动截图对比板：
##   godot --path <root> scenes/art_lab/bake_pilot.tscn -- --shot user://art001_A.png --variant A
##   godot --path <root> scenes/art_lab/bake_pilot.tscn -- --shot user://art001_C.png --variant C --light daylight
## 按键：1/2/3 变体；L 灯光；T 炮塔 90°/180°；G 火炮俯仰；滚轮相机距离。

const DIR := "res://assets/art001/m4a3_pilot/m4a3_1k.glb"
const VARIANTS := ["A", "B", "C"]

var vehicle: Node3D
var cam: Camera3D
var studio: Node3D
var daylight: Node3D
var variant := "C"
var cam_dist := 9.0
var shot_path := ""
var boot_variant := ""

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
			boot_variant = args[i + 1]
		if args[i] == "--light" and i + 1 < args.size():
			_set_light(args[i + 1])
		if args[i] == "--dist" and i + 1 < args.size():
			cam_dist = float(args[i + 1])
		if args[i] == "--yaw" and i + 1 < args.size():
			vehicle.rotation.y = float(args[i + 1])
	cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)
	if boot_variant != "":
		BakeComparison.set_variant(_meshes(), boot_variant)
	else:
		BakeComparison.set_variant(_meshes(), variant)
	for i in args.size():
		if args[i] == "--perf":
			_perf_mode(args)
			return
	if shot_path != "":
		await _autoshot()

## 8 车纯渲染性能采样：10s 预热 + 30s 采样（真实渲染帧，非合成）
func _perf_mode(args: Array) -> void:
	var tag := "B"
	var out_path := "user://art001_perf.txt"
	for i in args.size():
		if args[i] == "--variant" and i + 1 < args.size():
			tag = args[i + 1]
		if args[i] == "--perf-out" and i + 1 < args.size():
			out_path = args[i + 1]
	var scene := load(DIR) as PackedScene
	for k in range(8):
		var v := scene.instantiate() as Node3D
		v.position = Vector3(-14.0 + (k % 4) * 9.0, 0, -8.0 + float(k / 4) * 12.0)
		add_child(v)
		BakeComparison.set_variant(_collect_meshes(v), tag)
	_set_light("daylight")
	await get_tree().create_timer(10.0).timeout   # 预热 10s（着色器编译/缓存）
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:      # 采样 30s
		await get_tree().process_frame
		frames += 1
	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	var fps := float(frames) / elapsed
	var line := "ART001_PERF variant=%s vehicles=8 frames=%d seconds=%.1f avg_fps=%.1f gpu_timestamps=NOT_CAPTURED" % [tag, frames, elapsed, fps]
	print(line)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_line(line)
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
	var out := []
	var stack := [vehicle]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out

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
		if k.keycode == KEY_1:
			variant = "A"
		elif k.keycode == KEY_2:
			variant = "B"
		elif k.keycode == KEY_3:
			variant = "C"
		elif k.keycode == KEY_L:
			_set_light("daylight" if studio.visible else "studio")
		elif k.keycode == KEY_T:
			var t := vehicle.find_child("turret", true, false)
			if t is Node3D:
				(t as Node3D).rotation.y = 0.0 if absf((t as Node3D).rotation.y) < 0.1 else (PI * 0.5 if absf((t as Node3D).rotation.y) < 1.0 else PI)
		elif k.keycode == KEY_G:
			var b := vehicle.find_child("barrel", true, false)
			if b is Node3D:
				(b as Node3D).rotation.x = 0.0 if absf((b as Node3D).rotation.x) < 0.1 else 0.25
		elif k.keycode == KEY_UP:
			cam_dist = maxf(3.0, cam_dist - 1.0)
		elif k.keycode == KEY_DOWN:
			cam_dist = minf(30.0, cam_dist + 1.0)
		else:
			return
		BakeComparison.set_variant(_meshes(), variant)
		cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(3.0, cam_dist - 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(30.0, cam_dist + 1.0)
		cam.position = Vector3(cam.position.x, 2.4 + cam_dist * 0.2, cam_dist)

func _autoshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(shot_path)
	print("ART001_SHOT %s -> %s (%d)" % [boot_variant, shot_path, err])
	get_tree().quit()