class_name TankVehicle
extends CharacterBody3D
## 车辆运动（职责：驾驶）。003：命令驱动——不再直接读取全局键鼠；
## throttle/steer 由 VehicleActor 经 VehicleCommand 传入（PlayerController 是唯一输入入口）。
## CharacterBody3D + 简化重力；速度/加速度全部来自 GameConfig。

var forward_speed := 0.0     # m/s，正值 = 沿 -Z 前进
var turret_rig: TurretRig
var camera_rig: CameraRig
var _spawn := Transform3D()
var visual_layer: int = GameConfig.VIS_LAYER_VEHICLE   # 003：实例视觉层（A=2，B=4；炮镜只剔除本车层）
var hits_taken := 0           # 003：被命中计数（试射目标计数来源；无装甲/伤害判定）
var defs: VehicleDefinition = null   # 003-R1：由 VehicleActor 注入——驾驶参数唯一来源（null 时回退 GameConfig 常量）
var entity_id := ""   # 003-R2：实体标识注入（命中事件 target 身份来源）
var life_id := 0      # 003-R2：实体生命周期标识（同名车销毁重建后不同）
var _drive_calls := 0 # 003-R2：apply_drive 调用计数（命令单次物理消费断言用）
var capabilities_provider := Callable()
var state_generation := 0

signal hit_registered(identity: Dictionary)   # 003-R2：生产命中事件携带发射时冻结的完整身份（round/shooter/shot/target/life）

func drive_call_count() -> int:
	# 003-R2：驾驶执行次数（验证每物理步恰好一次，不存在双路径并行）
	return _drive_calls

func _ready() -> void:
	collision_layer = GameConfig.LAYER_VEHICLE
	# 003-R1：行驶碰撞包含其他车辆——A 开向 B 不穿过 B（稳定阻挡，无碰撞伤害/推挤）
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE
	floor_snap_length = 0.3
	_spawn = transform
	_build()

func _build() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.5, 4.2)
	cs.shape = shape
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	_mesh_box(Vector3(2.3, 0.8, 3.4), Vector3(0, 0.95, 0), Color(0.42, 0.48, 0.28))      # 车体
	_mesh_box(Vector3(0.55, 0.6, 3.9), Vector3(-1.25, 0.3, 0), Color(0.18, 0.18, 0.18))  # 左履带
	_mesh_box(Vector3(0.55, 0.6, 3.9), Vector3(1.25, 0.3, 0), Color(0.18, 0.18, 0.18))   # 右履带
	turret_rig = TurretRig.new()
	turret_rig.name = "TurretPivot"
	turret_rig.position = Vector3(0, 1.35, 0)
	turret_rig.visual_layer = visual_layer
	add_child(turret_rig)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraPivot"
	camera_rig.position = Vector3(0, 1.6, 0)
	camera_rig.visual_layer = visual_layer
	add_child(camera_rig)

func _mesh_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.layers = visual_layer
	add_child(mi)
	return mi

func apply_drive(throttle: float, steer: float, delta: float) -> void:
	# 003：统一命令驱动（throttle ∈ [-1,1]，steer ∈ [-1,1] 正 = 右转）
	# 003-R1：参数来自 VehicleDefinition（defs 注入）；null 时回退 GameConfig 常量
	_drive_calls += 1   # 003-R2：执行计数（提交≠执行的验证证据）
	if capabilities_provider.is_valid():
		var caps: Dictionary = capabilities_provider.call()
		if not caps.drive:
			throttle = 0.0
		if not caps.steer:
			steer = 0.0
	var fwd_max: float = defs.forward_max_speed if defs != null else GameConfig.FORWARD_MAX_SPEED
	var rev_max: float = defs.reverse_max_speed if defs != null else GameConfig.REVERSE_MAX_SPEED
	var fwd_acc: float = defs.forward_accel if defs != null else GameConfig.FORWARD_ACCEL
	var rev_acc: float = defs.reverse_accel if defs != null else GameConfig.REVERSE_ACCEL
	var brake: float = defs.brake_decel if defs != null else GameConfig.BRAKE_DECEL
	var coast: float = defs.coast_decel if defs != null else GameConfig.COAST_DECEL
	var turn: float = defs.hull_turn_speed if defs != null else GameConfig.HULL_TURN_SPEED
	var target := 0.0
	if throttle > 0.0:
		target = throttle * fwd_max
	elif throttle < 0.0:
		target = throttle * rev_max
	if throttle != 0.0:
		var braking: bool = signf(forward_speed) != signf(throttle) and absf(forward_speed) > 0.05
		var rate := brake if braking else (fwd_acc if throttle > 0.0 else rev_acc)
		forward_speed = move_toward(forward_speed, target, rate * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, coast * delta)
	rotation.y += deg_to_rad(turn) * steer * delta
	# 003-R1：前向用 global basis——actor 带非零 Y 旋转出生时移动沿车头方向
	# （velocity 是全局坐标；local basis 在旋转父级下会丢失出生朝向）
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * forward_speed
	velocity.z = fwd.z * forward_speed
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GameConfig.GRAVITY * delta
	move_and_slide()

func set_spawn(t: Transform3D) -> void:
	# 003：由 VehicleActor 在装配后记录真实出生点（reset 回到该点）
	_spawn = t

func register_hit(identity: Dictionary) -> void:
	# 003：真实生产命中事件（由 gunner 命中结算调用；每发只调一次）
	# 003-R2：事件携带发射时冻结的完整身份；用独立副本传递，
	# 多个监听者之间不会互相改写对方看到的结果
	hits_taken += 1
	hit_registered.emit(identity.duplicate(true))

func reset() -> void:
	transform = _spawn
	forward_speed = 0.0
	velocity = Vector3.ZERO
	hits_taken = 0
