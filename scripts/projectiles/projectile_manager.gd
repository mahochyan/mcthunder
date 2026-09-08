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
signal projectile_contact(record: Dictionary)
signal projectile_damage(record: Dictionary)
signal shot_record_ready(record: Dictionary)
signal shot_records_cleared
var shot_records := ShotRecordStore.new()
var _record_epoch := 0
var _notifying_record_clear := false
var damage_handler := Callable() # Non-notifying commit to the matching live target's state.
var contact_policy := Callable() # Optional match-specific friendly/protection stop, before armor or external modules.

var _next_projectile_id := 1
var _active: Dictionary = {}     # projectile_id -> ProjectileState（pending + flying）
var _pending: Array = []         # 已接收尚未开始推进（出生当步不推进）
var _accepted_launches: Dictionary = {}   # "shooter:shot" -> true（duplicate_launch 守卫）
var _shut_down := false                   # 006-R1-B：退出/清理后拒绝新发射

func close_round() -> void:
	# A finished battle retains immutable replay records but rejects every later launch.
	_shut_down = true
	_cancel_depth += 1
	for pid in _active.keys(): finish_once(int(pid),"cancelled_match_finished",{})
	_cancel_depth -= 1
var _cancel_depth := 0                    # 006-R1 有限收尾：取消过程深度（嵌套取消不提前开放）
var snapshot_provider := Callable()       # 由 Main 注入：当前车辆快照（每物理步取一次）
var exclude_provider := Callable()        # 由 Main 注入：func(shooter_id, life_id) -> Array[RID]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 100

func _exit_tree() -> void:
	# 006：场景销毁/初始化失败——静默清理（不发出信号；旧回调不得访问已释放对象）
	# 006-R1-B：置关闭位——之后 try_spawn 一律拒绝（manager_shutdown）
	_shut_down = true
	shot_records.clear()
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
	# 生命周期守卫在任何占容量、记录发射身份、生成 projectile_id 之前。
	if _shut_down or not is_inside_tree() or is_queued_for_deletion():
		# 006-R1-B：退出/清理中拒绝新发射（不占容量、不记编号）
		return {"ok": false, "projectile_id": 0, "reason": "manager_shutdown"}
	if _cancel_depth > 0:
		# 006-R1 有限收尾：取消过程中拒绝新发射（同步回调重入同样拒绝）——
		# 否则 cancel_all 末尾清空会把已接收的新弹无声删除（无终止记录、去重键已占），
		# cancel_by_shooter 则把新弹遗留。嵌套取消期间深度不归零；
		# 清理返回后同一请求正常接受。
		return {"ok": false, "projectile_id": 0, "reason": "manager_clearing"}
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
	var armor_policy := str(spec.get("armor_policy", "resolve"))
	var curve: PackedVector2Array = spec.get("penetration_curve", PackedVector2Array())
	if armor_policy not in ["resolve", "legacy_contact_only"] \
			or (armor_policy == "resolve" and not PenetrationCurve.validate(curve)) \
			or (armor_policy == "legacy_contact_only" and not spec.get("test_only", false)):
		return {"ok": false, "projectile_id": 0, "reason": "invalid_armor_policy"}

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
	st.armor_policy = armor_policy
	st.penetration_curve = curve.duplicate()
	st.born_physics_tick = Engine.get_physics_frames()
	st.position_world = pos
	st.previous_position_world = pos
	st.velocity_world = vel
	st.launch_position = pos
	st.launch_velocity = vel
	st.gravity_world = grav
	st.max_age_s = max_age
	st.max_distance_m = max_dist
	st.status = "pending"
	ShotRecordBuilder.sample_path(st)
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
	if not _live(st):
		return
	if not is_finite(delta) or delta < 0.0:
		finish_once(st.projectile_id, "unresolved_query", {"detail": "invalid delta"})
		return
	var remaining_dt := minf(delta, st.max_age_s - st.age_s)
	if remaining_dt <= 0.0:
		finish_once(st.projectile_id, "expired_time", {})
		return
	var pending_h: Array[float] = []
	var step_contacts := 0
	while remaining_dt > BallisticMath.TIME_EPS and _live(st):
		if pending_h.is_empty():
			var plan := BallisticMath.plan_times(st.velocity_world, st.gravity_world, remaining_dt)
			if not plan.get("ok", false):
				finish_once(st.projectile_id, "unresolved_query", {"detail": str(plan.get("reason", ""))})
				return
			var times: PackedFloat64Array = plan.times
			for i in range(times.size() - 1):
				pending_h.append(times[i + 1] - times[i])
		var h: float = pending_h.pop_front()
		var adv := BallisticMath.advance_free(st.position_world, st.velocity_world, st.gravity_world, h)
		if not adv.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": str(adv.get("reason", ""))})
			return
		var cand_p: Vector3 = adv.position
		var seg := cand_p - st.position_world
		var seg_len := seg.length()
		if seg_len < MIN_SEG_M:
			st.previous_position_world = st.position_world
			st.position_world = cand_p
			st.velocity_world = adv.velocity
			st.age_s += h
			st.travelled_m += seg_len
			ShotRecordBuilder.sample_path(st)
			remaining_dt -= h
			continue
		var dir := seg / seg_len
		var remaining_distance := maxf(0.0, st.max_distance_m - st.travelled_m)
		var alpha := minf(1.0, remaining_distance / seg_len)
		var query_len := seg_len * alpha
		var used_h := h * alpha
		var query_end := st.position_world + dir * query_len
		if query_len < MIN_SEG_M:
			st.travelled_m = st.max_distance_m
			st.age_s += used_h
			finish_once(st.projectile_id, "expired_distance", {})
			return
		var ws := WorldQueryAdapter.query_world_stop(space, st.position_world, dir, query_len, _exclude_for(st))
		if not ws.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "world query"})
			return
		var world_contact: Dictionary = ws.get("contact", {}) if ws.get("hit", false) else {}
		var qr := ShotQueryService.query({
			"query_id": "proj_%d_%d" % [st.projectile_id, Engine.get_physics_frames()],
			"physics_tick": Engine.get_physics_frames(),
			"from_world": st.position_world, "to_world": query_end,
			"excluded_instances": [{"entity_id": st.shooter_id, "life_id": st.shooter_life_id}],
			"include_modules": true, "include_crew": st.armor_policy == "resolve", "world_stop": world_contact,
		}, snapshots)
		if not qr.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "geometry query"})
			return
		# Only suppress already processed surfaces at this exact starting point.
		# Co-located other surfaces remain candidates; never exclude an entire target.
		var filtered: Array = []
		for ev in qr.get("events", []):
			var key := _surface_key(ev)
			if st.start_surfaces.has(key) and float(ev.get("distance_m", INF)) <= GameConfig.ARMOR_START_EPS_M \
					and (ev.get("point_world", Vector3.INF) as Vector3).distance_to(st.start_surfaces[key]) <= GameConfig.ARMOR_START_EPS_M:
				continue
			filtered.append(ev)
		qr.events = filtered
		var sel := ExternalContactSelector.select_contact(qr)
		var status := str(sel.get("status", "unresolved"))
		if st.armor_policy == "resolve" and status != "unresolved":
			var boundary := INF
			if status == "vehicle":
				boundary = float(sel.event.distance_m)
			elif status == "world":
				boundary = float(sel.contact.distance_m)
			var damage_contact := DamageResolver.next_contact(qr,st.interior_targets,st.damage_seen,boundary)
			if not damage_contact.is_empty():
				status = "damage"
				sel.event = damage_contact
		if status in ["vehicle", "world", "damage"]:
			var ev: Dictionary = sel.contact if status == "world" else sel.event
			var t_frac := clampf(float(ev.get("t", 0.0)), 0.0, 1.0)
			var contact_time := used_h * t_frac
			var impact_p: Vector3 = ev.get("point_world", query_end)
			st.previous_position_world = st.position_world
			st.position_world = impact_p
			st.velocity_world += st.gravity_world * contact_time
			st.age_s += contact_time
			st.travelled_m += st.previous_position_world.distance_to(impact_p)
			ShotRecordBuilder.sample_path(st)
			if status in ["vehicle","damage"]:
				ev["geometry_frame"] = ShotRecordBuilder.capture_frame(st,ev,snapshots)
				if contact_policy.is_valid():
					var policy: Dictionary = contact_policy.call({"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shooter_team_id":st.shooter_team_id},ev.duplicate(true))
					if not _live(st): return
					if not policy.get("allow",false):
						finish_once(st.projectile_id,str(policy.get("reason","blocked_by_rules")),{"target_id":ev.get("entity_id",""),"target_life_id":ev.get("life_id",0),"surface_id":ev.get("surface_id",ev.get("module_id",""))})
						return
			remaining_dt = maxf(0.0, remaining_dt - contact_time)
			if status == "world":
				var collider: Object = ev.get("collider", null)
				finish_once(st.projectile_id, "impact_world", {"surface_id": "world_contact"})
				if collider != null and is_instance_valid(collider) and collider.has_method("register_hit"):
					collider.register_hit({})
				return
			if status == "damage":
				if not handle_damage_contact(st,ev):
					return
				pending_h.clear()
				continue
			if step_contacts >= GameConfig.ARMOR_CONTACTS_PER_STEP or st.contacts.size() >= GameConfig.ARMOR_CONTACTS_PER_SHOT:
				finish_once(st.projectile_id, "contact_budget", {"detail": "bounded contact limit"})
				return
			step_contacts += 1
			if not handle_contact(st, ev):
				return
			pending_h.clear() # Replan remaining time with reflected/current velocity.
			continue
		if status == "unresolved":
			finish_once(st.projectile_id, "unresolved_query", {"detail": "incomplete geometry"})
			return
		st.previous_position_world = st.position_world
		st.position_world = query_end
		st.velocity_world += st.gravity_world * used_h
		st.age_s += used_h
		st.travelled_m += query_len
		ShotRecordBuilder.sample_path(st)
		remaining_dt -= used_h
		if alpha < 1.0:
			finish_once(st.projectile_id, "expired_distance", {})
			return
	if not _live(st):
		return
	if st.age_s >= st.max_age_s - END_EPS:
		finish_once(st.projectile_id, "expired_time", {})
	elif st.travelled_m >= st.max_distance_m - END_EPS:
		finish_once(st.projectile_id, "expired_distance", {})


func _live(st: ProjectileState) -> bool:
	return not _shut_down and not is_queued_for_deletion() and not st.is_terminal() \
		and _active.get(st.projectile_id) == st


static func _surface_key(event: Dictionary) -> String:
	return JSON.stringify([event.get("entity_id", ""), event.get("life_id", 0), event.get("part_id", ""), event.get("surface_id", "")])


func handle_contact(st: ProjectileState, ev: Dictionary) -> bool:
	var incoming_velocity := st.velocity_world
	var result := {"result": "legacy_contact_only", "continue_flight": false}
	if st.armor_policy == "resolve":
		result = ArmorResolver.resolve(ev, st.velocity_world, {
			"base_mm": PenetrationCurve.sample_mm(st.penetration_curve, st.travelled_m),
			"scale": st.budget_scale, "consumed_mm": st.consumed_mm, "ricochets": st.ricochets,
		})
		st.budget_scale = result.scale
		st.consumed_mm = result.consumed_mm
		st.ricochets = result.ricochets
		if result.result == "ricochet":
			st.velocity_world = result.direction * st.velocity_world.length() * float(result.speed_scale)
		if result.result == "penetrated":
			st.interior_targets[DamageResolver.target_key(ev)] = not bool(result.backface)
	# Prune only surfaces left behind. Multiple surfaces at the same point each cost once.
	for key in st.start_surfaces.keys():
		if st.position_world.distance_to(st.start_surfaces[key]) > GameConfig.ARMOR_START_EPS_M:
			st.start_surfaces.erase(key)
	st.start_surfaces[_surface_key(ev)] = st.position_world
	var target_key := JSON.stringify([ev.get("entity_id", ""), ev.get("life_id", 0)])
	var first_for_target := not st.contacted_targets.has(target_key)
	st.contacted_targets[target_key] = true
	var record := ev.duplicate(true)
	record.merge(result, true)
	record.merge({
		"projectile_id": st.projectile_id, "round_id": st.round_id, "shot_id": st.shot_id,
		"shooter_id": st.shooter_id, "shooter_life_id": st.shooter_life_id,
		"target_id": ev.get("entity_id", ""), "target_life_id": ev.get("life_id", 0),
		"shell_id": st.shell_id, "contact_index": st.contacts.size() + 1,
		"first_for_target": first_for_target, "armor_policy": st.armor_policy,
		"flight_time_s": st.age_s, "travelled_m": st.travelled_m,
		"impact_point": st.position_world, "impact_velocity": incoming_velocity,
		"incoming_velocity": incoming_velocity, "outgoing_velocity": st.velocity_world,
		"physics_tick": Engine.get_physics_frames(),
	}, true)
	st.contacts.append(record.duplicate(true))
	projectile_contact.emit(record.duplicate(true))
	# A synchronous listener may cancel/reset/free this manager. Never resurrect the shot.
	if not _live(st):
		return false
	if not result.get("continue_flight", false):
		var reason := "impact_vehicle" if st.armor_policy == "legacy_contact_only" else "armor_" + str(result.result)
		finish_once(st.projectile_id, reason, {
			"target_id": ev.get("entity_id", ""), "target_life_id": ev.get("life_id", 0),
			"surface_id": ev.get("surface_id", ""),
		})
		return false
	return true

func handle_damage_contact(st: ProjectileState, ev: Dictionary) -> bool:
	if not damage_handler.is_valid() or st.damage_records.size() >= GameConfig.DAMAGE_MAX_CONTACTS:
		finish_once(st.projectile_id,"unresolved_damage",{"detail":"missing handler or damage budget"})
		return false
	var before := maxf(0,st.budget_scale * PenetrationCurve.sample_mm(st.penetration_curve,st.travelled_m) - st.consumed_mm)
	if before <= 0:
		finish_once(st.projectile_id,"damage_budget_exhausted",{})
		return false
	var event := ev.duplicate(true)
	event.merge({
		"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,
		"shot_id":st.shot_id,"projectile_id":st.projectile_id,
		"event_id":JSON.stringify([st.round_id,st.shooter_id,st.shooter_life_id,st.shot_id,st.projectile_id,DamageResolver.item_key(ev)]),
	},true)
	var delta: Dictionary = damage_handler.call(event,before)
	if not _live(st):
		return false
	if not delta.get("ok",false):
		finish_once(st.projectile_id,"unresolved_damage",{"detail":delta.get("reason","")})
		return false
	var spent := float(delta.get("consumed_mm",0))
	if not is_finite(spent) or spent < 0 or spent > before + 1e-5:
		finish_once(st.projectile_id,"unresolved_damage",{"detail":"invalid damage budget"})
		return false
	st.consumed_mm += spent
	st.damage_seen[DamageResolver.item_key(ev)] = true
	event.merge(delta,true)
	event.merge({
		"target_id":ev.get("entity_id",""),"target_life_id":ev.get("life_id",0),
		"damage_index":st.damage_records.size()+1,"flight_time_s":st.age_s,"travelled_m":st.travelled_m,
		"before_mm":before,"after_mm":maxf(0,before-spent),
		"impact_point":st.position_world,"impact_velocity":st.velocity_world,
		"rules_version":GameConfig.DAMAGE_RULES_VERSION,"physics_tick":Engine.get_physics_frames(),
	},true)
	st.damage_records.append(event.duplicate(true))
	projectile_damage.emit(event.duplicate(true))
	if not _live(st):
		return false
	if before - spent <= 1e-5:
		finish_once(st.projectile_id,"damage_budget_exhausted",{})
		return false
	return true



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
	record["detail"] = terminal_data.get("detail", "")
	record["armor_policy"] = st.armor_policy
	record["contacts"] = st.contacts.duplicate(true)
	record["damage_records"] = st.damage_records.duplicate(true)
	record["rules_version"] = GameConfig.ARMOR_RULES_VERSION
	ShotRecordBuilder.sample_path(st)
	var replay_record: Dictionary = {}
	var record_epoch := _record_epoch
	if not reason.begins_with("cancelled"):
		replay_record = ShotRecordBuilder.freeze(st,record)
		var stored := shot_records.push_bounded(replay_record)
		if not stored.ok:
			replay_record = {} # Invalid data cannot become an invented replay.
	projectile_finished.emit(record)
	if not replay_record.is_empty() and record_epoch == _record_epoch and not _shut_down and not is_queued_for_deletion():
		shot_record_ready.emit(replay_record)

func clear_records() -> void:
	_record_epoch += 1
	shot_records.clear()
	if not _notifying_record_clear:
		_notifying_record_clear = true
		shot_records_cleared.emit()
		_notifying_record_clear = false


func cancel_all(reason: String) -> void:
	# 整场重开/场景切换：先取消全部活动与待推进飞弹（不产生命中事件）。
	# 006-R1 有限收尾：清理期间设深度门——finish_once 的同步回调内 try_spawn
	# 被拒（manager_clearing）；不再用末尾 _active.clear()/_pending.clear() 兜底
	# （finish_once 已逐发移除，清理期间也不接收新发射）。
	_cancel_depth += 1
	clear_records()
	var ids := _active.keys()
	for pid in ids:
		finish_once(int(pid), reason, {})
	_cancel_depth -= 1


func cancel_by_shooter(shooter_id: String, shooter_life_id: int, reason: String) -> void:
	# 单车重置：只取消该车发出的飞弹；不取消其他车辆的飞弹。
	# 006-R1 有限收尾：与 cancel_all 同一深度门（回调内新发射被拒）。
	_cancel_depth += 1
	clear_records()
	var ids := _active.keys()
	for pid in ids:
		var st: ProjectileState = _active.get(pid)
		if st != null and st.shooter_id == shooter_id and st.shooter_life_id == shooter_life_id:
			finish_once(int(pid), reason, {})
	_cancel_depth -= 1
