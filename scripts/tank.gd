class_name TankVehicle
extends CharacterBody3D
## 车辆运动（职责：驾驶）。003：命令驱动——不再直接读取全局键鼠；
## throttle/steer 由 VehicleActor 经 VehicleCommand 传入（PlayerController 是唯一输入入口）。
## CharacterBody3D + 简化重力；速度/加速度全部来自 GameConfig。

var forward_speed := 0.0     # m/s，正值 = 沿 -Z 前进
var powertrain := DrivePowertrain.new()
var tracks := TrackDrive.new()
var fallback_definition := VehicleDefinition.new()
var presentation_enabled := true
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
var ground_state: Dictionary = {"grounded":false,"slope_deg":0.0,"normal":Vector3.UP,"points":[],"normals":[]}
var slope_blocked := false
var recoil_velocity := Vector3.ZERO # World-space response, separate from engine speed.

func kick_recoil(shot_direction: Vector3) -> void:
	if not shot_direction.is_finite() or shot_direction.length_squared() < 0.01: return
	var up: Vector3 = ground_state.normal if ground_state.grounded else Vector3.UP
	recoil_velocity -= shot_direction.normalized().slide(up)*GameConfig.CHASSIS_RECOIL_SPEED_MPS
	recoil_velocity = recoil_velocity.limit_length(GameConfig.CHASSIS_RECOIL_MAX_MPS)

signal hit_registered(identity: Dictionary)   # 003-R2：生产命中事件携带发射时冻结的完整身份（round/shooter/shot/target/life）

func drive_call_count() -> int:
	# 003-R2：驾驶执行次数（验证每物理步恰好一次，不存在双路径并行）
	return _drive_calls

func _ready() -> void:
	collision_layer = GameConfig.LAYER_VEHICLE
	# 003-R1：行驶碰撞包含其他车辆——A 开向 B 不穿过 B（稳定阻挡，无碰撞伤害/推挤）
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE
	floor_snap_length = GameConfig.DRIVE_FLOOR_SNAP_M
	floor_max_angle = deg_to_rad(defs.max_slope_deg if defs != null else GameConfig.DRIVE_MAX_SLOPE_DEG)
	floor_stop_on_slope = true
	floor_constant_speed = true
	_spawn = transform
	_build()

func _build() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = defs.drive_collision_size if defs != null else GameConfig.DRIVE_COLLISION_SIZE
	cs.shape = shape
	cs.position = defs.drive_collision_center if defs != null else GameConfig.DRIVE_COLLISION_CENTER
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
	camera_rig.presentation_enabled = presentation_enabled
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
	mi.add_to_group("base_vehicle_visual")
	add_child(mi)
	return mi

func apply_drive(throttle: float, steer: float, delta: float) -> void:
	# 003：统一命令驱动（throttle ∈ [-1,1]，steer ∈ [-1,1] 正 = 右转）
	# 003-R1：参数来自 VehicleDefinition（defs 注入）；null 时回退 GameConfig 常量
	_drive_calls += 1   # 003-R2：执行计数（提交≠执行的验证证据）
	var track_pivot := false
	var left_available := true
	if capabilities_provider.is_valid():
		var caps: Dictionary = capabilities_provider.call()
		track_pivot=caps.get("track_pivot",false)
		left_available=caps.get("left_track",true)
		if not caps.drive:
			throttle = 0.0
		if not caps.steer:
			steer = 0.0
	var definition := defs if defs!=null else fallback_definition
	var forward := VehiclePose.flat_forward(global_basis)
	var size := defs.drive_collision_size if defs != null else GameConfig.DRIVE_COLLISION_SIZE
	ground_state = GroundProbe.sample(self,forward,Vector2(size.x*0.42,size.z*0.53))
	if track_pivot:
		steer*=float(ground_state.left_support if left_available else ground_state.right_support)
	else: steer*=minf(ground_state.left_support,ground_state.right_support)
	if ground_state.grounded:
		forward_speed=tracks.step(forward_speed,steer,delta,definition)
		if track_pivot: forward_speed=tracks.single_track_pivot(steer,left_available,definition)
		forward = forward.rotated(Vector3.UP,tracks.yaw_rate*delta)
	else:
		# Tracks cannot apply longitudinal or yaw traction without ground support.
		tracks.yaw_rate=0
		powertrain.traction_acceleration=0
		powertrain.braking=false
	var grade := forward.slide(ground_state.normal).normalized().y if ground_state.grounded else 0.0
	if ground_state.grounded:
		if track_pivot: powertrain.reset()
		else: forward_speed=powertrain.step(forward_speed,throttle,grade,true,delta,definition,ground_state.surface_drag,ground_state.traction_support)
	var limit := defs.max_slope_deg if defs != null else GameConfig.DRIVE_MAX_SLOPE_DEG
	slope_blocked = GroundProbe.blocks_uphill(ground_state,forward*signf(forward_speed),limit)
	if slope_blocked: forward_speed = 0.0
	tracks.refresh(forward_speed,definition.drive_profile.track_spacing_m)
	var up := Vector3.UP if ground_state.grounded else global_basis.y.normalized()
	if ground_state.grounded and float(ground_state.slope_deg) <= limit+0.1:
		up = ground_state.normal
	global_basis = VehiclePose.approach(global_basis,VehiclePose.compose(forward,up),delta)
	# 003-R1：前向用 global basis——actor 带非零 Y 旋转出生时移动沿车头方向
	# （velocity 是全局坐标；local basis 在旋转父级下会丢失出生朝向）
	var fwd := forward.slide(up).normalized()
	if is_on_floor() and not slope_blocked:
		velocity = fwd*forward_speed-up
	else:
		velocity.x = forward.x*forward_speed
		velocity.z = forward.z*forward_speed
		velocity.y -= GameConfig.GRAVITY * delta
	# Use the same collision solver as driving, never teleport a presentation mesh.
	# Integrate exponential damping over the step to avoid frame-rate-dependent travel.
	var attenuation := exp(-GameConfig.CHASSIS_RECOIL_DAMPING*delta)
	var recoil_step := recoil_velocity*(1.0-attenuation)/maxf(GameConfig.CHASSIS_RECOIL_DAMPING*delta,0.000001)
	velocity += recoil_step
	move_and_slide()
	recoil_velocity *= attenuation
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if recoil_velocity.dot(normal) < 0: recoil_velocity = recoil_velocity.slide(normal)
	if recoil_velocity.length_squared() < 0.000001: recoil_velocity = Vector3.ZERO

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
	powertrain.reset()
	tracks.reset()
	recoil_velocity = Vector3.ZERO
	transform = _spawn
	forward_speed = 0.0
	velocity = Vector3.ZERO
	hits_taken = 0
	slope_blocked = false
	ground_state = {"grounded":false,"slope_deg":0.0,"normal":Vector3.UP,"points":[],"normals":[]}
