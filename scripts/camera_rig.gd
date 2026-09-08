class_name CameraRig
extends Node3D
## 相机（职责：观察/瞄准视角）。003：鼠标输入由 PlayerController 读取并 set_aim；
## 本脚本不再直接读取全局键鼠。第三人称防穿墙（射线查询排除本车）；
## 炮镜沿炮管实际方向，cull_mask 只剔除本车视觉层（不隐藏其他车）。

var cam: Camera3D
var turret: TurretRig = null    # 由 actor 注入
var tank: TankVehicle = null    # 由 actor 注入
var aim_yaw := 0.0              # 全局观察朝向（弧度，0 = -Z）
var aim_pitch := 0.0            # 观察俯仰（弧度，正 = 抬头）
var sight := false
var visual_layer: int = GameConfig.VIS_LAYER_VEHICLE   # 003：本车视觉层（炮镜只剔除该位）

var _sight_requested := false
var snapshot_provider := Callable()
var _precise_point := Vector3.ZERO
var _precise_valid := false
var intent_contact: Dictionary = {}

func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 400.0
	cam.fov = GameConfig.MAIN_FOV
	add_child(cam)
	cam.current = false # VehicleActor explicitly assigns the local controller's camera.
	cam.position = Vector3(0, 1.0, 6.5)

func set_aim(yaw: float, pitch: float) -> void:
	# 003：PlayerController 唯一入口（不再由本脚本读鼠标）
	aim_yaw = wrapf(yaw, -PI, PI)
	aim_pitch = clampf(pitch, deg_to_rad(GameConfig.CAM_PITCH_MIN), deg_to_rad(GameConfig.CAM_PITCH_MAX))

func set_local_control(on: bool) -> void:
	# 003：本地控制者设置——只有被控制的车拥有有效本地游戏相机
	cam.current = on

func set_sight_requested(on: bool) -> void:
	_sight_requested = on

func clear_intent_cache() -> void:
	_precise_valid = false
	intent_contact.clear()

func _exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if tank != null:
		ex.append(tank.get_rid())
	return ex

func _process(_delta: float) -> void:
	sight = _sight_requested and turret != null
	if sight:
		# 炮镜：贴在炮根上方、沿炮管实际方向看；cull_mask 只剔除本车视觉层
		var bdir := turret.barrel_direction()
		var bp := turret.barrel_pivot.global_position
		cam.global_position = bp + Vector3.UP * 0.45 - bdir * 0.35
		cam.look_at(cam.global_position + bdir * 50.0)
		cam.fov = GameConfig.SIGHT_FOV
		cam.cull_mask &= ~visual_layer
	else:
		var pivot_pos := global_position
		var dir_h := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
		# 002-R1：视线随 aim_pitch 同步俯仰——相机中心射线（=玩家想瞄方向）与炮管
		# 指向一致；机位仍沿水平方向绕 pivot（保持固定高度），防穿墙查询不变
		var cp := cos(aim_pitch)
		var dir3d := Vector3(dir_h.x * cp, sin(aim_pitch), dir_h.z * cp)
		var distance := tank.defs.follow_camera_distance if tank != null and tank.defs != null else GameConfig.CAM_DISTANCE
		var height := tank.defs.follow_camera_height if tank != null and tank.defs != null else GameConfig.CAM_HEIGHT
		var desired := pivot_pos - dir_h * distance + Vector3.UP * height
		var from := pivot_pos + Vector3.UP * 0.3
		var hit := _ray(from, desired)
		if not hit.is_empty():
			desired = hit.position + hit.normal * 0.3   # 防穿墙：贴墙缩距
		cam.global_position = desired
		# 002-R1：相机前向 ≡ dir3d（从相机位置沿瞄准方向看）→ 中心射线与炮管指向精确一致
		cam.look_at(cam.global_position + dir3d * 12.0)
		cam.fov = GameConfig.MAIN_FOV
		cam.cull_mask |= visual_layer

func _ray(from: Vector3, to: Vector3, mask: int = GameConfig.LAYER_WORLD) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, _exclude())
	return space.intersect_ray(q)

func get_aim_point() -> Vector3:
	if _precise_valid and not sight:
		return _precise_point
	# 玩家想瞄的点：相机中心射线（第三人称下即屏幕中心方向）。
	# 003：意图射线查 WORLD|VEHICLE（排除本车）——B 等车辆可被瞄准，
	# 否则炮塔会越过车辆对准其后方世界点，炮管射线从目标上方掠过。
	# 006-R1-C：射线长度 150→300m——相机在炮管后方 ~6.5m，150m 射道从相机处
	# 已超 150m，意图射线打不到远靶导致炮管收敛到回退瞄点（远射道不可用）；
	# 上限须覆盖 gun_range(200m) + 相机偏移。
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit := _ray(from, from + dir * 300.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE)
	if not hit.is_empty():
		return hit.position
	return from + dir * 60.0

func intent_point() -> Vector3:
	if _precise_valid:
		return _precise_point
	# 002-R2：输入意图射线 → 期望世界瞄点 P（炮塔按 P 求目标角）。
	# 第三人称：相机中心射线；炮镜：沿意图方向从炮根发出（独立输入意图，
	# 不以实际炮管方向反向锁死——否则炮塔会跟随自己、无法继续改变目标）。
	if sight and turret != null:
		var pivot := turret.barrel_pivot.global_position
		var cp := cos(aim_pitch)
		var dir3d := Vector3(-sin(aim_yaw) * cp, sin(aim_pitch), -cos(aim_yaw) * cp)
		var hit := _ray(pivot, pivot + dir3d * 150.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE)
		if not hit.is_empty():
			return hit.position
		return pivot + dir3d * 60.0
	return get_aim_point()

func _physics_process(_delta: float) -> void:
	# Actual armor silhouette in resolve mode. World queries stay in the physical update.
	_precise_valid = false
	intent_contact.clear()
	if not snapshot_provider.is_valid() or tank == null: return
	var snapshots: Array = snapshot_provider.call()
	if snapshots.is_empty(): return
	var from := cam.global_position
	var direction := -cam.global_basis.z
	if _sight_requested and turret != null:
		from = turret.barrel_pivot.global_position
		direction = Vector3(-sin(aim_yaw)*cos(aim_pitch),sin(aim_pitch),-cos(aim_yaw)*cos(aim_pitch))
	var world := WorldQueryAdapter.query_world_stop(get_world_3d().direct_space_state,from,direction,300,_exclude())
	if not world.get("ok",false): return
	var query := ShotQueryService.query({"from_world":from,"to_world":from+direction*300,
		"excluded_instances":[{"entity_id":tank.entity_id,"life_id":tank.life_id}],
		"include_modules":true,"include_crew":false,"world_stop":world.get("contact",{})},snapshots)
	var selected := ExternalContactSelector.select_contact(query)
	var boundary := INF
	if selected.status == "vehicle":
		intent_contact = selected.event
	elif selected.status == "world":
		intent_contact = selected.contact
	elif selected.status == "unresolved":
		return
	if not intent_contact.is_empty(): boundary = float(intent_contact.distance_m)
	var external_module := DamageResolver.next_contact(query,{}, {},boundary)
	if not external_module.is_empty(): intent_contact = external_module
	_precise_point = intent_contact.get("point_world",from+direction*60)
	_precise_valid = true
