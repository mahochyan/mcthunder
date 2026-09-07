class_name PlayerController
extends Node
## 003：本地玩家控制器——唯一读取全局键鼠的入口。
## 鼠标 → 相机意图（cam_rig.set_aim）；键鼠 → VehicleCommand（throttle/steer/aim_held）。
## fire 边沿用 Input.is_action_just_pressed（Input 系统内部跟踪按下边沿，跨帧的
## release→press 不会被 _process 的轮询间隔吞掉）；暂停时不检测（暂停中按下/恢复后
## 按住都不触发，恢复后由 gunner 的 resume_grace 把关误击发）。

var cam_rig: CameraRig = null   # 由 actor 注入（本地控制者设置时）
var gunner: Gunner = null       # 由 actor 注入（fire 消费）
var _fire_pending := false

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if Input.is_action_just_pressed("fire"):
		_fire_pending = true
	if _fire_pending and gunner != null:
		gunner.request_fire()
		_fire_pending = false

func _unhandled_input(event: InputEvent) -> void:
	if cam_rig == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_rig.set_aim(
			cam_rig.aim_yaw - event.relative.x * GameConfig.MOUSE_SENS,
			cam_rig.aim_pitch - event.relative.y * GameConfig.MOUSE_SENS)

func poll() -> VehicleCommand:
	# 每物理帧由 VehicleActor 调用（驾驶/炮镜命令；fire 已在 _process 消费）
	var cmd := VehicleCommand.new()
	cmd.throttle = (1.0 if Input.is_action_pressed("move_forward") else 0.0) - (1.0 if Input.is_action_pressed("move_back") else 0.0)
	cmd.steer = Input.get_axis("turn_right", "turn_left")
	cmd.aim_held = Input.is_action_pressed("aim")
	cmd.clear_aim = true   # 本地玩家每帧清除脚本瞄点，回到相机意图
	return cmd
