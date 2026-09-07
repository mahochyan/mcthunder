class_name Gunner
extends Node3D
## 射击（职责：开火/冷却/命中判定/特效）。
## 命中规则（工作单 §D）：
##   - 命中查询只依据炮口实际方向（炮管 basis），绝不使用相机射线代替；
##   - 只处理第一处有效碰撞；一律排除本车 RID；
##   - 相机可见但炮管被墙遮挡时不得命中墙后目标（射线首碰即墙）；
##   - 炮管穿墙时阻止开火：额外检查炮根 → 炮口线段遮挡；
##   - 冷却 2s，按住开火键不绕过（is_action_just_pressed 触发 + 冷却闸门）。

var tank: TankVehicle = null
var turret: TurretRig = null
var weapon: WeaponDefinition = null   # 003-R1：由 actor 注入——装填/射程唯一来源（null 回退 GameConfig）
var shooter_id := ""                  # 003-R1：由 actor 注入（实体标识，命中事件携带）
var shot_id := 0                      # 003-R2：本实体射击编号——每次成功发射 +1（含空射/打墙），发射时分配
var round_provider := Callable()      # 003-R2：开火时刻任务轮次来源（由 main 注入；空 = -1）
var cooldown_left := 0.0
var resume_grace := 0.0
var shots_fired := 0
var blocked_reason := ""          # "" / "cooldown" / "grace" / "barrel_occluded"
var last_shot_result := ""        # 003："" / "hit" / "miss" / "blocked:cooldown" / "blocked:grace" / "blocked:barrel_occluded"
var actual_hit_point := Vector3.ZERO   # 炮管实际指向命中点（供实际指向标记）

var _tracer: MeshInstance3D
var _tracer_mesh: ImmediateMesh
var _tracer_mat: StandardMaterial3D
var _tracer_left := 0.0

func setup(t: TankVehicle, tr: TurretRig, w: WeaponDefinition = null) -> void:
	tank = t
	turret = tr
	weapon = w

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

func request_fire() -> bool:
	# 003：统一开火请求入口（PlayerController 边沿 → VehicleCommand → 本方法；
	# 不再由本脚本直接读取全局 fire 键）
	return try_fire()

func _current_round() -> int:
	# 003-R2：开火那一刻的任务轮次（发射身份冻结来源；未注入 = -1，任务侧必拒）
	return round_provider.call() if round_provider.is_valid() else -1

func _update_actual_aim() -> void:
	if turret == null:
		return
	var range: float = weapon.gun_range if weapon != null else GameConfig.GUN_RANGE
	var muz := turret.muzzle.global_position
	var dir := turret.barrel_direction()
	var hit := _ray(muz, dir, range)
	if not hit.is_empty():
		actual_hit_point = hit.position
	else:
		actual_hit_point = muz + dir * 60.0

func try_fire() -> bool:
	if cooldown_left > 0.0:
		blocked_reason = "cooldown"
		last_shot_result = "blocked:cooldown"
		return false
	if resume_grace > 0.0:
		blocked_reason = "grace"
		last_shot_result = "blocked:grace"
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
	# 炮口实际方向命中查询（003-R1：射程来自 WeaponDefinition）
	# 003-R2：通过全部开火检查后先分配射击身份、冻结发射上下文——
	# round_id 取开火时刻（不在命中送达时补填）；每次成功发射消耗一个编号
	shot_id += 1
	var identity := {
		"round_id": _current_round(),
		"shooter_id": shooter_id,
		"shooter_life_id": tank.life_id,
		"shot_id": shot_id,
		"target_id": "",
		"target_life_id": 0,
	}
	var range: float = weapon.gun_range if weapon != null else GameConfig.GUN_RANGE
	var dir := turret.barrel_direction()
	var ghit := _ray(muz, dir, range)
	var end := muz + dir * range
	var hit_vehicle := false
	if not ghit.is_empty():
		end = ghit.position
		var col: Object = ghit.collider
		if col is TankVehicle:
			# 车辆命中：补齐目标身份（来自实际碰撞对象）→ 发出完整事件
			identity["target_id"] = col.entity_id
			identity["target_life_id"] = col.life_id
			col.register_hit(identity)
			hit_vehicle = true
		elif col != null and col.has_method("register_hit"):
			col.register_hit({})   # 靶板等非车辆对象：只触发自身反馈，不产生任务事件
	last_shot_result = "hit" if hit_vehicle else "miss"
	_spawn_tracer(muz, end)
	turret.kick_recoil()
	cooldown_left = weapon.reload_time if weapon != null else GameConfig.RELOAD_TIME
	shots_fired += 1
	blocked_reason = ""
	return true

func _ray(from: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE, _exclude())
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
	cooldown_left = 0.0
	resume_grace = 0.0
	blocked_reason = ""
	last_shot_result = ""
	_tracer_left = 0.0
	if _tracer != null:
		_tracer.visible = false