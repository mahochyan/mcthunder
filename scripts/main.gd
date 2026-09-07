class_name Main
extends Node3D
## 流程（职责：装配 / 暂停恢复 / 重置 / 失焦自动暂停 / 瞄准标记 / 截图自检模式）。
## 003：装配两辆独立车辆实体（A=玩家控制，B=测试目标零命令）；统一生成/销毁入口；
## reset_vehicle（单车）与 reset_range（整场）分离；试射目标（A 命中 B 三次）。
## 节点处理模式：Main=ALWAYS（Esc 与失焦在暂停时仍可用）；Actor 子树=PAUSABLE；HUD 继承 ALWAYS。

var world: WorldBuilder
var defs: VehicleDefs
var controller: PlayerController
var actor_a: VehicleActor
var actor_b: VehicleActor
var tank: TankVehicle        # 兼容引用 → actor_a.tank（现有测试/autoshot 使用）
var turret: TurretRig        # 兼容引用 → actor_a.turret
var cam_rig: CameraRig       # 兼容引用 → actor_a.cam_rig
var gunner: Gunner           # 兼容引用 → actor_a.gunner
var hud: HUD
var targets: Array = []
var trial_hits := 0           # 003：试射目标计数（只由 B 的真实生产命中事件推进）
const TRIAL_TARGET := 3
var _paused := false
var _autoshot := false
var _debug_on := false
var _shot_step := 0
var _shot_errors := 0    # 002-R1：截图失败汇总（必需截图失败 → 自检退出码非 0）
var _shots_saved := 0
var _shot_dir := "docs"  # 002-R2：--shot-dir <路径> 指定归档目录（分分辨率独立保存）
var _marker_desired: MeshInstance3D   # 青色圆球 = 玩家想瞄的点（相机中心）
var _marker_actual: MeshInstance3D    # 橙色方块 = 炮管实际指向

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autoshot = OS.get_cmdline_user_args().has("--autoshot")
	var ua := OS.get_cmdline_user_args()
	for i in ua.size():
		if ua[i] == "--shot-dir" and i + 1 < ua.size():
			_shot_dir = ua[i + 1]
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build()
	targets = world.targets
	defs = VehicleDefs.new()
	var lr := defs.load_defaults()
	if not lr.ok:
		push_error("003: default defs load failed: " + ", ".join(lr.errors))
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	actor_a = VehicleActor.new()
	actor_a.name = "ActorA"
	add_child(actor_a)
	var ra := actor_a.setup(defs, "player_tank", "A", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 8)), GameConfig.VIS_LAYER_VEHICLE, controller)
	if not ra.ok:
		push_error("003: actor A setup failed: " + ", ".join(ra.errors))
	actor_b = VehicleActor.new()
	actor_b.name = "ActorB"
	add_child(actor_b)
	var rb := actor_b.setup(defs, "player_tank", "B", 2, Transform3D(Basis.IDENTITY, Vector3(8, 0, 0)), GameConfig.VIS_LAYER_VEHICLE_B, null)
	if not rb.ok:
		push_error("003: actor B setup failed: " + ", ".join(rb.errors))
	# 兼容引用（指向 A 组件）
	tank = actor_a.tank
	turret = actor_a.turret
	cam_rig = actor_a.cam_rig
	gunner = actor_a.gunner
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	# 试射目标：B 的真实生产命中事件推进计数（同一发命中不重复记分）
	actor_b.tank.hit_registered.connect(_on_b_hit)
	if not _autoshot and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_b_hit() -> void:
	if trial_hits < TRIAL_TARGET:
		trial_hits += 1

func spawn_vehicle(vehicle_id: String, entity_id: String, pos: Vector3, ctrl: Node = null) -> VehicleActor:
	# 003：统一实体生成入口（T003-04 生命周期测试用）
	var a := VehicleActor.new()
	a.name = "Spawned_" + entity_id
	add_child(a)
	var r := a.setup(defs, vehicle_id, entity_id, 9, Transform3D(Basis.IDENTITY, pos), GameConfig.VIS_LAYER_VEHICLE_B, ctrl)
	if not r.ok:
		a.queue_free()
		return null
	return a

func despawn_vehicle(a: VehicleActor) -> void:
	# 003：统一实体销毁入口（信号随对象释放自动断开；相机 current 由本地控制者设置管理）
	if a == null:
		return
	a.queue_free()

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
	# 兼容别名（002 测试沿用）；003 语义 = 整场重开
	reset_range()

func reset_range() -> void:
	# 003：整场重开——两车 + 靶板 + 试射目标全部复位
	actor_a.reset_vehicle()
	actor_b.reset_vehicle()
	for t in targets:
		t.reset()
	trial_hits = 0

func reset_vehicle(actor: VehicleActor) -> void:
	# 003：单车重置——不污染其他车/靶场/试射目标
	if actor != null:
		actor.reset_vehicle()

func _notification(what: int) -> void:
	# 窗口失去焦点自动暂停，避免切回后车辆仍在移动
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _paused and not _autoshot:
			_pause()

func _process(_delta: float) -> void:
	var hits := []
	for t in targets:
		hits.append(t.hit_count)
	var control_text := "CONTROL: A (PLAYER)"
	var result_text := ""
	if gunner.last_shot_result != "":
		result_text = "LAST SHOT: " + gunner.last_shot_result.to_upper()
	var trial_text := "TRIAL: A HIT B %d/%d" % [trial_hits, TRIAL_TARGET]
	if trial_hits >= TRIAL_TARGET:
		trial_text = "TRIAL COMPLETE: A HIT B 3/3 (R to restart)"
	hud.update_hud(tank.forward_speed, gunner.cooldown_left, gunner.blocked_reason, hits, cam_rig.sight, control_text, result_text, trial_text)
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
	var d := cam_rig.intent_point()   # 002-R2：期望瞄点 = 输入意图射线命中点
	var a := gunner.actual_hit_point
	_marker_desired.visible = _in_front(cam_pos, cam_fwd, d)
	_marker_actual.visible = _in_front(cam_pos, cam_fwd, a)
	if _marker_desired.visible:
		_marker_desired.global_position = d
	if _marker_actual.visible:
		_marker_actual.global_position = a

func _autoshot_step() -> void:
	# 截图自检模式（仅 -- --autoshot 启动时）：有限帧、真实抓帧、自动退出。
	# 002 扩展：T002-04 窗口证据（持火跨越暂停/恢复、鼠标重捕获）；
	# 002-R2 扩展：真实鼠标事件验证俯仰响应（下压/水平/上抬）。
	_shot_step += 1
	match _shot_step:
		40:
			_shot("autoshot_1_thirdperson.png")
			Input.action_press("aim")
		100:
			_shot("autoshot_2_sight.png")
			Input.action_release("aim")
			Input.action_press("move_forward")
		150:
			_shot("autoshot_3_moved.png")
			Input.action_release("move_forward")
			Input.action_press("fire")   # 持火跨越暂停（T002-04）
		160:
			_pause()
		170:
			_shot("autoshot_4_paused.png")
			print("[T002-04] paused: mouse_mode=", Input.mouse_mode, " (0=VISIBLE) shots=", gunner.shots_fired, " cooldown=", "%.2f" % gunner.cooldown_left)
		180:
			_resume()
			print("[T002-04] resumed: mouse_mode=", Input.mouse_mode, " (2=CAPTURED) grace=", "%.2f" % gunner.resume_grace)
		185:
			var ev_dn := InputEventMouseMotion.new()
			ev_dn.relative = Vector2(0, 60)   # 下压
			Input.parse_input_event(ev_dn)
		186:
			var ev_lv := InputEventMouseMotion.new()
			ev_lv.relative = Vector2(0, -60)   # 回水平
			Input.parse_input_event(ev_lv)
			call_deferred("_print_aim", "after mouse down")
		187:
			var ev_up := InputEventMouseMotion.new()
			ev_up.relative = Vector2(0, -60)   # 上抬
			Input.parse_input_event(ev_up)
			call_deferred("_print_aim", "after mouse level")
		188:
			call_deferred("_print_aim", "after mouse up")
		190:
			Input.action_release("fire")
			_shot("autoshot_5_resumed.png")
			print("[T002-04] after resume+hold: shots=", gunner.shots_fired, "（应与暂停期间一致，无补射）")
			for i in 3:
				_reset_all()   # T002-05 窗口证据：重置不得暂停或释放鼠标
			print("[T002-05] after 3 resets: mouse_mode=", Input.mouse_mode, " paused=", _paused, " (2=CAPTURED, false)")
		200:
			print("[autoshot] done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			get_tree().quit(1 if (_shot_errors > 0 or _shots_saved < 5) else 0)   # 002-R1：截图失败 → 自检非零

func _print_aim(label: String) -> void:
	# 002-R2：帧末（相机 _process 之后）打印意图俯仰与相机前向俯仰的匹配对
	print("[R2-A] ", label, ": aim_pitch=", "%.2f" % rad_to_deg(cam_rig.aim_pitch), " cam_fwd_pitch=", "%.2f" % rad_to_deg(asin(-cam_rig.cam.global_transform.basis.z.y)))

func _shot(rel: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("[autoshot] FAILED to capture ", rel)
		_shot_errors += 1
		return
	var path := ProjectSettings.globalize_path("res://" + _shot_dir + "/" + rel)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(path)
	if err == OK:
		print("[autoshot] saved ", path)
		_shots_saved += 1
	else:
		print("[autoshot] FAILED (err=", err, ") to save ", path)
		_shot_errors += 1