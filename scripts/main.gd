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
var _round_id := 0            # 003-R1：任务轮次/生命周期标识（reset_range 递增；旧轮次命中无效）
var _round_shots := {}        # 003-R2：本回合已计分射击编号（重开清空；旧事件由轮次+生命周期拒绝）
var _paused := false
var _aborted := false         # 003-R2：启动失败短路标志（true = 停止正常帧/输入处理）
var _abort_reason := ""
var _autoshot := false
var _debug_on := false
var _shot_step := 0
var _shot_errors := 0    # 002-R1：截图失败汇总（必需截图失败 → 自检退出码非 0）
var _shots_saved := 0
var _shot_dir := "docs"  # 002-R2：--shot-dir <路径> 指定归档目录（分分辨率独立保存）
var _autoshot_wait := 0   # 003-R1：正常演示跨帧等待（>0 每帧递减，纯等待后推进到下一步；装填轮询用 _shot_step -= 1 原地驻留）
var _demo_poll := 0       # 003-R2：自然瞄准/装填轮询帧计数（有限超时判据）
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
		# 003-R2：启动失败受控短路——打印错误后真正停止装配，不继续使用半初始化组件
		_abort_initialization("default defs load failed", lr.errors)
		return
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	actor_a = VehicleActor.new()
	actor_a.name = "ActorA"
	add_child(actor_a)
	var ra := actor_a.setup(defs, "player_tank", "A", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 8)), GameConfig.VIS_LAYER_VEHICLE, controller)
	if not ra.ok:
		_abort_initialization("actor A setup failed", ra.errors)
		return
	actor_b = VehicleActor.new()
	actor_b.name = "ActorB"
	add_child(actor_b)
	var rb := actor_b.setup(defs, "player_tank", "B", 2, Transform3D(Basis.IDENTITY, Vector3(8, 0, 0)), GameConfig.VIS_LAYER_VEHICLE_B, null)
	if not rb.ok:
		_abort_initialization("actor B setup failed", rb.errors)
		return
	# 兼容引用（指向 A 组件）
	tank = actor_a.tank
	turret = actor_a.turret
	cam_rig = actor_a.cam_rig
	gunner = actor_a.gunner
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	# 试射目标：B 的真实生产命中事件推进计数（完整身份校验见 _on_b_hit）
	actor_b.tank.hit_registered.connect(_on_b_hit)
	# 003-R2：发射身份的轮次来源（A/B 由 _ready 直建，不经 spawn_vehicle，需注入）
	actor_a.gunner.round_provider = Callable(self, "get_round_id")
	actor_b.gunner.round_provider = Callable(self, "get_round_id")
	if not _autoshot and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _abort_initialization(reason: String, errors: Array) -> void:
	# 003-R2：启动失败受控短路——关闭正常帧与输入处理、清理本次已建实体、
	# 显示实际错误；无窗口/截图自检模式以非零码退出（自动验收可见）。
	_aborted = true
	_abort_reason = reason
	push_error("003-R2 ABORT: %s: %s" % [reason, ", ".join(errors)])
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	set_process_input(false)
	# 清理半建对象（装配边界失败时可能有已加入树的实体）
	for c in get_children():
		if c is VehicleActor:
			c.queue_free()
	actor_a = null
	actor_b = null
	# 可见错误显示（不建正式菜单系统）
	var err_label := Label.new()
	err_label.text = "INIT FAILED: %s\n%s" % [reason, "\n".join(errors)]
	err_label.position = Vector2(40, 40)
	add_child(err_label)
	if DisplayServer.get_name() == "headless" or _autoshot:
		print("[003-R2] ABORT exit: initialization failed (headless/autoshot)")
		get_tree().quit(1)   # 非零退出 = 自动验收可见

func get_round_id() -> int:
	# 003-R2：gunner 发射身份的轮次来源（开火时刻冻结）
	return _round_id

func spawn_vehicle(vehicle_id: String, entity_id: String, pos: Vector3, ctrl: Node = null, defs_override: VehicleDefs = null, spawn_tf: Transform3D = Transform3D()) -> VehicleActor:
	# 003：统一实体生成入口（T003-04 生命周期测试用）；003-R1：可指定配置注册表与出生变换
	var d: VehicleDefs = defs_override if defs_override != null else defs
	var tf: Transform3D = spawn_tf if spawn_tf != Transform3D() else Transform3D(Basis.IDENTITY, pos)
	var a := VehicleActor.new()
	a.name = "Spawned_" + entity_id
	add_child(a)
	var r := a.setup(d, vehicle_id, entity_id, 9, tf, GameConfig.VIS_LAYER_VEHICLE_B, ctrl)
	if not r.ok:
		a.queue_free()
		return null
	a.gunner.round_provider = Callable(self, "get_round_id")   # 003-R2：发射身份轮次来源
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
	# 003-R1：轮次递增——重开后旧轮次命中事件无效
	# 003-R2：只清本回合去重集合（旧事件已由轮次+生命周期拒绝，无需无限保留历史编号）
	actor_a.reset_vehicle()
	actor_b.reset_vehicle()
	for t in targets:
		t.reset()
	trial_hits = 0
	_round_id += 1
	_round_shots.clear()

func reset_vehicle(actor: VehicleActor) -> void:
	# 003：单车重置——不污染其他车/靶场/试射目标
	if actor != null:
		actor.reset_vehicle()

func _notification(what: int) -> void:
	# 窗口失去焦点自动暂停，避免切回后车辆仍在移动
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _paused and not _autoshot:
			_pause()

func _on_b_hit(identity: Dictionary) -> void:
	# 003-R2：任务只接受——当前轮次、正确射手、正确目标、双方生命周期存续的唯一命中。
	# 轮次/生命周期在开火时刻冻结进事件（不在接收时补填）：旧轮次迟到事件
	# （含重开后才首次送达的旧事件）与同名车重建后的旧身份事件都会被拒绝。
	if _aborted or identity.is_empty():
		return
	if int(identity.get("round_id", -1)) != _round_id:
		return   # 旧轮次事件（开火时的轮次 ≠ 当前轮次）
	if identity.get("shooter_id", "") != actor_a.entity_id:
		return   # 射手必须是玩家车 A
	if identity.get("target_id", "") != actor_b.entity_id:
		return   # 目标必须是 B（靶板/墙/空射不产生车辆命中事件）
	if int(identity.get("shooter_life_id", 0)) != actor_a.life_id:
		return   # 射手生命周期不匹配（同名 A 销毁重建后旧事件）
	if int(identity.get("target_life_id", 0)) != actor_b.life_id:
		return   # 目标生命周期不匹配（B 重生后旧事件）
	var sid := int(identity.get("shot_id", 0))
	if _round_shots.has(sid):
		return   # 同一发重复投递不重复计分
	_round_shots[sid] = true
	if trial_hits < TRIAL_TARGET:
		trial_hits += 1

func _process(_delta: float) -> void:
	if _aborted:
		return   # 003-R2：启动失败短路——正常帧已停止（错误画面静态显示）
	var hits := []
	for t in targets:
		hits.append(t.hit_count)
	# 003-R1：提示来自实际状态（实体标识/配置内容层级），不写死 HUD 文字
	var control_text := "CONTROL: %s (PLAYER)" % actor_a.entity_id
	if actor_a.definition.content_tier == "test":
		control_text += " [TEST ONLY]"
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
	# 002-R2 扩展：真实鼠标事件验证俯仰响应（下压/水平/上抬）；
	# 003-R1 扩展：正常输入完整演示（自然瞄准→正常输入开火→自然装填→3/3→R 重开）。
	# match 分支不能 await——跨帧等待用 _autoshot_wait（纯等待后推进，不重跑当前步骤）。
	if _autoshot_wait > 0:
		_autoshot_wait -= 1
		return
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
			print("[autoshot] phase1 done: shots_saved=", _shots_saved, " errors=", _shot_errors)
		210:
			# 003 演示：重置后把相机转向 B（A 在 (0,0,8)，B 在 (8,0,0) → -45°），
			# 炮塔以有限转速收敛（35°/s × 45° ≈ 77 帧）
			_reset_all()
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		290:
			_shot("autoshot_6_two_vehicles.png")   # 第三人称：两辆车同框（A 近景，B 在画面中央）
			print("[003] two_vehicles: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " A screen=", cam_rig.cam.unproject_position(actor_a.tank.global_position))
			Input.action_press("aim")
		300:
			_shot("autoshot_7_sight_sees_b.png")   # 炮镜：B 可见（cull_mask 只剔除 A 自身视觉层）
			print("[003] sight: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " sight=", cam_rig.sight, " cull_mask=", cam_rig.cam.cull_mask)
			Input.action_release("aim")
			# 试射目标：三次真实生产命中（try_fire 即 PlayerController 调用的同一生产路径）
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
		310:
			_shot("autoshot_8_trial_complete.png")   # 试射完成：TRIAL COMPLETE 3/3
			print("[003] trial_hits=", trial_hits, " b_hits=", actor_b.tank.hits_taken)
			print("[003-R1] NOTE: autoshot_8 为构造状态演示（清零冷却+直接 try_fire），证明真实命中函数推进 HUD；正常输入完整演示见 autoshot_9~13")
		320:
			print("[autoshot] phase1 done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			# 003-R1：正常输入完整演示——自然瞄准 → 正常输入开火 → 自然装填 → 3/3 → R 重开
			# （不清零冷却、不直接写任务计数、不绕过命令入口）
			_reset_all()
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		330:
			# 相机对准 B（模拟玩家鼠标瞄准；B 在 (8,0,0)，A 在 (0,0,8)）——先偏航
			var d_ab: Vector3 = actor_b.tank.global_position - actor_a.tank.global_position
			cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z)
			_autoshot_wait = 2   # 等相机轨道/look_at 更新
		331:
			# 相机位置随偏航更新后再算俯仰（瞄 B 中心）
			var b_center2: Vector3 = actor_b.tank.global_position + Vector3(0, 1.0, 0)
			var cam_pos2: Vector3 = cam_rig.cam.global_position
			var horiz2: float = Vector3(cam_pos2.x - b_center2.x, 0, cam_pos2.z - b_center2.z).length()
			cam_rig.aim_pitch = atan2(1.0 - cam_pos2.y, horiz2)
			_autoshot_wait = 2
		332:
			# 003-R2：自然瞄准——不 snap（snap 证明的是"程序预先对齐"），等待炮塔
			# 以有限转速真实追赶意图瞄点并稳定对准；有限超时（900 帧）判失败
			if turret.aim_error_deg() > 0.5:
				_demo_poll += 1
				if _demo_poll > 900:
					_shot_errors += 1
					print("[003-R2] FAIL: natural aim timeout (err=%.2f°)" % turret.aim_error_deg())
					_demo_poll = 0
				_shot_step -= 1   # 原地驻留，继续等待追赶
			else:
				print("[003-R2] natural aim locked: err=%.2f° polls=%d" % [turret.aim_error_deg(), _demo_poll])
				_demo_poll = 0
		333:
			Input.action_press("fire")   # 正常输入开火（第 1 发：Input 边沿 → 命令入口 → 生产命中）
			_autoshot_wait = 2   # 给控制器/物理帧时间消费开火
		334:
			Input.action_release("fire")
			print("[003-R1] shot1: trial_hits=", trial_hits, " cooldown=", "%.2f" % gunner.cooldown_left)
		335:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1   # 自然装填原地等待（不清零冷却；不重跑 334 的打印）
		336:
			Input.action_press("fire")   # 第 2 发
			_autoshot_wait = 2
		337:
			Input.action_release("fire")
			print("[003-R1] shot2: trial_hits=", trial_hits)
		338:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1
		339:
			Input.action_press("fire")   # 第 3 发
			_autoshot_wait = 2
		340:
			Input.action_release("fire")
			print("[003-R1] shot3: trial_hits=", trial_hits)
		341:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1
		342:
			_shot("autoshot_9_trial_normal_complete.png")   # 正常输入/自然装填完成 3/3
			print("[003-R1] normal trial: trial_hits=", trial_hits, " b_hits=", actor_b.tank.hits_taken, " shots_fired=", gunner.shots_fired)
			if trial_hits < TRIAL_TARGET:
				_shot_errors += 1
				print("[003-R1] FAIL: normal-input trial did not reach 3/3")
			_key_event(KEY_R)   # 真实 R 事件 → 整场重开
		343:
			pass   # 等待 R 事件在输入阶段冲刷
		344:
			pass
		345:
			_shot("autoshot_10_trial_restarted.png")   # R 重开后计数归零
			print("[003-R1] after R: trial_hits=", trial_hits, " round=", _round_id)
			if trial_hits != 0:
				_shot_errors += 1
				print("[003-R1] FAIL: R restart did not reset trial")
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		346:
			_shot("autoshot_11_two_vehicles_r1.png")   # 两车同框（正常任务演示后）
			print("[003-R1] two_vehicles_r1: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position))
			Input.action_press("aim")
		347:
			pass   # 等炮镜切换
		348:
			_shot("autoshot_12_sight_sees_b_r1.png")   # 炮镜见 B（正常任务演示后）
			print("[003-R1] sight_r1: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " sight=", cam_rig.sight, " cull_mask=", cam_rig.cam.cull_mask)
			Input.action_release("aim")
		349:
			pass
		350:
			_shot("autoshot_13_hud_r1.png")   # HUD：CONTROL: A (PLAYER) [TEST ONLY] / TRIAL 0/3
			print("[003-R1] hud: control_text 来自实际状态（entity_id + content_tier）")
			print("[autoshot] done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			get_tree().quit(1 if (_shot_errors > 0 or _shots_saved < 13) else 0)   # 必需截图失败 → 自检非零

func _key_event(k: Key) -> void:
	# 003-R1：真实按键事件（按下+释放）经 Input.parse_input_event 走完整输入管线
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = k
	ev2.physical_keycode = k
	ev2.pressed = false
	Input.parse_input_event(ev2)

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