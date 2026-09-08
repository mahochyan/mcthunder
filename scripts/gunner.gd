class_name Gunner
extends Node3D
## 射击（职责：开火条件校验/请求生成/扣弹与装填/发射反馈）。
## 006：即时命中结算移除——try_fire 只校验并请求 ProjectileManager 生成飞弹；
## 实际撞击由管理器逐段推进后经 projectile_finished 事件送达（Main 分发）。
## 命中规则（工作单 §D + 006）：
##   - 发射只依据真实炮口位置与炮管方向（turret.barrel_direction），绝不使用相机射线；
##   - 炮管穿墙时阻止开火：额外检查炮根 → 炮口线段遮挡（保留）；
##   - 冷却 2s，按住开火键不绕过（is_action_just_pressed 触发 + 冷却闸门）；
##   - 合法发射扣一发；拒绝发射不扣弹、不装填、不增加射击计数；
##   - 初速 = 炮管单位方向 × muzzle_velocity_mps + 发射瞬间车体平移速度
##     （炮口切向速度不实现，作为明确弹道近似记录）。

var tank: TankVehicle = null
var turret: TurretRig = null
var weapon: WeaponDefinition = null   # 003-R1：由 actor 注入——装填/射程唯一来源（null 回退 GameConfig）
var shell: ShellDefinition = null      # 006：由 actor 注入——弹种运动参数唯一来源
var projectile_manager: ProjectileManager = null   # 006：由 main 注入——唯一推进执行器
var shooter_id := ""                  # 003-R1：由 actor 注入（实体标识，命中事件携带）
var shooter_team_id := 0              # 006：由 actor 注入（发射身份队伍，冻结）
var shot_id := 0                      # 003-R2：本实体射击编号——每次成功发射 +1（含空射/打墙），发射时分配
var round_provider := Callable()      # 003-R2：开火时刻任务轮次来源（由 main 注入；空 = -1）
var snapshot_provider := Callable()   # 005：查询快照来源（由 main 注入；空 = 无几何查询，保守 miss）
var rounds_remaining := 0             # 006：剩余弹数（实例状态，不共享；整场/单车重开恢复配额）
var cooldown_left := 0.0
var resume_grace := 0.0
var shots_fired := 0
var blocked_reason := ""          # "" / "cooldown" / "grace" / "barrel_occluded" / "no_ammo" / "projectile_capacity" / "invalid_shell" / "invalid_spawn" / "duplicate_launch"
var last_shot_result := ""        # 003："" / "fired" / "blocked:<reason>"（006：命中结果由管理器事件送达，不再即时判定）
var actual_hit_point := Vector3.ZERO   # 炮管实际指向命中点（供实际指向标记）
var last_query_events: Array = []      # 005：最近一次开火的统一查询事件（调试/证据用；只读展示）
var _aim_query_cache: Dictionary = {}  # 005-R1：物理阶段统一查询缓存（实际指向标记同源）

var _tracer: MeshInstance3D
var _tracer_mesh: ImmediateMesh
var _tracer_mat: StandardMaterial3D
var _tracer_left := 0.0

func setup(t: TankVehicle, tr: TurretRig, w: WeaponDefinition = null, s: ShellDefinition = null) -> void:
	tank = t
	turret = tr
	weapon = w
	shell = s
	rounds_remaining = w.initial_rounds if w != null else 30   # 006：单武器初始弹数（测试配额）

func _exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if tank != null:
		ex.append(tank.get_rid())
	return ex

func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	resume_grace = maxf(0.0, resume_grace - delta)
	_update_actual_aim()
	_update_effects(delta)

func _physics_process(_delta: float) -> void:
	# 005-R1：实际指向标记的统一查询在物理阶段执行（世界遮挡 + 同一车辆几何服务），
	# 结果缓存给 _process 读取——与开火判定路径同源（不再用旧 _ray 粗碰撞）。
	if turret == null or tank == null:
		return
	if not snapshot_provider.is_valid():
		return
	var range: float = weapon.gun_range if weapon != null else GameConfig.GUN_RANGE
	var muz := turret.muzzle.global_position
	var dir := turret.barrel_direction()
	if not muz.is_finite() or not dir.is_finite():
		return
	var ws_result := WorldQueryAdapter.query_world_stop(get_world_3d().direct_space_state, muz, dir, range, _exclude())
	var world_contact: Dictionary = ws_result.get("contact", {}) if ws_result.get("hit", false) else {}
	var snapshots: Array = snapshot_provider.call()
	_aim_query_cache = ShotQueryService.query({
		"query_id": "aim_%s_%d" % [shooter_id, Engine.get_physics_frames()],
		"physics_tick": Engine.get_physics_frames(),
		"from_world": muz,
		"to_world": muz + dir * range,
		"excluded_instances": [{"entity_id": tank.entity_id, "life_id": tank.life_id}],
		"include_modules": true,
		"include_crew": false,
		"world_stop": world_contact,
	}, snapshots)
	if not ws_result.get("ok", false):
		_aim_query_cache["__world_ok"] = false
		_aim_query_cache["__world_reason"] = str(ws_result.get("reason", "no_space"))

func _update_actual_aim() -> void:
	if turret == null:
		return
	var range: float = weapon.gun_range if weapon != null else GameConfig.GUN_RANGE
	var muz := turret.muzzle.global_position
	var dir := turret.barrel_direction()
	if _aim_query_cache.get("__world_ok", true) == false:
		actual_hit_point = muz + dir * 60.0
		return
	var sel := ExternalContactSelector.select_contact(_aim_query_cache)
	match sel.get("status", "unresolved"):
		"vehicle":
			actual_hit_point = sel["event"].get("point_world", muz + dir * 60.0)
		"world":
			actual_hit_point = sel["contact"].get("point_world", muz + dir * 60.0)
		_:
			actual_hit_point = muz + dir * 60.0

func request_fire() -> bool:
	# 003：统一开火请求入口（PlayerController 边沿 → VehicleCommand → 本方法；
	# 不再由本脚本直接读取全局 fire 键）
	return try_fire()

func _current_round() -> int:
	# 003-R2：开火那一刻的任务轮次（发射身份冻结来源；未注入 = -1，任务侧必拒）
	return round_provider.call() if round_provider.is_valid() else -1

func try_fire() -> bool:
	# 006：发射流程——检查暂停/实体/输入 → 冷却/宽限/火键门/弹药 → 炮根-炮口遮挡
	# → 冻结真实炮口/方向/速度/身份 → 管理器接收该发 → 扣弹/装填/编号/计数 → 特效。
	# 这里不查远处目标并登记命中（实际撞击由管理器推进后经事件送达）。
	if cooldown_left > 0.0:
		blocked_reason = "cooldown"
		last_shot_result = "blocked:cooldown"
		return false
	if resume_grace > 0.0:
		blocked_reason = "grace"
		last_shot_result = "blocked:grace"
		return false
	if rounds_remaining <= 0:
		blocked_reason = "no_ammo"
		last_shot_result = "blocked:no_ammo"
		return false
	if projectile_manager == null:
		# 装配缺失：保守拒绝（不扣弹、不装填、不计数）
		blocked_reason = "invalid_spawn"
		last_shot_result = "blocked:invalid_spawn"
		return false
	# 炮根 → 炮口 遮挡检查：炮管穿墙时禁止开火
	var root := turret.barrel_pivot.global_position
	var muz := turret.muzzle.global_position
	var seg := muz - root
	var seg_len := seg.length()
	if seg_len > 0.01:
		var block_hit := _ray(root, seg / seg_len, seg_len + 0.05)
		if not block_hit.is_empty() and root.distance_to(block_hit.position) < seg_len - 0.02:
			blocked_reason = "barrel_occluded"
			last_shot_result = "blocked:barrel_occluded"
			return false
	# 冻结发射上下文：真实炮口、炮管方向、车体速度、身份（round_id 取开火时刻）
	var dir := turret.barrel_direction()
	if not muz.is_finite() or not dir.is_finite():
		blocked_reason = "invalid_spawn"
		last_shot_result = "blocked:invalid_spawn"
		return false
	var next_shot_id := shot_id + 1
	if shell == null:
		blocked_reason = "invalid_shell"
		last_shot_result = "blocked:invalid_shell"
		return false
	var muzzle_velocity: float = shell.muzzle_velocity_mps
	if not is_finite(muzzle_velocity) or muzzle_velocity <= 0.0:
		blocked_reason = "invalid_shell"
		last_shot_result = "blocked:invalid_shell"
		return false
	var gravity_world := Vector3(0.0, -9.81, 0.0) * shell.gravity_scale
	var max_age: float = shell.max_flight_time_s
	var max_dist: float = weapon.gun_range if weapon != null else GameConfig.GUN_RANGE
	var spec := {
		"round_id": _current_round(),
		"shooter_id": shooter_id,
		"shooter_life_id": tank.life_id,
		"shooter_team_id": shooter_team_id,
		"shot_id": next_shot_id,
		"shell_id": shell.id,
		"position_world": muz,
		"velocity_world": dir * muzzle_velocity + tank.velocity,
		"gravity_world": gravity_world,
		"max_age_s": max_age,
		"max_distance_m": max_dist,
	}
	var spawn := projectile_manager.try_spawn(spec)
	if not spawn.get("ok", false):
		# 拒绝发射不扣弹、不装填、不增加射击计数
		blocked_reason = str(spawn.get("reason", "invalid_spawn"))
		last_shot_result = "blocked:" + blocked_reason
		return false
	# 只有 ok=true 后一次性提交扣弹、冷却、编号与计数（无 await，不触发可重入开火信号）
	shot_id = next_shot_id
	rounds_remaining -= 1
	cooldown_left = weapon.reload_time if weapon != null else GameConfig.RELOAD_TIME
	shots_fired += 1
	blocked_reason = ""
	last_shot_result = "fired"
	last_query_events = []
	_spawn_tracer(muz, muz + dir * 0.6)   # 006：仅炮口闪光（短线段）；不再画到未来目标
	turret.kick_recoil()
	return true

func _ray(from: Vector3, dir: Vector3, dist: float) -> Dictionary:
	# 005-R1 收尾 A：hit_from_inside=true——炮根/炮口位于实体墙内部时仍识别遮挡
	# （命中点在起点、法线为零；"未取得法线"不等于"没有墙"）。
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE, _exclude())
	q.hit_from_inside = true
	return space.intersect_ray(q)

func _ensure_tracer() -> void:
	if _tracer != null:
		return
	_tracer_mesh = ImmediateMesh.new()
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tracer_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.9)
	_tracer = MeshInstance3D.new()
	_tracer.mesh = _tracer_mesh
	_tracer.material_override = _tracer_mat
	_tracer.layers = 1
	# 003-R1：示踪线在世界空间管理（top_level 脱离父级变换）——
	# 顶点直接用世界坐标，不重复叠加父变换，也不随射击后车辆运动拖动旧线段
	_tracer.top_level = true
	add_child(_tracer)

func tracer_points() -> Array:
	# 003-R1：示踪线世界端点（测试/调试用；不可见时返回空）
	if _tracer == null or not _tracer.visible:
		return []
	var arr := _tracer_mesh.surface_get_arrays(0)
	if arr.is_empty() or not (arr[0] is PackedVector3Array):
		return []
	var verts: PackedVector3Array = arr[0]
	var out: Array = []
	for v in verts:
		out.append(v)
	return out

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	_ensure_tracer()
	_tracer_mesh.clear_surfaces()
	_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer_mesh.surface_add_vertex(a)
	_tracer_mesh.surface_add_vertex(b)
	_tracer_mesh.surface_end()
	_tracer.visible = true
	_tracer_left = 0.12

func _update_effects(delta: float) -> void:
	if _tracer_left > 0.0:
		_tracer_left -= delta
		_tracer_mat.albedo_color.a = clampf(_tracer_left / 0.12, 0.0, 1.0) * 0.9
		if _tracer_left <= 0.0:
			_tracer.visible = false

func reset_state() -> void:
	# 003：单车/整场重置——清零瞬时状态；006：恢复弹药测试配额
	# （普通暂停、F6 打开关闭不补弹；只有重置路径恢复）
	cooldown_left = 0.0
	resume_grace = 0.0
	blocked_reason = ""
	last_shot_result = ""
	rounds_remaining = weapon.initial_rounds if weapon != null else 30
	_tracer_left = 0.0
	if _tracer != null:
		_tracer.visible = false