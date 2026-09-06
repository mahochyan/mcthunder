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