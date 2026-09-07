class_name PlayerController
extends Node
## 003：本地玩家控制器——唯一读取全局键鼠的节点。
## 003-R1：不直接调用 Gunner——只生成意图与开火请求（VehicleCommand），
## 由 VehicleActor.apply_command 在物理步统一验证并消费一次。
## fire 边沿用 Input.is_action_just_pressed（Input 系统内部跟踪按下边沿，
## 跨帧的 release→press 不会被 _process 的轮询间隔吞掉）；暂停时清空待发请求
## （暂停中按下/恢复后按住都不触发，也不得暂停后补发旧请求）。

var cam_rig: CameraRig = null   # 由 actor 注入（本地控制者设置时）
var gunner: Gunner = null       # 由 actor 注入（仅用于状态查询，不直接调用开火）
var _fire_pending := false

func _process(_delta: float) -> void:
	if get_tree().paused:
		_fire_pending = false   # 003-R1：暂停清空待发请求，恢复后不补发
		return
	if Input.is_action_just_pressed("fire"):
		_fire_pending = true

func _unhandled_input(event: InputEvent) -> void:
	if cam_rig == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_rig.set_aim(
			cam_rig.aim_yaw - event.relative.x * GameConfig.MOUSE_SENS,
			cam_rig.aim_pitch - event.relative.y * GameConfig.MOUSE_SENS)

func poll() -> VehicleCommand:
	# 每物理帧由 VehicleActor 调用；fire 请求在此消费一次（不重复射击）
	var cmd := VehicleCommand.new()
	cmd.throttle = (1.0 if Input.is_action_pressed("move_forward") else 0.0) - (1.0 if Input.is_action_pressed("move_back") else 0.0)
	cmd.steer = Input.get_axis("turn_right", "turn_left")
	cmd.aim_held = Input.is_action_pressed("aim")
	cmd.clear_aim = true   # 本地玩家每帧清除脚本瞄点，回到相机意图
	cmd.fire_requested = _fire_pending
	_fire_pending = false
	return cmd

func reset_pending() -> void:
	# 003-R1：重置清理待发命令（由 VehicleActor.reset_vehicle 调用）
	_fire_pending = false
