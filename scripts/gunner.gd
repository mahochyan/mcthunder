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
var snapshot_provider := Callable()   # 005：查询快照来源（由 main 注入；空 = 无几何查询，保守 miss）
var cooldown_left := 0.0
var resume_grace := 0.0
var shots_fired := 0
var blocked_reason := ""          # "" / "cooldown" / "grace" / "barrel_occluded"
var last_shot_result := ""        # 003："" / "hit" / "miss" / "blocked:cooldown" / "blocked:grace" / "blocked:barrel_occluded"
var actual_hit_point := Vector3.ZERO   # 炮管实际指向命中点（供实际指向标记）
var last_query_events: Array = []      # 005：最近一次开火的统一查询事件（调试/证据用；只读展示）
var _aim_query_cache: Dictionary = {}  # 005-R1：物理阶段统一查询缓存（实际指向标记同源）

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
	var end := muz + dir * range
	# 005-R1：统一命中查询——保留原始完整线段（世界遮挡作为结果接触，不提前截断 to_world，
	# 墙后候选保留并标注遮挡）；有效外部接触由 ExternalContactSelector 统一选取：
	# 车辆命中只认"首个有效装甲外表面接触"；模块/乘员是内部候选，不参与本轮计分；
	# 查询不完整/失败 → 保守未决（unresolved），不产生车辆命中，也不假装畅通。
	var ws_result := WorldQueryAdapter.query_world_stop(get_world_3d().direct_space_state, muz, dir, range, _exclude())
	var world_contact: Dictionary = ws_result.get("contact", {}) if ws_result.get("hit", false) else {}
	var world_collider: Object = world_contact.get("collider", null) if not world_contact.is_empty() else null
	if not ws_result.get("ok", false):
		# 输入或物理空间无效 → 未决：不伪造命中、也不当没有墙
		last_query_events = []
		last_shot_result = "unresolved"
		_spawn_tracer(muz, end)
		turret.kick_recoil()
		cooldown_left = weapon.reload_time if weapon != null else GameConfig.RELOAD_TIME
		shots_fired += 1
		blocked_reason = ""
		return true
	var snapshots: Array = snapshot_provider.call() if snapshot_provider.is_valid() else []
	var qr := ShotQueryService.query({
		"query_id": "shot_%s_%d" % [shooter_id, shot_id],
		"physics_tick": Engine.get_physics_frames(),
		"from_world": muz,
		"to_world": end,
		"excluded_instances": [{"entity_id": tank.entity_id, "life_id": tank.life_id}],
		"include_modules": true,
		"include_crew": false,
		"world_stop": world_contact,
	}, snapshots)
	last_query_events = qr.get("events", [])
	var sel := ExternalContactSelector.select_contact(qr)
	var contact_end := end
	var hit_vehicle := false
	match sel.get("status", "unresolved"):
		"vehicle":
			# 首个有效装甲外表面接触在墙前 → 命中该实体（几何查询结果，非物理粗碰撞）
			var ev: Dictionary = sel["event"]
			var target := _find_vehicle(str(ev.get("entity_id", "")), int(ev.get("life_id", 0)))
			if target != null:
				identity["target_id"] = target.entity_id
				identity["target_life_id"] = target.life_id
				target.register_hit(identity)
				hit_vehicle = true
				contact_end = ev.get("point_world", end)
		"world":
			# 最近世界遮挡：靶板等世界对象只触发自身反馈，不产生任务事件
			if world_collider != null and world_collider.has_method("register_hit"):
				world_collider.register_hit({})
			contact_end = sel["contact"].get("point_world", end)
		_:
			pass   # miss / unresolved：不产生计分事件；示踪线终点 = 完整线段终点
	last_shot_result = "hit" if hit_vehicle else ("unresolved" if sel.get("status", "") == "unresolved" else "miss")
	_spawn_tracer(muz, contact_end)
	turret.kick_recoil()
	cooldown_left = weapon.reload_time if weapon != null else GameConfig.RELOAD_TIME
	shots_fired += 1
	blocked_reason = ""
	return true

func _find_vehicle(entity_id: String, life_id: int) -> TankVehicle:
	# 005：按快照事件身份找实际车辆实例（临时查找，不持有 Node 引用）。
	# 递归遍历整棵树（-s 脚本模式下 current_scene 可能为 null，实体可能在任意层级）。
	var tree := get_tree()
	if tree == null:
		return null
	return _find_vehicle_in(tree.root, entity_id, life_id)

func _find_vehicle_in(node: Node, entity_id: String, life_id: int) -> TankVehicle:
	for c in node.get_children():
		if c is VehicleActor and c.tank != null and is_instance_valid(c.tank) \
				and c.tank.entity_id == entity_id and c.tank.life_id == life_id:
			return c.tank
		var r := _find_vehicle_in(c, entity_id, life_id)
		if r != null:
			return r
	return null

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