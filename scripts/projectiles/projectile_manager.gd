class_name ProjectileManager
extends Node3D
## 006：唯一推进飞弹的物理执行器（不持有车辆 Node；由当前战斗场景拥有）。
## 职责：接收发射（try_spawn，只校验/复制/占容量/入待推进集合，不推进不撞击）、
## 每物理步逐段推进（出生当步不推进）、分段完整路径查询（世界 + 车辆几何）、
## 一次性终止与身份分发（finish_once 先标终止再通知）、暂停/重开/销毁清理。
##
## 处理模式：PROCESS_MODE_PAUSABLE（暂停冻结，不继承 Main 的 ALWAYS）；
## process_physics_priority = 100（车辆之后运行——Godot 物理回调按优先级从小到大执行）。
##
## 每物理步只取一次当前车辆快照（_snapshot_provider），供本步全部飞弹查询使用；
## 下一物理步重新采样，不使用开火瞬间保存的整车快照一直算到落点。
## 目标几何视为在单个物理步内固定：支持目标移动后后续步看到新位置，
## 但不保证检测"目标在一个 tick 内高速横穿弹道"（连续路径检测针对炮弹扫掠，
## 不等于双方完整连续碰撞）。

const MAX_ACTIVE := 64          # 活动炮弹上限（含已接收尚未推进的）
const MIN_SEG_M := 1.0e-6       # 近零位移段阈值（不触发零长度射线）
const END_EPS := 1.0e-9         # 寿命/路程端点容差

signal projectile_finished(record: Dictionary)   # 终止记录（一次且完整；先标终止再发出）

var _next_projectile_id := 1
var _active: Dictionary = {}     # projectile_id -> ProjectileState（pending + flying）
var _pending: Array = []         # 已接收尚未开始推进（出生当步不推进）
var _accepted_launches: Dictionary = {}   # "shooter:shot" -> true（duplicate_launch 守卫）
var _shut_down := false                   # 006-R1-B：退出/清理后拒绝新发射
var snapshot_provider := Callable()       # 由 Main 注入：当前车辆快照（每物理步取一次）
var exclude_provider := Callable()        # 由 Main 注入：func(shooter_id, life_id) -> Array[RID]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 100

func _exit_tree() -> void:
	# 006：场景销毁/初始化失败——静默清理（不发出信号；旧回调不得访问已释放对象）
	# 006-R1-B：置关闭位——之后 try_spawn 一律拒绝（manager_shutdown）
	_shut_down = true
	_active.clear()
	_pending.clear()


func active_count() -> int:
	# pending 的 id 同时也在 _active 中（出生当步不推进），不得重复计数
	return _active.size()

func get_projectile_state(projectile_id: int) -> ProjectileState:
	# 006：按 id 读活动飞弹状态（测试/调试用；不持有车辆 Node）
	return _active.get(projectile_id) as ProjectileState

func active_states() -> Array:
	# 006-R1-A：只从 _active 枚举一次（pending 的 id 已在 _active 内，不得重复返回）
	var out: Array = []
	for st in _active.values():
		out.append(st)
	return out


func try_spawn(spec: Dictionary) -> Dictionary:
	# 当前调用中只校验、复制数据、占用容量、加入待推进集合——
	# 不推进、不撞击、不发命中信号。返回 {ok, projectile_id, reason}。
	if _shut_down:
		# 006-R1-B：退出/清理中拒绝新发射（不占容量、不记编号）
		return {"ok": false, "projectile_id": 0, "reason": "manager_shutdown"}
	var tree := get_tree()
	if tree != null and tree.paused:
		# 006-R1-B：暂停期间拒绝新发射（恢复后可发射）
		return {"ok": false, "projectile_id": 0, "reason": "manager_paused"}
	if spec == null or spec.is_empty():
		return {"ok": false, "projectile_id": 0, "reason": "invalid_spawn"}
	var shell_id: String = str(spec.get("shell_id", ""))
	if shell_id.is_empty():
		return {"ok": false, "projectile_id": 0, "reason": "invalid_shell"}
	var shooter_id: String = str(spec.get("shooter_id", ""))
	if shooter_id.is_empty():
		return {"ok": false, "projectile_id": 0, "reason": "invalid_spawn"}
	var shot_id: int = int(spec.get("shot_id", 0))
	if shot_id <= 0:
		return {"ok": false, "projectile_id": 0, "reason": "invalid_spawn"}
	# 006-R1-B：完整发射身份去重（轮次/射手实体/生命周期/射击编号）——
	# 同名新车（新 life_id）的第 1 发不再被旧车同编号挡住；
	# 旧生命周期的重复提交仍被拒绝
	var launch_key := JSON.stringify([
		int(spec.get("round_id", -1)),
		shooter_id,
		int(spec.get("shooter_life_id", 0)),
		shot_id,
	])
	if _accepted_launches.has(launch_key):
		return {"ok": false, "projectile_id": 0, "reason": "duplicate_launch"}
	var pos: Vector3 = spec.get("position_world", Vector3.ZERO)
	var vel: Vector3 = spec.get("velocity_world", Vector3.ZERO)
	var grav: Vector3 = spec.get("gravity_world", Vector3.ZERO)
	var max_age: float = float(spec.get("max_age_s", 0.0))
	var max_dist: float = float(spec.get("max_distance_m", 0.0))
	if not pos.is_finite() or not vel.is_finite() or not grav.is_finite():
		return {"ok": false, "projectile_id": 0, "reason": "invalid_spawn"}
	if not is_finite(max_age) or max_age <= 0.0 or not is_finite(max_dist) or max_dist <= 0.0:
		return {"ok": false, "projectile_id": 0, "reason": "invalid_spawn"}
	if _active.size() >= MAX_ACTIVE:
		return {"ok": false, "projectile_id": 0, "reason": "projectile_capacity"}

	var st := ProjectileState.new()
	st.projectile_id = _next_projectile_id
	_next_projectile_id += 1
	st.round_id = int(spec.get("round_id", -1))
	st.shooter_id = shooter_id
	st.shooter_life_id = int(spec.get("shooter_life_id", 0))
	st.shooter_team_id = int(spec.get("shooter_team_id", 0))
	st.shot_id = shot_id
	st.shell_id = shell_id
	st.seed = int(spec.get("seed", 0))
	st.born_physics_tick = Engine.get_physics_frames()
	st.position_world = pos
	st.previous_position_world = pos
	st.velocity_world = vel
	st.gravity_world = grav
	st.max_age_s = max_age
	st.max_distance_m = max_dist
	st.status = "pending"
	_active[st.projectile_id] = st
	_pending.append(st.projectile_id)
	_accepted_launches[launch_key] = true
	return {"ok": true, "projectile_id": st.projectile_id, "reason": "accepted"}


func _physics_process(delta: float) -> void:
	# 006-R1-A：唯一推进循环内明确检查出生 tick——无论发射发生在管理器之前
	# （正常车辆 priority 0 < 100）还是之后（演示 200 > 100），出生 tick 都不推进。
	var now_tick := Engine.get_physics_frames()
	if _active.is_empty():
		return
	var snapshots: Array = snapshot_provider.call() if snapshot_provider.is_valid() else []
	var space := get_world_3d().direct_space_state
	for pid in _active.keys():
		var st: ProjectileState = _active.get(pid)
		if st == null or st.is_terminal():
			continue
		# 出生 tick 无论在管理器之前还是之后提交，都不能推进
		if now_tick <= st.born_physics_tick:
			continue
		if st.status == "pending":
			st.status = "flying"
			_pending.erase(pid)
		advance_projectile(st, delta, snapshots, space)


func advance_projectile(st: ProjectileState, delta: float, snapshots: Array, space: PhysicsDirectSpaceState3D) -> void:
	# 单发逐段推进：剩余寿命裁短本步 → plan_times → 逐子段
	# （advance_free 求候选终点 → 必要时按剩余路程裁短 → 世界查询 → 车辆几何查询 →
	#   选择器选外部接触 → 按结果推进或终止）。
	if st.is_terminal():
		return
	var step := minf(delta, st.max_age_s - st.age_s)
	if step <= 0.0:
		finish_once(st.projectile_id, "expired_time", {})
		return
	var plan := BallisticMath.plan_times(st.velocity_world, st.gravity_world, step)
	if not plan.get("ok", false):
		finish_once(st.projectile_id, "unresolved_query", {"detail": "plan_times: %s" % str(plan.get("reason", ""))})
		return
	var times: PackedFloat64Array = plan["times"]
	for i in range(times.size() - 1):
		if st.is_terminal():
			return
		var t0 := times[i]
		var t1 := times[i + 1]
		var h := t1 - t0
		if h <= 0.0:
			continue
		var adv := BallisticMath.advance_free(st.position_world, st.velocity_world, st.gravity_world, h)
		if not adv.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "advance_free: %s" % str(adv.get("reason", ""))})
			return
		var cand_p: Vector3 = adv["position"]
		var cand_v: Vector3 = adv["velocity"]
		var seg := cand_p - st.position_world
		var seg_len := seg.length()
		# 近零位移段：不触发零长度射线错误；继续更新时间与速度（转折情况按分段结果处理）
		if seg_len < MIN_SEG_M:
			st.previous_position_world = st.position_world
			st.position_world = cand_p
			st.velocity_world = cand_v
			st.age_s += h
			continue
		var dir := seg / seg_len
		# 006-R1-A：路程裁短统一记账——查询、位置、路程、时间、速度用同一裁短比例
		var remaining := st.max_distance_m - st.travelled_m
		var alpha := minf(1.0, remaining / seg_len)
		var query_len := seg_len * alpha
		var used_h := h * alpha
		var query_end := st.position_world + dir * query_len
		if query_len < MIN_SEG_M:
			# 剩余路程近零：不再按完整子段推进，立即到期终止
			st.travelled_m = st.max_distance_m
			st.age_s += used_h
			finish_once(st.projectile_id, "expired_distance", {})
			return
		# 世界查询（整条裁短后线段；自身排除用发射者 RID）
		var ws := WorldQueryAdapter.query_world_stop(space, st.position_world, dir, query_len, _exclude_for(st))
		var world_contact: Dictionary = ws.get("contact", {}) if ws.get("hit", false) else {}
		if not ws.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "world: %s" % str(ws.get("reason", ""))})
			return
		# 车辆几何查询（同一段；排除发射者实体身份）
		var qr := ShotQueryService.query({
			"query_id": "proj_%d_%d" % [st.projectile_id, Engine.get_physics_frames()],
			"physics_tick": Engine.get_physics_frames(),
			"from_world": st.position_world,
			"to_world": st.position_world + dir * query_len,
			"excluded_instances": [{"entity_id": st.shooter_id, "life_id": st.shooter_life_id}],
			"include_modules": true,
			"include_crew": false,
			"world_stop": world_contact,
		}, snapshots)
		if not qr.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "query: %s" % str(qr.get("reason", ""))})
			return
		var sel := ExternalContactSelector.select_contact(qr)
		var status: String = str(sel.get("status", "unresolved"))
		if status == "vehicle":
			# 停在装甲接触点，生成一次终止记录（模块/乘员不参与本轮外部停止或计分）
			var ev: Dictionary = sel["event"]
			var t_frac := clampf(float(ev.get("t", 0.0)), 0.0, 1.0)
			var contact_time := used_h * t_frac   # 006-R1-A：接触用时按裁短后子段折算
			var impact_p: Vector3 = ev.get("point_world", query_end)
			var impact_v: Vector3 = st.velocity_world + st.gravity_world * contact_time
			st.previous_position_world = st.position_world
			st.position_world = impact_p
			st.velocity_world = impact_v
			st.age_s += contact_time
			st.travelled_m += st.previous_position_world.distance_to(impact_p)
			finish_once(st.projectile_id, "impact_vehicle", {
				"impact_point": impact_p,
				"impact_velocity": impact_v,
				"target_id": str(ev.get("entity_id", "")),
				"target_life_id": int(ev.get("life_id", 0)),
				"surface_id": str(ev.get("surface_id", "")),
			})
			return
		elif status == "world":
			# 停在世界接触点（世界对象只在撞击瞬间查验并反馈，不保存活 collider）。
			# 006-R1-B：先提交终止，再调外部反馈——register_hit 回调里触发重置时
			# 该发已终止、状态已提交，回调不得二次结算或访问未提交状态。
			var ct: Dictionary = sel["contact"]
			var t_frac := clampf(float(ct.get("t", 0.0)), 0.0, 1.0)
			var contact_time := used_h * t_frac   # 006-R1-A：接触用时按裁短后子段折算
			var impact_p: Vector3 = ct.get("point_world", query_end)
			var impact_v: Vector3 = st.velocity_world + st.gravity_world * contact_time
			var collider: Object = ct.get("collider", null)
			st.previous_position_world = st.position_world
			st.position_world = impact_p
			st.velocity_world = impact_v
			st.age_s += contact_time
			st.travelled_m += st.previous_position_world.distance_to(impact_p)
			finish_once(st.projectile_id, "impact_world", {
				"impact_point": impact_p,
				"impact_velocity": impact_v,
				"surface_id": "world_contact",
			})
			if collider != null and is_instance_valid(collider) and collider.has_method("register_hit"):
				collider.register_hit({})
			return
		elif status == "unresolved":
			# 不完整查询 → 停止模拟，标记未决，不计命中，不假装飞过
			finish_once(st.projectile_id, "unresolved_query", {"detail": "selector unresolved"})
			return
		# miss：接受该段运动结果（006-R1-A：按裁短比例记账，不用未裁短子段）
		st.previous_position_world = st.position_world
		st.position_world = query_end
		st.velocity_world = st.velocity_world + st.gravity_world * used_h
		st.age_s += used_h
		st.travelled_m += query_len
		if alpha < 1.0:
			# 已到路程上限（本段被裁短且无接触）→ 到期终止（位置/路程/时间一致）
			finish_once(st.projectile_id, "expired_distance", {})
			return
	# 本步结束：寿命/路程端点（接触恰好位于端点时已在上面的接触分支处理）
	if st.age_s >= st.max_age_s - END_EPS:
		finish_once(st.projectile_id, "expired_time", {})
	elif st.travelled_m >= st.max_distance_m - END_EPS:
		finish_once(st.projectile_id, "expired_distance", {})


func _exclude_for(st: ProjectileState) -> Array[RID]:
	if exclude_provider.is_valid():
		return exclude_provider.call(st.shooter_id, st.shooter_life_id)
	return []


func finish_once(projectile_id: int, reason: String, terminal_data: Dictionary) -> void:
	# 必须先标终止、移出活动集合，再通知监听者——命中监听者触发重置时，
	# 不会把同一发再结算一次。
	var st: ProjectileState = _active.get(projectile_id)
	if st == null or st.is_terminal():
		return
	st.status = "terminal"
	st.terminal_reason = reason
	_active.erase(projectile_id)
	_pending.erase(projectile_id)
	var record: Dictionary = {
		"projectile_id": st.projectile_id,
		"round_id": st.round_id,
		"shooter_id": st.shooter_id,
		"shooter_life_id": st.shooter_life_id,
		"shooter_team_id": st.shooter_team_id,
		"shot_id": st.shot_id,
		"shell_id": st.shell_id,
		"reason": reason,
		"flight_time_s": st.age_s,
		"travelled_m": st.travelled_m,
		"impact_point": terminal_data.get("impact_point", st.position_world),
		"impact_velocity": terminal_data.get("impact_velocity", st.velocity_world),
		"target_id": terminal_data.get("target_id", ""),
		"target_life_id": terminal_data.get("target_life_id", 0),
		"surface_id": terminal_data.get("surface_id", ""),
		"query_id": "proj_%d" % st.projectile_id,
		"physics_tick": Engine.get_physics_frames(),
	}
	projectile_finished.emit(record)


func cancel_all(reason: String) -> void:
	# 整场重开/场景切换：先取消全部活动与待推进飞弹（不产生命中事件）
	for pid in _active.keys():
		finish_once(pid, reason, {})
	_active.clear()
	_pending.clear()


func cancel_by_shooter(shooter_id: String, shooter_life_id: int, reason: String) -> void:
	# 单车重置：只取消该车发出的飞弹；不取消其他车辆的飞弹
	for pid in _active.keys():
		var st: ProjectileState = _active.get(pid)
		if st != null and st.shooter_id == shooter_id and st.shooter_life_id == shooter_life_id:
			finish_once(pid, reason, {})
