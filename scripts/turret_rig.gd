class_name TurretRig
extends Node3D
## 炮塔/炮管（职责：瞄准执行）。按有限转速追随全局瞄准角；车体转向不改变观察方向。
## 炮管俯仰限制 [BARREL_PITCH_MIN, BARREL_PITCH_MAX]；后坐/炮口闪光特效。

const BARREL_BASE_Z := -1.2

var cam_rig: CameraRig = null   # 由 actor 注入（默认瞄准角来源）
var visual_layer: int = GameConfig.VIS_LAYER_VEHICLE   # 003：实例视觉层（A=2，B=4）
var defs: VehicleDefinition = null   # 003-R1：由 actor 注入——转速/俯仰限位唯一来源（null 回退 GameConfig）
var barrel_pivot: Node3D
var muzzle: Node3D
var barrel_mesh: MeshInstance3D
var _flash: MeshInstance3D
var _flash_left := 0.0
var _recoil := 0.0
var _aim_override: Vector3 = Vector3.ZERO   # 003：脚本命令瞄准点（B 测试用）
var _has_aim_override := false

func _ready() -> void:
	var tm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.55, 1.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.54, 0.32)
	box.material = mat
	tm.mesh = box
	tm.position = Vector3(0, 0.275, 0.1)
	tm.layers = visual_layer
	add_child(tm)
	barrel_pivot = Node3D.new()
	barrel_pivot.name = "BarrelPivot"
	barrel_pivot.position = Vector3(0, 0.15, -0.75)
	add_child(barrel_pivot)
	barrel_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, 2.4)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.25, 0.25, 0.25)
	bm.material = bmat
	barrel_mesh.mesh = bm
	barrel_mesh.position = Vector3(0, 0, BARREL_BASE_Z)
	barrel_mesh.layers = visual_layer
	barrel_pivot.add_child(barrel_mesh)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -2.45)
	barrel_pivot.add_child(muzzle)
	_flash = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.85, 0.3)
	sm.material = fmat
	_flash.mesh = sm
	_flash.position = Vector3(0, 0, -2.5)
	_flash.layers = 3
	_flash.visible = false
	barrel_pivot.add_child(_flash)

func set_aim_point(p: Vector3) -> void:
	# 003：脚本命令瞄准点（B 测试目标用；A 由 PlayerController 经 cam_rig 意图）
	_aim_override = p
	_has_aim_override = true

func clear_aim_point() -> void:
	_has_aim_override = false

func _aim_point() -> Vector3:
	if _has_aim_override:
		return _aim_override
	if cam_rig != null:
		return cam_rig.intent_point()
	return Vector3.ZERO

func _process(delta: float) -> void:
	if cam_rig != null or _has_aim_override:
		var hull = get_parent()
		var hull_yaw: float = hull.global_rotation.y if hull != null else 0.0
		# 002-R2：目标角由期望世界瞄点 P 反推（相机与炮管位置不同，
		# 方向不必相同，但必须汇聚到同一点）；保留有限转速与俯仰限位
		# 002-R3：水平目标角符号修正——炮管 -Z 前向、右手系、无镜像约定下
		# 前向 = (-sin yaw, 0, -cos yaw)，故世界 yaw = atan2(-dx, -dz)
		# 003-R1：转速/限位来自 VehicleDefinition（defs 注入）
		var yaw_speed: float = defs.turret_yaw_speed if defs != null else GameConfig.TURRET_YAW_SPEED
		var pitch_speed: float = defs.turret_pitch_speed if defs != null else GameConfig.TURRET_PITCH_SPEED
		var P := _aim_point()
		var target := _target_angles(P)
		var desired_local := wrapf(target.y - hull_yaw, -PI, PI)
		var max_step := deg_to_rad(yaw_speed) * delta
		var cur := rotation.y
		rotation.y = cur + clampf(wrapf(desired_local - cur, -PI, PI), -max_step, max_step)
		barrel_pivot.rotation.x = move_toward(barrel_pivot.rotation.x, target.x, deg_to_rad(pitch_speed) * delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.0)
	barrel_mesh.position.z = BARREL_BASE_Z + _recoil
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false

func _target_angles(P: Vector3) -> Vector2:
	# 002-R3：共用目标角计算（正常追赶与 snap_to_aim 两条路径必须一致）。
	# 返回 (pitch, yaw_global)：由期望世界瞄点 P 与炮根位置反推武器目标方向。
	# 炮管 -Z 前向、右手系、无镜像：前向 = (-sin yaw, 0, -cos yaw)，
	# 目标方向 d = P - 炮根 → yaw = atan2(-d.x, -d.z)（负号不能省略）。
	# 003-R1：俯仰限位来自 VehicleDefinition（defs 注入）
	var p_min: float = defs.barrel_pitch_min if defs != null else GameConfig.BARREL_PITCH_MIN
	var p_max: float = defs.barrel_pitch_max if defs != null else GameConfig.BARREL_PITCH_MAX
	var pivot := barrel_pivot.global_position
	var d := P - pivot
	var yaw_global := atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, sqrt(d.x * d.x + d.z * d.z)), deg_to_rad(p_min), deg_to_rad(p_max))
	return Vector2(pitch, yaw_global)

func snap_to_aim() -> void:
	# 立即对齐期望世界瞄点 P（重置与自动检查使用；正常运行靠有限转速追随）
	if cam_rig == null and not _has_aim_override:
		return
	var hull = get_parent()
	var hull_yaw: float = hull.global_rotation.y if hull != null else 0.0
	var target := _target_angles(_aim_point())
	rotation.y = wrapf(target.y - hull_yaw, -PI, PI)
	barrel_pivot.rotation.x = target.x

func kick_recoil() -> void:
	_recoil = 0.22
	_flash.visible = true
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_flash_left = 0.06

func barrel_direction() -> Vector3:
	# 炮管实际指向（世界系）
	return -barrel_pivot.global_transform.basis.z

func reset_state() -> void:
	_recoil = 0.0
	_flash_left = 0.0
	_flash.visible = false
	barrel_mesh.position.z = BARREL_BASE_Z