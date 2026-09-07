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
	_check_defs()
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
	main.cam_rig.aim_yaw = 0.0
	main.cam_rig.aim_pitch = deg_to_rad(-2.0)   # 相机视线落在靶板上（002-R2 点瞄准）
	turret_snap(main)
	for i in 5:
		await physics_frame
	gunner.cooldown_left = 0.0
	var wall = main.world.build_wall(Vector3(0, 1.5, -6.0), Vector3(6, 3, 1.0))
	await physics_frame
	var see_hit0 := _camera_ray_hit(main)
	_ok(see_hit0.collider == board, "遮挡前提：相机确实看见指定靶板（collider 身份验证）")
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

	# --- T002-03a：相机可见但炮管被挡（近置高墙：相机视线越过、炮管仰角不足） ---
	board.reset()
	tank.reset()
	tank.rotation = Vector3.ZERO
	tank.global_position = Vector3(0, 0, 8)
	var tgt := TargetBoard.new()
	tgt.position = Vector3(5.06, 0.21, -28)   # 相机射线与碰撞盒中心交点（身份验证用临时靶板）
	main.world.add_child(tgt)
	main.cam_rig.aim_yaw = deg_to_rad(-8.0)   # 相机视线穿过中/右靶板间隙对准墙后靶板
	main.cam_rig.aim_pitch = deg_to_rad(-3.19)
	turret_snap(main)
	var tall_wall = main.world.build_wall(Vector3(0.71, 1.5, 2.5), Vector3(6, 3, 1.0))
	for i in 5:
		await physics_frame
	var see_hit := _camera_ray_hit(main)
	_ok(see_hit.collider == tgt, "T002-03a 前提：相机视线越过近墙并选中墙后靶板（collider 身份验证）")
	_ok(see_hit.position.distance_to(tgt.global_position) < 2.0, "T002-03a 前提：距离辅助 (dist=%.2f)" % see_hit.position.distance_to(tgt.global_position))
	gunner.cooldown_left = 0.0
	var fa: bool = gunner.try_fire()
	_ok(fa, "T002-03a 开火（炮根→炮口无遮挡）")
	_ok(tgt.hit_count == 0, "T002-03a 近墙挡住炮射线，墙后靶板未被命中 (hits=%d)" % tgt.hit_count)
	tall_wall.queue_free()
	tgt.queue_free()
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

	# --- R2-A（002-R2）：相机响应鼠标意图（下压/水平/上抬；逻辑级，真实事件见窗口证据） ---
	tank.reset()
	main.cam_rig.aim_yaw = 0.0
	for p in [-10.0, 0.0, 10.0]:
		main.cam_rig.aim_pitch = deg_to_rad(p)
		await process_frame
		await process_frame
		var fwd: Vector3 = -main.cam_rig.cam.global_transform.basis.z
		var fwd_pitch: float = rad_to_deg(asin(fwd.y))
		_ok(absf(fwd_pitch - p) < 0.5, "R2-A 相机前向俯仰响应意图（意图=%.0f° 实际=%.1f°）" % [p, fwd_pitch])
	main.cam_rig.aim_pitch = 0.0

	# --- R3-A（002-R3）：稳定收敛——左右目标 + 车体非零 yaw + 延迟开火 ---
	# 修复前实跑本段应失败（旧公式 atan2(dx,-dz) 使炮塔掠过正确方向后继续转离，
	# 稳定保持检查会抓住"首次过线即 break"的漏检；见 logs/002-R3/checks_R3_prefix.log）
	var b1 := TargetBoard.new()
	b1.position = Vector3(0, 0.0, -12)
	main.world.add_child(b1)
	var b2 := TargetBoard.new()
	b2.position = Vector3(6.53, 0.0, -24)   # 右侧远靶（+X）
	main.world.add_child(b2)
	var b3 := TargetBoard.new()
	b3.position = Vector3(-6.53, 0.0, -24)  # 左侧远靶（-X）
	main.world.add_child(b3)
	# 近靶 B1（12m）：意图射线选中（collider 身份验证 + 距离辅助）
	main.cam_rig.aim_yaw = 0.0
	main.cam_rig.aim_pitch = deg_to_rad(-5.5)   # 相机视线对准 B1 碰撞盒中心
	await process_frame
	await process_frame
	var sel1 := _camera_ray_hit(main)
	_ok(sel1.collider == b1, "R3-A 意图射线选中近靶 B1（collider 身份验证）")
	_ok(sel1.position.distance_to(b1.global_position) < 2.0, "R3-A 近靶 B1 距离辅助 (dist=%.2f)" % sel1.position.distance_to(b1.global_position))
	# 稳定收敛：摆偏炮塔，首次过线后连续保持 1 秒（60 帧），中途转离即失败
	main.turret.rotation.y = 1.0
	main.turret.barrel_pivot.rotation.x = 0.0
	var stab := await _stable_converge(main)
	_ok(stab.converged, "R3-A 近靶 B1 稳定收敛（首次过线=%d 帧，保持 %.2f 秒，最大误差=%.2f°，结束误差=%.2f°）" % [stab.first_cross, stab.hold_time, stab.max_err, stab.final_err])
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var ok1: bool = gunner.try_fire()
	_ok(ok1 and b1.hit_count == 1 and b2.hit_count == 0 and b3.hit_count == 0, "R3-A 稳定后实射命中近靶 B1 (b1=%d b2=%d b3=%d)" % [b1.hit_count, b2.hit_count, b3.hit_count])
	# 保持意图，等真实装填自然结束再打一炮——不手动恢复开火条件，
	# 先断言开火条件已自然满足，再调用生产 try_fire 验证命中
	await create_timer(GameConfig.RELOAD_TIME + 0.2).timeout
	_ok(gunner.cooldown_left <= 0.0 and gunner.resume_grace <= 0.0, "R3-A 第二炮前开火条件已自然满足 (cooldown=%.2f grace=%.2f)" % [gunner.cooldown_left, gunner.resume_grace])
	var ok1b: bool = gunner.try_fire()
	_ok(ok1b and b1.hit_count == 2, "R3-A 装填自然结束后第二炮仍命中近靶 B1 (b1=%d)" % b1.hit_count)
	# 右侧远靶 B2（24m；相机环绕偏移已计入：x(z)=tanθ·(8−z)）
	main.cam_rig.aim_yaw = deg_to_rad(-11.54)
	main.cam_rig.aim_pitch = deg_to_rad(-3.83)
	await process_frame
	await process_frame
	var sel2 := _camera_ray_hit(main)
	_ok(sel2.collider == b2, "R3-A 意图射线选中右侧远靶 B2（collider 身份验证）")
	_ok(sel2.position.distance_to(b2.global_position) < 2.0, "R3-A 远靶 B2 距离辅助 (dist=%.2f)" % sel2.position.distance_to(b2.global_position))
	main.turret.rotation.y = -1.0
	main.turret.barrel_pivot.rotation.x = 0.0
	stab = await _stable_converge(main)
	_ok(stab.converged, "R3-A 右侧远靶 B2 稳定收敛（首次过线=%d 帧，保持 %.2f 秒，最大误差=%.2f°，结束误差=%.2f°）" % [stab.first_cross, stab.hold_time, stab.max_err, stab.final_err])
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var ok2: bool = gunner.try_fire()
	_ok(ok2 and b2.hit_count == 1 and b1.hit_count == 2 and b3.hit_count == 0, "R3-A 稳定后实射命中右侧远靶 B2 (b1=%d b2=%d b3=%d)" % [b1.hit_count, b2.hit_count, b3.hit_count])
	# 左侧远靶 B3（24m）
	main.cam_rig.aim_yaw = deg_to_rad(11.54)
	main.cam_rig.aim_pitch = deg_to_rad(-3.83)
	await process_frame
	await process_frame
	var sel3 := _camera_ray_hit(main)
	_ok(sel3.collider == b3, "R3-A 意图射线选中左侧远靶 B3（collider 身份验证）")
	_ok(sel3.position.distance_to(b3.global_position) < 2.0, "R3-A 远靶 B3 距离辅助 (dist=%.2f)" % sel3.position.distance_to(b3.global_position))
	main.turret.rotation.y = 1.0
	main.turret.barrel_pivot.rotation.x = 0.0
	stab = await _stable_converge(main)
	_ok(stab.converged, "R3-A 左侧远靶 B3 稳定收敛（首次过线=%d 帧，保持 %.2f 秒，最大误差=%.2f°，结束误差=%.2f°）" % [stab.first_cross, stab.hold_time, stab.max_err, stab.final_err])
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var ok3: bool = gunner.try_fire()
	_ok(ok3 and b3.hit_count == 1 and b2.hit_count == 1, "R3-A 稳定后实射命中左侧远靶 B3 (b1=%d b2=%d b3=%d)" % [b1.hit_count, b2.hit_count, b3.hit_count])
	# 车体转过非零角度：局部角 = 目标全局角 - 车体 yaw 的扣除逻辑
	tank.rotation.y = 0.5
	await physics_frame
	await physics_frame
	main.cam_rig.aim_yaw = 0.0
	main.cam_rig.aim_pitch = deg_to_rad(-5.5)
	await process_frame
	await process_frame
	var sel4 := _camera_ray_hit(main)
	_ok(sel4.collider == b1, "R3-A 车体转过非零角度后意图射线仍选中近靶 B1（collider 身份验证）")
	main.turret.rotation.y = 1.0
	main.turret.barrel_pivot.rotation.x = 0.0
	stab = await _stable_converge(main)
	_ok(stab.converged, "R3-A 车体非零 yaw 下近靶 B1 稳定收敛（首次过线=%d 帧，保持 %.2f 秒，最大误差=%.2f°，结束误差=%.2f°）" % [stab.first_cross, stab.hold_time, stab.max_err, stab.final_err])
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var ok4: bool = gunner.try_fire()
	_ok(ok4 and b1.hit_count == 3, "R3-A 车体非零 yaw 下实射命中近靶 B1 (b1=%d)" % b1.hit_count)
	b1.queue_free()
	b2.queue_free()
	b3.queue_free()
	for i in 3:
		await physics_frame

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
	var cd_frozen: float = gunner.cooldown_left
	for i in 30:
		await process_frame
	_ok(gunner.shots_fired == s_hold, "T002-04 恢复后持火未补射 (shots=%d)" % gunner.shots_fired)
	await create_timer(0.5).timeout
	_ok(gunner.cooldown_left < cd_frozen - 0.3, "R2-B 恢复后装填计时继续推进 (%.2f → %.2f)" % [cd_frozen, gunner.cooldown_left])
	Input.action_release("fire")
	Input.action_release("move_forward")

	# --- R1-B（002-R1）：真实鼠标事件点击“继续”按钮（无冷却遮掩场景） ---
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	await process_frame   # 与上一段 release 隔帧，保证 just_pressed 边沿
	var s0: int = gunner.shots_fired
	Input.action_press("fire")
	for i in 2:
		await physics_frame   # 003-R1：fire 请求在物理步消费（headless 下 process 帧率高于物理步，process 窗口可能恰好无物理 tick；用 physics 等待保证确定性，断言不变）
	_ok(gunner.shots_fired == s0 + 1, "R1-B 前提：无冷却持火立即合法射击 (shots=%d)" % gunner.shots_fired)
	await create_timer(GameConfig.RELOAD_TIME + 0.25).timeout   # 装填完成，火仍按住
	_ok(gunner.cooldown_left == 0.0, "R1-B 前提：装填完成、无冷却遮掩 (cd=%.2f)" % gunner.cooldown_left)
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
		await physics_frame   # 003-R1：fire 请求在物理步消费
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

	# --- R2-B（002-R2）：持续持火经真实 Esc 暂停/恢复；关键点断言 fire 仍按住 ---
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var sh0: int = gunner.shots_fired
	Input.action_press("fire")
	for i in 2:
		await physics_frame   # 003-R1：fire 请求在物理步消费（PlayerController 只生成命令）
	_ok(gunner.shots_fired == sh0 + 1, "R2-B 前提：无冷却持火立即合法射击 (shots=%d)" % gunner.shots_fired)
	_ok(Input.is_action_pressed("fire"), "R2-B 前提：fire 处于按住状态")
	_key(KEY_ESCAPE)   # 真实 Esc 事件 → 暂停
	await process_frame
	await process_frame   # 事件在下一帧输入阶段冲刷；物理阶段调用需隔两帧
	_ok(paused, "R2-B 真实 Esc 事件触发暂停")
	_ok(Input.is_action_pressed("fire"), "R2-B 暂停期间 fire 仍按住")
	await create_timer(0.5).timeout
	_ok(Input.is_action_pressed("fire"), "R2-B 暂停 0.5s 后 fire 仍按住")
	_key(KEY_ESCAPE)   # 真实 Esc 事件 → 恢复
	await process_frame
	await process_frame
	_ok(not paused, "R2-B 真实 Esc 事件触发恢复")
	_ok(Input.is_action_pressed("fire"), "R2-B 恢复后 fire 仍按住")
	await create_timer(GameConfig.RELOAD_TIME + GameConfig.RESUME_GRACE + 0.3).timeout
	_ok(gunner.shots_fired == sh0 + 1, "R2-B 持续持火跨暂停/恢复/装填/宽限后无额外射击 (shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")
	await process_frame
	Input.action_press("fire")
	for i in 2:
		await physics_frame   # 003-R1：fire 请求在物理步消费
	_ok(gunner.shots_fired == sh0 + 2, "R2-B 释放后重新按下可合法射击 (shots=%d)" % gunner.shots_fired)
	Input.action_release("fire")

	# --- R2-B（002-R2）：真实 R 事件——运行中重置保持运行与鼠标捕获；暂停中重置保持暂停 ---
	main._reset_all()
	await physics_frame
	var spawn_r: Vector3 = tank.global_position
	tank.global_position = spawn_r + Vector3(4.0, 0.0, 3.0)
	_key(KEY_R)
	await process_frame
	await process_frame   # 事件在下一帧输入阶段冲刷；物理阶段调用需隔两帧
	_ok(not paused, "R2-B 运行中真实 R 事件重置且不暂停")
	_ok(tank.global_position.distance_to(spawn_r) < 0.1, "R2-B 运行中 R 重置位置 (dist=%.2f)" % tank.global_position.distance_to(spawn_r))
	main._pause()
	tank.global_position = spawn_r + Vector3(4.0, 0.0, 3.0)
	_key(KEY_R)
	await process_frame
	await process_frame
	_ok(paused, "R2-B 暂停中真实 R 事件重置且保持暂停")
	_ok(tank.global_position.distance_to(spawn_r) < 0.1, "R2-B 暂停中 R 重置位置 (dist=%.2f)" % tank.global_position.distance_to(spawn_r))
	main._resume()

	# --- R2-B（002-R2）：真实 F3 事件切换调试显示 ---
	_key(KEY_F3)
	await process_frame
	await process_frame
	_ok(main._debug_on and main.hud.debug_label.visible, "R2-B 真实 F3 事件开启调试显示")
	_key(KEY_F3)
	await process_frame
	await process_frame
	_ok(not main._debug_on and not main.hud.debug_label.visible, "R2-B 再次 F3 关闭调试显示")

	# --- 暂停/恢复状态切换（无窗口下只验证逻辑状态） ---
	main._pause()
	_ok(paused and main.hud._pause_root.visible, "Esc 暂停生效并显示暂停界面")
	main._resume()
	_ok(not paused and gunner.resume_grace > 0.0, "恢复生效且带开炮宽限")

	# --- T003-01：共享配置独立状态（003-R1：真实行动验证，不直接改状态副本） ---
	_ok(main.actor_a.state != main.actor_b.state, "T003-01 A/B 状态实例独立")
	_ok(main.actor_a.state.definition_id == main.actor_b.state.definition_id, "T003-01 A/B 共享同一配置定义 (id=%s)" % main.actor_a.state.definition_id)
	_ok(main.actor_a.definition == main.actor_b.definition, "T003-01 A/B 共享同一 VehicleDefinition 实例")
	var def_fwd: float = main.actor_a.definition.forward_max_speed
	main._reset_all()
	await physics_frame
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	_ok(main.actor_a.tank.forward_speed > 1.0, "T003-01 A 真实驾驶产生速度 (v=%.2f)" % main.actor_a.tank.forward_speed)
	_ok(main.actor_b.tank.forward_speed < 0.01, "T003-01 B 真实状态不受 A 驾驶影响 (v=%.2f)" % main.actor_b.tank.forward_speed)
	_ok(absf(main.actor_a.state.forward_speed - main.actor_a.tank.forward_speed) < 0.001, "T003-01 A 状态快照与真实组件一致")
	_ok(main.actor_b.state.forward_speed == 0.0, "T003-01 B 状态快照保持 0")
	_ok(main.actor_a.definition.forward_max_speed == def_fwd, "T003-01 共享配置未被 A 行动修改")

	# --- T003-02：A/B 输入隔离与统一命令 ---
	main._reset_all()
	await physics_frame
	var b_pos0: Vector3 = main.actor_b.tank.global_position
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	_ok(main.actor_a.tank.forward_speed > 1.0, "T003-02 键盘输入只驱动 A (v=%.2f)" % main.actor_a.tank.forward_speed)
	_ok(main.actor_b.tank.forward_speed < 0.01, "T003-02 B 零命令不响应键盘 (v=%.2f)" % main.actor_b.tank.forward_speed)
	_ok(main.actor_b.tank.global_position.distance_to(b_pos0) < 0.01, "T003-02 B 位置不动")
	# 统一命令：脚本命令经同一提交入口驱动 B 炮塔（目标在 B 右侧 → yaw 需转）
	# 003-R2：submit 只暂存不执行——提交后下一物理步由 B 自己的 _physics_process 消费
	var b_yaw0: float = main.actor_b.turret.global_rotation.y
	var cmd_b := VehicleCommand.new()
	cmd_b.has_aim_point = true
	cmd_b.aim_world_point = main.actor_b.tank.global_position + Vector3(10, 0, 0)
	main.actor_b.submit_command(cmd_b)
	for i in 30:
		await physics_frame
	_ok(absf(main.actor_b.turret.global_rotation.y - b_yaw0) > 0.01, "T003-02 脚本命令经统一通道驱动 B 炮塔 (Δyaw=%.2f°)" % rad_to_deg(absf(main.actor_b.turret.global_rotation.y - b_yaw0)))
	# 003-R2：脚本持续命令驱动 B 真实移动——不关闭 actor 物理更新，
	# 每帧经同一提交入口提交，B 的物理回调每步消费恰好一次
	var b_pos1: Vector3 = main.actor_b.tank.global_position
	var b_drive0: int = main.actor_b.tank.drive_call_count()
	var cmd_move := VehicleCommand.new()
	cmd_move.throttle = 1.0
	for i in 60:
		main.actor_b.submit_command(cmd_move)
		await physics_frame
	_ok(main.actor_b.tank.drive_call_count() - b_drive0 == 60, "T003-02 每物理步恰好消费一次（无双路径并行，drive=%d）" % (main.actor_b.tank.drive_call_count() - b_drive0))
	_ok(main.actor_b.tank.global_position.distance_to(b_pos1) > 1.0, "T003-02 脚本持续命令驱动 B 真实移动 (dist=%.2f)" % main.actor_b.tank.global_position.distance_to(b_pos1))
	# 003-R2：提交≠执行——提交后未到消费步不产生移动
	var b_pos_now: Vector3 = main.actor_b.tank.global_position
	main.actor_b.submit_command(cmd_move)
	_ok(main.actor_b.tank.global_position.distance_to(b_pos_now) < 0.001, "T003-02 提交命令不立即执行（等物理步消费）")
	# 003-R1：入口合法性——暂停时提交被拒绝
	main._pause()
	var b_pos_pause: Vector3 = main.actor_b.tank.global_position
	var paused_ok: bool = main.actor_b.submit_command(cmd_move)
	_ok(not paused_ok, "T003-02 暂停时命令提交被拒绝")
	_ok(main.actor_b.tank.global_position.distance_to(b_pos_pause) < 0.001, "T003-02 暂停时命令入口拒绝执行")
	main._resume()
	# 003-R1：非有限输入被钳制为 0（不产生 NaN 速度）
	var cmd_nan := VehicleCommand.new()
	cmd_nan.throttle = NAN
	main.actor_b.submit_command(cmd_nan)
	await physics_frame
	_ok(is_finite(main.actor_b.tank.forward_speed), "T003-02 非有限输入不产生 NaN 状态")

	# --- T003-03：自身命中排除 / A 命中 B / 墙挡不命中 / 炮镜不隐藏 B ---
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	await physics_frame
	var b_hits0: int = main.actor_b.tank.hits_taken
	var d_ab: Vector3 = main.actor_b.tank.global_position - main.actor_a.tank.global_position
	main.cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z)
	await process_frame
	await process_frame
	var cam_pos: Vector3 = main.cam_rig.cam.global_position
	var b_center: Vector3 = main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	var horiz: float = Vector3(cam_pos.x - b_center.x, 0, cam_pos.z - b_center.z).length()
	main.cam_rig.aim_pitch = atan2(1.0 - cam_pos.y, horiz)
	await process_frame   # 相机 look_at 按新 pitch 更新后再 snap（否则 intent 用旧前向）
	turret_snap(main)
	await physics_frame
	await physics_frame
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var fired_b: bool = gunner.try_fire()
	_ok(fired_b, "T003-03 A 开火成功")
	_ok(main.actor_b.tank.hits_taken == b_hits0 + 1, "T003-03 A 命中 B（自身排除生效）(hits=%d)" % main.actor_b.tank.hits_taken)
	_ok(main.actor_a.tank.hits_taken == 0, "T003-03 A 未被自身命中")
	# 墙挡不命中
	var t003_wall := StaticBody3D.new()
	t003_wall.collision_layer = GameConfig.LAYER_WORLD
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.5)
	wall_shape.shape = box
	t003_wall.add_child(wall_shape)
	var dir_ab: Vector3 = (main.actor_b.tank.global_position - main.actor_a.tank.global_position).normalized()
	t003_wall.position = main.actor_a.tank.global_position + dir_ab * 4.0
	t003_wall.rotation.y = atan2(dir_ab.x, dir_ab.z)
	main.add_child(t003_wall)
	await physics_frame
	await physics_frame
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	var fired_wall: bool = gunner.try_fire()
	_ok(fired_wall, "T003-03 墙挡时开火仍成功（命中墙）")
	_ok(main.actor_b.tank.hits_taken == b_hits0 + 1, "T003-03 墙挡不命中 B (hits=%d)" % main.actor_b.tank.hits_taken)
	t003_wall.queue_free()
	for i in 3:
		await physics_frame
	# 炮镜不隐藏 B（cull_mask 只剔除 A 自身视觉层；经真实输入通道开炮镜）
	Input.action_press("aim")
	for i in 2:
		await process_frame
	var mask: int = main.cam_rig.cam.cull_mask
	_ok((mask & GameConfig.VIS_LAYER_VEHICLE) == 0, "T003-03 炮镜剔除 A 自身视觉层")
	_ok((mask & GameConfig.VIS_LAYER_VEHICLE_B) != 0, "T003-03 炮镜保留 B 视觉层（B 可见）")
	Input.action_release("aim")
	await process_frame

	# --- T003-04：20 次生成/销毁（实体/相机/信号清理） ---
	var spawn_ok := true
	for i in 20:
		var sv: VehicleActor = main.spawn_vehicle("player_tank", "S%02d" % i, Vector3(12, 0, 20 + i * 1.5), null)
		if sv == null or sv.tank == null:
			spawn_ok = false
			break
		await physics_frame
		await physics_frame
		if sv.cam_rig.cam.current:
			spawn_ok = false
			break
		main.despawn_vehicle(sv)
		await physics_frame
		await physics_frame
		if is_instance_valid(sv):
			spawn_ok = false
			break
	_ok(spawn_ok, "T003-04 20 次生成/销毁：实体/相机/信号清理干净")

	# --- T003-06：试射目标（真实命中才推进；空射/冷却拒绝不推进；重启可重复；单车重置不污染） ---
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	await physics_frame
	_ok(main.trial_hits == 0, "T003-06 重置后试射计数归零")
	# 空射不推进
	main.cam_rig.aim_yaw = 0.0
	main.cam_rig.aim_pitch = deg_to_rad(20.0)
	await process_frame
	turret_snap(main)
	for i in 30:
		await physics_frame
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	_ok(main.trial_hits == 0, "T003-06 空射不推进试射计数")
	# 冷却拒绝不推进
	gunner.cooldown_left = 5.0
	gunner.try_fire()
	_ok(main.trial_hits == 0, "T003-06 冷却拒绝不推进试射计数")
	gunner.cooldown_left = 0.0
	# 真实命中推进（B 移到 A 正前方）
	var b_orig: Vector3 = main.actor_b.tank.global_position
	main.actor_b.tank.global_position = Vector3(0, 0, -6)
	await physics_frame
	await physics_frame
	main.cam_rig.aim_yaw = 0.0
	await process_frame
	await process_frame
	var cam_pos2: Vector3 = main.cam_rig.cam.global_position
	var b_center2: Vector3 = main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	var horiz2: float = Vector3(cam_pos2.x - b_center2.x, 0, cam_pos2.z - b_center2.z).length()
	main.cam_rig.aim_pitch = atan2(1.0 - cam_pos2.y, horiz2)
	await process_frame   # 相机 look_at 按新 pitch 更新后再 snap
	turret_snap(main)
	await physics_frame
	await physics_frame
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	_ok(main.trial_hits == 1, "T003-06 真实命中推进试射计数 (hits=%d)" % main.trial_hits)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	_ok(main.trial_hits == 2, "T003-06 第二次命中推进 (hits=%d)" % main.trial_hits)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	_ok(main.trial_hits == 3, "T003-06 第三次命中完成试射 (hits=%d)" % main.trial_hits)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	_ok(main.trial_hits == 3, "T003-06 完成后再命中不超计 (hits=%d)" % main.trial_hits)
	# 单车重置不污染试射目标
	main.reset_vehicle(main.actor_a)
	_ok(main.trial_hits == 3, "T003-06 单车重置不污染试射计数 (hits=%d)" % main.trial_hits)
	# 整场重置可重复
	main._reset_all()
	_ok(main.trial_hits == 0, "T003-06 整场重置后试射计数归零（可重复）")
	main.actor_b.tank.global_position = b_orig
	await physics_frame

	# --- T003-07（003-R1）：两套不同测试配置跑出不同真实表现（不修改 GameConfig） ---
	var defs2 := VehicleDefs.new()
	var slow_v := VehicleDefinition.new()
	slow_v.id = "test_slow"
	slow_v.weapon_id = "test_slow_gun"
	slow_v.forward_max_speed = 4.0
	slow_v.forward_accel = 4.0
	slow_v.reverse_max_speed = 2.0
	slow_v.reverse_accel = 3.0
	slow_v.brake_decel = 8.0
	slow_v.coast_decel = 2.0
	slow_v.hull_turn_speed = 30.0
	slow_v.turret_yaw_speed = 20.0
	slow_v.turret_pitch_speed = 15.0
	slow_v.barrel_pitch_min = -8.0
	slow_v.barrel_pitch_max = 20.0
	var slow_w := WeaponDefinition.new()
	slow_w.id = "test_slow_gun"
	slow_w.shell_id = "test_slow_shell"
	slow_w.reload_time = 3.0
	slow_w.gun_range = 100.0
	slow_w.barrel_pitch_min = -8.0
	slow_w.barrel_pitch_max = 20.0
	var slow_s := ShellDefinition.new()
	slow_s.id = "test_slow_shell"
	defs2.vehicles["test_slow"] = slow_v
	defs2.weapons["test_slow_gun"] = slow_w
	defs2.shells["test_slow_shell"] = slow_s
	var fast_v := VehicleDefinition.new()
	fast_v.id = "test_fast"
	fast_v.weapon_id = "test_fast_gun"
	fast_v.forward_max_speed = 12.0
	fast_v.forward_accel = 10.0
	fast_v.reverse_max_speed = 5.0
	fast_v.reverse_accel = 6.0
	fast_v.brake_decel = 14.0
	fast_v.coast_decel = 4.0
	fast_v.hull_turn_speed = 120.0
	fast_v.turret_yaw_speed = 60.0
	fast_v.turret_pitch_speed = 45.0
	fast_v.barrel_pitch_min = -8.0
	fast_v.barrel_pitch_max = 20.0
	var fast_w := WeaponDefinition.new()
	fast_w.id = "test_fast_gun"
	fast_w.shell_id = "test_fast_shell"
	fast_w.reload_time = 1.0
	fast_w.gun_range = 300.0
	fast_w.barrel_pitch_min = -8.0
	fast_w.barrel_pitch_max = 20.0
	var fast_s := ShellDefinition.new()
	fast_s.id = "test_fast_shell"
	defs2.vehicles["test_fast"] = fast_v
	defs2.weapons["test_fast_gun"] = fast_w
	defs2.shells["test_fast_shell"] = fast_s
	var slow_a: VehicleActor = main.spawn_vehicle("test_slow", "SLOW", Vector3(0, 0, 30), null, defs2)
	var fast_a: VehicleActor = main.spawn_vehicle("test_fast", "FAST", Vector3(0, 0, 40), null, defs2)
	_ok(slow_a != null and fast_a != null, "T003-07 两套配置实体生成成功")
	# 脚本持续命令驱动真实移动（慢车 vs 快车，120 物理帧 = 2s）
	var cmd_slow := VehicleCommand.new()
	cmd_slow.throttle = 1.0
	var cmd_fast := VehicleCommand.new()
	cmd_fast.throttle = 1.0
	for i in 120:
		slow_a.submit_command(cmd_slow)
		fast_a.submit_command(cmd_fast)
		await physics_frame
	_ok(slow_a.tank.forward_speed < fast_a.tank.forward_speed - 2.0, "T003-07 慢车/快车真实速度不同 (slow=%.2f fast=%.2f)" % [slow_a.tank.forward_speed, fast_a.tank.forward_speed])
	_ok(absf(slow_a.tank.forward_speed - 4.0) < 0.5, "T003-07 慢车速度接近配置上限 4 m/s (v=%.2f)" % slow_a.tank.forward_speed)
	_ok(absf(fast_a.tank.forward_speed - 12.0) < 0.5, "T003-07 快车速度接近配置上限 12 m/s (v=%.2f)" % fast_a.tank.forward_speed)
	# 炮塔转速不同（脚本命令驱动真实转动，目标在各自右侧 20m）
	var cmd_turn_s := VehicleCommand.new()
	cmd_turn_s.has_aim_point = true
	cmd_turn_s.aim_world_point = slow_a.tank.global_position + Vector3(20, 0, 0)
	var cmd_turn_f := VehicleCommand.new()
	cmd_turn_f.has_aim_point = true
	cmd_turn_f.aim_world_point = fast_a.tank.global_position + Vector3(20, 0, 0)
	var yaw0_s: float = slow_a.turret.global_rotation.y
	var yaw0_f: float = fast_a.turret.global_rotation.y
	for i in 30:
		slow_a.submit_command(cmd_turn_s)
		fast_a.submit_command(cmd_turn_f)
		await physics_frame
	var d_s: float = absf(slow_a.turret.global_rotation.y - yaw0_s)
	var d_f: float = absf(fast_a.turret.global_rotation.y - yaw0_f)
	_ok(d_f > d_s + 0.05, "T003-07 快车炮塔转速快于慢车 (slow=%.1f° fast=%.1f°)" % [rad_to_deg(d_s), rad_to_deg(d_f)])
	# 装填时间不同（真实冷却来自各自武器配置）
	slow_a.gunner.cooldown_left = 0.0
	slow_a.gunner.resume_grace = 0.0
	fast_a.gunner.cooldown_left = 0.0
	fast_a.gunner.resume_grace = 0.0
	slow_a.gunner.try_fire()
	fast_a.gunner.try_fire()
	_ok(absf(slow_a.gunner.cooldown_left - 3.0) < 0.01, "T003-07 慢车装填 3s 来自配置 (cd=%.2f)" % slow_a.gunner.cooldown_left)
	_ok(absf(fast_a.gunner.cooldown_left - 1.0) < 0.01, "T003-07 快车装填 1s 来自配置 (cd=%.2f)" % fast_a.gunner.cooldown_left)
	_ok(slow_a.gunner.weapon.gun_range == 100.0 and fast_a.gunner.weapon.gun_range == 300.0, "T003-07 射程来自各自武器配置")
	main.despawn_vehicle(slow_a)
	main.despawn_vehicle(fast_a)
	for i in 3:
		await physics_frame

	# --- T003-08（003-R1）：多车碰撞与坐标 ---
	# A 开向 B 不穿过 B（稳定阻挡，无碰撞伤害/推挤）
	var c_actor: VehicleActor = main.spawn_vehicle("player_tank", "C", Vector3(8, 0, 6))
	_ok(c_actor != null, "T003-08 C 实体生成")
	var b_pos0_c: Vector3 = main.actor_b.tank.global_position
	var cmd_fwd := VehicleCommand.new()
	cmd_fwd.throttle = 1.0
	for i in 120:
		c_actor.submit_command(cmd_fwd)
		await physics_frame
	var c_pos: Vector3 = c_actor.tank.global_position
	_ok(c_pos.z > b_pos0_c.z + 2.0, "T003-08 C 被 B 阻挡不穿过 (c.z=%.2f b.z=%.2f)" % [c_pos.z, b_pos0_c.z])
	_ok(main.actor_b.tank.global_position.distance_to(b_pos0_c) < 0.01, "T003-08 B 未被推动")
	main.despawn_vehicle(c_actor)
	for i in 3:
		await physics_frame
	# 非原点 + 非零 Y 旋转出生：实际移动沿车头方向，重置回正确世界出生变换
	var rot_tf := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-10, 0, -10))
	var r_actor := VehicleActor.new()
	main.add_child(r_actor)
	var r_res := r_actor.setup(main.defs, "player_tank", "ROT", 9, rot_tf, GameConfig.VIS_LAYER_VEHICLE_B, null)
	_ok(r_res.ok, "T003-08 旋转出生实体 setup 成功")
	var r_pos0: Vector3 = r_actor.tank.global_position
	var r_yaw0: float = r_actor.tank.global_rotation.y
	for i in 60:
		r_actor.submit_command(cmd_fwd)
		await physics_frame
	var moved: Vector3 = r_actor.tank.global_position - r_pos0
	# 移动方向必须与车头方向（-global basis.z）一致（非零 Y 旋转出生）
	var fwd_dir: Vector3 = -r_actor.tank.global_transform.basis.z
	var move_dir: Vector3 = moved.normalized()
	_ok(moved.length() > 1.0 and fwd_dir.dot(move_dir) > 0.9, "T003-08 旋转出生下移动沿车头方向 (dist=%.2f dot=%.2f)" % [moved.length(), fwd_dir.dot(move_dir)])
	r_actor.reset_vehicle()
	_ok(r_actor.tank.global_position.distance_to(r_pos0) < 0.1, "T003-08 重置回正确世界出生变换")
	_ok(absf(r_actor.tank.global_rotation.y - r_yaw0) < 0.01, "T003-08 重置回正确出生朝向")
	r_actor.queue_free()
	for i in 3:
		await physics_frame
	# 示踪线世界坐标：起点 = 真实炮口世界位置；不随射击后车辆运动拖动
	main._reset_all()
	turret_snap(main)
	gunner.cooldown_left = 0.0
	gunner.resume_grace = 0.0
	gunner.try_fire()
	var pts: Array = gunner.tracer_points()
	_ok(pts.size() == 2, "T003-08 示踪线端点可读")
	var muz_w: Vector3 = main.actor_a.turret.muzzle.global_position
	_ok(pts[0].distance_to(muz_w) < 0.5, "T003-08 示踪线起点 = 真实炮口世界位置")
	var pts_before: Array = pts.duplicate()
	tank.global_position += Vector3(0, 0, 2)
	await physics_frame
	var pts_after: Array = gunner.tracer_points()
	_ok(pts_after.size() == 2 and pts_after[0].distance_to(pts_before[0]) < 0.01 and pts_after[1].distance_to(pts_before[1]) < 0.01, "T003-08 旧示踪线不随车辆运动拖动")

	# --- T003-09（003-R1/R2）：真实任务闭环——射手/射击编号/轮次/生命周期；正常输入链路 ---
	# C 射击 B：B 可被命中，但不能替 A 得分
	# 003-R2：C2 经同一提交入口提交命令，由 C2 自己的物理回调消费（不关闭任何生产回调）
	var c2: VehicleActor = main.spawn_vehicle("player_tank", "C2", Vector3(8, 0, 6))
	_ok(c2 != null, "T003-09 C2 实体生成")
	var cmd_aim_c := VehicleCommand.new()
	cmd_aim_c.has_aim_point = true
	cmd_aim_c.aim_world_point = main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	for i in 30:
		c2.submit_command(cmd_aim_c)
		await physics_frame
	var b_hits0_c2: int = main.actor_b.tank.hits_taken
	var t_hits0: int = main.trial_hits
	var cmd_fire_c := VehicleCommand.new()
	cmd_fire_c.fire_requested = true
	c2.submit_command(cmd_fire_c)
	await physics_frame
	await physics_frame
	_ok(main.actor_b.tank.hits_taken == b_hits0_c2 + 1, "T003-09 C 射击 B 可命中 (b_hits=%d)" % main.actor_b.tank.hits_taken)
	_ok(main.trial_hits == t_hits0, "T003-09 C 命中不替 A 得分 (trial=%d)" % main.trial_hits)
	# 同名车销毁重建：entity_id 相同，life_id 必须不同（生命周期身份）
	var c2_old_life: int = c2.life_id
	main.despawn_vehicle(c2)
	for i in 3:
		await physics_frame
	var c2b: VehicleActor = main.spawn_vehicle("player_tank", "C2", Vector3(8, 0, 6))
	_ok(c2b != null and c2b.life_id != c2_old_life, "T003-09 同名车重建后 life_id 不同 (%d→%d)" % [c2_old_life, c2b.life_id])
	main.despawn_vehicle(c2b)
	for i in 3:
		await physics_frame
	# 同一射击编号重复投递不重复计分（完整合法身份）
	var h1: int = main.trial_hits
	var id_ok := _task_identity(main, 999001)
	main._on_b_hit(id_ok)
	_ok(main.trial_hits == h1 + 1, "T003-09 新射击编号推进 (trial=%d)" % main.trial_hits)
	main._on_b_hit(id_ok)
	_ok(main.trial_hits == h1 + 1, "T003-09 同一射击编号重复投递不重复计分 (trial=%d)" % main.trial_hits)
	# 003-R2 强反例①：旧回合产生、任务接收器尚未收到的事件——重开后才首次送达 → 不计分
	# （接收器用开火时冻结的 round_id 校验，不用"是否见过该编号"判断）
	var id_stale := _task_identity(main, 999002)   # 冻结于当前（旧）轮次
	main._reset_all()   # 轮次递增 + 本回合去重清空——旧事件此刻才首次送达
	var h2: int = main.trial_hits
	main._on_b_hit(id_stale)
	_ok(main.trial_hits == h2, "T003-09 旧轮次事件重开后首次送达不计分 (trial=%d)" % main.trial_hits)
	# 003-R2 强反例②：同名车重建后的旧生命周期事件 → 不计分
	var id_old_life := _task_identity(main, 999003)
	id_old_life["shooter_life_id"] = c2_old_life + 99999   # 模拟旧实体已销毁的生命周期身份
	main._on_b_hit(id_old_life)
	_ok(main.trial_hits == h2, "T003-09 旧生命周期身份事件不计分 (trial=%d)" % main.trial_hits)
	# 正常输入链路：Input 开火 → 命令入口 → 真实命中 → 自然装填 → 推进（不清零冷却）
	main._reset_all()
	var d_ab9: Vector3 = main.actor_b.tank.global_position - main.actor_a.tank.global_position
	main.cam_rig.aim_yaw = atan2(-d_ab9.x, -d_ab9.z)
	await process_frame
	await process_frame
	var cam9: Vector3 = main.actor_a.cam_rig.cam.global_position
	var b_center9: Vector3 = main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	var horiz9: float = Vector3(cam9.x - b_center9.x, 0, cam9.z - b_center9.z).length()
	main.cam_rig.aim_pitch = atan2(1.0 - cam9.y, horiz9)
	await process_frame
	turret_snap(main)
	await physics_frame
	await physics_frame
	var t0: int = main.trial_hits
	Input.action_press("fire")
	for i in 2:
		await physics_frame
	Input.action_release("fire")
	_ok(main.trial_hits == t0 + 1, "T003-09 正常输入链路真实命中推进 (trial=%d)" % main.trial_hits)
	# 自然装填等待（不清零冷却）
	while main.actor_a.gunner.cooldown_left > 0.0:
		await physics_frame
	Input.action_press("fire")
	for i in 2:
		await physics_frame
	Input.action_release("fire")
	_ok(main.trial_hits == t0 + 2, "T003-09 自然装填后第二次命中推进 (trial=%d)" % main.trial_hits)
	# 真实 R 事件重开（整场重开，计数归零）
	_key(KEY_R)
	await process_frame
	await process_frame
	_ok(main.trial_hits == 0, "T003-09 真实 R 事件整场重开归零 (trial=%d)" % main.trial_hits)

	# --- T003-10（003-R2 收尾）：初始化失败守卫——失焦通知不得访问空 HUD/实体 ---
	# 程序注入通知验证代码路径（不冒充操作系统级 Alt+Tab 真人测试）
	var was_aborted: bool = main._aborted
	var was_inited: bool = main._initialized
	var paused_before: bool = main._paused
	# ① 终止态（abort 后）：失焦通知 → 不进入正常暂停、不访问空 HUD（无脚本错误即通过）
	main._aborted = true
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(main._paused == paused_before, "T003-10 失败终止态收失焦通知不进入正常暂停")
	# ② 初始化中态（未完成初始化）：失焦通知 → 同样被守卫拦截
	main._aborted = false
	main._initialized = false
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(main._paused == paused_before, "T003-10 初始化未完成态收失焦通知被守卫拦截")
	# ③ 恢复正常态：失焦自动暂停行为保持（002 行为不回退）
	main._aborted = was_aborted
	main._initialized = was_inited
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(main._paused, "T003-10 正常态失焦自动暂停保持（002 行为）")
	main._resume()

	_finish()

func turret_snap(main) -> void:
	main.turret.snap_to_aim()

func _task_identity(m: Node, sid: int) -> Dictionary:
	# 003-R2：构造完整合法任务命中身份（round/shooter/life/shot/target 来自实际状态）
	return {
		"round_id": m.get_round_id(),
		"shooter_id": m.actor_a.entity_id,
		"shooter_life_id": m.actor_a.life_id,
		"shot_id": sid,
		"target_id": m.actor_b.entity_id,
		"target_life_id": m.actor_b.life_id,
	}

func _key(k: Key) -> void:
	# 002-R2：真实按键事件（按下+释放）经 Input.parse_input_event 走完整输入管线
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

func _camera_ray_hit(main) -> Dictionary:
	# 002-R3：独立射线查询（与生产相同的 mask/exclude），返回 collider 供身份验证
	var cam: Camera3D = main.cam_rig.cam
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 150.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE, [main.tank.get_rid()])
	return space.intersect_ray(q)

func _stable_converge(main) -> Dictionary:
	# 002-R3 收尾版：稳定收敛验收——真值 = 期望世界点 P - 炮根位置（不复制生产 atan2）。
	# 炮根（barrel_pivot）随炮塔转动而绕车体中心移动，故每帧取当前 pivot 计算 want；
	# 收敛后 pivot 稳定，want 稳定，夹角应保持 0。
	# 首次达标（进入 0.5° 误差区）时保持时间从零开始、最大误差初始化为当前误差；
	# 之后按模拟更新时间（physics delta）累计，至少持续 1.0 秒，全程误差 ≤0.5°，
	# 任何一次超过 0.5° 即失败（继续生产更新，不暂停）。
	# 输出：首次过线帧、实际保持时长、最大误差、结束误差。
	var P: Vector3 = main.cam_rig.get_aim_point()
	var first_cross := -1
	var hold_time := 0.0
	var max_err := 0.0
	var final_err := 0.0
	for i in 240:
		await physics_frame
		var bdir: Vector3 = main.turret.barrel_direction()
		var want: Vector3 = (P - main.turret.barrel_pivot.global_position).normalized()
		var err: float = rad_to_deg(bdir.angle_to(want))
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
				max_err = err
			continue
		hold_time += 1.0 / Engine.physics_ticks_per_second   # 模拟时间（物理固定步长）
		max_err = maxf(max_err, err)
		final_err = err
		if err > 0.5:
			return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": err}
		if hold_time >= 1.0:
			return {"converged": true, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": err}
	return {"converged": false, "first_cross": first_cross, "hold_time": hold_time, "max_err": max_err, "final_err": final_err}

func _check_fonts() -> void:
	var f := ThemeDB.fallback_font
	var cjk: bool = f != null and f.has_char(0x4E2D)
	print("font_cjk_support=", cjk, "  (默认字体中文字形能力 → 决定 HUD 语言)")
	_ok(true, "默认字体 CJK 能力已记录")

func _check_scripts() -> void:
	for p in ["game_config", "world_builder", "target_board", "tank", "turret_rig", "camera_rig", "gunner", "hud", "main"]:
		var s = load("res://scripts/%s.gd" % p)
		_ok(s != null, "脚本可解析加载: %s.gd" % p)
	for p in ["defs/vehicle_definition", "defs/weapon_definition", "defs/shell_definition", "defs/vehicle_defs", "defs/vehicle_runtime_state", "defs/vehicle_command"]:
		var s = load("res://scripts/%s.gd" % p)
		_ok(s != null, "脚本可解析加载: %s.gd" % p)

func _check_defs() -> void:
	# --- T003-05（003）：错误配置校验失败并定位字段，不悄悄给默认值 ---
	var v_bad := VehicleDefinition.new()
	v_bad.id = ""
	var vres := v_bad.validate()
	_ok(not vres.ok and "id" in vres.errors[0], "T003-05 缺 ID 校验失败并定位 id 字段")
	v_bad.id = "bad"
	v_bad.forward_max_speed = -5.0
	vres = v_bad.validate()
	_ok(not vres.ok and "forward_max_speed" in vres.errors[0], "T003-05 非法速度校验失败并定位 forward_max_speed 字段")
	v_bad.forward_max_speed = 8.0
	v_bad.weapon_id = ""
	vres = v_bad.validate()
	_ok(not vres.ok and "weapon_id" in vres.errors[0], "T003-05 缺武器引用校验失败并定位 weapon_id 字段")
	var w_bad := WeaponDefinition.new()
	w_bad.id = ""
	var wres := w_bad.validate()
	_ok(not wres.ok and "id" in wres.errors[0], "T003-05 武器缺 ID 校验失败并定位 id 字段")
	var s_bad := ShellDefinition.new()
	s_bad.id = ""
	var sres := s_bad.validate()
	_ok(not sres.ok and "id" in sres.errors[0], "T003-05 弹种缺 ID 校验失败并定位 id 字段")
	# 默认配置 .tres 加载 + 校验 + 引用解析
	var defs := VehicleDefs.new()
	var lr := defs.load_defaults()
	_ok(lr.ok, "T003-05 默认配置 .tres 加载并校验通过")
	var v_ok := defs.get_vehicle("player_tank")
	_ok(v_ok != null and v_ok.validate().ok, "T003-05 默认车辆定义校验通过")
	var res_missing := defs.resolve_vehicle("no_such_vehicle")
	_ok(not res_missing.ok and "vehicle_id" in res_missing.errors[0], "T003-05 未知车辆引用失败并定位 vehicle_id")
	var v_missing_weapon := VehicleDefinition.new()
	v_missing_weapon.id = "bad_vehicle"
	v_missing_weapon.weapon_id = "no_such_weapon"
	defs.vehicles["bad_vehicle"] = v_missing_weapon
	var res_w := defs.resolve_vehicle("bad_vehicle")
	_ok(not res_w.ok and "weapon_id" in res_w.errors[0], "T003-05 缺武器引用解析失败并定位 weapon_id 字段")
	# RC-001：车型身份/来源/核验字段校验
	var v_tier := VehicleDefinition.new()
	v_tier.id = "t"
	v_tier.weapon_id = "w"
	v_tier.content_tier = "bogus"
	var tres := v_tier.validate()
	_ok(not tres.ok and "content_tier" in tres.errors[0], "T003-05 非法 content_tier 校验失败并定位字段")
	v_tier.content_tier = "production"
	v_tier.verification = "estimated"
	tres = v_tier.validate()
	_ok(not tres.ok and "verification" in tres.errors[0], "T003-05 production 未核验校验失败并定位 verification 字段")
	v_tier.verification = "verified"
	tres = v_tier.validate()
	_ok(not tres.ok and "verification" in tres.errors[0], "T003-05 verified 无实质来源校验失败并定位 verification 字段")
	v_tier.source_refs = ["TEST ONLY: development fixture, no historical basis"]
	tres = v_tier.validate()
	_ok(not tres.ok, "T003-05 verified 仅 TEST ONLY 声明仍不通过")
	v_tier.source_refs = ["Hunnicutt, Sherman: A History of the American Medium Tank, p.120"]
	_ok(v_tier.validate().ok, "T003-05 production+verified+实质来源校验通过")
	# 默认测试车必须显式 TEST ONLY（不冒充历史车型）
	_ok(v_ok.content_tier == "test", "T003-05 默认测试车 content_tier=test")
	_ok(v_ok.verification == "unknown", "T003-05 默认测试车 verification=unknown")
	_ok(v_ok.source_refs.size() > 0 and "TEST ONLY" in v_ok.source_refs[0], "T003-05 默认测试车 source_refs 显式 TEST ONLY 声明")
	var w_ok := defs.get_weapon("player_tank_gun")
	_ok(w_ok != null and w_ok.source_refs.size() > 0 and "TEST ONLY" in w_ok.source_refs[0], "T003-05 默认测试武器 source_refs 显式 TEST ONLY 声明")
	var s_ok := defs.get_shell("ap_75")
	_ok(s_ok != null and s_ok.source_refs.size() > 0 and "TEST ONLY" in s_ok.source_refs[0], "T003-05 默认测试弹种 source_refs 显式 TEST ONLY 声明")

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