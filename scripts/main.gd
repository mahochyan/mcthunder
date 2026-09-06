class_name Main
extends Node3D
## 流程（职责：装配 / 暂停恢复 / 重置 / 失焦自动暂停 / 瞄准标记 / 截图自检模式）。
## 节点处理模式：Main=ALWAYS（Esc 与失焦在暂停时仍可用）；Tank 子树=PAUSABLE；HUD 继承 ALWAYS。

var world: WorldBuilder
var tank: TankVehicle
var turret: TurretRig
var cam_rig: CameraRig
var gunner: Gunner
var hud: HUD
var targets: Array = []
var _paused := false
var _autoshot := false
var _debug_on := false
var _shot_step := 0
var _marker_desired: MeshInstance3D   # 青色圆球 = 玩家想瞄的点（相机中心）
var _marker_actual: MeshInstance3D    # 橙色方块 = 炮管实际指向

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autoshot = OS.get_cmdline_user_args().has("--autoshot")
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build()
	targets = world.targets
	var tank_scene: PackedScene = load("res://scenes/tank.tscn")
	tank = tank_scene.instantiate()
	tank.name = "Tank"
	add_child(tank)
	turret = tank.turret_rig
	cam_rig = tank.camera_rig
	turret.cam_rig = cam_rig
	cam_rig.turret = turret
	cam_rig.tank = tank
	gunner = Gunner.new()
	gunner.name = "Gunner"
	add_child(gunner)
	gunner.setup(tank, turret)
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	tank.process_mode = Node.PROCESS_MODE_PAUSABLE
	gunner.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not _autoshot and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()
	elif event.is_action_pressed("reset"):
		_reset_all()
	elif event.is_action_pressed("debug_toggle"):
		_debug_on = not _debug_on
		hud.set_debug_visible(_debug_on)

func _pause() -> void:
	if _paused:
		return
	_paused = true
	get_tree().paused = true
	hud.show_pause(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	hud.show_pause(false)
	# 鼠标重捕获：仅无窗口模式跳过；autoshot 模式也执行以便窗口证据（002 T002-04）
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gunner.resume_grace = GameConfig.RESUME_GRACE   # 恢复点击不得意外开炮

func _reset_all() -> void:
	tank.reset()
	cam_rig.aim_yaw = 0.0
	cam_rig.aim_pitch = 0.0
	turret.snap_to_aim()
	gunner.reset_state()
	turret.reset_state()
	for t in targets:
		t.reset()

func _notification(what: int) -> void:
	# 窗口失去焦点自动暂停，避免切回后车辆仍在移动
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _paused and not _autoshot:
			_pause()

func _process(_delta: float) -> void:
	var hits := []
	for t in targets:
		hits.append(t.hit_count)
	hud.update_hud(tank.forward_speed, gunner.cooldown_left, gunner.blocked_reason, hits, cam_rig.sight)
	hud.update_debug(Engine.get_frames_per_second(), tank.forward_speed, rad_to_deg(turret.global_rotation.y), rad_to_deg(turret.barrel_pivot.rotation.x), gunner.cooldown_left)
	_update_markers()
	if _autoshot:
		_autoshot_step()

func _make_marker(sphere: bool, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if sphere:
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.24
		mesh = s
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.22, 0.22, 0.22)
		mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.layers = 1
	add_child(mi)
	return mi

func _in_front(cam_pos: Vector3, cam_fwd: Vector3, p: Vector3) -> bool:
	# 屏幕后方的投影标记隐藏（点积过滤），不跳到错误位置
	return cam_fwd.dot(p - cam_pos) > 0.5

func _update_markers() -> void:
	if _marker_desired == null:
		_marker_desired = _make_marker(true, Color(0.2, 0.9, 1.0))
		_marker_actual = _make_marker(false, Color(1.0, 0.55, 0.1))
	var cam_pos := cam_rig.cam.global_position
	var cam_fwd := -cam_rig.cam.global_transform.basis.z
	var d := cam_rig.get_aim_point()
	var a := gunner.actual_hit_point
	_marker_desired.visible = _in_front(cam_pos, cam_fwd, d)
	_marker_actual.visible = _in_front(cam_pos, cam_fwd, a)
	if _marker_desired.visible:
		_marker_desired.global_position = d
	if _marker_actual.visible:
		_marker_actual.global_position = a

func _autoshot_step() -> void:
	# 截图自检模式（仅 -- --autoshot 启动时）：有限帧、真实抓帧、自动退出。
	# 002 扩展：附带 T002-04 的窗口模式证据（持火跨越暂停/恢复、鼠标重捕获）。
	_shot_step += 1
	match _shot_step:
		40:
			_shot("docs/autoshot_1_thirdperson.png")
			Input.action_press("aim")
		100:
			_shot("docs/autoshot_2_sight.png")
			Input.action_release("aim")
			Input.action_press("move_forward")
		150:
			_shot("docs/autoshot_3_moved.png")
			Input.action_release("move_forward")
			Input.action_press("fire")   # 持火跨越暂停（T002-04）
		160:
			_pause()
		170:
			_shot("docs/autoshot_4_paused.png")
			print("[T002-04] paused: mouse_mode=", Input.mouse_mode, " (0=VISIBLE) shots=", gunner.shots_fired, " cooldown=", "%.2f" % gunner.cooldown_left)
		180:
			_resume()
			print("[T002-04] resumed: mouse_mode=", Input.mouse_mode, " (2=CAPTURED) grace=", "%.2f" % gunner.resume_grace)
		190:
			Input.action_release("fire")
			_shot("docs/autoshot_5_resumed.png")
			print("[T002-04] after resume+hold: shots=", gunner.shots_fired, "（应与暂停期间一致，无补射）")
		200:
			get_tree().quit()

func _shot(rel: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("[autoshot] FAILED to capture ", rel)
		return
	var path := ProjectSettings.globalize_path("res://" + rel)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(path)
	if err == OK:
		print("[autoshot] saved ", path)
	else:
		print("[autoshot] FAILED (err=", err, ") to save ", path)