class_name VehicleActor
extends Node3D
## 003：车辆实体容器——统一生成/销毁/本地控制者设置。
## 拥有：共享定义（VehicleDefinition/WeaponDefinition/ShellDefinition）、
## 独立 VehicleRuntimeState、TankVehicle（驾驶）、TurretRig（瞄准）、
## CameraRig（观察）、Gunner（射击）、可选 PlayerController（本地控制者）。
## apply_command 是唯一命令入口：驱动/炮塔/武器走同一套限制。

var definition: VehicleDefinition
var weapon: WeaponDefinition
var shell: ShellDefinition
var state: VehicleRuntimeState
var tank: TankVehicle
var turret: TurretRig
var cam_rig: CameraRig
var gunner: Gunner
var controller: Node = null   # PlayerController（本地控制者）或 null（零命令静止）
var label3d: Label3D

func setup(defs: VehicleDefs, vehicle_id: String, entity_id: String, team_id: int, spawn: Transform3D, visual_layer: int, ctrl: Node) -> Dictionary:
	# 返回 {ok, errors}；定义引用解析失败 → 明确报错并定位字段
	var res := defs.resolve_vehicle(vehicle_id)
	if not res.ok:
		return res
	definition = res.vehicle
	weapon = res.weapon
	shell = res.shell
	state = VehicleRuntimeState.new()
	state.entity_id = entity_id
	state.team_id = team_id
	state.definition_id = definition.id
	controller = ctrl
	transform = spawn
	var ps: PackedScene = load("res://scenes/tank.tscn")
	tank = ps.instantiate()
	tank.name = "Tank"
	tank.visual_layer = visual_layer
	add_child(tank)
	tank.position = Vector3.ZERO   # 003：位置由 actor.transform 统一管理（tank.tscn 根自带偏移清零）
	tank.set_spawn(tank.transform)   # 003：局部出生点（世界位置 = actor 全局变换）
	turret = tank.turret_rig
	cam_rig = tank.camera_rig
	turret.cam_rig = cam_rig
	cam_rig.turret = turret
	cam_rig.tank = tank
	cam_rig.visual_layer = visual_layer
	gunner = Gunner.new()
	gunner.name = "Gunner"
	add_child(gunner)
	gunner.setup(tank, turret)
	process_mode = Node.PROCESS_MODE_PAUSABLE   # 003：暂停时整实体（驱动/武器）冻结
	tank.process_mode = Node.PROCESS_MODE_PAUSABLE
	gunner.process_mode = Node.PROCESS_MODE_PAUSABLE
	if controller != null:
		controller.cam_rig = cam_rig
		controller.gunner = gunner
		cam_rig.set_local_control(true)
	else:
		cam_rig.set_local_control(false)
	# 003：A/PLAYER 与 B/TEST TARGET 明确标识（不改共享配置伪造实例状态）
	label3d = Label3D.new()
	label3d.text = entity_id
	label3d.position = Vector3(0, 2.7, 0)
	label3d.font_size = 48
	label3d.outline_size = 10
	label3d.modulate = Color(0.4, 1.0, 0.4) if controller != null else Color(1.0, 0.85, 0.3)
	tank.add_child(label3d)
	return {"ok": true}

func _physics_process(delta: float) -> void:
	var cmd := VehicleCommand.new()
	if controller != null:
		cmd = controller.poll()
	apply_command(cmd, delta)

func apply_command(cmd: VehicleCommand, delta: float) -> void:
	# 统一命令入口：驱动/炮塔/武器走同一套限制（冷却/俯仰限位/遮挡由生产逻辑把关）
	tank.apply_drive(cmd.throttle, cmd.steer, delta)
	if cmd.has_aim_point:
		turret.set_aim_point(cmd.aim_world_point)
	elif cmd.clear_aim:
		turret.clear_aim_point()
	cam_rig.set_sight_requested(cmd.aim_held)
	if cmd.fire_requested:
		gunner.request_fire()
	# 状态同步：真实状态来源（HUD/试射目标只读，不另算一套显示用结果）
	state.forward_speed = tank.forward_speed
	state.turret_yaw = turret.global_rotation.y
	state.gun_pitch = turret.barrel_pivot.rotation.x
	state.cooldown_left = gunner.cooldown_left
	state.resume_grace = gunner.resume_grace
	state.shots_fired = gunner.shots_fired
	state.last_shot_result = gunner.last_shot_result
	state.hits_taken = tank.hits_taken

func reset_vehicle() -> void:
	# 003：单车重置——不污染其他车/靶场/试射目标
	tank.reset()
	cam_rig.aim_yaw = 0.0
	cam_rig.aim_pitch = 0.0
	turret.snap_to_aim()
	gunner.reset_state()
	turret.reset_state()
	state.reset()
