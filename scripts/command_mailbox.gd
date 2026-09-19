class_name CommandMailbox
extends RefCounted
## 003-R2：命令暂存器——"接收命令"与"执行命令"分离（对齐 GPT 参考实现）。
## submit 只做验证/复制/暂存（不移动、不射击）；每物理步由车辆唯一的
## _physics_process 调用 consume 恰好一次；无暂存时返回零命令
## （保持"无输入=零命令静止"语义，不需要调用方区分）。
##
## 同一物理步内多次提交：合并为一个执行命令——驾驶用最新样本，
## 开火请求做逻辑"或"（该步最多消费一次开火边沿）；后续提交未提供
## 显式瞄点操作时，保留此前暂存的瞄点操作。
## 这不是永久保持油门的控制器：脚本需持续提交驾驶意图。
## set_blocked() 清空暂存——只在暂停/恢复等状态切换时调用，不要每帧调用。

var _pending: VehicleCommand = null
var _blocked := false

func set_blocked(value: bool) -> void:
	# 003-R2：暂停/恢复等状态切换的显式清理入口（不依赖已停止的回调自清）
	_blocked = value
	clear()

func clear() -> void:
	_pending = null

func submit(cmd: VehicleCommand) -> bool:
	# 复制后暂存：调用者提交后修改/复用同一对象不影响暂存内容。
	# 验证：阻塞/空命令拒绝；油门/转向非有限整条拒绝；
	# 瞄点非有限整条拒绝；has_aim_point 与 clear_aim 同时置位拒绝。
	if _blocked or cmd == null:
		return false
	if not is_finite(cmd.throttle) or not is_finite(cmd.steer):
		return false
	if cmd.has_aim_point and not cmd.aim_world_point.is_finite():
		return false
	if cmd.has_aim_point and cmd.clear_aim:
		return false
	if cmd.aim_intent==null or not AimIntent.valid_snapshot(cmd.aim_intent.snapshot()) or absi(cmd.zeroing_steps)>20:
		return false
	if cmd.aim_intent.active and cmd.has_aim_point: return false
	if cmd.select_shell < -1 or cmd.select_shell > 7: return false
	if cmd.secondary_fire_index < 0 or cmd.secondary_fire_index > 7: return false
	var copy := VehicleCommand.new()
	copy.throttle = clampf(cmd.throttle, -1.0, 1.0)
	copy.steer = clampf(cmd.steer, -1.0, 1.0)
	copy.has_aim_point = cmd.has_aim_point
	copy.aim_world_point = cmd.aim_world_point
	copy.clear_aim = cmd.clear_aim
	copy.aim_held = cmd.aim_held
	copy.hold_aim = cmd.hold_aim
	copy.aim_intent=cmd.aim_intent.copy()
	copy.range_requested=cmd.range_requested
	copy.apply_range_requested=cmd.apply_range_requested
	copy.zeroing_steps=cmd.zeroing_steps
	copy.select_shell = cmd.select_shell
	copy.cycle_shell_requested = cmd.cycle_shell_requested
	# 同一步多次提交合并：开火做逻辑或；驾驶/炮镜用最新样本；
	# fire-only 的后续提交不覆盖本步已暂存的显式瞄点操作
	copy.fire_requested = cmd.fire_requested
	copy.repair_requested = cmd.repair_requested
	copy.extinguish_requested = cmd.extinguish_requested
	copy.replace_crew_requested = cmd.replace_crew_requested
	copy.cancel_recovery_requested = cmd.cancel_recovery_requested
	# WT-EXPANSION-01 item B step 4: this copy is field by field, so a command field that is not named here is dropped
	# on the last stage before execution. The secondary request is copied AND merged like the main gun's, because the
	# input-path acceptance leg reached the actor with the flag already gone and no error anywhere.
	copy.secondary_fire_requested = cmd.secondary_fire_requested
	copy.secondary_fire_index = cmd.secondary_fire_index
	if _pending != null:
		if copy.select_shell == -1: copy.select_shell = _pending.select_shell
		copy.cycle_shell_requested = copy.cycle_shell_requested or _pending.cycle_shell_requested
		copy.range_requested=copy.range_requested or _pending.range_requested
		copy.apply_range_requested=copy.apply_range_requested or _pending.apply_range_requested
		copy.zeroing_steps=clampi(copy.zeroing_steps+_pending.zeroing_steps,-20,20)
		if not copy.aim_intent.active and not copy.has_aim_point and not copy.clear_aim: copy.aim_intent=_pending.aim_intent.copy()
		copy.fire_requested = copy.fire_requested or _pending.fire_requested
		copy.repair_requested = copy.repair_requested or _pending.repair_requested
		copy.extinguish_requested = copy.extinguish_requested or _pending.extinguish_requested
		copy.replace_crew_requested = copy.replace_crew_requested or _pending.replace_crew_requested
		copy.cancel_recovery_requested = copy.cancel_recovery_requested or _pending.cancel_recovery_requested
		copy.secondary_fire_requested = copy.secondary_fire_requested or _pending.secondary_fire_requested
		# The channel index belongs to the submission that actually asked to fire: a later driving-only sample in the
		# same physics step must not retarget a staged secondary request to another channel.
		if not cmd.secondary_fire_requested and _pending.secondary_fire_requested:
			copy.secondary_fire_index = _pending.secondary_fire_index
		if not copy.has_aim_point and not copy.clear_aim and not copy.aim_intent.active:
			copy.has_aim_point = _pending.has_aim_point
			copy.aim_world_point = _pending.aim_world_point
			copy.clear_aim = _pending.clear_aim
	_pending = copy
	return true

func consume() -> VehicleCommand:
	# 每物理步恰好消费一次；阻塞/无暂存 → 零命令
	if _blocked:
		clear()
		return VehicleCommand.new()
	var cmd := _pending
	_pending = null
	if cmd == null:
		cmd = VehicleCommand.new()
	return cmd

func has_staged() -> bool:
	return _pending != null
