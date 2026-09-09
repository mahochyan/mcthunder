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
var commands_enabled := true    # 005-d：调试面板打开时禁用意图生成（面板不消费弹药/任务，也不得被点击误触开火）
var _fire_pending := false
var _shell_pending := -1
var _recovery_pending: Dictionary = {}
var _recovery_release_guard: Dictionary = {}
var _need_fire_release := false   # 005-R1-C：面板关闭/暂停后必须观察到火键释放才重新允许捕获
var _fire_release_after_frame := -1

func _process(_delta: float) -> void:
	if get_tree().paused:
		_shell_pending = -1
		_recovery_pending.clear()
		_arm_recovery_release()
		_fire_pending = false   # 003-R1：暂停清空待发请求，恢复后不补发
		return
	if not commands_enabled:
		_shell_pending = -1
		_recovery_pending.clear()
		_fire_pending = false   # 005-d：面板打开期间不捕获开火边沿（面板点击=左键=fire 动作）
		return
	if _need_fire_release:
		if Engine.get_process_frames()<=_fire_release_after_frame or Input.is_action_pressed("fire") or Input.is_action_just_pressed("fire"):
			_fire_pending = false
			return
		_need_fire_release = false
		# A menu press and release can share one render frame. Input may still
		# report just_pressed after held became false; discard this entire edge.
		_fire_pending = false
		return
	if Input.is_action_just_pressed("fire"):
		_fire_pending = true
	for i in 2:
		if Input.is_action_just_pressed("shell_%d"%(i+1)): _shell_pending = i
	for action in ["repair","extinguish","replace_crew","cancel_recovery"]:
		if _recovery_release_guard.get(action,false):
			if not Input.is_action_pressed(action): _recovery_release_guard.erase(action)
			continue
		if Input.is_action_just_pressed(action): _recovery_pending[action] = true

func _unhandled_input(event: InputEvent) -> void:
	if not commands_enabled:
		return   # 005-d：面板打开期间不响应鼠标瞄准（避免炮塔随鼠标转向、姿态漂移）
	if cam_rig == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_rig.set_aim(
			cam_rig.aim_yaw - event.relative.x * GameConfig.MOUSE_SENS,
			cam_rig.aim_pitch - event.relative.y * GameConfig.MOUSE_SENS)

func poll() -> VehicleCommand:
	# 每物理帧由 VehicleActor 调用；fire 请求在此消费一次（不重复射击）
	var cmd := VehicleCommand.new()
	if not commands_enabled:
		return cmd   # 005-d：空命令（零油门/零转向/无开火）——车辆滑行自然减速
	cmd.throttle = (1.0 if Input.is_action_pressed("move_forward") else 0.0) - (1.0 if Input.is_action_pressed("move_back") else 0.0)
	cmd.steer = Input.get_axis("turn_right", "turn_left")
	cmd.aim_held = Input.is_action_pressed("aim")
	cmd.clear_aim = true   # 本地玩家每帧清除脚本瞄点，回到相机意图
	cmd.fire_requested = _fire_pending
	cmd.select_shell = _shell_pending
	_shell_pending = -1
	cmd.repair_requested = _recovery_pending.get("repair",false)
	cmd.extinguish_requested = _recovery_pending.get("extinguish",false)
	cmd.replace_crew_requested = _recovery_pending.get("replace_crew",false)
	cmd.cancel_recovery_requested = _recovery_pending.get("cancel_recovery",false)
	_recovery_pending.clear()
	_fire_pending = false
	return cmd

func require_fire_release() -> void:
	_shell_pending = -1
	_arm_recovery_release()
	# 005-R1-C：重新允许意图前调用——关闭调试面板用的鼠标左键/暂停中按下的 fire
	# 不得被当作开火边沿；若火键此刻仍按住则等到真实释放（保守门）。
	_fire_pending = false
	_need_fire_release = true
	# Input.parse_input_event/accumulated OS input can expose its edge on the next
	# render frame. Observe release only after crossing that input boundary.
	_fire_release_after_frame = Engine.get_process_frames()+1

func reset_pending() -> void:
	_shell_pending = -1
	_recovery_pending.clear()
	_arm_recovery_release()
	# 003-R1：重置清理待发命令（由 VehicleActor.reset_vehicle 与暂停入口调用）；
	# 只清待发边沿，不臂释放门（002 语义：无冷却时 按下→立即合法射击；
	# 门仅由 close_query_debug 的 require_fire_release 臂起，防面板关闭瞬时的按住误射）。
	_fire_pending = false

func _arm_recovery_release() -> void:
	for action in ["repair","extinguish","replace_crew","cancel_recovery"]:
		_recovery_release_guard[action] = true
