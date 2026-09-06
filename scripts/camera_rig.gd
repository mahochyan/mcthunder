class_name CameraRig
extends Node3D
## 相机（职责：观察/瞄准视角）。鼠标控制全局瞄准角；车体转向不甩回视角。
## 第三人称防穿墙（射线查询排除本车）；按住右键进入炮镜（沿炮管实际方向，剔除自身网格）。

var cam: Camera3D
var turret: TurretRig = null    # 由 main 注入
var tank: TankVehicle = null    # 由 main 注入
var aim_yaw := 0.0              # 全局观察朝向（弧度，0 = -Z）
var aim_pitch := 0.0            # 观察俯仰（弧度，正 = 抬头）
var sight := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 400.0
	cam.fov = GameConfig.MAIN_FOV
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.0, 6.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		aim_yaw = wrapf(aim_yaw - event.relative.x * GameConfig.MOUSE_SENS, -PI, PI)
		aim_pitch = clampf(aim_pitch - event.relative.y * GameConfig.MOUSE_SENS, deg_to_rad(GameConfig.CAM_PITCH_MIN), deg_to_rad(GameConfig.CAM_PITCH_MAX))

func _exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if tank != null:
		ex.append(tank.get_rid())
	return ex

func _process(_delta: float) -> void:
	sight = Input.is_action_pressed("aim") and turret != null
	if sight:
		# 炮镜：贴在炮根上方、沿炮管实际方向看；cull_mask 剔除本车视觉层
		var bdir := turret.barrel_direction()
		var bp := turret.barrel_pivot.global_position
		cam.global_position = bp + Vector3.UP * 0.45 - bdir * 0.35
		cam.look_at(cam.global_position + bdir * 50.0)
		cam.fov = GameConfig.SIGHT_FOV
		cam.cull_mask &= ~GameConfig.VIS_LAYER_VEHICLE
	else:
		var pivot_pos := global_position
		var dir_h := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
		# 002-R1：视线随 aim_pitch 同步俯仰——相机中心射线（=玩家想瞄方向）与炮管
		# 指向一致；机位仍沿水平方向绕 pivot（保持固定高度），防穿墙查询不变
		var cp := cos(aim_pitch)
		var dir3d := Vector3(dir_h.x * cp, sin(aim_pitch), dir_h.z * cp)
		var desired := pivot_pos - dir_h * GameConfig.CAM_DISTANCE + Vector3.UP * GameConfig.CAM_HEIGHT
		var from := pivot_pos + Vector3.UP * 0.3
		var hit := _ray(from, desired)
		if not hit.is_empty():
			desired = hit.position + hit.normal * 0.3   # 防穿墙：贴墙缩距
		cam.global_position = desired
		# 002-R1：相机前向 ≡ dir3d（从相机位置沿瞄准方向看）→ 中心射线与炮管指向精确一致
		cam.look_at(cam.global_position + dir3d * 12.0)
		cam.fov = GameConfig.MAIN_FOV
		cam.cull_mask |= GameConfig.VIS_LAYER_VEHICLE

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_WORLD, _exclude())
	return space.intersect_ray(q)

func get_aim_point() -> Vector3:
	# 玩家想瞄的点：相机中心射线（第三人称下即屏幕中心方向）
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit := _ray(from, from + dir * 150.0)
	if not hit.is_empty():
		return hit.position
	return from + dir * 60.0