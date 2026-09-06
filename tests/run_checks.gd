extends SceneTree
## PixelArmor 无窗口自动检查（工作单 §四）。
## 运行: godot --headless --path <工程根> -s res://tests/run_checks.gd
## 原则：测试全部调用游戏实际使用的逻辑——实例化真实主场景、真实输入动作、
##       真实射击/驾驶代码；失败时退出码非 0；不以退出码为唯一依据（全文输出留档）。

var fails: Array[String] = []
var count := 0

func _initialize() -> void:
	var wd := create_timer(90.0)
	wd.timeout.connect(func() -> void:
		print("[WATCHDOG] 90s 超时，强制退出（存在卡死/等待）")
		quit(2))
	_run()

func _run() -> void:
	print("=== PixelArmor 自动检查 ===")
	print("engine=", Engine.get_version_info()["string"], "  os=", OS.get_name())
	_check_fonts()
	_check_scripts()
	_check_actions()
	var ps: PackedScene = load("res://scenes/main.tscn")
	_ok(ps != null, "主场景资源可加载")
	if ps == null:
		_finish()
		return
	var main = ps.instantiate()
	_ok(main != null, "主场景可实例化")
	if main == null:
		_finish()
		return
	root.add_child(main)
	await process_frame
	await process_frame
	_ok(main.tank != null, "必要节点: 坦克存在")
	_ok(main.turret != null, "必要节点: 炮塔存在")
	_ok(main.cam_rig != null and main.cam_rig.cam != null, "必要节点: 相机存在")
	_ok(main.gunner != null, "必要节点: 射击控制存在")
	_ok(main.hud != null, "必要节点: 界面存在")
	_ok(main.targets.size() == 3, "三块靶板存在 (实际=%d)" % main.targets.size())
	if main.tank == null or main.gunner == null or main.targets.size() != 3:
		_finish()
		return
	var tank: TankVehicle = main.tank
	var gunner: Gunner = main.gunner
	var board: TargetBoard = main.targets[1]   # 中间靶板 (0,0,-22)

	# --- 冷却：连续射击受 2s 冷却限制；按住不绕过 ---
	tank.reset()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var r1: bool = gunner.try_fire()
	_ok(r1, "首次开火成功")
	var r2: bool = gunner.try_fire()
	_ok(not r2 and gunner.blocked_reason == "cooldown", "冷却期内第二次开火被拒")
	_ok(gunner.shots_fired == 1, "冷却期内未产生额外射击 (shots=%d)" % gunner.shots_fired)
	Input.action_press("fire")
	for i in 5:
		await process_frame
	_ok(gunner.shots_fired == 1, "按住开火键不绕过冷却 (shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")
	await create_timer(GameConfig.RELOAD_TIME + 0.15).timeout
	_ok(gunner.cooldown_left <= 0.0, "冷却自然结束")
	gunner.resume_grace = 0.3
	var rg: bool = gunner.try_fire()
	_ok(not rg and gunner.blocked_reason == "grace", "暂停恢复宽限期内开火被拒")
	gunner.resume_grace = 0.0

	# --- 遮挡：墙后靶板不被实际射击代码命中 ---
	board.reset()   # 清零冷却测试遗留的合法命中计数，保证断言只看本段行为
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 8)   # 面向 -Z，正对中间靶板
	turret_snap(main)
	for i in 5:
		await physics_frame
	gunner.cooldown_left = 0.0
	var wall = main.world.build_wall(Vector3(0, 1.5, -6.0), Vector3(6, 3, 1.0))
	await physics_frame
	var rf: bool = gunner.try_fire()
	_ok(rf, "无遮挡时开火成功")
	_ok(board.hit_count == 0, "遮挡墙后靶板未被命中 (hits=%d)" % board.hit_count)
	wall.queue_free()
	await physics_frame
	await physics_frame
	gunner.cooldown_left = 0.0
	var r2f: bool = gunner.try_fire()
	_ok(r2f and board.hit_count == 1, "移除墙后同一射击代码命中靶板 (hits=%d)" % board.hit_count)
	_ok(board._flash_left > 0.0, "命中后靶板变色反馈触发")

	# --- 炮管穿墙：阻止开火 ---
	board.reset()   # 同上：清零上段遗留计数
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 0)
	turret_snap(main)
	var wall2 = main.world.build_wall(Vector3(0, 1.5, -1.8), Vector3(6, 3, 1.0))
	for i in 8:
		await physics_frame
	gunner.cooldown_left = 0.0
	var shots_before := gunner.shots_fired
	var rb: bool = gunner.try_fire()
	_ok(not rb and gunner.blocked_reason == "barrel_occluded", "炮管穿墙时开火被阻止")
	_ok(gunner.shots_fired == shots_before, "穿墙开火未产生射击")
	_ok(board.hit_count == 0, "穿墙未命中墙后靶板 (hits=%d)" % board.hit_count)
	wall2.queue_free()
	for i in 3:
		await physics_frame

	# --- 驾驶：加速 / 限速 / 滑行停车 / 倒车限制 / 原地转向 / 无平移 ---
	tank.reset()
	turret_snap(main)
	await physics_frame
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	_ok(tank.forward_speed > 4.0, "前进加速有效 (v=%.2f)" % tank.forward_speed)
	_ok(tank.forward_speed <= GameConfig.FORWARD_MAX_SPEED + 0.01, "前进限速 8m/s (v=%.2f)" % tank.forward_speed)
	_ok(tank.global_position.z < 4.0, "车辆沿 -Z 前进 (z=%.2f)" % tank.global_position.z)
	Input.action_release("move_forward")
	for i in 200:
		await physics_frame
	_ok(tank.forward_speed < 0.4, "松开按键滑行停车 (v=%.2f)" % tank.forward_speed)
	var z_coast := tank.global_position.z
	Input.action_press("move_back")
	for i in 150:
		await physics_frame
	_ok(tank.forward_speed >= -GameConfig.REVERSE_MAX_SPEED - 0.01, "倒车限速 3m/s (v=%.2f)" % tank.forward_speed)
	_ok(tank.global_position.z > z_coast + 1.0, "倒车位移有效 (z=%.2f)" % tank.global_position.z)
	Input.action_release("move_back")
	var yaw0 := tank.rotation.y
	Input.action_press("turn_left")
	for i in 30:
		await physics_frame
	Input.action_release("turn_left")
	_ok(absf(tank.rotation.y - yaw0) > 0.2, "A 键原地转向有效")
	_ok(absf(tank.global_position.x) < 1.0, "无左右平移 (x=%.2f)" % tank.global_position.x)
	for i in 30:
		await physics_frame

	# --- 重置 ---
	board.hit_count = 3
	gunner.cooldown_left = 1.0
	main._reset_all()
	await physics_frame
	_ok(board.hit_count == 0, "重置清零靶板命中")
	_ok(gunner.cooldown_left == 0.0, "重置清零装填状态")
	_ok(tank.global_position.distance_to(Vector3(0, 0, 8)) < 0.1, "重置恢复出生位置")

	# --- T002-03a：相机可见但炮管被挡（矮墙：相机视线越过、炮射线被挡） ---
	board.reset()
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 8)
	turret_snap(main)
	var low_wall = main.world.build_wall(Vector3(0, 1.0, -6.0), Vector3(6, 2.0, 1.0))
	for i in 5:
		await physics_frame
	var see_point: Vector3 = main.cam_rig.get_aim_point()
	_ok(see_point.z < -10.0, "T002-03a 前提：相机视线越过矮墙看到远处靶板 (aim_z=%.1f)" % see_point.z)
	gunner.cooldown_left = 0.0
	var fa: bool = gunner.try_fire()
	_ok(fa, "T002-03a 开火（炮根→炮口无遮挡）")
	_ok(board.hit_count == 0, "T002-03a 矮墙挡住炮射线，墙后靶板未被命中 (hits=%d)" % board.hit_count)
	low_wall.queue_free()
	for i in 3:
		await physics_frame

	# --- T002-03b：炮口进入墙体 ---
	board.reset()
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 0)
	turret_snap(main)
	var body_wall = main.world.build_wall(Vector3(0, 1.5, -2.8), Vector3(6, 3, 1.2))
	for i in 5:
		await physics_frame
	var mz: Vector3 = main.turret.muzzle.global_position
	_ok(mz.z > -3.4 and mz.z < -2.2, "T002-03b 前提：炮口位于墙体内部 (muzzle_z=%.2f, 墙 -2.2..-3.4)" % mz.z)
	gunner.cooldown_left = 0.0
	var fb: bool = gunner.try_fire()
	_ok(not fb and gunner.blocked_reason == "barrel_occluded", "T002-03b 炮口入墙时开火被阻止")
	_ok(board.hit_count == 0, "T002-03b 未命中墙后靶板 (hits=%d)" % board.hit_count)
	body_wall.queue_free()
	for i in 3:
		await physics_frame

	# --- T002-03c：贴墙开炮（炮口越过墙体远面） ---
	board.reset()
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 2.2)
	turret_snap(main)
	var hug_wall = main.world.build_wall(Vector3(0, 1.5, -0.4), Vector3(6, 3, 0.6))
	for i in 5:
		await physics_frame
	var mz2: Vector3 = main.turret.muzzle.global_position
	_ok(mz2.z < -0.7, "T002-03c 前提：炮口越过墙体远面 (muzzle_z=%.2f < -0.7)" % mz2.z)
	gunner.cooldown_left = 0.0
	var fc: bool = gunner.try_fire()
	_ok(not fc and gunner.blocked_reason == "barrel_occluded", "T002-03c 贴墙开炮被阻止（炮根→炮口线段被墙截断）")
	_ok(board.hit_count == 0, "T002-03c 未命中墙后靶板 (hits=%d)" % board.hit_count)
	hug_wall.queue_free()
	for i in 3:
		await physics_frame

	# --- 相机贴墙防穿：期望机位在墙外时被压回 ---
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 27)   # 贴近南侧内墙（内面 29.0）
	main.cam_rig.aim_yaw = 0.0                  # 朝 -Z 看 → 相机机位被推到墙外
	for i in 5:
		await physics_frame
	await process_frame
	var camz: float = main.cam_rig.cam.global_position.z
	_ok(camz < 28.8, "第三人称相机贴墙防穿 (cam_z=%.2f < 29.0 内墙面)" % camz)

	# --- R1-A（002-R1）：第三人称相机前向与炮管指向的俯仰一致性 ---
	tank.reset()
	main.cam_rig.aim_yaw = 0.0
	main.cam_rig.aim_pitch = deg_to_rad(10.0)
	turret_snap(main)   # 先设俯仰再对齐（避免有限转速追赶期干扰测量）
	for i in 5:
		await physics_frame
	await process_frame
	var cam_fwd: Vector3 = -main.cam_rig.cam.global_transform.basis.z
	var bdir: Vector3 = main.turret.barrel_direction()
	var aim_diff: float = rad_to_deg(cam_fwd.angle_to(bdir))
	_ok(aim_diff < 5.0, "R1-A 相机前向与炮管指向俯仰一致（鼠标俯仰→瞄点→炮管须一致）(diff=%.1f°)" % aim_diff)
	main.cam_rig.aim_pitch = 0.0

	# --- 瞄点标记屏幕后方过滤（单元逻辑） ---
	_ok(not main._in_front(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, 5)), "屏幕后方瞄点标记隐藏（点积过滤）")
	_ok(main._in_front(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, -5)), "屏幕前方瞄点标记保留")

	# --- T002-04：暂停前持火；恢复/失焦不补射；驾驶与装填按暂停规则停止 ---
	board.reset()
	tank.reset()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	Input.action_press("move_forward")
	Input.action_press("fire")
	for i in 6:
		await process_frame
	var s_hold := gunner.shots_fired
	_ok(s_hold >= 1, "T002-04 前提：持火已产生一次射击 (shots=%d)" % s_hold)
	for i in 20:
		await physics_frame
	var pos_at_pause: Vector3 = tank.global_position
	var cd_at_pause: float = gunner.cooldown_left
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(paused, "T002-04 窗口失焦通知触发自动暂停")
	await create_timer(0.6).timeout
	_ok(absf(gunner.cooldown_left - cd_at_pause) < 0.0001, "T002-04 暂停期间装填计时真正冻结（暂停前=%.3f，暂停0.6s后=%.3f）" % [cd_at_pause, gunner.cooldown_left])
	_ok(tank.global_position.distance_to(pos_at_pause) < 0.001, "T002-04 暂停期间驾驶停止")
	main._resume()
	for i in 30:
		await process_frame
	_ok(gunner.shots_fired == s_hold, "T002-04 恢复后持火未补射 (shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")
	Input.action_release("move_forward")

	# --- R1-B（002-R1）：真实鼠标事件点击“继续”按钮（无冷却遮掩场景） ---
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var s0: int = gunner.shots_fired
	Input.action_press("fire")
	for i in 2:
		await process_frame
	_ok(gunner.shots_fired == s0 + 1, "R1-B 前提：无冷却持火立即合法射击 (shots=%d)" % gunner.shots_fired)
	await create_timer(GameConfig.RELOAD_TIME + 0.25).timeout   # 装填完成，火仍按住
	var s1: int = gunner.shots_fired
	main._pause()
	await process_frame
	var btn: Button = main.hud.resume_btn
	_ok(btn != null and btn.visible, "R1-B 前提：继续按钮存在且可见")
	var center: Vector2 = btn.get_global_rect().get_center()
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	press_ev.position = center
	press_ev.global_position = center
	Input.parse_input_event(press_ev)
	await process_frame
	var rel_ev := InputEventMouseButton.new()
	rel_ev.button_index = MOUSE_BUTTON_LEFT
	rel_ev.pressed = false
	rel_ev.position = center
	rel_ev.global_position = center
	Input.parse_input_event(rel_ev)
	await process_frame
	_ok(not paused, "R1-B 真实鼠标事件点击“继续”按钮 → 恢复")
	_ok(gunner.shots_fired == s1, "R1-B 恢复瞬间无误射 (shots=%d)" % gunner.shots_fired)
	await create_timer(GameConfig.RESUME_GRACE + 0.2).timeout
	_ok(gunner.shots_fired == s1, "R1-B 宽限结束后无延迟补射（火持续按住）(shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")
	await process_frame
	Input.action_press("fire")
	for i in 2:
		await process_frame
	_ok(gunner.shots_fired == s1 + 1, "R1-B 宽限结束后重新按下可合法射击 (shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")

	# --- T002-05：连续 20 次重置（全靶板/位置/朝向/速度/冷却） ---
	main._reset_all()
	await physics_frame
	var spawn_pos: Vector3 = tank.global_position
	var reset_ok := true
	for i in 20:
		for t in main.targets:
			t.hit_count = i
		gunner.cooldown_left = 1.0
		gunner.resume_grace = 0.5
		tank.forward_speed = 5.0
		tank.global_position = spawn_pos + Vector3(3.0, 0.0, 2.0)
		tank.rotation.y = 0.7
		main._reset_all()
		await physics_frame
		if board.hit_count != 0 or gunner.cooldown_left != 0.0 or absf(tank.forward_speed) > 0.001:
			reset_ok = false
		if tank.global_position.distance_to(spawn_pos) > 0.01 or absf(tank.rotation.y) > 0.001:
			reset_ok = false
		for t in main.targets:
			if t.hit_count != 0:
				reset_ok = false
	_ok(reset_ok, "T002-05 连续 20 次重置：3 块靶板/位置/朝向/速度/冷却全部复位")

	# --- 暂停/恢复状态切换（无窗口下只验证逻辑状态） ---
	main._pause()
	_ok(paused and main.hud._pause_root.visible, "Esc 暂停生效并显示暂停界面")
	main._resume()
	_ok(not paused and gunner.resume_grace > 0.0, "恢复生效且带开炮宽限")

	_finish()

func turret_snap(main) -> void:
	main.turret.snap_to_aim()

func _check_fonts() -> void:
	var f := ThemeDB.fallback_font
	var cjk: bool = f != null and f.has_char(0x4E2D)
	print("font_cjk_support=", cjk, "  (默认字体中文字形能力 → 决定 HUD 语言)")
	_ok(true, "默认字体 CJK 能力已记录")

func _check_scripts() -> void:
	for p in ["game_config", "world_builder", "target_board", "tank", "turret_rig", "camera_rig", "gunner", "hud", "main"]:
		var s = load("res://scripts/%s.gd" % p)
		_ok(s != null, "脚本可解析加载: %s.gd" % p)

func _check_actions() -> void:
	for a in GameConfig.ACTIONS:
		_ok(InputMap.has_action(a), "输入动作存在: " + a)

func _ok(cond: bool, label: String) -> void:
	count += 1
	if cond:
		print("[PASS] ", label)
	else:
		print("[FAIL] ", label)
		fails.append(label)

func _finish() -> void:
	print("=== 结果: %d 项检查, %d 失败 ===" % [count, fails.size()])
	if fails.is_empty():
		print("CHECKS_PASS")
		quit(0)
	else:
		for f in fails:
			print("  失败项: ", f)
		print("CHECKS_FAIL")
		quit(1)