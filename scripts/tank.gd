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

signal hit_registered        # 003：真实生产命中事件（register_hit 每发只触发一次）

func _ready() -> void:
	collision_layer = GameConfig.LAYER_VEHICLE
	collision_mask = GameConfig.LAYER_WORLD
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
	var fwd := -transform.basis.z
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

func register_hit() -> void:
	# 003：真实生产命中事件（由 gunner 命中结算调用；每发只调一次）
	hits_taken += 1
	hit_registered.emit()

func reset() -> void:
	transform = _spawn
	forward_speed = 0.0
	velocity = Vector3.ZERO
	hits_taken = 0
