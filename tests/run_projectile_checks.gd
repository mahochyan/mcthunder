extends SceneTree
## 006：有限速度炮弹验收检查（run_projectile_checks.gd）
## 运行：godot --headless --path <工程根> -s res://tests/run_projectile_checks.gd
## 覆盖：T006-01 自由飞行（纯数学 + 管理器推进）
##       T006-02 高速薄板（1200 m/s 一步跨越检出，前板后第二目标不中）
##       T006-03 渲染帧率不变性（headless 代理：同状态两次发射撞击一致；
##               真实 30/144 max-fps 对比由 --ballistics-demo 双分辨率证据承担）
##       T006-04 生命周期（100 次暂停/恢复 + 20 次整场重置 + 飞行中暂停冻结）
##       T006-05 炮口权威（相机方向与炮管错开仍按炮管飞行；贴墙遮挡）
##       四组集成：发射原子性 / 实际撞击 / 身份与边界 / 动态采样
## 失败时退出码非 0；PASS 文本与退出码分别检查（运行器见 docs/DELIVERY_006.md）。

var _pass := 0
var _fail := 0
var _main: Node = null
var _records: Array = []

func _initialize() -> void:
	var wd := create_timer(240.0)
	wd.timeout.connect(func() -> void:
		print("[WATCHDOG] 240s 超时，强制退出（存在卡死/等待）")
		quit(2))
	_run()

func _run() -> void:
	print("=== 006 弹道验收检查 ===")
	print("engine=", Engine.get_version_info()["string"], "  os=", OS.get_name())
	_math_checks()
	await _manager_checks()
	await _high_speed_plate_checks()
	await _main_checks()
	await _lifecycle_checks()
	await _muzzle_authority_checks()
	await _determinism_checks()
	print("=== 结果: %d 项检查, %d 失败 ===" % [_pass + _fail, _fail])
	if _fail > 0:
		print("PROJECTILE_CHECKS_FAIL")
		quit(1)
	print("PROJECTILE_CHECKS_PASS")
	quit(0)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL[%d]: %s" % [_pass + _fail, label])

# --- T006-01a：纯数学自由飞行 ---

func _math_checks() -> void:
	var r := BallisticMath.advance_free(Vector3(0, 3, 0), Vector3(300, 0, 0), Vector3(0, -9.81, 0), 0.5)
	_ok(r.get("ok") == true, "T006-01a advance_free ok")
	var p: Vector3 = r.get("position", Vector3.ZERO)
	var v: Vector3 = r.get("velocity", Vector3.ZERO)
	_ok(p.distance_to(Vector3(150, 1.77375, 0)) <= 0.001, "T006-01a 0.5s 位置 (150,1.77375,0) 容差 0.001m (实际=%s)" % str(p))
	_ok(v.distance_to(Vector3(300, -4.905, 0)) <= 0.001, "T006-01a 0.5s 速度 (300,-4.905,0) 容差 0.001m/s (实际=%s)" % str(v))
	# 非有限输入
	var bad := BallisticMath.advance_free(Vector3(NAN, 0, 0), Vector3(300, 0, 0), Vector3(0, -9.81, 0), 0.5)
	_ok(bad.get("ok") == false and bad.get("reason") == "non_finite_state", "T006-01a 非有限位置拒绝")
	var bad2 := BallisticMath.advance_free(Vector3(0, 3, 0), Vector3(300, 0, 0), Vector3(0, -9.81, 0), -0.1)
	_ok(bad2.get("ok") == false and bad2.get("reason") == "invalid_dt", "T006-01a 负 dt 拒绝")
	# plan_times 常规
	var pt := BallisticMath.plan_times(Vector3(300, 0, 0), Vector3(0, -9.81, 0), 1.0 / 60.0)
	_ok(pt.get("ok") == true, "T006-01a plan_times ok")
	var times: Array = pt.get("times", [])
	_ok(times.size() >= 1 and times.size() <= BallisticMath.MAX_SUBSTEPS, "T006-01a 子步数 1..32 (实际=%d)" % times.size())
	_ok(absf(times[0]) < 1.0e-9 and absf(times[times.size() - 1] - 1.0 / 60.0) < 1.0e-9, "T006-01a 子步首尾 = 0..dt")
	# 垂直转折点拆分
	var pt2 := BallisticMath.plan_times(Vector3(0, 5, 0), Vector3(0, -9.81, 0), 1.0)
	_ok(pt2.get("ok") == true, "T006-01a 转折 plan_times ok")
	var times2: Array = pt2.get("times", [])
	var has_turn := false
	for t in times2:
		if absf(float(t) - 5.0 / 9.81) < 1.0e-3:
			has_turn = true
	_ok(has_turn, "T006-01a 转折点 t=5/9.81 在子步边界 (times=%s)" % str(times2))
	# 预算超限
	var pt3 := BallisticMath.plan_times(Vector3(0, 0, 0), Vector3(0, 1.0e6, 0), 1.0)
	_ok(pt3.get("ok") == false and pt3.get("reason") == "substep_budget_exceeded", "T006-01a 子步预算超限拒绝")
	var pt4 := BallisticMath.plan_times(Vector3(0, 0, 0), Vector3(0, -9.81, 0), 0.0)
	_ok(pt4.get("ok") == false and pt4.get("reason") == "invalid_dt", "T006-01a dt<=0 拒绝")

# --- 管理器基础（最小场景） ---

func _manager_checks() -> void:
	var holder := Node3D.new()
	holder.name = "ProjHolder"
	root.add_child(holder)
	var mgr := ProjectileManager.new()
	mgr.name = "Mgr"
	holder.add_child(mgr)
	mgr.snapshot_provider = Callable(self, "empty_snapshots")
	mgr.exclude_provider = Callable(self, "empty_excludes")
	mgr.projectile_finished.connect(_on_finished)
	await process_frame
	# 出生当步不推进：spawn 后立即（同帧）状态 = pending
	var spec := _spec(1, "S1", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0)
	var sp := mgr.try_spawn(spec)
	_ok(sp.get("ok") == true, "T006-01b try_spawn ok")
	var pid: int = sp.get("projectile_id", 0)
	var st := mgr.get_projectile_state(pid)
	_ok(st != null and st.status == "pending", "T006-01b 出生当步不推进 (status=%s)" % (st.status if st != null else "null"))
	await physics_frame   # 本帧管理器稍后晋升并首次推进（测试恢复点在其之前）
	await physics_frame   # 已晋升并推进 1 步
	st = mgr.get_projectile_state(pid)
	_ok(st != null and st.status == "flying", "T006-01b 下一物理步转 flying")
	# 自由飞行 31 帧等待 = 30 步推进 = 0.5s → (150, 1.77375, 0)
	for i in 29:
		await physics_frame
	st = mgr.get_projectile_state(pid)
	_ok(st != null, "T006-01b 0.5s 时仍在飞")
	if st != null:
		_ok(st.position_world.distance_to(Vector3(150, 1.77375, 0)) <= 0.001, "T006-01b 管理器推进 0.5s 位置容差 0.001m (实际=%s)" % str(st.position_world))
	# 取消 S1（释放容量；accepted 发射记录保留，重复发射检查仍有效）
	mgr.cancel_all("cancelled_reset")
	# 拒绝：空 shell / 非有限位置 / 重复发射
	var r1 := _spec(2, "S1", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0).duplicate()
	r1["shell_id"] = ""
	_ok(mgr.try_spawn(r1).get("reason") == "invalid_shell", "T006-01b 空 shell_id 拒绝")
	var r2 := _spec(3, "S1", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0).duplicate()
	r2["position_world"] = Vector3(NAN, 0, 0)
	_ok(mgr.try_spawn(r2).get("reason") == "invalid_spawn", "T006-01b 非有限位置拒绝")
	var r3 := _spec(4, "S1", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0).duplicate()
	r3["shot_id"] = 1
	_ok(mgr.try_spawn(r3).get("reason") == "duplicate_launch", "T006-01b 同射手同 shot_id 重复发射拒绝")
	# 容量：64 满 → 第 65 发拒绝
	for i in 64:
		var s := _spec(100 + i, "CAP", 1, Vector3(0, 100, 0), Vector3(0, 0, 0), 0.5, 200.0)
		s["shot_id"] = i + 1
		var rr := mgr.try_spawn(s)
		if not rr.get("ok", false):
			_ok(false, "T006-01b 容量填充第 %d 发失败: %s" % [i + 1, rr.get("reason", "")])
			break
	_ok(mgr.active_count() == 64, "T006-01b 容量 64 满 (active=%d)" % mgr.active_count())
	var rcap := _spec(999, "CAP", 1, Vector3(0, 100, 0), Vector3(0, 0, 0), 0.5, 200.0)
	rcap["shot_id"] = 999
	_ok(mgr.try_spawn(rcap).get("reason") == "projectile_capacity", "T006-01b 容量满拒绝第 65 发")
	# 等容量弹全部到期（0.5s = 30 帧）
	for i in 40:
		await physics_frame
		if mgr.active_count() == 0:
			break
	_ok(mgr.active_count() == 0, "T006-01b 容量弹到期清空 (active=%d)" % mgr.active_count())
	# 寿命/路程到期
	var s_age := _spec(200, "S2", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 0.1, 200.0)
	mgr.try_spawn(s_age)
	for i in 20:
		await physics_frame
		if mgr.active_count() == 0:
			break
	_ok(_last_reason() == "expired_time", "T006-01b 寿命到期 expired_time (reason=%s)" % _last_reason())
	var s_dist := _spec(201, "S3", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 10.0)
	var sp_dist := mgr.try_spawn(s_dist)
	_ok(sp_dist.get("ok") == true, "T006-01b 路程弹已接收")
	for i in 20:
		await physics_frame
		if mgr.active_count() == 0:
			break
	_ok(_last_reason() == "expired_distance", "T006-01b 路程到期 expired_distance (reason=%s)" % _last_reason())
	# cancel_by_shooter：只取消该射手
	var s_a := _spec(300, "CA", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0)
	var s_b := _spec(301, "CB", 1, Vector3(0, 3, 0), Vector3(300, 0, 0), 8.0, 200.0)
	mgr.try_spawn(s_a)
	mgr.try_spawn(s_b)
	await physics_frame
	mgr.cancel_by_shooter("CA", 1, "cancelled_reset")
	_ok(mgr.active_count() == 1, "T006-01b cancel_by_shooter 只取消该射手 (active=%d)" % mgr.active_count())
	mgr.cancel_all("cancelled_reset")
	_ok(mgr.active_count() == 0, "T006-01b cancel_all 清空")
	holder.queue_free()
	await process_frame

# --- T006-02：高速薄板（1200 m/s，60Hz 一步 20m，板在采样端点之间） ---

func _high_speed_plate_checks() -> void:
	var holder := Node3D.new()
	holder.name = "PlateHolder"
	root.add_child(holder)
	var mgr := ProjectileManager.new()
	mgr.name = "Mgr"
	holder.add_child(mgr)
	mgr.snapshot_provider = Callable(self, "empty_snapshots")
	mgr.exclude_provider = Callable(self, "empty_excludes")
	mgr.projectile_finished.connect(_on_finished)
	# 薄板：x=2.3 处 0.1m 厚（起点前 2.3m，位于第一子步 0..5m 内部，不在端点上）
	var plate := StaticBody3D.new()
	plate.collision_layer = GameConfig.LAYER_WORLD
	plate.collision_mask = 0
	holder.add_child(plate)
	var pcs := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(0.1, 6.0, 6.0)
	pcs.shape = pbox
	plate.add_child(pcs)
	plate.position = Vector3(2.3, 3.0, 0.0)
	# 第二目标：x=5（前板之后）
	var back := StaticBody3D.new()
	back.collision_layer = GameConfig.LAYER_WORLD
	back.collision_mask = 0
	holder.add_child(back)
	var bcs := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(0.1, 6.0, 6.0)
	bcs.shape = bbox
	back.add_child(bcs)
	back.position = Vector3(5.0, 3.0, 0.0)
	await process_frame
	_records.clear()
	var spec := _spec(1, "HS", 1, Vector3(0, 3, 0), Vector3(1200, 0, 0), 8.0, 200.0)
	var sp := mgr.try_spawn(spec)
	_ok(sp.get("ok") == true, "T006-02 高速弹已接收")
	for i in 10:
		await physics_frame
		if mgr.active_count() == 0:
			break
	_ok(_records.size() == 1, "T006-02 恰好一次终止 (records=%d)" % _records.size())
	if _records.size() == 1:
		var rec: Dictionary = _records[0]
		_ok(rec.get("reason") == "impact_world", "T006-02 终止原因 impact_world (reason=%s)" % str(rec.get("reason")))
		var pt: Vector3 = rec.get("impact_point", Vector3.ZERO)
		_ok(pt.x >= 2.2 and pt.x <= 2.31, "T006-02 接触点在前板前表面 x≈2.25（板心 2.3 半厚 0.05）(实际 x=%.3f)" % pt.x)
		_ok(rec.get("travelled_m", 0.0) < 5.0, "T006-02 路程 < 5m（未越过前板）(dist=%.3f)" % rec.get("travelled_m", 0.0))
	holder.queue_free()
	await process_frame

# --- 主场景集成：发射原子性 / 实际撞击 / 身份与边界 / 动态采样 ---

func _main_checks() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	_ok(ps != null, "主场景资源可加载")
	if ps == null:
		return
	_main = ps.instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_ok(_main.projectiles != null, "主场景 ProjectileManager 存在")
	if _main.projectiles == null:
		return
	_main.projectiles.projectile_finished.connect(_on_finished)
	# --- 发射原子性 ---
	_main._reset_all()
	await _aim_at_b()
	var b_hits0: int = _main.actor_b.tank.hits_taken
	var ammo0: int = _main.gunner.rounds_remaining
	var shots0: int = _main.gunner.shots_fired
	var fired: bool = _fire()
	_ok(fired, "集成-原子性 开火成功")
	_ok(_main.actor_b.tank.hits_taken == b_hits0, "集成-原子性 try_fire 返回后目标尚未加分 (hits=%d)" % _main.actor_b.tank.hits_taken)
	_ok(_main.gunner.rounds_remaining == ammo0 - 1, "集成-原子性 接收成功只扣一发 (ammo=%d)" % _main.gunner.rounds_remaining)
	_ok(_main.gunner.shots_fired == shots0 + 1, "集成-原子性 射击计数 +1")
	await _wait_done(120)
	_ok(_main.actor_b.tank.hits_taken == b_hits0 + 1, "集成-原子性 真实撞击后目标 +1 (hits=%d)" % _main.actor_b.tank.hits_taken)
	# --- 拒绝路径不扣弹 ---
	_main._reset_all()
	await _aim_at_b()
	_main.gunner.rounds_remaining = 0
	var ammo_z: int = _main.gunner.rounds_remaining
	var shots_z: int = _main.gunner.shots_fired   # shots_fired 是实体终生计数，重置不清零——比较增量
	var f_no := _fire()
	_ok(not f_no, "集成-原子性 无弹拒绝")
	_ok(_main.gunner.rounds_remaining == ammo_z and _main.gunner.shots_fired == shots_z, "集成-原子性 无弹不扣弹不计数")
	_main._reset_all()
	await _aim_at_b()
	_main.gunner.cooldown_left = 1.0
	var f_cd: bool = _main.gunner.try_fire()
	_ok(not f_cd, "集成-原子性 冷却拒绝")
	_ok(_main.gunner.rounds_remaining == 30, "集成-原子性 冷却不扣弹")
	# 容量满拒绝
	_main._reset_all()
	await _aim_at_b()
	for i in 64:
		var s := _spec(500 + i, "FILL", 1, Vector3(0, 100, 0), Vector3(0, 0, 0), 0.5, 200.0)
		s["shot_id"] = i + 1
		_main.projectiles.try_spawn(s)
	_ok(_main.projectiles.active_count() == 64, "集成-原子性 容量填满")
	var f_cap := _fire()
	_ok(not f_cap, "集成-原子性 容量满拒绝")
	_ok(_main.gunner.rounds_remaining == 30, "集成-原子性 容量满不扣弹")
	_main.projectiles.cancel_all("cancelled_reset")
	# 炮管遮挡拒绝（005-F-A 模式：炮根-炮口段包墙）
	var rt_in: Vector3 = _main.actor_a.turret.barrel_pivot.global_position
	var mz_in: Vector3 = _main.actor_a.turret.muzzle.global_position
	var mn_in: Vector3 = rt_in.min(mz_in)
	var mx_in: Vector3 = rt_in.max(mz_in)
	var c_in: Vector3 = (mn_in + mx_in) / 2.0
	var sz_in: Vector3 = mx_in - mn_in + Vector3(0.2, 0.2, 0.2)
	var inner_wall = _main.world.build_wall(c_in, sz_in)
	for i in 2:
		await physics_frame
	var f_occ := _fire()
	_ok(not f_occ, "集成-原子性 炮管遮挡拒绝")
	_ok(_main.gunner.rounds_remaining == 30, "集成-原子性 遮挡不扣弹")
	inner_wall.queue_free()
	for i in 3:
		await physics_frame
	# --- 实际撞击：首处接触只终止一次；模块候选不计分 ---
	_main._reset_all()
	await _aim_at_b()
	_records.clear()
	var b_h0: int = _main.actor_b.tank.hits_taken
	_fire()
	await _wait_done(120)
	var veh_recs := 0
	for r in _records:
		if r.get("reason") == "impact_vehicle":
			veh_recs += 1
	_ok(veh_recs == 1, "集成-撞击 恰好一次 impact_vehicle (n=%d)" % veh_recs)
	_ok(_main.actor_b.tank.hits_taken == b_h0 + 1, "集成-撞击 目标恰好 +1（模块候选不计分）(hits=%d)" % _main.actor_b.tank.hits_taken)
	# --- 身份与边界 ---
	# 旧轮次飞弹不能新局计分：发射后立即整场重开（取消飞弹）
	_main._reset_all()
	await _aim_at_b()
	var b_h1: int = _main.actor_b.tank.hits_taken
	_fire()
	await physics_frame
	_main.reset_range()
	await _wait_done(60)
	_ok(_main.actor_b.tank.hits_taken == b_h1, "集成-身份 重开取消旧飞弹不计分 (hits=%d)" % _main.actor_b.tank.hits_taken)
	_ok(_main.gunner.rounds_remaining == 30, "集成-身份 重开弹药复位")
	# 寿命/路程上限外无命中（管理器直发，目标 B 在 11.3m 外）
	_main._reset_all()
	var a_muz: Vector3 = _main.actor_a.turret.muzzle.global_position
	var b_center: Vector3 = _main.actor_b.tank.global_position + Vector3(0, 0.95, 0)
	var dir_b: Vector3 = (b_center - a_muz).normalized()
	var s_short := _spec(700, _main.actor_a.entity_id, _main.actor_a.life_id, a_muz, dir_b * 300.0, 8.0, 5.0)
	s_short["round_id"] = _main.get_round_id()
	s_short["shot_id"] = 700
	_main.projectiles.try_spawn(s_short)
	await _wait_done(60)
	_ok(_main.actor_b.tank.hits_taken == 0, "集成-边界 路程上限外无命中 (hits=%d)" % _main.actor_b.tank.hits_taken)
	# 射手销毁不崩溃：生成 X → 发射 → 销毁 → 飞弹继续（管理器持有）
	var xa: VehicleActor = _main.spawn_vehicle("player_tank", "X", Vector3(0, 0, -10))
	_ok(xa != null, "集成-身份 生成 X")
	if xa != null:
		xa.gunner.cooldown_left = 0.0
		xa.gunner.resume_grace = 0.0
		xa.turret.set_aim_point(Vector3(0, 1, -20))
		xa.turret.snap_to_aim()
		await physics_frame
		await physics_frame
		_records.clear()
		var fx: bool = xa.gunner.try_fire()
		_ok(fx, "集成-身份 X 开火成功")
		_main.despawn_vehicle(xa)
		await physics_frame   # 1 步推进 ≈5m，尚未到达 ~7m 外接触面
		_ok(_main.projectiles.active_count() >= 1, "集成-身份 射手销毁后飞弹继续 (active=%d)" % _main.projectiles.active_count())
		await _wait_done(120)
		_ok(_records.size() >= 1, "集成-身份 销毁后飞弹正常终止（无崩溃）")
	# 同名重建不继承旧命中：Y 发射后销毁，新 Y 在别处，旧弹不冒充
	var xb: VehicleActor = _main.spawn_vehicle("player_tank", "Y", Vector3(0, 0, -10))
	_ok(xb != null, "集成-身份 生成 Y")
	if xb != null:
		xb.gunner.cooldown_left = 0.0
		xb.gunner.resume_grace = 0.0
		xb.turret.set_aim_point(Vector3(0, 1, -20))
		xb.turret.snap_to_aim()
		await physics_frame
		await physics_frame
		var fy: bool = xb.gunner.try_fire()
		_ok(fy, "集成-身份 Y 开火成功")
		_main.despawn_vehicle(xb)
		await physics_frame
		var y2: VehicleActor = _main.spawn_vehicle("player_tank", "Y", Vector3(5, 0, -10))
		_ok(y2 != null, "集成-身份 同名重建成功")
		await _wait_done(120)
		_ok(y2.tank.hits_taken == 0, "集成-身份 同名重建不继承旧命中 (hits=%d)" % y2.tank.hits_taken)
		_main.despawn_vehicle(y2)
	# --- 动态采样：发射后到达前目标移走，后续查询看到新位置；不追踪 ---
	_main._reset_all()
	await _aim_at_b()
	var b_h2: int = _main.actor_b.tank.hits_taken
	var a_muz2: Vector3 = _main.actor_a.turret.muzzle.global_position
	var b_center2: Vector3 = _main.actor_b.tank.global_position + Vector3(0, 0.95, 0)
	var dir2: Vector3 = (b_center2 - a_muz2).normalized()
	var s_dyn := _spec(800, _main.actor_a.entity_id, _main.actor_a.life_id, a_muz2, dir2 * 300.0, 8.0, 200.0)
	s_dyn["round_id"] = _main.get_round_id()
	s_dyn["shot_id"] = 800
	_main.projectiles.try_spawn(s_dyn)
	await physics_frame
	# 到达前把 B 移走（相对移动，不重置）
	_main.actor_b.tank.global_position += Vector3(4, 0, 0)
	await _wait_done(120)
	_ok(_main.actor_b.tank.hits_taken == b_h2, "集成-动态 目标移走不命中（不追踪）(hits=%d)" % _main.actor_b.tank.hits_taken)
	# 后续查询看到新位置：新发一弹瞄准新位置 → 命中
	var b_center3: Vector3 = _main.actor_b.tank.global_position + Vector3(0, 0.95, 0)
	var dir3: Vector3 = (b_center3 - a_muz2).normalized()
	var s_dyn2 := _spec(801, _main.actor_a.entity_id, _main.actor_a.life_id, a_muz2, dir3 * 300.0, 8.0, 200.0)
	s_dyn2["round_id"] = _main.get_round_id()
	s_dyn2["shot_id"] = 801
	_main.projectiles.try_spawn(s_dyn2)
	await _wait_done(120)
	_ok(_main.actor_b.tank.hits_taken == b_h2 + 1, "集成-动态 后续查询见新位置并命中 (hits=%d)" % _main.actor_b.tank.hits_taken)

# --- T006-04：生命周期（100 暂停/恢复 + 20 整场重置 + 飞行中暂停冻结） ---

func _lifecycle_checks() -> void:
	_main._reset_all()
	await _aim_at_b()
	var ammo_before: int = _main.gunner.rounds_remaining
	for i in 100:
		_main._pause()
		await process_frame
		_main._resume()
		await process_frame
	_ok(_main.gunner.rounds_remaining == ammo_before, "T006-04 100 次暂停/恢复无额外扣弹 (ammo=%d)" % _main.gunner.rounds_remaining)
	_ok(_main.projectiles.active_count() == 0, "T006-04 100 次暂停/恢复无飞弹残留 (active=%d)" % _main.projectiles.active_count())
	for i in 20:
		_main.reset_range()
		await physics_frame
	_ok(_main.gunner.rounds_remaining == 30, "T006-04 20 次整场重置弹药复位 (ammo=%d)" % _main.gunner.rounds_remaining)
	_ok(_main.projectiles.active_count() == 0, "T006-04 20 次整场重置无飞弹残留 (active=%d)" % _main.projectiles.active_count())
	_ok(_main.actor_b.tank.hits_taken == 0, "T006-04 20 次整场重置无旧命中 (hits=%d)" % _main.actor_b.tank.hits_taken)
	# 飞行中暂停冻结：位置/年龄/路程不推进，恢复后继续
	_main._reset_all()
	await _aim_at_b()
	_fire()
	await physics_frame   # 1 步推进 ≈5m（B 装甲在 ~7.7m 外，仍在飞）
	var sts: Array = _main.projectiles.active_states()
	_ok(sts.size() == 1, "T006-04 飞行中暂停前有 1 发在飞 (n=%d)" % sts.size())
	if sts.size() == 1:
		var st0: ProjectileState = sts[0]
		var p0: Vector3 = st0.position_world
		var a0: float = st0.age_s
		var d0: float = st0.travelled_m
		_main._pause()
		for i in 5:
			await process_frame
		var st1: ProjectileState = _main.projectiles.get_projectile_state(st0.projectile_id)
		_ok(st1 != null, "T006-04 暂停中飞弹仍在活动集合")
		if st1 != null:
			_ok(st1.position_world.distance_to(p0) < 1.0e-6, "T006-04 暂停中位置冻结")
			_ok(absf(st1.age_s - a0) < 1.0e-9, "T006-04 暂停中年龄冻结")
			_ok(absf(st1.travelled_m - d0) < 1.0e-9, "T006-04 暂停中路程冻结")
		_main._resume()
		await _wait_done(120)
		_ok(_main.actor_b.tank.hits_taken == 1, "T006-04 恢复后撞击正常 (hits=%d)" % _main.actor_b.tank.hits_taken)

# --- T006-05：炮口权威（相机方向与炮管错开，只按真实炮口/炮管飞行） ---

func _muzzle_authority_checks() -> void:
	_main._reset_all()
	# 炮管指向 B（真实炮口方向），相机故意错开 30°
	var d_ab: Vector3 = _main.actor_b.tank.global_position - _main.actor_a.tank.global_position
	_main.cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z) + deg_to_rad(30.0)
	await process_frame
	await process_frame
	var cam_pos: Vector3 = _main.cam_rig.cam.global_position
	var b_center: Vector3 = _main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	var horiz: float = Vector3(cam_pos.x - b_center.x, 0, cam_pos.z - b_center.z).length()
	_main.cam_rig.aim_pitch = atan2(1.0 - cam_pos.y, horiz)
	await process_frame
	# 炮管 snap 到 B 方向（与相机错开）
	_main.actor_a.turret.set_aim_point(b_center)
	_main.actor_a.turret.snap_to_aim()
	await physics_frame
	await physics_frame
	var b_h0: int = _main.actor_b.tank.hits_taken
	var fired := _fire()
	_ok(fired, "T006-05 开火成功")
	await _wait_done(120)
	_ok(_main.actor_b.tank.hits_taken == b_h0 + 1, "T006-05 只按真实炮口/炮管方向飞行（相机错开仍命中）(hits=%d)" % _main.actor_b.tank.hits_taken)
	# 贴墙遮挡继续成立（炮根-炮口段包墙 → 拒绝）
	var rt_in: Vector3 = _main.actor_a.turret.barrel_pivot.global_position
	var mz_in: Vector3 = _main.actor_a.turret.muzzle.global_position
	var mn_in: Vector3 = rt_in.min(mz_in)
	var mx_in: Vector3 = rt_in.max(mz_in)
	var c_in: Vector3 = (mn_in + mx_in) / 2.0
	var sz_in: Vector3 = mx_in - mn_in + Vector3(0.2, 0.2, 0.2)
	var inner_wall = _main.world.build_wall(c_in, sz_in)
	for i in 2:
		await physics_frame
	var f_occ := _fire()
	_ok(not f_occ, "T006-05 贴墙遮挡继续成立")
	inner_wall.queue_free()
	for i in 3:
		await physics_frame

# --- T006-03 代理：同状态两次发射 → 撞击一致（真实 30/144 对比见 demo 证据） ---

func _determinism_checks() -> void:
	_main._reset_all()
	await _aim_at_b()
	_records.clear()
	_fire()
	await _wait_done(120)
	var r1: Dictionary = _records[0] if _records.size() > 0 else {}
	_main._reset_all()
	await _aim_at_b()
	_records.clear()
	_fire()
	await _wait_done(120)
	var r2: Dictionary = _records[0] if _records.size() > 0 else {}
	_ok(not r1.is_empty() and not r2.is_empty(), "T006-03 两次发射均有终止记录")
	if not r1.is_empty() and not r2.is_empty():
		var p1: Vector3 = r1.get("impact_point", Vector3.ZERO)
		var p2: Vector3 = r2.get("impact_point", Vector3.ZERO)
		_ok(p1.distance_to(p2) <= 0.001, "T006-03 同状态两次发射接触点一致 ≤0.001m (diff=%.5f)" % p1.distance_to(p2))
		var t1: float = r1.get("flight_time_s", 0.0)
		var t2: float = r2.get("flight_time_s", 0.0)
		_ok(absf(t1 - t2) <= 1.0 / 60.0, "T006-03 飞行时间差 ≤1 物理步 (diff=%.5f)" % absf(t1 - t2))

# --- 辅助 ---

func _spec(pid: int, shooter: String, life: int, pos: Vector3, vel: Vector3, max_age: float, max_dist: float) -> Dictionary:
	return {
		"round_id": 1,
		"shooter_id": shooter,
		"shooter_life_id": life,
		"shooter_team_id": 1,
		"shot_id": pid,
		"shell_id": "ap_75",
		"position_world": pos,
		"velocity_world": vel,
		"gravity_world": Vector3(0, -9.81, 0),
		"max_age_s": max_age,
		"max_distance_m": max_dist,
	}

func empty_snapshots() -> Array:
	return []

func empty_excludes(_shooter_id: String, _shooter_life_id: int) -> Array[RID]:
	return []

func _on_finished(record: Dictionary) -> void:
	_records.append(record)

func _last_reason() -> String:
	if _records.is_empty():
		return ""
	return str(_records[_records.size() - 1].get("reason", ""))

func _aim_at_b() -> void:
	# 006：走生产瞄准路径——相机意图 → 控制者每物理步 set_aim_point → 炮塔跟踪。
	# 相机轨道位置随 aim_yaw/pitch 变化，炮塔有限速跟踪又带动相机，
	# 是慢收敛耦合；必须等"相机位姿 + 炮管指向"都稳定后读数/发射，
	# 否则两次发射的炮管角不一致（撞击点漂移 ~0.26m）。
	var b_center: Vector3 = _main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
	var d_ab: Vector3 = b_center - _main.actor_a.tank.global_position
	_main.cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z)
	_main.cam_rig.aim_pitch = 0.0
	# process_frame 信号在节点 _process 之前发出——先空等 2 帧确保相机
	# 至少完整处理过一次新 aim_yaw，否则首次读数是旧位姿 → 假收敛。
	await process_frame
	await process_frame
	var settled := false
	for iter in 4:
		var cam_pos: Vector3 = _main.cam_rig.cam.global_position
		var horiz: float = Vector3(cam_pos.x - b_center.x, 0, cam_pos.z - b_center.z).length()
		_main.cam_rig.aim_pitch = atan2(1.0 - cam_pos.y, horiz)
		# 等相机位置与炮管指向都收敛（最多 30 帧探针）
		var last_pos: Vector3 = _main.cam_rig.cam.global_position
		var last_dir: Vector3 = _main.actor_a.turret.barrel_direction()
		settled = false
		for i in 30:
			await process_frame
			var cp: Vector3 = _main.cam_rig.cam.global_position
			var bd: Vector3 = _main.actor_a.turret.barrel_direction()
			if cp.distance_to(last_pos) < 1.0e-5 and bd.distance_to(last_dir) < 1.0e-5:
				settled = true
				break
			last_pos = cp
			last_dir = bd
		if settled:
			break
	_main.turret.snap_to_aim()
	await physics_frame
	await physics_frame

func _fire() -> bool:
	_main.gunner.cooldown_left = 0.0
	_main.gunner.resume_grace = 0.0
	return _main.gunner.try_fire()

func _wait_done(timeout_frames: int) -> void:
	for i in timeout_frames:
		await physics_frame
		if _main.projectiles.active_count() == 0:
			return
