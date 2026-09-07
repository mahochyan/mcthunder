class_name CommandMailbox
extends RefCounted
## 003-R2：命令暂存器——"接收命令"与"执行命令"分离。
## submit 只做复制与暂存（不移动、不射击）；每物理步由车辆唯一的
## _physics_process 调用 consume 恰好一次；无暂存时返回零命令
## （保持"无输入=零命令静止"语义，不需要调用方区分）。
## 暂停/重置/解绑时由持有方调用 clear()，恢复不补执行旧请求。

var _staged: VehicleCommand = null

func submit(cmd: VehicleCommand) -> bool:
	# 复制后暂存：调用者提交后修改/复用同一对象不影响暂存内容。
	# 同一物理步内多次提交：最后提交者赢得本步消费。
	if cmd == null:
		return false
	var copy := VehicleCommand.new()
	copy.throttle = cmd.throttle
	copy.steer = cmd.steer
	copy.aim_world_point = cmd.aim_world_point
	copy.has_aim_point = cmd.has_aim_point
	copy.clear_aim = cmd.clear_aim
	copy.aim_held = cmd.aim_held
	copy.fire_requested = cmd.fire_requested
	copy.select_shell = cmd.select_shell
	_staged = copy
	return true

func consume() -> VehicleCommand:
	# 每物理步恰好消费一次；无暂存 → 零命令
	var cmd := _staged
	_staged = null
	if cmd == null:
		cmd = VehicleCommand.new()
	return cmd

func clear() -> void:
	# 暂停/重置/解绑：丢弃未消费请求（不跨暂停/回合生效）
	_staged = null

func has_staged() -> bool:
	return _staged != null