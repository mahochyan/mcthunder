class_name VehicleActor
extends Node3D
## 003：车辆实体容器——统一生成/销毁/本地控制者设置。
## 拥有：共享定义（VehicleDefinition/WeaponDefinition/ShellDefinition）、
## 独立 VehicleRuntimeState、TankVehicle（驾驶）、TurretRig（瞄准）、
## CameraRig（观察）、Gunner（射击）、可选 PlayerController（本地控制者）。
## 003-R2：submit_command 是唯一命令提交入口（验证/复制/暂存，不执行）；
## 每辆车唯一的 _physics_process 每步消费一次——玩家与脚本同一执行器。

static var _life_counter := 0   # 003-R2：实体生命周期计数（同名车销毁重建后新旧区分）

var definition: VehicleDefinition
var weapon: WeaponDefinition
var shell: ShellDefinition
var state: VehicleRuntimeState
var entity_id := ""   # 003-R1：实体标识（HUD 提示/命中事件来源）
var life_id := 0      # 003-R2：实体生命周期标识（setup 生成；同 id 重建后不同）
var tank: TankVehicle
var turret: TurretRig
var cam_rig: CameraRig
var gunner: Gunner
var controller: Node = null   # PlayerController（本地控制者）或 null（零命令静止）
var label3d: Label3D
var _mailbox := CommandMailbox.new()   # 003-R2：命令暂存
var debug_command_trace := false       # 003-R2：提交/消费/执行三处调试记录（默认关）
var _consume_count := 0                # 003-R2：本步消费计数（调试用）

func setup(defs: VehicleDefs, vehicle_id: String, entity_id: String, team_id: int, spawn: Transform3D, visual_layer: int, ctrl: Node) -> Dictionary:
	# 返回 {ok, errors}；定义引用解析失败 → 明确报错并定位字段；
	# 003-R1：校验失败受控停止——不继续生成半有效实体（调用方负责释放本节点）
	var res := defs.resolve_vehicle(vehicle_id)
	if not res.ok:
		return res
	definition = res.vehicle
	weapon = res.weapon
	shell = res.shell
	_life_counter += 1
	life_id = _life_counter   # 003-R2：同名车重建后生命周期不同
	state = VehicleRuntimeState.new()
	state.entity_id = entity_id
	state.team_id = team_id
	state.definition_id = definition.id
	self.entity_id = entity_id   # 003-R1：实体标识（HUD 提示/命中事件来源）
	controller = ctrl
	transform = spawn
	var ps: PackedScene = load("res://scenes/tank.tscn")
	tank = ps.instantiate()
	tank.name = "Tank"
	tank.visual_layer = visual_layer
	tank.defs = definition   # 003-R1：驾驶参数唯一来源
	add_child(tank)
	tank.position = Vector3.ZERO   # 003：位置由 actor.transform 统一管理（tank.tscn 根自带偏移清零）
	tank.set_spawn(tank.transform)   # 003：局部出生点（世界位置 = actor 全局变换）
	turret = tank.turret_rig
	cam_rig = tank.camera_rig
	turret.cam_rig = cam_rig
	turret.defs = definition   # 003-R1：炮塔转速/俯仰限位唯一来源
	cam_rig.turret = turret
	cam_rig.tank = tank
	cam_rig.visual_layer = visual_layer
	gunner = Gunner.new()
	gunner.name = "Gunner"
	add_child(gunner)
	gunner.setup(tank, turret, weapon)   # 003-R1：装填/射程唯一来源
	gunner.shooter_id = entity_id   # 003-R1：命中事件携带射手标识
	tank.entity_id = entity_id   # 003-R2：命中事件 target 身份来源
	tank.life_id = life_id       # 003-R2：目标生命周期标识
	process_mode = Node.PROCESS_MODE_PAUSABLE   # 003：暂停时整实体（驱动/武器）冻结
	tank.process_mode = Node.PROCESS_MODE_PAUSABLE
	gunner.process_mode = Node.PROCESS_MODE_PAUSABLE
	set_controller(ctrl)   # 003-R1：统一控制者绑定入口（含相机 current 管理）
	# 003：A/PLAYER 与 B/TEST TARGET 明确标识（不改共享配置伪造实例状态）
	# 003-R1：提示来自实际状态（控制者绑定是实际状态，不是写死的标签文字）
	label3d = Label3D.new()
	label3d.text = entity_id + (" (PLAYER)" if controller != null else " (TEST TARGET)")
	label3d.position = Vector3(0, 2.7, 0)
	label3d.font_size = 48
	label3d.outline_size = 10
	label3d.modulate = Color(0.4, 1.0, 0.4) if controller != null else Color(1.0, 0.85, 0.3)
	tank.add_child(label3d)
	return {"ok": true}

func set_controller(ctrl: Node) -> void:
	# 003-R1：统一控制者绑定/解绑——解绑清理引用；只有被控制的车拥有有效本地游戏相机
	# 003-R2：控制者变更时清空暂存（不跨绑定继承旧请求）
	_mailbox.clear()
	if controller != null:
		controller.cam_rig = null
		controller.gunner = null
	controller = ctrl
	if controller != null:
		controller.cam_rig = cam_rig
		controller.gunner = gunner
		cam_rig.set_local_control(true)
	else:
		cam_rig.set_local_control(false)

func _notification(what: int) -> void:
	# 003-R2：暂停瞬间清空暂存——恢复时不补执行上一轮待发请求（自动兜底；
	# 暂停/重置/解绑路径另有显式清理，见 pause_block/clear_commands）
	if what == NOTIFICATION_PAUSED:
		_mailbox.clear()

func pause_block(value: bool) -> void:
	# 003-R2：暂停/恢复等状态切换的显式清理入口（main._pause/_resume 调用）——
	# 不指望已停止物理回调的 actor 自己清掉暂存
	_mailbox.set_blocked(value)

func clear_commands() -> void:
	# 003-R2：重开/解绑路径显式清空暂存
	_mailbox.clear()

func _exit_tree() -> void:
	# 003-R1：销毁后引用清理（控制者不再指向已释放组件）
	if controller != null:
		controller.cam_rig = null
		controller.gunner = null

func submit_command(cmd: VehicleCommand) -> bool:
	# 003-R2：唯一命令提交入口——验证/复制/暂存，不移动、不射击。
	# 玩家输入与脚本命令走同一入口；执行由本车唯一的 _physics_process 完成。
	# 返回 false = 本步命令被拒绝（暂停/实体无效/无效瞄点）。
	if not is_inside_tree() or get_tree().paused:
		_mailbox.clear()   # 暂停拒绝并清空（恢复不补执行）
		return false
	if not is_instance_valid(tank) or not is_instance_valid(gunner) or not is_instance_valid(turret):
		return false
	if cmd != null and cmd.has_aim_point:
		var p := cmd.aim_world_point
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			return false   # 无效瞄点整条拒绝（NaN/INF 不得进入瞄准）
	var ok := _mailbox.submit(cmd)
	if ok and debug_command_trace and cmd != null:
		print("[cmd-trace] submit entity=%s throttle=%.2f fire=%s" % [entity_id, cmd.throttle, str(cmd.fire_requested)])
	return ok

func _physics_process(delta: float) -> void:
	# 003-R2：每辆车唯一物理执行器——有控制者先经同一提交入口收集本步命令，
	# 然后消费恰好一次（无输入 = 零命令静止）；脚本不再传入 delta 决定运动时间。
	_consume_count = 0
	if controller != null:
		submit_command(controller.poll())
	var cmd := _mailbox.consume()
	_consume_count += 1
	if debug_command_trace:
		print("[cmd-trace] consume entity=%s tick=%d throttle=%.2f fire=%s" % [entity_id, Engine.get_physics_frames(), cmd.throttle, str(cmd.fire_requested)])
	_apply_command_once(cmd, delta)

func _apply_command_once(cmd: VehicleCommand, delta: float) -> void:
	# 003-R2：命令执行体（由原 apply_command 改名而来；驾驶/瞄准算法不变）。
	# 003-R1：入口合法性约束——实体无效拒绝、有限值、输入范围钳制
	if not is_instance_valid(tank) or not is_instance_valid(gunner) or not is_instance_valid(turret):
		return
	var throttle := clampf(cmd.throttle if is_finite(cmd.throttle) else 0.0, -1.0, 1.0)
	var steer := clampf(cmd.steer if is_finite(cmd.steer) else 0.0, -1.0, 1.0)
	if debug_command_trace:
		print("[cmd-trace] execute entity=%s tick=%d throttle=%.2f steer=%.2f fire=%s" % [entity_id, Engine.get_physics_frames(), throttle, steer, str(cmd.fire_requested)])
	tank.apply_drive(throttle, steer, delta)
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
	# 003-R1：清理旧瞄点/待发命令/炮镜请求/瞬时状态
	# 003-R2：重置清空暂存（不跨回合执行旧请求）
	_mailbox.clear()
	tank.reset()
	cam_rig.aim_yaw = 0.0
	cam_rig.aim_pitch = 0.0
	cam_rig.set_sight_requested(false)
	turret.clear_aim_point()   # 先清旧瞄点再 snap（否则 snap 会追旧脚本目标）
	turret.snap_to_aim()
	gunner.reset_state()
	turret.reset_state()
	if controller != null and controller.has_method("reset_pending"):
		controller.reset_pending()
	state.reset()
