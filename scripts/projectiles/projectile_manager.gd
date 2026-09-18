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
## 相邻权威快照中 basis 不变且平移有界的部件使用相对运动扫掠。
## 旋转、超界位移或不连续身份仍按步末静态几何查询；这不是完整体积 CCD。
## 本批仅 kinetic 使用平移扫掠；internal_burst 的接触/内部路径/破片统一
## 保留原步末静态几何，避免接触时刻与内部效应混用不同姿态。

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
var armor_handler := Callable() # Atomic reactive armor resolution on the matching live actor.
var damage_handler := Callable() # Non-notifying commit to the matching live target's state.
var contact_policy := Callable() # Optional match-specific friendly/protection stop, before armor or external modules.

var _next_projectile_id := 1
var feedback: CombatFeedback
var presentation_enabled := true
var _active: Dictionary = {}     # projectile_id -> ProjectileState（pending + flying）
var _pending: Array = []         # 已接收尚未开始推进（出生当步不推进）
var _accepted_launches: Dictionary = {}   # "shooter:shot" -> true（duplicate_launch 守卫）
var _shut_down := false                   # 006-R1-B：退出/清理后拒绝新发射
var _previous_snapshots: Array = []
var _snapshot_tick := -1

func close_round() -> void:
	# A finished battle retains immutable replay records but rejects every later launch.
	_shut_down = true
	if feedback!=null: feedback.audio.stop_loops()
	_cancel_depth += 1
	for pid in _active.keys(): finish_once(int(pid),"cancelled_match_finished",{})
	_cancel_depth -= 1
var _cancel_depth := 0                    # 006-R1 有限收尾：取消过程深度（嵌套取消不提前开放）
var snapshot_provider := Callable()       # 由 Main 注入：当前车辆快照（每物理步取一次）
var exclude_provider := Callable()        # 由 Main 注入：func(shooter_id, life_id) -> Array[RID]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = SimulationPhases.PROJECTILES
	if presentation_enabled:
		feedback=CombatFeedback.new(); feedback.name="CombatFeedback"; add_child(feedback)

func _exit_tree() -> void:
	# 006：场景销毁/初始化失败——静默清理（不发出信号；旧回调不得访问已释放对象）
	# 006-R1-B：置关闭位——之后 try_spawn 一律拒绝（manager_shutdown）
	_shut_down = true
	shot_records.clear()
	_active.clear()
	_pending.clear()
	_previous_snapshots.clear()


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
	var effect_policy := str(spec.get("effect_policy","kinetic"))
	if effect_policy not in ["kinetic","internal_burst","long_rod","chemical","he_blast"] or (effect_policy in ["internal_burst","long_rod","chemical"] and armor_policy != "resolve"):
		return {"ok":false,"projectile_id":0,"reason":"invalid_effect_policy"}
	var curve: PackedVector2Array = spec.get("penetration_curve", PackedVector2Array())
	var fuze: Variant = spec.get("fuze_policy", {})
	if not ShellFuze.validate(fuze, effect_policy).is_empty():
		return {"ok":false,"projectile_id":0,"reason":"invalid_fuze_policy"}
	if not fuze.is_empty() and not is_finite(max_age + float(fuze.delay_s)):
		return {"ok":false,"projectile_id":0,"reason":"invalid_fuze_policy"}
	# CD003: an ENGINEERING round declares its finite cross-section through the spec. A declaration that cannot be resolved
	# REFUSES the launch by name instead of quietly falling back to the v1 line rule; a round that declares nothing is a
	# LEGACY line round and the state records that explicitly, so the fallback is visible rather than silent.
	var shape_sampling: Dictionary = {}
	var shape_source := "legacy_line"
	if spec.has("shape_profile") or spec.has("shape_kind"):
		var resolved := ProjectileShapeProfile.resolve(spec)
		if not resolved.get("ok",false):
			return {"ok":false,"projectile_id":0,"reason":str(resolved.get("reason","no_shape_profile"))}
		shape_sampling = resolved.get("sampling",{})
		shape_source = str(resolved.get("source","project_engineering_profile"))
	elif spec.has("section_radius_m"):
		var raw_radius := float(spec.get("section_radius_m",0.0))
		var raw_rays := int(spec.get("section_rays",0))
		if not is_finite(raw_radius) or raw_radius <= 0.0 or raw_rays < 3:
			return {"ok":false,"projectile_id":0,"reason":"invalid_shape_section"}
		shape_sampling = {"section_radius_m":raw_radius,"rays":raw_rays,"error_bound_m":INF,"exact":false,
			"note":"explicit raw section with no declared error bound"}
		shape_source = "explicit_section"
	if armor_policy not in ["resolve", "legacy_contact_only"] \
			or (armor_policy == "resolve" and not PenetrationCurve.validate(curve)) \
			or (armor_policy == "legacy_contact_only" and not spec.get("test_only", false)):
		return {"ok": false, "projectile_id": 0, "reason": "invalid_armor_policy"}

	var st := ProjectileState.new()
	var impact: Variant = spec.get("impact_profile", {})
	if not ArmorImpactProfile.validate(impact, effect_policy).is_empty():
		return {"ok":false,"projectile_id":0,"reason":"invalid_impact_profile"}
	var caliber: Variant = spec.get("caliber_mm", 0.0)
	if not impact.is_empty() and (not (caliber is float or caliber is int) or not is_finite(float(caliber)) or float(caliber)<=0.0):
		return {"ok":false,"projectile_id":0,"reason":"invalid_impact_caliber"}
	st.impact_profile = impact.duplicate(true)
	var post: Variant=spec.get("post_penetration_profile",{})
	if not SpallProfile.validate(post,effect_policy).is_empty(): return {"ok":false,"projectile_id":0,"reason":"invalid_post_penetration_profile"}
	st.post_penetration_profile=post.duplicate(true)
	var chemical: Variant=spec.get("chemical_profile",{})
	if not ChemicalProfile.validate(chemical,effect_policy).is_empty() or not ChemicalProfile.matches_curve(chemical,curve): return {"ok":false,"projectile_id":0,"reason":"invalid_chemical_profile"}
	st.chemical_profile=chemical.duplicate(true)
	st.caliber_mm = float(caliber) if caliber is float or caliber is int else 0.0
	st.effect_policy = effect_policy
	st.fuze_policy = fuze.duplicate(true)
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
	st.shape_sampling = shape_sampling.duplicate(true)
	st.shape_source = shape_source
	st.penetration_curve = curve.duplicate()
	st.born_physics_tick = Engine.get_physics_frames()
	st.position_world = pos
	st.previous_position_world = pos
	st.velocity_world = vel
	st.launch_position = pos
	st.launch_velocity = vel
	st.gravity_world = grav
	# CD004 design point 1: the drag coefficient travels with the frozen launch state. Absent means 0, the legacy curve.
	st.drag_k_per_m = float(spec.get("drag_k_per_m",0.0))
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
	# Sample after authority vehicle mechanisms even when no projectile exists,
	# so the first advancing flight tick has the correct beginning target pose.
	var current: Array = snapshot_provider.call() if snapshot_provider.is_valid() else []
	var snapshots := TranslationSweep.bind(_previous_snapshots, current, _snapshot_tick == now_tick - 1, delta)
	_previous_snapshots = current.duplicate(true)
	_snapshot_tick = now_tick
	if _active.is_empty():
		return
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
	if st.effect_policy == "internal_burst":
		# Its inside-path and fragments are still instantaneous static rules.
		# Continuous motion must not be enabled for just one half of that path.
		snapshots = TranslationSweep.frame_at(snapshots, 1.0)
	if not is_finite(delta) or delta < 0.0:
		finish_once(st.projectile_id, "unresolved_query", {"detail": "invalid delta"})
		return
	if delta == 0.0: return
	var remaining_dt := minf(delta, st.max_age_s - st.age_s)
	if st.fuze_resting and not st.fuze_rest_target.is_empty():
		var carrier := ShellEffectPolicy.target_snapshot(st.fuze_rest_target, snapshots)
		var part_id := str(st.fuze_rest_target.get("part_id", ""))
		if not carrier.is_empty() and carrier.get("part_world_transforms", {}).has(part_id):
			st.previous_position_world = st.position_world
			st.position_world = carrier.part_world_transforms[part_id] * st.fuze_rest_local
	var age_at_start := st.age_s
	if remaining_dt <= 0.0:
		finish_once(st.projectile_id, "expired_time", {})
		return
	var pending_h: Array[float] = []
	var step_contacts := 0
	while remaining_dt > BallisticMath.TIME_EPS and _live(st):
		if _detonate_due_fuze(st, snapshots, space): return
		var acceleration := st.acceleration_world()
		if pending_h.is_empty():
			var plan := BallisticMath.plan_times(st.velocity_world, acceleration, remaining_dt)
			if not plan.get("ok", false):
				finish_once(st.projectile_id, "unresolved_query", {"detail": str(plan.get("reason", ""))})
				return
			var times: PackedFloat64Array = plan.times
			for i in range(times.size() - 1):
				pending_h.append(times[i + 1] - times[i])
		var h: float = pending_h.pop_front()
		if st.fuze_due_age_s >= 0.0:
			h = minf(h, maxf(0.0, st.fuze_due_age_s - st.age_s))
			pending_h.clear() # Replan the unconsumed remainder after an exact timer boundary.
		var adv := BallisticMath.advance_profile(st.position_world, st.velocity_world, acceleration, st.drag_k_per_m, h)
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
			"motion_fraction": Vector2(clampf((st.age_s - age_at_start) / delta, 0.0, 1.0), clampf((st.age_s - age_at_start + used_h) / delta, 0.0, 1.0)),
			"excluded_instances": [{"entity_id": st.shooter_id, "life_id": st.shooter_life_id}],
			"include_modules": true, "include_crew": st.armor_policy == "resolve", "world_stop": world_contact,
			"shape_section": (st.shape_sampling if not st.shape_sampling.is_empty() else {}),
		}, snapshots)
		if not qr.get("ok", false):
			finish_once(st.projectile_id, "unresolved_query", {"detail": "geometry query"})
			return
		# Only suppress already processed surfaces at this exact starting point.
		# Co-located other surfaces remain candidates; never exclude an entire target.
		# CD02-T03 / TerminalResponseV2 invariant: re-sampling the SAME plate at the SAME crossing must not debit it a
		# second time. A denser triangulation added a small second charge on the mantlet that never reached the contact
		# list, which shifted every later layer's entry budget by exactly that amount - measured as one hundred and ten
		# millimetres of implied accumulation against one hundred. A genuine re-entry after leaving a plate happens
		# metres away, so comparing the crossing distance keeps that case alive while dropping the duplicate triangles.
		var crossed: Dictionary = {}
		for row in st.contacts:
			crossed[str(row.get("surface_id",""))] = float(row.get("distance_m",INF))
		var filtered: Array = []
		for ev in qr.get("events", []):
			var key := _surface_key(ev)
			if st.start_surfaces.has(key) and float(ev.get("distance_m", INF)) <= GameConfig.ARMOR_START_EPS_M \
					and (ev.get("point_world", Vector3.INF) as Vector3).distance_to(st.start_surfaces[key]) <= GameConfig.ARMOR_START_EPS_M:
				continue
			var crossed_surface := str(ev.get("surface_id",""))
			if not crossed_surface.is_empty() and crossed.has(crossed_surface) \
					and absf(float(ev.get("distance_m",INF)) - float(crossed[crossed_surface])) <= GameConfig.ARMOR_START_EPS_M:
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
			# CD01-T06: an ammunition occupancy that the snapshot does not carry is unknown, not empty. When the target
			# declares ammunition modules but the snapshot omits their occupancy, the shot is finished as an explicit
			# incomplete result instead of being answered from an assumed empty or assumed full rack.
			var target_snapshot := {}
			for candidate in snapshots:
				if str(candidate.get("entity_id",""))==str(sel.event.get("entity_id","")) \
						and int(candidate.get("life_id",-1))==int(sel.event.get("life_id",-1)):
					target_snapshot = candidate
					break
			if not target_snapshot.has("ammo_contents") and _declares_ammo_modules(target_snapshot):
				finish_once(st.projectile_id,"ammo_occupancy_unknown",{"detail":"the query snapshot carries no ammunition occupancy for a target that declares ammunition modules"})
				return
			var occupancy: Dictionary = target_snapshot.get("ammo_contents",{})
			var damage_contact := DamageResolver.next_contact(qr,st.interior_targets,st.damage_seen,boundary,occupancy)
			if not damage_contact.is_empty():
				status = "damage"
				sel.event = damage_contact
		if status != "unresolved" and st.fuze_policy.is_empty() and not st.burst_target.is_empty():
			var boundary := query_len+ShellEffectPolicy.EPS
			if status in ["vehicle","damage"]: boundary = float(sel.event.distance_m)
			elif status == "world": boundary = float(sel.contact.distance_m)
			var contact_fraction := clampf(boundary/maxf(query_len,ShellEffectPolicy.EPS),0.0,1.0)
			var effect := ShellEffectPolicy.on_inside_path(st,snapshots,dir,query_len,contact_fraction)
			if not effect.is_empty() and float(effect.distance_m) < boundary:
				status = "burst" if effect.kind == "burst" else ("effect_entry" if effect.kind == "entry" else "effect_exit")
				sel.event = {"t":float(effect.distance_m)/query_len,"point_world":st.position_world+dir*float(effect.distance_m)}
		if status in ["vehicle", "world", "damage", "burst", "effect_exit", "effect_entry"]:
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
				var impact_snapshots := snapshots
				if ev.has("motion_fraction"):
					impact_snapshots = TranslationSweep.frame_at(snapshots, float(ev.motion_fraction))
				ev["geometry_frame"] = ShotRecordBuilder.capture_frame(st,ev,impact_snapshots)
				if contact_policy.is_valid():
					var policy: Dictionary = contact_policy.call({"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shooter_team_id":st.shooter_team_id},ev.duplicate(true))
					if not _live(st): return
					if not policy.get("allow",false):
						finish_once(st.projectile_id,str(policy.get("reason","blocked_by_rules")),{"target_id":ev.get("entity_id",""),"target_life_id":ev.get("life_id",0),"surface_id":ev.get("surface_id",ev.get("module_id",""))})
						return
			remaining_dt = maxf(0.0, remaining_dt - contact_time)
			if st.effect_policy=="chemical" and status in ["vehicle","world","damage"]:
				var chemical_snapshots := TranslationSweep.frame_at(snapshots,float(ev.get("motion_fraction",1.0)))
				ChemicalJetSystem.emit(st,ev,status,chemical_snapshots,space,_exclude_for(st),Callable(self,"_commit_damage_event"),Callable(self,"record_chemical_armor"),contact_policy,Callable(self,"_live"),Callable(self,"resolve_armor"))
				if _live(st): finish_once(st.projectile_id,"chemical_detonation",{"target_id":ev.get("entity_id",""),"target_life_id":ev.get("life_id",0)})
				return
			if status == "effect_entry":
				st.burst_inside_started=true; st.burst_entry_distance=st.travelled_m; pending_h.clear(); continue
			if status == "effect_exit":
				st.burst_target.clear(); pending_h.clear(); continue
			if status == "burst":
				_emit_internal_burst(st,snapshots,space)
				return
			if status == "world":
				var collider: Object = ev.get("collider", null)
				var world_damage: Dictionary = {}
				if collider is DestructibleSection:
					world_damage = collider.apply_shell_impact({"manager_id":get_instance_id(),"projectile_id":st.projectile_id,
						"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,
						"shot_id":st.shot_id,"point":st.position_world,"velocity":st.velocity_world})
				var waiting := _rest_for_fuze(st, {}, "impact_world")
				if not waiting: finish_once(st.projectile_id, "impact_world", {"surface_id": "world_contact","world_damage":world_damage})
				if collider != null and is_instance_valid(collider) and collider.has_method("register_hit"):
					collider.register_hit({})
				if not waiting: return
				pending_h.clear()
				continue
			if status == "damage":
				if st.fuze_due_age_s >= 0.0:
					var damaged := ShellEffectPolicy.target_snapshot(ev, snapshots)
					if damaged.get("part_world_transforms", {}).has(ev.get("part_id", "")):
						ev["part_world_transform"] = damaged.part_world_transforms[ev.part_id]
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
			if not st.post_penetration_profile.is_empty():
				var spall_snapshots := TranslationSweep.frame_at(snapshots,float(ev.get("motion_fraction",1.0)))
				_emit_spall(st,ev,spall_snapshots,space)
				if not _live(st): return
			pending_h.clear() # Replan remaining time with reflected/current velocity.
			continue
		if status == "unresolved":
			finish_once(st.projectile_id, "unresolved_query", {"detail": "incomplete geometry"})
			return
		st.previous_position_world = st.position_world
		st.position_world = query_end
		# CD004 design point 1: carry the WHOLE profile-aware velocity change, not gravity alone. adv.velocity already holds
		# the drag term, and this path used to discard it and add gravity by itself, so a shot's speed never decayed with
		# distance even though its position was advanced with the drag - measured as a retention of exactly 1.000 at every
		# range while the same advance called directly decayed to 0.81004. The share is proportional because this path may
		# consume only part of the step (alpha) when the distance cap bites: for a vacuum profile adv.velocity minus the
		# current velocity is exactly gravity*h, so this reduces to the line it replaces and every existing shot is identical.
		st.velocity_world += (adv.velocity - st.velocity_world) * alpha
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
	else:
		_detonate_due_fuze(st, snapshots, space)


func _detonate_due_fuze(st: ProjectileState, snapshots: Array, space: PhysicsDirectSpaceState3D) -> bool:
	if not ShellFuze.due(st): return false
	# Lifetime/range win the tie. Physical contacts commit first; an armed
	# arrested body keeps its timer and can burst at the contact position.
	if st.age_s >= st.max_age_s - END_EPS:
		finish_once(st.projectile_id,"expired_time",{}); return true
	if st.travelled_m >= st.max_distance_m - END_EPS:
		finish_once(st.projectile_id,"expired_distance",{}); return true
	_emit_internal_burst(st, snapshots, space)
	return true


func _rest_for_fuze(st: ProjectileState, event: Dictionary, reason: String) -> bool:
	if st.fuze_due_age_s < 0.0 or not _live(st): return false
	st.fuze_resting = true
	st.fuze_stop_reason = reason
	st.velocity_world = Vector3.ZERO
	if event.get("part_world_transform") is Transform3D:
		st.fuze_rest_target = event.duplicate(true)
		st.fuze_rest_local = (event.part_world_transform as Transform3D).affine_inverse() * st.position_world
	return true


func _live(st: ProjectileState) -> bool:
	return not _shut_down and not is_queued_for_deletion() and not st.is_terminal() \
		and _active.get(st.projectile_id) == st


static func _surface_key(event: Dictionary) -> String:
	return JSON.stringify([event.get("entity_id", ""), event.get("life_id", 0), event.get("part_id", ""), event.get("surface_id", "")])


func resolve_armor(st: ProjectileState, event: Dictionary, direction: Vector3, budget: Dictionary) -> Dictionary:
	if event.get("reactive_profile",{}).is_empty(): return ArmorResolver.resolve(event,direction,budget)
	var fallback := ArmorResolver.resolve(event,direction,budget)
	if not _live(st): return fallback
	if not armor_handler.is_valid(): st.replay_error="missing_reactive_authority"; return fallback
	event["round_id"]=st.round_id; event["shooter_id"]=st.shooter_id; event["shooter_life_id"]=st.shooter_life_id
	event["event_id"]=JSON.stringify([st.round_id,st.shooter_id,st.shooter_life_id,st.shot_id,st.projectile_id,event.get("armor_trace","carrier_"+str(st.contacts.size())),event.get("entity_id"),event.get("life_id"),event.get("surface_id")])
	var committed: Dictionary=armor_handler.call(event.duplicate(true),direction,budget.duplicate(true))
	if not _live(st): return fallback
	if not committed.get("ok",false): st.replay_error="reactive_commit_"+str(committed.get("reason","failed")); return fallback
	event["reactive_before"]=committed.reactive_before
	event["reactive_event_index"]=st.reactive_event_count
	st.reactive_event_count+=1
	return committed.result

func handle_contact(st: ProjectileState, ev: Dictionary) -> bool:
	var incoming_velocity := st.velocity_world
	var result := {"result": "legacy_contact_only", "continue_flight": false}
	if st.armor_policy == "resolve":
		result = resolve_armor(st, ev, st.velocity_world, {
			"base_mm": PenetrationCurve.sample_mm(st.penetration_curve, st.travelled_m),
			"scale": st.budget_scale, "consumed_mm": st.consumed_mm, "ricochets": st.ricochets,
			"impact_profile":st.impact_profile,"caliber_mm":st.caliber_mm,"effect_policy":st.effect_policy,
		})
		if not _live(st): return false
		st.budget_scale = result.scale
		st.consumed_mm = result.consumed_mm
		st.ricochets = result.ricochets
		if result.result in ["ricochet","penetrated"]:
			# CD004 design point 3: the residual-velocity rule rides the same application point as ricochet. The resolver
			# returns the incoming DIRECTION VECTOR for a penetration - which is the velocity that was passed in, not a unit
			# vector, so it must be normalised or the speed is multiplied by itself; an unnormalised first attempt produced
			# 725208 m/s, exactly nine hundred squared times the scale. The ricochet branch already returns a unit vector.
			# A round that declares no residual model carries speed_scale 1.0, which makes this a no-op for existing shots.
			st.velocity_world = result.direction.normalized() * st.velocity_world.length() * float(result.speed_scale)
		if result.result == "penetrated":
			ShellFuze.arm(st, ev, result)
			st.interior_targets[DamageResolver.target_key(ev)] = not bool(result.backface)
			var key := DamageResolver.target_key(ev)
			if st.effect_policy == "internal_burst" and st.fuze_policy.is_empty() and not bool(result.backface) and st.burst_target.is_empty() and not st.burst_visited.has(key):
				st.burst_target = ev.duplicate(true); st.burst_entry_distance = st.travelled_m; st.burst_inside_started=false; st.burst_visited[key] = true
	# Prune only surfaces left behind. Multiple surfaces at the same point each cost once.
	for key in st.start_surfaces.keys():
		if st.position_world.distance_to(st.start_surfaces[key]) > GameConfig.ARMOR_START_EPS_M:
			st.start_surfaces.erase(key)
	st.start_surfaces[_surface_key(ev)] = st.position_world
	var target_key := JSON.stringify([ev.get("entity_id", ""), ev.get("life_id", 0)])
	var first_for_target := not st.contacted_targets.has(target_key)
	st.contacted_targets[target_key] = true
	var record := ev.duplicate(true)
	var waiting := false
	if result.get("result", "") in ["stopped", "perforated_stop"]:
		waiting = _rest_for_fuze(st, ev, "armor_"+str(result.result))
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
		if waiting: return true
		var reason := "impact_vehicle" if st.armor_policy == "legacy_contact_only" else "armor_" + str(result.result)
		finish_once(st.projectile_id, reason, {
			"target_id": ev.get("entity_id", ""), "target_life_id": ev.get("life_id", 0),
			"surface_id": ev.get("surface_id", ""),
		})
		return false
	return true

## CD01-T06: does this snapshot belong to a target that declares ammunition modules? Only such a target needs the
## ammunition occupancy, and only such a target is refused when the snapshot omits it.
func _declares_ammo_modules(snapshot: Dictionary) -> bool:
	var layout = snapshot.get("layout",null)
	if layout == null: return false
	for module in layout.modules:
		if module.kind == "ammo": return true
	return false

func handle_damage_contact(st: ProjectileState, ev: Dictionary) -> bool:
	if not damage_handler.is_valid() or st.damage_records.size() >= GameConfig.DAMAGE_MAX_CONTACTS:
		finish_once(st.projectile_id,"unresolved_damage",{"detail":"missing handler or damage budget"})
		return false
	var before := maxf(0,st.budget_scale * PenetrationCurve.sample_mm(st.penetration_curve,st.travelled_m) - st.consumed_mm)
	if before <= 0:
		if _rest_for_fuze(st, ev, "damage_budget_exhausted"): return true
		finish_once(st.projectile_id,"damage_budget_exhausted",{})
		return false
	var committed := _commit_damage_event(st,ev,before,st.position_world,st.velocity_world)
	if not committed.get("ok",false):
		# CD02-T03 / CombatIdentity invariant: a repeated event id must read the original result and change nothing, so a
		# duplicate commit is a no-op that lets the flight continue. Treating it as fatal aborted the whole shot, which
		# is how a denser triangulation of the SAME plate swallowed a real later layer. The duplicate must also be
		# recorded as seen: returning without marking it made the manager offer the same event again for ever, which
		# spun the probe at full CPU until it was killed.
		var why := str(committed.get("reason",""))
		if why=="invalid_or_duplicate":
			st.damage_seen[DamageResolver.item_key(ev)] = true
			return _live(st)
		if _live(st): finish_once(st.projectile_id,"unresolved_damage",{"detail":why})
		return false
	if before - float(committed.consumed_mm) <= 1e-5:
		if _rest_for_fuze(st, ev, "damage_budget_exhausted"): return true
		finish_once(st.projectile_id,"damage_budget_exhausted",{})
		return false
	return _live(st)

func record_chemical_armor(st: ProjectileState, event: Dictionary, result: Dictionary, point: Vector3, direction: Vector3) -> Dictionary:
	if not _live(st) or st.contacts.size()>=GameConfig.ARMOR_CONTACTS_PER_SHOT: return {"ok":false,"reason":"contact_budget_or_lifecycle"}
	var target_key := JSON.stringify([event.get("entity_id",""),event.get("life_id",0)])
	var first := not st.contacted_targets.has(target_key); st.contacted_targets[target_key]=true
	var record := event.duplicate(true); record.merge(result,true)
	record.merge({"projectile_id":st.projectile_id,"round_id":st.round_id,"shot_id":st.shot_id,
		"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shell_id":st.shell_id,
		"target_id":event.get("entity_id",""),"target_life_id":event.get("life_id",0),
		"contact_index":st.contacts.size()+1,"first_for_target":first,"armor_policy":"resolve","effect_channel":"chemical_jet",
		"flight_time_s":st.age_s,"travelled_m":st.travelled_m,"impact_point":point,"impact_velocity":direction,
		"incoming_velocity":direction,"outgoing_velocity":direction,"physics_tick":Engine.get_physics_frames()},true)
	st.contacts.append(record.duplicate(true)); st.chemical_effect.contact_indices.append(st.contacts.size()-1)
	projectile_contact.emit(record.duplicate(true))
	return {"ok":_live(st)}

func _commit_damage_event(st: ProjectileState, ev: Dictionary, before: float, point: Vector3, velocity: Vector3, fragment_id: int = -1) -> Dictionary:
	if not _live(st) or not damage_handler.is_valid() or st.damage_records.size() >= GameConfig.DAMAGE_MAX_CONTACTS:
		return {"ok":false,"reason":"damage_budget_or_lifecycle"}
	var event := ev.duplicate(true)
	var event_identity: Array = [st.round_id,st.shooter_id,st.shooter_life_id,st.shot_id,st.projectile_id,DamageResolver.item_key(ev)]
	if fragment_id >= 0: event_identity.append(fragment_id)
	event.merge({
		"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,
		"shot_id":st.shot_id,"projectile_id":st.projectile_id,
		"event_id":JSON.stringify(event_identity),
		"fragment_id":fragment_id,
	},true)
	var delta: Dictionary = damage_handler.call(event,before)
	if not _live(st):
		return {"ok":false,"reason":"cancelled"}
	if not delta.get("ok",false):
		return delta
	var spent := float(delta.get("consumed_mm",0))
	if not is_finite(spent) or spent < 0 or spent > before + 1e-5:
		return {"ok":false,"reason":"invalid damage budget"}
	if fragment_id < 0 and ev.get("effect_channel","")!="chemical_jet":
		st.consumed_mm += spent
		st.damage_seen[DamageResolver.item_key(ev)] = true
	event.merge(delta,true)
	event.merge({
		"target_id":ev.get("entity_id",""),"target_life_id":ev.get("life_id",0),
		"damage_index":st.damage_records.size()+1,"flight_time_s":st.age_s,"travelled_m":st.travelled_m,
		"before_mm":before,"after_mm":maxf(0,before-spent),
		"impact_point":point,"impact_velocity":velocity,
		"rules_version":GameConfig.DAMAGE_RULES_VERSION,"physics_tick":Engine.get_physics_frames(),
	},true)
	st.damage_records.append(event.duplicate(true))
	if fragment_id >= 0: st.fragments[fragment_id].damage_indices.append(st.damage_records.size()-1)
	if ev.get("effect_channel","")=="chemical_jet":
		st.chemical_effect.damage_indices.append(st.damage_records.size()-1)
		st.chemical_effect.remaining_mm=maxf(0,before-spent)
	projectile_damage.emit(event.duplicate(true))
	return {"ok":_live(st),"consumed_mm":spent,"event":event}

func _emit_internal_burst(st: ProjectileState, snapshots: Array, space: PhysicsDirectSpaceState3D) -> void:
	var target := ShellEffectPolicy.target_snapshot(st.burst_target, snapshots)
	var frame := ShotRecordBuilder.capture_frame(st,st.burst_target,snapshots) if not target.is_empty() else -1
	st.burst = {"point_world":st.position_world,"time_s":st.age_s,"seed":st.seed,"geometry_frame":frame,
		"target_id":st.burst_target.get("entity_id",""),"target_life_id":st.burst_target.get("life_id",0),"rules_version":ShellEffectPolicy.VERSION}
	# CD07 design point one: one explosion root event records its channels SEPARATELY. The fragment channel is the existing
	# bounded emitter called below; the blast and overpressure channels are declared here and explicitly marked as not yet
	# applied, so nothing pretends that a shared in-radius switch already exists. An external HE round is marked as such.
	var legacy_channels := ShellEffectPolicy.legacy_template()
	st.burst["channels"] = {
		"fragment":{"applied":true,"version":ShellEffectPolicy.VERSION,"lines":int(legacy_channels.max_fragments),
			"range_m":float(legacy_channels.fragment_range_m),"budget_mm":float(legacy_channels.fragment_budget_mm)},
		"blast":{"applied":false,"pending":"cd07-blast-channel","reason":"declared by WT-CD-007 design point one and not yet applied"},
		"overpressure":{"applied":false,"pending":"cd07-overpressure-channel","reason":"declared by WT-CD-007 design point one and not yet applied"}}
	# CD07 design point two, first half: whether the pressure has a PATH into the compartment is decided by bounded
	# connectivity rules, and the two facts available at the burst are whether the explosion is outside the hull and whether
	# the armour was actually breached. A closed compartment with no breach therefore gets NO invented interior overpressure,
	# while an interior burst or a perforated plate gives the pressure a path. This is a game abstraction, not a pressure
	# formula, and the verdict and its inputs are both recorded rather than a silent in-radius switch.
	var burst_outside := bool(st.burst.get("external",true))
	var breached := false
	for contact in st.contacts:
		if str(contact.get("result","")) in ["penetrated","perforated_stop"]: breached = true
	var pressure_reaches: bool = (not burst_outside) or breached
	st.burst["channels"]["overpressure"] = {"applied":pressure_reaches,"model":"cd07-bounded-connectivity-v1",
		"burst_outside":burst_outside,"breached":breached,
		"pending":("" if pressure_reaches else "cd07-connectivity-openings"),
		"reason":("an interior burst or a breached plate gives the pressure a path" if pressure_reaches
			else "closed compartment with no breach: the pressure has no path in, so there is no invented interior overpressure")}
	if st.effect_policy=="he_blast": st.burst["external_he"]=true
	if not st.fuze_policy.is_empty():
		st.burst["fuze"] = {"version":ShellFuze.VERSION,"policy":st.fuze_policy.duplicate(true),
			"armed_age_s":st.fuze_armed_age_s,"due_age_s":st.fuze_due_age_s}
		st.burst["external"] = target.is_empty() or not ShellEffectPolicy.inside(target, st.position_world)
		st.burst["stop_reason"] = st.fuze_stop_reason
	FragmentSystem.emit_bounded(st,snapshots,space,_exclude_for(st),Callable(self,"_commit_damage_event").bind(),contact_policy,Callable(self,"_live"),{},Callable(self,"resolve_armor"))
	if _live(st): finish_once(st.projectile_id,"internal_burst",{"target_id":st.burst.target_id,"target_life_id":st.burst.target_life_id})

func _emit_spall(st: ProjectileState, event: Dictionary, snapshots: Array, space: PhysicsDirectSpaceState3D) -> void:
	if st.post_penetration_profile.is_empty() or st.spall_events.size()>=SpallProfile.MAX_EVENTS or st.contacts.is_empty(): return
	var contact: Dictionary=st.contacts.back()
	var surface := _surface_key(event)
	if contact.result!="penetrated" or contact.backface or st.spall_surfaces.has(surface): return
	var allocated := SpallProfile.allocation(st.post_penetration_profile,float(contact.after_mm))
	if allocated<=0: return
	var batch := {"id":st.spall_events.size(),"contact_index":st.contacts.size()-1,"point_world":st.position_world,
		"time_s":st.age_s,"geometry_frame":event.geometry_frame,"direction":st.velocity_world.normalized(),
		"allocated_mm":allocated,"parent_before_mm":contact.after_mm,"parent_after_mm":float(contact.after_mm)-allocated,
		"fragment_start":st.fragments.size(),"fragment_count":0,"rules_version":SpallProfile.VERSION}
	# Commit budget and batch before any damage callback can reset or finish the shot.
	st.spall_surfaces[surface]=true; st.consumed_mm+=allocated; st.spall_events.append(batch)
	FragmentSystem.emit_bounded(st,snapshots,space,_exclude_for(st),Callable(self,"_commit_damage_event"),contact_policy,Callable(self,"_live"),
		{"batch":batch,"contact":event,"profile":st.post_penetration_profile},Callable(self,"resolve_armor"))



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
	if not terminal_data.get("world_damage",{}).is_empty(): record["world_damage"] = terminal_data.world_damage.duplicate(true)
	record["armor_policy"] = st.armor_policy
	record["contacts"] = st.contacts.duplicate(true)
	record["damage_records"] = st.damage_records.duplicate(true)
	record["burst"] = st.burst.duplicate(true)
	record["fragments"] = st.fragments.duplicate(true)
	record["spall_events"] = st.spall_events.duplicate(true)
	record["chemical_effect"] = st.chemical_effect.duplicate(true)
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
