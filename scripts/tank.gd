class_name TankVehicle
extends CharacterBody3D
## 车辆运动（职责：驾驶）。W 前进 / S 后退 / A·D 车体原地转向；无左右平移。
## CharacterBody3D + 简化重力；速度/加速度全部来自 GameConfig。

var forward_speed := 0.0     # m/s，正值 = 沿 -Z 前进
var turret_rig: TurretRig
var camera_rig: CameraRig
var _spawn := Transform3D()

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
	add_child(turret_rig)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraPivot"
	camera_rig.position = Vector3(0, 1.6, 0)
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
	mi.layers = GameConfig.VIS_LAYER_VEHICLE
	add_child(mi)
	return mi

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle += 1.0
	if Input.is_action_pressed("move_back"):
		throttle -= 1.0
	var target := 0.0
	if throttle > 0.0:
		target = throttle * GameConfig.FORWARD_MAX_SPEED
	elif throttle < 0.0:
		target = throttle * GameConfig.REVERSE_MAX_SPEED
	if throttle != 0.0:
		var braking: bool = signf(forward_speed) != signf(throttle) and absf(forward_speed) > 0.05
		var rate := GameConfig.BRAKE_DECEL if braking else (GameConfig.FORWARD_ACCEL if throttle > 0.0 else GameConfig.REVERSE_ACCEL)
		forward_speed = move_toward(forward_speed, target, rate * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, GameConfig.COAST_DECEL * delta)
	var turn := Input.get_axis("turn_right", "turn_left")
	rotation.y += deg_to_rad(GameConfig.HULL_TURN_SPEED) * turn * delta
	var fwd := -transform.basis.z
	velocity.x = fwd.x * forward_speed
	velocity.z = fwd.z * forward_speed
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GameConfig.GRAVITY * delta
	move_and_slide()

func reset() -> void:
	transform = _spawn
	forward_speed = 0.0
	velocity = Vector3.ZERO