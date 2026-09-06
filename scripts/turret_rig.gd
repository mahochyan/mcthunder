class_name TurretRig
extends Node3D
## 炮塔/炮管（职责：瞄准执行）。按有限转速追随全局瞄准角；车体转向不改变观察方向。
## 炮管俯仰限制 [BARREL_PITCH_MIN, BARREL_PITCH_MAX]；后坐/炮口闪光特效。

const BARREL_BASE_Z := -1.2

var cam_rig: CameraRig = null   # 由 main 注入（瞄准角来源）
var barrel_pivot: Node3D
var muzzle: Node3D
var barrel_mesh: MeshInstance3D
var _flash: MeshInstance3D
var _flash_left := 0.0
var _recoil := 0.0

func _ready() -> void:
	var tm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.55, 1.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.54, 0.32)
	box.material = mat
	tm.mesh = box
	tm.position = Vector3(0, 0.275, 0.1)
	tm.layers = GameConfig.VIS_LAYER_VEHICLE
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
	barrel_mesh.layers = GameConfig.VIS_LAYER_VEHICLE
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

func _process(delta: float) -> void:
	if cam_rig != null:
		var hull = get_parent()
		var hull_yaw: float = hull.global_rotation.y if hull != null else 0.0
		var desired_local := wrapf(cam_rig.aim_yaw - hull_yaw, -PI, PI)
		var max_step := deg_to_rad(GameConfig.TURRET_YAW_SPEED) * delta
		var cur := rotation.y
		rotation.y = cur + clampf(wrapf(desired_local - cur, -PI, PI), -max_step, max_step)
		var pitch_target := clampf(cam_rig.aim_pitch, deg_to_rad(GameConfig.BARREL_PITCH_MIN), deg_to_rad(GameConfig.BARREL_PITCH_MAX))
		barrel_pivot.rotation.x = move_toward(barrel_pivot.rotation.x, pitch_target, deg_to_rad(GameConfig.TURRET_PITCH_SPEED) * delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.0)
	barrel_mesh.position.z = BARREL_BASE_Z + _recoil
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false

func snap_to_aim() -> void:
	# 立即对齐瞄准角（重置与自动检查使用；正常运行靠有限转速追随）
	if cam_rig == null:
		return
	var hull = get_parent()
	var hull_yaw: float = hull.global_rotation.y if hull != null else 0.0
	rotation.y = wrapf(cam_rig.aim_yaw - hull_yaw, -PI, PI)
	barrel_pivot.rotation.x = clampf(cam_rig.aim_pitch, deg_to_rad(GameConfig.BARREL_PITCH_MIN), deg_to_rad(GameConfig.BARREL_PITCH_MAX))

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